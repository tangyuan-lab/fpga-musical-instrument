`timescale 1ns/1ps
module tb_gain_audit;
    `include "sim/result.svh"
    GSR GSR(.GSRI(1'b1));
    reg clk=0;always #10 clk=~clk;
    reg rst_n=0,tick=0,start=0,master_tick=0;
    reg [6:0] live=80,song=60;reg [255:0] song_gains={16{16'h8000}};
    wire cv,cr,cd,ce,se,init,gd,gl;wire [4:0] owner,read_owner;wire [15:0] target,read_gain;
    workstation_track_mix source(.clk(clk),.rst_n(rst_n),.song_gains(song_gains),.piano_volume(live),.midi_volume(song),
        .command_valid(cv),.command_ready(cr),.command_done(cd),.command_error(ce),.command_owner(owner),.command_gain(target),.error(se));
    track_gain_bank_packed #(.OWNERS(19)) gains(.clk(clk),.rst_n(rst_n),.sample_tick(tick),
        .command_valid(cv),.command_ready(cr),.command_owner(owner),.command_gain(target),.command_done(cd),.command_error(ce),
        .read_owner(read_owner),.read_gain(read_gain),.initialized(init),.frame_done(gd),.deadline_error(gl),.percussion_gain());
    reg [511:0] voice_pcm=0;reg [159:0] tracks=0;wire busy,valid,clip,late;
    wire signed [15:0] mixed,out;wire signed [22:0] raw;wire master_clip;reg [1:0] boost=2;
    voice_postmix_models8_32 mix(.clk(clk),.rst_n(rst_n),.panic(1'b0),.start(start),.voice_pcm(voice_pcm),
        .percussion_mask(32'd0),.percussion_gain(16'h8000),.envelopes({32{15'h7fff}}),.pressures({32{7'd127}}),
        .tracks(tracks),.gain_owner(read_owner),.track_gain(read_gain),.busy(busy),.valid(valid),.clipped(clip),.deadline_error(late),
        .pcm(mixed),.raw_mix(raw),.voice_scaled());
    pcm_master_gain master(.clk(clk),.rst_n(rst_n),.clear(1'b0),.sample_tick(master_tick),.sample_in(mixed),
        .boost(boost),.sample_out(out),.clipped(master_clip),.gain_q8());
    reg signed [15:0] sine[0:31];initial $readmemh("sim/gain_audit_sine.mem",sine);
    integer file,case_id,frame_no,voices=1,source_owner=16,pressure_num=100,phase_spread=0,sample,clock_count;
    reg [2047:0] output_path;reg clipped_frame;
    always @(posedge clk)if(rst_n)begin
        if(se||ce||gl||late)$fatal(1,"gain audit control error");
        if(master_clip)clipped_frame<=1;
    end
    task automatic frame;
        begin
            @(negedge clk);clock_count=0;voice_pcm=0;tracks=0;
            for(integer i=0;i<32;i=i+1)begin
                tracks[i*5+:5]=source_owner==16 ? 16:source_owner==17 ? 17:i%16;
                if(i<voices)begin
                    sample=$signed(sine[(frame_no+(phase_spread?i*2:0))%32]);
                    voice_pcm[i*16+:16]=16'(sample*pressure_num/100);
                end
            end
            tick=1;clipped_frame=0;@(negedge clk);tick=0;clock_count=clock_count+1;
            while(!gd&&clock_count<100)begin @(negedge clk);clock_count=clock_count+1;end
            if(!gd)$fatal(1,"gain frame timeout");
            start=1;@(negedge clk);start=0;clock_count=clock_count+1;
            while(!valid&&clock_count<160)begin @(negedge clk);clock_count=clock_count+1;end
            if(!valid||clip)$fatal(1,"postmix failed");
            master_tick=1;@(negedge clk);master_tick=0;clock_count=clock_count+1;
            repeat(4)begin @(negedge clk);clock_count=clock_count+1;end
            if((^{out,mixed,raw})===1'bx)$fatal(1,"gain audit output X");
            $fwrite(file,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d\n",case_id,frame_no,out,mixed,raw,clipped_frame,
                    gains.gain_mirror[16*16+:16],gains.gain_mirror[0+:16]);
            repeat(1041-clock_count)@(negedge clk);
        end
    endtask
    initial begin
        if(!$value$plusargs("OUT=%s",output_path))$fatal(1,"output path missing");
        file=$fopen(output_path,"w");if(!file)$fatal(1,"output file open");
        repeat(4)@(negedge clk);rst_n=1;wait(init);repeat(1500)@(negedge clk);
        for(case_id=0;case_id<11;case_id=case_id+1)begin
            live=80;song=60;boost=2;voices=1;source_owner=16;pressure_num=100;phase_spread=0;song_gains={16{16'h8000}};
            case(case_id)
                1:source_owner=0;
                2:begin live=100;song=100;end
                3:begin live=100;song=100;source_owner=0;end
                4:begin voices=4;source_owner=0;end
                5:begin voices=16;source_owner=0;end
                6:pressure_num=8;
                7:begin voices=32;source_owner=0;live=100;song=100;boost=3;end
                8:song=0;
                9:begin live=0;source_owner=0;end
                10:begin voices=16;source_owner=0;phase_spread=1;end
            endcase
            for(frame_no=0;frame_no<768;frame_no=frame_no+1)frame();
        end
        $fclose(file);complete_test("tb_gain_audit",11*768);
        $display("PASS tb_gain_audit cases=11 samples=8448 fixed_mix_divisor=32");$finish;
    end
    initial begin #200000000;$fatal(1,"gain audit timeout");end
endmodule
