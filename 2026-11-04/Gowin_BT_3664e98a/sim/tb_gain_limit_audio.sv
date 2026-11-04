`timescale 1ns/1ps
module tb_gain_limit_audio;
    `include "sim/result.svh"
    reg clk=0;always #10 clk=~clk;
    reg rst_n=0,tick=0;reg signed [15:0] sample=0;
    wire signed [15:0] bypass,protected_pcm;wire valid,clipped,limited;wire [15:0] gain;
    wire [18:0] pre,post;
    pcm_master_gain baseline(.clk(clk),.rst_n(rst_n),.clear(1'b0),.sample_tick(tick),.sample_in(sample),.boost(2'd3),
        .sample_out(bypass),.clipped(),.gain_q8(),.limiter_enabled(1'b0),.limiter_release(2'd1),.valid(),.limited(),.limiter_gain(),.peak_in(),.peak_out());
    pcm_master_gain #(.LIMITER_CAPABLE(1)) dut(.clk(clk),.rst_n(rst_n),.clear(1'b0),.sample_tick(tick),.sample_in(sample),.boost(2'd3),
        .sample_out(protected_pcm),.clipped(clipped),.gain_q8(),.limiter_enabled(1'b1),.limiter_release(2'd1),.valid(valid),.limited(limited),.limiter_gain(gain),.peak_in(pre),.peak_out(post));
    reg signed [15:0] source[0:143999];reg [2047:0] input_path,output_path;
    integer file;
    task automatic frame;
        begin @(negedge clk);tick=1;@(negedge clk);tick=0;repeat(40)@(negedge clk);end
    endtask
    initial begin
        if(!$value$plusargs("INPUT=%s",input_path)||!$value$plusargs("OUT=%s",output_path))$fatal(1,"audio paths required");
        $readmemh(input_path,source);file=$fopen(output_path,"w");if(!file)$fatal(1,"output open");
        repeat(4)@(negedge clk);rst_n=1;repeat(160)frame();
        for(integer i=0;i<144000;i=i+1)begin
            sample=source[i];frame();
            if(clipped||protected_pcm>30000||protected_pcm< -30000)$fatal(1,"limiter audio exceeded ceiling");
            $fwrite(file,"%0d,%0d,%0d,%0d,%0d\n",sample,bypass,protected_pcm,gain,pre);
        end
        $fclose(file);complete_test("tb_gain_limit_audio",144000);$display("PASS tb_gain_limit_audio samples=144000 ceiling=30000");$finish;
    end
    initial begin #200000000;$fatal(1,"audio timeout");end
endmodule
