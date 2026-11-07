`timescale 1ns/1ps
`default_nettype none
// 兼容鼓通路的后级音量；逐拍流水计算，不改变鼓的原始力度或尾音状态。
module pcm_percent_gain #(parameter integer DIRECT_GAIN=0)(
    input wire clk,rst_n,clear,input wire signed [15:0] sample_in,input wire [6:0] volume,input wire [15:0] gain_in,
    output reg signed [15:0] sample_out
);
    reg [31:0] scale_product;reg [15:0] gain;reg signed [15:0] delayed0,delayed1;
    reg signed [32:0] product;
    always @(posedge clk)begin
        if(!rst_n||clear)begin scale_product<=0;gain<=0;delayed0<=0;delayed1<=0;product<=0;sample_out<=0;end
        else begin
            scale_product<=(volume>100 ? 7'd100:volume)*32'd21474836;
            gain<=16'((scale_product+32768)>>16);delayed0<=sample_in;delayed1<=delayed0;
            product<=delayed1*$signed({1'b0,DIRECT_GAIN ? gain_in:gain});
            sample_out<=product>>>15;
        end
    end
endmodule
`default_nettype wire
