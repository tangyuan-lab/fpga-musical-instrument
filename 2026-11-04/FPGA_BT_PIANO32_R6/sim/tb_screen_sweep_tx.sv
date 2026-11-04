`timescale 1ns/1ps
module tb_screen_sweep_tx;
    `include "sim/result.svh"
    reg clk=0,rst_n=0;always #10 clk=~clk;
    reg [3:0] view=7;reg [1:0] graph_kind=0;reg freeze_graph=0,right_channel=0;
    reg scope_command_valid=0;reg [7:0] scope_command_op=0,scope_command_value=0;
    reg [6:0] scope_available=32;wire [23:0] scope_pair={12'd2800,12'd1400};reg scope_overflow=0;
    wire scope_pop,scope_clear,scope_capture_enable,tx,graph_lock;wire [5:0] graph_address;
    mega138_screen_tx #(.CLKS_PER_BIT(8),.STARTUP_CYCLES(2),.UPDATE_CYCLES(2000),.STREAM_SUPPORT(1),
        .STREAM_UPDATE_CYCLES(5000),.ACK_TIMEOUT_CYCLES(60000)) dut(
        .clk(clk),.rst_n(rst_n),.view(view),.mode(3'd3),.test_kind(3'd0),.build_id(32'h12345678),
        .voice_mask(32'd0),.timeout_count(32'd0),.revision(32'd99),.voices(6'd0),.peak_voices(6'd0),
        .keys(16'd0),.flags(16'd0),.pressure(192'd0),.result(8'd0),.song_status(224'd0),
        .song_ready(1'b1),.ddr_ready(1'b1),.command_feedback(112'd0),.peaks(64'd0),
        .graph_ready(1'b1),.lock_granted(graph_lock),.graph_data(16'd123),.graph_lock(graph_lock),.graph_address(graph_address),.tx(tx),
        .graph_kind(graph_kind),.freeze_graph(freeze_graph),.right_channel(right_channel),
        .scope_command_valid(scope_command_valid),.scope_command_op(scope_command_op),.scope_command_value(scope_command_value),
        .scope_available(scope_available),.scope_pair(scope_pair),.scope_overflow(scope_overflow),
        .scope_pop(scope_pop),.scope_clear(scope_clear),.scope_capture_enable(scope_capture_enable));
    wire [7:0] b;wire bv;uart_rx #(.CLKS_PER_BIT(8)) monitor(.clk(clk),.rst_n(rst_n),.rx(tx),.data(b),.valid(bv),.framing_error());
    reg [511:0] message=0;integer ff=0,clicks=0,metas=0,seqs=0,pops=0,clears=0,statuses=0,checks=0;
    reg [511:0] last_message=0;integer wait_count,target_clicks;
    always @(posedge clk)begin
        if(scope_pop)pops=pops+1;
        if(scope_clear)clears=clears+1;
        if(bv)begin
            if(b==8'hff)begin
                ff=ff+1;
                if(ff==3)begin
                    last_message=message;
                    if(message=="click wavePlot,1")clicks=clicks+1;
                    if(message=="rxWMeta.val=2")metas=metas+1;
                    if(message=="rxFrame.val=1")seqs=seqs+1;
                    if(message=="rxLink.val=1")statuses=statuses+1;
                    message=0;ff=0;
                end
            end else begin
                if(ff!=0)$fatal(1,"bad command terminator");message=(message<<8)|512'(b);
            end
        end
    end
    task command(input [7:0] op,input [7:0] v);
        begin @(negedge clk);scope_command_valid=1;scope_command_op=op;scope_command_value=v;@(negedge clk);scope_command_valid=0;end
    endtask
    task await_click(input integer target);
        begin wait_count=0;while(clicks<target&&wait_count<600000)begin @(negedge clk);wait_count=wait_count+1;end
            if(clicks<target)$fatal(1,"sweep packet/commit missing target=%0d got=%0d field=%0d state=%0d",target,clicks,dut.field,dut.state);
            repeat(20)@(negedge clk);
        end
    endtask
    task ack;
        begin command(8'h6c,dut.scope_sequence[7:0]);command(8'h6d,dut.scope_sequence[15:8]);end
    endtask
    initial begin
        repeat(5)@(negedge clk);rst_n=1;command(8'h6a,1);await_click(1);
        if(pops!=8||metas!=1||seqs!=1)$fatal(1,"packet must contain 8 stable columns, epoch and final sequence pops=%0d meta=%0d seq=%0d",pops,metas,seqs);
        checks=checks+1;
        // Lost ACK retries only the idempotent commit, never overwrites the data bank.
        await_click(2);if(pops!=8)$fatal(1,"retry must not consume another packet");checks=checks+1;
        command(8'h6c,8'hff);command(8'h6d,0);repeat(100)@(negedge clk);
        if(!dut.waiting_ack)$fatal(1,"wrong ACK released packet");checks=checks+1;
        ack();await_click(3);if(pops!=16)$fatal(1,"next packet not delivered after valid ACK");checks=checks+1;
        freeze_graph=1;ack();repeat(80000)@(negedge clk);
        if(scope_capture_enable||pops!=16)$fatal(1,"freeze failed");checks=checks+1;
        right_channel=1;freeze_graph=0;command(8'h6a,2);await_click(4);ack();
        if(dut.packet_epoch!=2||!dut.packet_channel)$fatal(1,"new channel epoch not tagged");checks=checks+1;
        view=4;repeat(80000)@(negedge clk);if(scope_capture_enable)$fatal(1,"hidden scope must stop capture");checks=checks+1;
        view=7;command(8'h6a,3);await_click(5);ack();scope_overflow=1;repeat(50)@(negedge clk);scope_overflow=0;
        await_click(6);if(!dut.packet_gap)$fatal(1,"loss must tag discontinuity");ack();checks=checks+1;
        command(8'h6a,0);repeat(200000)@(negedge clk);
        if(statuses==0)$fatal(1,"status/heartbeat fields starved");checks=checks+1;
        target_clicks=clicks+3;command(8'h6a,4);await_click(target_clicks);repeat(80000)@(negedge clk);
        if(!dut.scope_fault||scope_capture_enable)$fatal(1,"missing ACK must stop after bounded retries");checks=checks+1;
        target_clicks=clicks+1;command(8'h6a,5);await_click(target_clicks);ack();
        if(dut.scope_fault||!scope_capture_enable)$fatal(1,"new epoch must recover after link fault");checks=checks+1;
        complete_test("tb_screen_sweep_tx",checks);$display("PASS tb_screen_sweep_tx checks=%0d clicks=%0d status=%0d",checks,clicks,statuses);$finish;
    end
endmodule
