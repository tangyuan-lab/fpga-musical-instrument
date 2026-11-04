`timescale 1ns/1ps
`include "rtl/damping_defaults.vh"
module tb_damping_audio;
    reg [95:0] settings=`DAMPING_DEFAULTS;
    reg test_pass=0;
    `include "sim/result.svh"
    GSR GSR(.GSRI(1'b1));
    reg clk=0;always #10 clk=~clk;
    reg rst_n=0,panic=0,command_valid=0;
    reg [1:0] command_op=0,command_source=3;
    reg [31:0] command_id=0;
    reg [4:0] command_track=18,command_timbre=10;
    reg [6:0] command_note=60,command_velocity=96;
    reg signed [13:0] bend=0;
    reg parameter_write=0;
    reg mix_valid=0;reg [4:0] mix_track=18;reg [15:0] mix_gain=32768;
    wire command_ready,command_done,sample_valid,deadline_error,parameter_error,mix_ready,mix_done,mix_error;
    wire [2:0] command_result;wire [5:0] voices;wire [31:0] active;wire signed [15:0] pcm;
    integer clock_count=0,frame_count=0,last_tick=0,max_cycles=0,elapsed=0;
    wire tick=clock_count%1041==1040;
    reg [31:0] audible=0;
    unified_models8_32 #(.DAMPING_ENABLE(1),.VELOCITY_TONE_ENABLE(1)) dut(.velocity_tone_setting(2'd0),.damping_settings(settings),.clk(clk),.rst_n(rst_n),.sample_tick(tick),.panic(panic),
        .command_valid(command_valid),.command_ready(command_ready),.command_op(command_op),.command_source(command_source),
        .command_id(command_id),.command_track(command_track),.command_note(command_note),.command_velocity(command_velocity),.command_timbre(command_timbre),
        .custom_ready(8'd0),.bend(bend),.vibrato_depth(8'd0),.vibrato_rate(8'd5),
        .table_write(1'b0),.table_address(11'd0),.table_data(16'd0),.parameter_write(parameter_write),.parameter_bank(5'd10),
        .attack_step(12'd64),.decay_step(12'd8),.sustain_level(12'd3072),.release_step(12'd32),
        .mix_valid(mix_valid),.mix_track(mix_track),.mix_gain(mix_gain),.mix_ready(mix_ready),.mix_done(mix_done),.mix_error(mix_error),
        .sample_valid(sample_valid),.clipped(),.parameter_error(parameter_error),.command_done(command_done),.command_result(command_result),
        .pcm(pcm),.voice_count(voices),.active_mask(active),.deadline_error(deadline_error),.percussion_gain());
    always @(posedge clk)if(rst_n)begin
        clock_count<=clock_count+1;
        if(tick)last_tick<=clock_count;
    end
    always @(negedge clk)if(rst_n)begin
        if((^{sample_valid,deadline_error,parameter_error})===1'bx)$fatal(1,"audio control X");
        if(deadline_error||parameter_error)$fatal(1,"audio errors deadline=%b parameter=%b t=%0t",deadline_error,parameter_error,$time);
        if(sample_valid)begin
            if((^pcm)===1'bx)$fatal(1,"audio PCM X");
            frame_count=frame_count+1;
            elapsed=clock_count-last_tick;
            if(elapsed>max_cycles)max_cycles=elapsed;
            if(elapsed>=1041)$fatal(1,"audio deadline %0d",elapsed);
            for(integer slot=0;slot<32;slot=slot+1)begin
                if((^dut.piano_pcm[slot*16+:16])===1'bx)$fatal(1,"slot X %0d",slot);
                if(dut.piano_pcm[slot*16+:16]!=0)audible[slot]=1;
            end
        end
    end
    task automatic send(input [1:0] op,src,input [31:0] id,input [4:0] track,patch,input [6:0] note,velocity,input [2:0] result);
        integer wait_cycles;
        begin
            @(negedge clk);command_op=op;command_source=src;command_id=id;command_track=track;
            command_timbre=patch;command_note=note;command_velocity=velocity;command_valid=1;
            wait_cycles=0;
            while(command_ready!==1'b1&&wait_cycles<5000)begin @(negedge clk);wait_cycles=wait_cycles+1;end
            if(command_ready!==1'b1)$fatal(1,"command accept timeout");
            @(negedge clk);command_valid=0;wait_cycles=0;
            while(command_done!==1'b1&&wait_cycles<5000)begin @(negedge clk);wait_cycles=wait_cycles+1;end
            if(command_done!==1'b1||command_result!==result)$fatal(1,"command result %0d expected %0d id %0d",command_result,result,id);
        end
    endtask
    task automatic frames(input integer count);
        integer target;
        begin target=frame_count+count;while(frame_count<target)@(negedge clk);end
    endtask
    task automatic clear;
        begin @(negedge clk);panic=1;@(negedge clk);panic=0;repeat(2)@(negedge clk);
            if(voices!==0||active!==0||pcm!==0)$fatal(1,"panic did not clear");audible=0;end
    endtask

    integer output_file, column, row_count=0;
    reg capture=0;
    reg [2047:0] output_path;
    reg [4:0] slots[0:10];
    always @(negedge clk)if(capture&&sample_valid)begin
        for(column=0;column<11;column=column+1)
            $fwrite(output_file,"%0d ",$signed(dut.transition_pcm[slots[column]*16+:16]));
        $fwrite(output_file,"\n");row_count=row_count+1;
    end
    initial begin
        if(!$value$plusargs("PCM=%s",output_path))$fatal(1,"missing PCM path");
        output_file=$fopen(output_path,"w");if(!output_file)$fatal(1,"PCM open");
        repeat(5)@(negedge clk);rst_n=1;clear();
        settings[0+:32]=32'h00000000;
        send(1,3,900,18,10,60,78,0);slots[0]=dut.control.event_slot;frames(2);
        settings[0+:32]=32'h00603460;
        send(1,3,901,18,10,60,78,0);slots[1]=dut.control.event_slot;frames(2);
        settings[0+:32]=32'h00a0d140;
        send(1,3,902,18,10,60,78,0);slots[2]=dut.control.event_slot;frames(2);
        settings[32+:32]=32'h00000000;
        send(1,3,903,18,19,60,78,0);slots[3]=dut.control.event_slot;frames(2);
        settings[32+:32]=32'h00608699;
        send(1,3,904,18,19,60,78,0);slots[4]=dut.control.event_slot;frames(2);
        settings[32+:32]=32'h00a209e1;
        send(1,3,905,18,19,60,78,0);slots[5]=dut.control.event_slot;frames(2);
        settings[32+:32]=32'h00e08699;
        send(1,3,906,18,19,60,78,0);slots[6]=dut.control.event_slot;frames(2);
        settings[64+:32]=32'h00000000;
        send(1,3,907,18,20,36,78,0);slots[7]=dut.control.event_slot;frames(2);
        settings[64+:32]=32'h006055af;
        send(1,3,908,18,20,36,78,0);slots[8]=dut.control.event_slot;frames(2);
        settings[64+:32]=32'h00a139a0;
        send(1,3,909,18,20,36,78,0);slots[9]=dut.control.event_slot;frames(2);
        settings[64+:32]=32'h00e055af;
        send(1,3,910,18,20,36,78,0);slots[10]=dut.control.event_slot;frames(2);
        capture=1;frames(12000);
        send(0,3,900,18,10,60,0,0);
        send(0,3,901,18,10,60,0,0);
        send(0,3,902,18,10,60,0,0);
        send(0,3,903,18,19,60,0,0);
        send(0,3,904,18,19,60,0,0);
        send(0,3,905,18,19,60,0,0);
        send(0,3,906,18,19,60,0,0);
        send(0,3,907,18,20,36,0,0);
        send(0,3,908,18,20,36,0,0);
        send(0,3,909,18,20,36,0,0);
        send(0,3,910,18,20,36,0,0);
        frames(36000);capture=0;$fclose(output_file);
        if(row_count<48000)$fatal(1,"PCM rows");
        test_pass=1;complete_test("tb_damping_audio",11);
        $display("PASS tb_damping_audio rows=%0d max_cycles=%0d",row_count,max_cycles);$finish;
    end
    initial begin #2500000000;$fatal(1,"capture timeout");end
endmodule
