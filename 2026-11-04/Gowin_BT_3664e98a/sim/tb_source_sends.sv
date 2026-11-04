`timescale 1ns/1ps
module tb_source_sends;
    `include "sim/result.svh"
    reg clk=0;always #10 clk=~clk;
    reg rst_n=0,start=0,clear=0;reg [511:0] samples=0;reg [159:0] tracks=0;
    wire valid,busy,clip,late;wire signed [15:0] dry;wire signed [22:0] raw,live,song;
    wire [4:0] owner;
    voice_postmix_models8_32 mix(.clk(clk),.rst_n(rst_n),.panic(clear),.start(start),.voice_pcm(samples),.percussion_mask(32'd0),
        .percussion_gain(16'h8000),.envelopes({32{15'h7fff}}),.pressures({32{7'd127}}),.tracks(tracks),.gain_owner(owner),
        .track_gain(16'h8000),.busy(busy),.valid(valid),.clipped(clip),.deadline_error(late),.pcm(dry),.raw_mix(raw),.raw_live(live),.raw_song(song),.voice_scaled());
    reg [7:0] lt=128,st=128;wire [7:0] lg,sg;wire signed [15:0] send_out;wire send_valid,send_clip;
    pcm_source_sends dut(.clk(clk),.rst_n(rst_n),.clear(clear),.sample_tick(valid),.raw_mix(raw),.raw_live(live),.raw_song(song),
        .live_target(lt),.song_target(st),.live_gain(lg),.song_gain(sg),.pcm(send_out),.valid(send_valid),.clipped(send_clip));
    integer checks=0,expected_live,expected_song,expected_raw,value,track,expected_send;
    task automatic frame(input integer index);
        begin
            expected_live=0;expected_song=0;expected_raw=0;
            @(negedge clk);
            for(integer i=0;i<32;i=i+1)begin
                value=((index*571+i*5237)%60001)-30000;track=(i+index)%19;
                samples[i*16+:16]=16'(value);tracks[i*5+:5]=5'(track);expected_raw=expected_raw+value;
                if(track<16)expected_song=expected_song+value;else if(track<18)expected_live=expected_live+value;
            end
            start=1;@(negedge clk);start=0;wait(valid);@(negedge clk);
            if(live!=expected_live||song!=expected_song||raw!=expected_raw||dry!==(16'(expected_raw>>>5))||late||clip)$fatal(1,"source grouping mismatch");
            wait(send_valid);@(negedge clk);
            expected_send=(expected_live*32'(lg)+expected_song*32'(sg)+(expected_raw-expected_live-expected_song)*128)>>>12;
            if(send_out!==16'(expected_send)||send_clip)$fatal(1,"source send output mismatch got=%0d expected=%0d",send_out,expected_send);
            if(lg==128&&sg==128&&send_out!==dry)$fatal(1,"unity sends changed original dry mix");
            checks=checks+1;repeat(3)@(negedge clk);
        end
    endtask
    initial begin
        repeat(4)@(negedge clk);rst_n=1;
        for(integer i=0;i<40;i=i+1)frame(i);
        lt=0;for(integer i=40;i<180;i=i+1)frame(i);
        if(lg!=0||sg!=128)$fatal(1,"live send did not settle independently");
        lt=128;st=0;for(integer i=180;i<320;i=i+1)frame(i);
        if(lg!=128||sg!=0)$fatal(1,"song send did not settle independently");
        clear=1;@(negedge clk);clear=0;frame(321);
        complete_test("tb_source_sends",checks);$display("PASS tb_source_sends frames=%0d grouping_19_owners=1 unity_bit_exact=1",checks);$finish;
    end
    initial begin #5000000;$fatal(1,"timeout");end
endmodule
