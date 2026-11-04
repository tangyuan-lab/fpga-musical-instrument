`timescale 1ns/1ps
`include "sim/audio_effects_46274_reference.sv"
`include "sim/audio_chorus_46274_reference.sv"
`include "sim/pcm_master_gain_46274_reference.sv"
module tb_gain_fx_bypass;
    `include "sim/result.svh"
    GSR GSR(.GSRI(1'b1));
    reg clk=0;always #10 clk=~clk;
    reg rst_n=0,clear=0,tick=0;reg signed [15:0] dry=0,send_in=0;
    reg [6:0] delay_mix=0,reverb_mix=0,feedback=31;reg [11:0] delay_samples=31;
    reg [7:0] chorus_mix=0,depth=17,rate=50;reg [1:0] boost=2;
    wire signed [15:0] a,b,sa,ca,cb,oa,ob;
    audio_effects_46274_reference ref_fx(.clk(clk),.rst_n(rst_n),.sample_tick(tick),.clear(clear),.dry(dry),
        .delay_mix(delay_mix),.reverb_mix(reverb_mix),.feedback(feedback),.delay_samples(delay_samples),.wet(a));
    audio_effects #(.SEPARATE_SEND(1)) new_fx(.clk(clk),.rst_n(rst_n),.sample_tick(tick),.clear(clear),.dry(dry),.send_in(send_in),
        .delay_mix(delay_mix),.reverb_mix(reverb_mix),.feedback(feedback),.delay_samples(delay_samples),.wet(b),.send_chain(sa),.clipped(),.valid());
    audio_chorus_46274_reference ref_ch(.clk(clk),.rst_n(rst_n),.sample_tick(tick),.clear(clear),.dry(a),.mix(chorus_mix),.depth(depth),.rate(rate),.out(ca));
    audio_chorus #(.SEPARATE_SEND(1)) new_ch(.clk(clk),.rst_n(rst_n),.sample_tick(tick),.clear(clear),.dry(b),.send_in(sa),.mix(chorus_mix),.depth(depth),.rate(rate),.out(cb),.clipped(),.valid());
    pcm_master_gain_46274_reference ref_master(.clk(clk),.rst_n(rst_n),.clear(clear),.sample_tick(tick),.sample_in(ca),.boost(boost),.sample_out(oa),.clipped(),.gain_q8());
    pcm_master_gain #(.LIMITER_CAPABLE(1)) new_master(.clk(clk),.rst_n(rst_n),.clear(clear),.sample_tick(tick),.sample_in(cb),.boost(boost),.sample_out(ob),.clipped(),.gain_q8(),
        .limiter_enabled(1'b0),.limiter_release(2'd1),.valid(),.limited(),.limiter_gain(),.peak_in(),.peak_out());
    integer checks=0;reg signed [15:0] expected_direct;
    task automatic frame(input integer index,input bit unity);
        begin
            @(negedge clk);dry=16'(((index*2371)%58001)-29000);send_in=unity?dry:0;
            tick=1;expected_direct=dry;@(negedge clk);tick=0;repeat(10)@(negedge clk);
            if(unity)begin
                if(a!==b||b!==sa||ca!==cb||oa!==ob)$fatal(1,"unity FX or master bypass changed baseline sample %0d",index);
            end else if(b!==expected_direct||sa!==0)$fatal(1,"zero sends changed dry or injected new wet sample %0d",index);
            checks=checks+1;
        end
    endtask
    initial begin
        repeat(4)@(negedge clk);rst_n=1;
        for(integer i=0;i<6500;i=i+1)begin
            if(i%401==0)boost=2'(i/401);
            if(i==3000)begin clear=1;@(negedge clk);clear=0;end
            frame(i,1);
        end
        clear=1;@(negedge clk);clear=0;
        for(integer i=0;i<6500;i=i+1)frame(i,0);
        complete_test("tb_gain_fx_bypass",checks);$display("PASS tb_gain_fx_bypass frames=%0d unity_postmix_pcm_bit_exact=1 zero_sends_keep_dry=1 dry_bypass_only=1 corrected_wet_path_verified_separately=1",checks);$finish;
    end
    initial begin #10000000;$fatal(1,"timeout");end
endmodule
