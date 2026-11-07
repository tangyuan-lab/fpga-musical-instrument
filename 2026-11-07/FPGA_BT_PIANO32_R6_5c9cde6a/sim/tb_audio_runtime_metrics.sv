`timescale 1ns/1ps
`default_nettype none
module tb_audio_runtime_metrics;
    `include "sim/result.svh"
    reg clk=0;always #10 clk=~clk;
    reg rst_n=0,clear=0,sample_tick=0,sample_valid=0;
    reg [5:0] completed_voices=32,active_voices=32;
    wire [511:0] snapshot;
    audio_runtime_metrics #(.WINDOW_CYCLES(1000)) dut(.*);
    initial begin
        repeat(3)@(negedge clk);rst_n=1;
        for(integer i=0;i<1000;i=i+1)begin
            sample_tick=i%100==0;sample_valid=i%100==75;@(negedge clk);
        end
        sample_tick=0;sample_valid=0;
        if(snapshot[31:0]!=1000||snapshot[63:32]!=10||snapshot[95:64]!=10||
           snapshot[127:96]!=320||snapshot[159:128]!=40||snapshot[191:160]!=100||
           snapshot[223:192]!=100||snapshot[255:224]!=75||snapshot[319:256]!=0)
            $fatal(1,"AUDIO_METRICS actual counters mismatch %h",snapshot);
        // 漏帧和重复返回必须分别累计，不得只依据输出时钟声称合成吞吐通过。
        sample_tick=1;@(negedge clk);sample_tick=0;repeat(10)@(negedge clk);
        sample_tick=1;@(negedge clk);sample_tick=0;sample_valid=1;@(negedge clk);
        @(negedge clk);sample_valid=0;
        repeat(1000)@(negedge clk);
        if(snapshot[287:256]!=1||snapshot[319:288]!=1)$fatal(1,"AUDIO_METRICS loss/extra missing");
        complete_test("tb_audio_runtime_metrics",12);$display("PASS tb_audio_runtime_metrics rates_voice_samples_pcm_bytes_loss_extra");$finish;
    end
    initial begin #100000;$fatal(1,"metrics timeout");end
endmodule
`default_nettype wire
