`timescale 1ns/1ps
// Production 115200 UART, 48kHz capture and real five-byte screen ACKs.
module tb_screen_sweep_wire #(parameter integer WORST_STATUS=1);
    `include "sim/result.svh"
    GSR GSR(.GSRI(1'b1));
    reg clk=0,rst_n=0;always #10 clk=~clk;
    reg sample_tick=0,screen_rx=1;reg signed [15:0] left=0,right=0;
    wire [23:0] scope_pair;wire [6:0] scope_available;wire scope_overflow,scope_pop,scope_clear,scope_capture_enable;
    screen_scope_capture cap(.clk(clk),.rst_n(rst_n),.clear(scope_clear),.enable(scope_capture_enable),
        .sample_tick(sample_tick),.right_channel(1'b0),.pop(scope_pop),.left(left),.right(right),
        .pair_data(scope_pair),.available(scope_available),.overflow(scope_overflow));
    wire command_valid;wire [7:0] command_op,command_value;wire [15:0] held_keys;
    screen_touch_keys_rx #(.CLKS_PER_BIT(434),.KEY_COUNT(16),.WORKSTATION_CONTROLS(1)) touch(
        .clk(clk),.rst_n(rst_n),.screen_rx_i(screen_rx),.held_keys(held_keys),.rx_activity(),.frame_error(),
        .octave_shift(),.test_mode(),.command_valid(command_valid),.command_op(command_op),.command_value(command_value));
    wire tx,graph_lock;wire [5:0] graph_address;
    mega138_screen_tx #(.CLKS_PER_BIT(434),.STARTUP_CYCLES(2),.STREAM_SUPPORT(1)) dut(
        .clk(clk),.rst_n(rst_n),.view(4'd7),.mode(3'd3),.test_kind(3'd0),.build_id(32'hffffffff),
        .voice_mask(WORST_STATUS ? 32'hffffffff:32'd0),.timeout_count(WORST_STATUS ? 32'hffffffff:32'd0),
        .revision(32'd1),.voices(6'd32),.peak_voices(6'd32),
        .keys(held_keys),.flags(16'hffff),.pressure(WORST_STATUS ? {192{1'b1}}:192'd0),.result(8'd255),
        .song_status(WORST_STATUS ? {224{1'b1}}:224'd0),.song_ready(1'b1),
        .ddr_ready(1'b1),.command_feedback({112{1'b1}}),.peaks({64{1'b1}}),.graph_ready(1'b1),.lock_granted(graph_lock),
        .graph_data(16'd0),.graph_lock(graph_lock),.graph_address(graph_address),.tx(tx),
        .graph_kind(2'd0),.freeze_graph(1'b0),.right_channel(1'b0),
        .scope_command_valid(command_valid),.scope_command_op(command_op),.scope_command_value(command_value),
        .scope_available(scope_available),.scope_pair(scope_pair),.scope_overflow(scope_overflow),
        .scope_pop(scope_pop),.scope_clear(scope_clear),.scope_capture_enable(scope_capture_enable));
    wire [7:0] b;wire bv,framing;
    uart_rx #(.CLKS_PER_BIT(434)) monitor(.clk(clk),.rst_n(rst_n),.rx(tx),.data(b),.valid(bv),.framing_error(framing));
    integer sample_clock=0,sample_index=0,reference_count=0,reference_low=0,reference_high=0,amplitude=0;
    integer expected[0:4095];integer qwrite=0,qread=0,bank[0:7];integer sequence_value=0,meta=0;
    integer ff=0,bytes_count=0,commits=0,checks=0,max_buffer=0,seen_keys=0,trace_handle=0;
    reg [511:0] message=0;string text;integer decoded,i,ignored;
    time first_commit=0,last_commit=0;real rate,bytes_per_second;
    event committed;
    reg [2047:0] trace_path;
    always @(negedge clk)begin
        sample_tick=0;
        if(rst_n)begin
            if(sample_clock==1041)begin
                sample_clock=0;sample_tick=1;sample_index=sample_index+1;
                amplitude=1500*(12000-sample_index%12000)/12000;
                left=sample_index%197<99 ? amplitude:-amplitude;
                if(sample_index%997==0)left=32767;right=-left;
            end else sample_clock=sample_clock+1;
        end
    end
    always @(posedge clk)if(rst_n)begin
        if(scope_clear)begin reference_count=0;qwrite=0;qread=0;end
        else if(scope_capture_enable && sample_tick)begin
            if(reference_count==0)begin reference_low=left;reference_high=left;end
            else begin if(left<reference_low)reference_low=left;if(left>reference_high)reference_high=left;end
            reference_count=reference_count+1;
            if(reference_count==192)begin
                reference_count=0;expected[qwrite]=((reference_high+32768)/16)*4096+(reference_low+32768)/16;qwrite=qwrite+1;
            end
        end
        if(scope_available>max_buffer)max_buffer=scope_available;
        if(held_keys[0])seen_keys=1;
        if(scope_overflow||dut.scope_fault||framing)$fatal(1,"production-rate link overflow/fault/framing");
        if(bv)begin
            bytes_count=bytes_count+1;
            if(b==255)begin
                ff=ff+1;
                if(ff==3)begin
                    text=$sformatf("%0s",message);
                    for(i=0;i<8;i=i+1)begin
                        case(i)
                            0:decoded=$sscanf(text,"rxG00.val=%d",bank[i]);1:decoded=$sscanf(text,"rxG01.val=%d",bank[i]);
                            2:decoded=$sscanf(text,"rxG02.val=%d",bank[i]);3:decoded=$sscanf(text,"rxG03.val=%d",bank[i]);
                            4:decoded=$sscanf(text,"rxG04.val=%d",bank[i]);5:decoded=$sscanf(text,"rxG05.val=%d",bank[i]);
                            6:decoded=$sscanf(text,"rxG06.val=%d",bank[i]);7:decoded=$sscanf(text,"rxG07.val=%d",bank[i]);
                        endcase
                    end
                    ignored=$sscanf(text,"rxFrame.val=%d",sequence_value);ignored=$sscanf(text,"rxWMeta.val=%d",meta);
                    if(message=="click wavePlot,1")begin
                        if(meta!=2)$fatal(1,"metadata epoch/gap mismatch %0d",meta);
                        for(i=0;i<8;i=i+1)begin
                            if(qread+i>=qwrite||bank[i]!=expected[qread+i])$fatal(1,"wire data missing/reordered column=%0d actual=%0d expected=%0d",qread+i,bank[i],expected[qread+i]);
                            checks=checks+1;
                        end
                        qread=qread+8;commits=commits+1;
                        if(first_commit==0)first_commit=$time;last_commit=$time;
                        $fwrite(trace_handle,"%0d,%0d,%0d",$time,sequence_value,meta);
                        for(i=0;i<8;i=i+1)$fwrite(trace_handle,",%0d",bank[i]);$fwrite(trace_handle,"\n");
                        ->committed;
                    end
                    message=0;ff=0;
                end
            end else begin if(ff!=0)$fatal(1,"malformed ASCII terminator");message=(message<<8)|512'(b);end
        end
    end
    task send_byte(input [7:0] v);
        integer k;
        begin screen_rx=0;repeat(434)@(negedge clk);for(k=0;k<8;k=k+1)begin screen_rx=v[k];repeat(434)@(negedge clk);end
            screen_rx=1;repeat(434)@(negedge clk);end
    endtask
    task command(input [7:0] op,input [7:0] value);
        begin send_byte(8'ha5);send_byte(8'h5a);send_byte(op);send_byte(value);send_byte(8'hff^op^value);end
    endtask
    initial begin
        wait(rst_n);repeat(100)@(negedge clk);command(8'h6a,1);
        forever begin
            @committed;
            // Model a 5ms screen draw and ACK on the actual serial wire.
            repeat(250000)@(negedge clk);
            command(8'h6c,8'(sequence_value));command(8'h6d,8'(sequence_value>>8));
            if(commits==6)command(1,0);
            if(commits==10)command(0,0);
        end
    end
    initial begin
        if(!$value$plusargs("SWEEP_CSV=%s",trace_path))$fatal(1,"missing CSV path");
        trace_handle=$fopen(trace_path,"w");$fwrite(trace_handle,"time_ns,sequence,meta,g0,g1,g2,g3,g4,g5,g6,g7\n");
        repeat(5)@(negedge clk);rst_n=1;
        repeat(60000000)begin
            @(negedge clk);
            if(commits>=24)begin
                rate=(commits-1)*1.0e9/(last_commit-first_commit);bytes_per_second=bytes_count*1.0e9/last_commit;
                if(rate<25||rate>32||bytes_per_second>10000||max_buffer>=64||!seen_keys||held_keys!=0)
                    $fatal(1,"not smooth at115200 rate=%f bytes/s=%f maxQ=%0d keyseen=%0d held=%h",rate,bytes_per_second,max_buffer,seen_keys,held_keys);
                $fclose(trace_handle);complete_test("tb_screen_sweep_wire",checks+4);
                $display("PASS tb_screen_sweep_wire commits=%0d rate=%f bytes_per_second=%f max_queue=%0d checks=%0d",commits,rate,bytes_per_second,max_buffer,checks+4);$finish;
            end
        end
        $fatal(1,"real-rate sweep did not complete");
    end
endmodule
