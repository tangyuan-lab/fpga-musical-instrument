`timescale 1ns/1ps
module tb_velocity_tone_bypass;
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
    unified_models8_32 dut(.clk(clk),.rst_n(rst_n),.sample_tick(tick),.panic(panic),
        .command_valid(command_valid),.command_ready(command_ready),.command_op(command_op),.command_source(command_source),
        .command_id(command_id),.command_track(command_track),.command_note(command_note),.command_velocity(command_velocity),.command_timbre(command_timbre),
        .custom_ready(8'd0),.bend(bend),.vibrato_depth(8'd0),.vibrato_rate(8'd5),
        .table_write(1'b0),.table_address(11'd0),.table_data(16'd0),.parameter_write(parameter_write),.parameter_bank(5'd10),
        .attack_step(12'd64),.decay_step(12'd8),.sustain_level(12'd3072),.release_step(12'd32),
        .mix_valid(mix_valid),.mix_track(mix_track),.mix_gain(mix_gain),.mix_ready(mix_ready),.mix_done(mix_done),.mix_error(mix_error),
        .sample_valid(sample_valid),.clipped(),.parameter_error(parameter_error),.command_done(command_done),.command_result(command_result),
        .pcm(pcm),.voice_count(voices),.active_mask(active),.deadline_error(deadline_error),.percussion_gain());
    wire new_ready,new_done,new_valid,new_deadline,new_parameter;wire [2:0] new_result;
    wire signed [15:0] new_pcm;wire [5:0] new_voices;wire [31:0] new_active;
    unified_models8_32 #(.DAMPING_ENABLE(1),.VELOCITY_TONE_ENABLE(1)) candidate(.velocity_tone_setting(2'd0),.damping_settings(96'd0),
        .clk(clk),.rst_n(rst_n),.sample_tick(tick),.panic(panic),
        .command_valid(command_valid),.command_ready(new_ready),.command_op(command_op),.command_source(command_source),
        .command_id(command_id),.command_track(command_track),.command_note(command_note),.command_velocity(command_velocity),.command_timbre(command_timbre),
        .custom_ready(8'd0),.bend(bend),.vibrato_depth(8'd0),.vibrato_rate(8'd5),
        .table_write(1'b0),.table_address(11'd0),.table_data(16'd0),.parameter_write(parameter_write),.parameter_bank(5'd10),
        .attack_step(12'd64),.decay_step(12'd8),.sustain_level(12'd3072),.release_step(12'd32),
        .mix_valid(mix_valid),.mix_track(mix_track),.mix_gain(mix_gain),.mix_ready(),.mix_done(),.mix_error(),
        .sample_valid(new_valid),.clipped(),.parameter_error(new_parameter),.command_done(new_done),.command_result(new_result),
        .pcm(new_pcm),.voice_count(new_voices),.active_mask(new_active),.deadline_error(new_deadline),.percussion_gain(),.chord_status());
    always @(negedge clk)if(rst_n)begin
        if({command_ready,command_done,sample_valid,deadline_error,parameter_error,pcm,voices,active} !==
           {new_ready,new_done,new_valid,new_deadline,new_parameter,new_pcm,new_voices,new_active})
            $fatal(1,"legacy bypass is not cycle/sample exact");
        if(command_done&&command_result!==new_result)$fatal(1,"legacy event result differs");
    end
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
    integer config_index,i;reg [4:0] patch;reg [6:0] note;
    initial begin
        repeat(5)@(negedge clk);rst_n=1;
        for(config_index=0;config_index<6;config_index=config_index+1)begin
            for(i=0;i<32;i=i+1)begin
                patch=config_index==0 ? 10:config_index==1||config_index==4 ? 19:config_index==2||config_index==5 ? 20:(i%3==0 ? 10:i%3==1 ? 19:20);
                note=patch==20 ? 28+i%16:60+i%16;
                if(config_index==4)note=note+12;
                if(config_index==5)note=note+24;
                send(1,3,100+i,18,patch,note,96,0);
            end
            frames(64);
            if(voices!==32||audible!==32'hffffffff)$fatal(1,"full32 config=%0d count=%0d audible=%h",config_index,voices,audible);
            $display("CHECK full32 config=%0d frames=64 audible=%h",config_index,audible);
            clear();
        end
        // 新音抢占旧ID后，旧松键必须返回未命中，不能释放新音。
        for(i=0;i<32;i=i+1)send(1,3,300+i,18,10,60+i%12,96,0);
        send(1,3,999,18,10,72,100,0);
        send(0,3,300,18,10,60,0,1);
        send(3,3,999,18,10,73,40,0);bend=200;frames(4);bend=0;
        if(voices!==32)$fatal(1,"stale release corrupted new voice");
        clear();
        send(1,2,20,7,19,60,100,0);send(1,0,21,16,10,64,100,0);frames(4);
        begin:check_tracks
            integer found_song,found_live;
            found_song=0;found_live=0;
            for(integer s=0;s<32;s=s+1)if(active[s])begin
                if(dut.tracks[s*5+:5]===7)found_song=found_song+1;
                if(dut.tracks[s*5+:5]===16)found_live=found_live+1;
            end
            if(found_song!=1||found_live!=1)$fatal(1,"track ownership lost song=%0d live=%0d",found_song,found_live);
        end
        send(0,2,20,7,19,60,0,0);frames(520);
        if(voices!==1)$fatal(1,"guitar tail did not finish independently count=%0d",voices);
        clear();
        send(1,0,501,16,10,60,96,0);send(1,1,502,17,19,64,96,0);send(1,0,503,16,20,67,96,0);
        send(1,2,504,0,10,61,96,0);frames(4);
        if(dut.chord_status[11:0]!==12'h091 || dut.chord_status[27:24]!==3 || dut.chord_status[15:12]!==0)
            $fatal(1,"accepted live chord/exclude song %h",dut.chord_status);
        send(0,1,502,17,19,64,0,0);frames(4);
        if(dut.chord_status[27:24]!==2 || dut.chord_status[4])$fatal(1,"released tail included in chord");
        clear();frames(4);
        @(negedge clk);parameter_write=1;@(negedge clk);parameter_write=0;
        send(1,0,601,16,10,60,96,0);frames(3);
        begin:check_envelope
            integer found;found=0;
            for(integer s=0;s<32;s=s+1)if(active[s])begin
                if(!dut.control.voice_adsr[s]||dut.envelopes[s*15+:15]==0||dut.envelopes[s*15+:15]>=32767)
                    $fatal(1,"ADSR capture/update did not progress");
                found=found+1;
            end
            if(found!=1)$fatal(1,"ADSR live voice missing");
        end
        send(0,0,601,16,10,60,0,0);frames(64);
        if(voices!=0)$fatal(1,"ADSR release did not retire voice");
        test_pass=1;complete_test("tb_velocity_tone_bypass",12);$display("PASS tb_velocity_tone_bypass full32=6 configurations max_cycles=%0d frames=%0d",max_cycles,frame_count);$finish;
    end
    initial begin #50000000;$fatal(1,"audio regression timeout");end
endmodule
