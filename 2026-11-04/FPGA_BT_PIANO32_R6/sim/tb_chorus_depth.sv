`timescale 1ns/1ps
`default_nettype none
module tb_chorus_depth;
    `include "sim/result.svh"
    reg clk=0;always #10 clk=~clk;
    reg rst_n=0,clear=0,sample_tick=0;
    reg signed [15:0] dry=0,send_in=0;
    reg [7:0] mix=0,depth=0,rate=0;
    wire signed [15:0] out,wet_component;wire clipped,valid;
    audio_chorus #(.SEPARATE_SEND(1)) dut(.*);
    integer checks=0,expected0,expected1;
    initial begin
        repeat(3)@(negedge clk);rst_n=1;
        // 独立整数公式覆盖完整参数范围及互补LFO，不使用DUT截位公式作参考。
        for(integer d=0;d<256;d=d+1)begin
            depth=d;
            for(integer x=0;x<256;x=x+1)begin
                @(negedge clk);dut.ph0=x*32768;dut.ph1=(x*32768)^24'h800000;
                #1;expected0=900-((x*d)/128);expected1=900-(((255-x)*d)/128);
                if(dut.delay0!==10'(expected0)||dut.delay1!==10'(expected1))
                    $fatal(1,"CHORUS_DEPTH_WRAP depth=%0d phase=%0d actual=%0d/%0d expected=%0d/%0d",d,x,dut.delay0,dut.delay1,expected0,expected1);
                checks=checks+1;
            end
        end
        complete_test("tb_chorus_depth",checks);
        $display("PASS tb_chorus_depth complete_depth_phase_range checks=%0d",checks);$finish;
    end
    initial begin #3000000;$fatal(1,"CHORUS_DEPTH timeout");end
endmodule
`default_nettype wire
