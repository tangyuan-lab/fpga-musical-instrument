`timescale 1ns/1ps
`default_nettype none
module tb_fx_response;
    `include "sim/result.svh"
    GSR GSR(.GSRI(1'b1));
    reg clk=0;always #10 clk=~clk;
    reg rst_n=0,clear=0,sample_tick=0;
    reg signed [15:0] dry=0,send_in=0;
    reg [6:0] delay_mix=0,reverb_mix=0,feedback=0;
    reg [14:0] delay_samples=12000;
    wire signed [15:0] wet,send_chain,delay_component,reverb_component;
    wire clipped,valid;
    audio_effects #(.SEPARATE_SEND(1)) dut(.*);
    integer checks=0,age,impulse_size=16000,expected,ref_a[0:2047],ref_b[0:3071],a,b;
    task automatic frame(input integer x);
        integer wait_cycles;
        begin
            @(negedge clk);dry=x;send_in=x;sample_tick=1;
            @(negedge clk);sample_tick=0;wait_cycles=0;
            while(valid!==1'b1&&wait_cycles<12)begin @(negedge clk);wait_cycles=wait_cycles+1;end
            if(valid!==1'b1||(^wet)===1'bx||(^delay_component)===1'bx||(^reverb_component)===1'bx||clipped)
                $fatal(1,"FX_RESPONSE invalid/X/clipped");
            repeat(3)@(negedge clk);
        end
    endtask
    task automatic reset_fx;
        begin clear=1;@(negedge clk);clear=0;repeat(260)frame(0);end
    endtask
    initial begin
        repeat(4)@(negedge clk);rst_n=1;
        for(integer c=0;c<3;c=c+1)begin
            delay_samples=c==0 ? 2400:c==1 ? 12000:28800;
            delay_mix=64;feedback=64;reverb_mix=0;reset_fx();
            for(integer i=0;i<=2*delay_samples;i=i+1)begin
                frame(i==0 ? impulse_size:0);
                expected=i==0 ? impulse_size:i==delay_samples ? 8000:i==2*delay_samples ? 4000:0;
                if(wet!==16'(expected))$fatal(1,"DELAY_RESPONSE n=%0d delay=%0d expected=%0d actual=%0d",i,delay_samples,expected,wet);
                checks=checks+1;
            end
        end
        delay_mix=0;feedback=0;reverb_mix=96;reset_fx();
        for(integer i=0;i<2048;i=i+1)ref_a[i]=0;
        for(integer i=0;i<3072;i=i+1)ref_b[i]=0;
        for(integer i=0;i<48000;i=i+1)begin
            a=ref_a[i%2048];b=ref_b[i%3072];
            expected=(i==0 ? impulse_size:0)+(((a+b)*96)>>>7);
            ref_a[i%2048]=(i==0 ? impulse_size:0)+((a*7)>>>3);
            ref_b[i%3072]=(i==0 ? impulse_size:0)+((b*13)>>>4);
            frame(i==0 ? impulse_size:0);
            if(wet!==16'(expected))$fatal(1,"REVERB_RESPONSE n=%0d expected=%0d actual=%0d",i,expected,wet);
            checks=checks+1;
        end
        complete_test("tb_fx_response",checks);
        $display("PASS tb_fx_response delay_50_250_600ms feedback_and_reverb_independent checks=%0d",checks);$finish;
    end
    initial begin #50000000;$fatal(1,"FX_RESPONSE timeout checks=%0d",checks);end
endmodule
`default_nettype wire
