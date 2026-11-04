`timescale 1ns/1ps
`default_nettype none
// 基于v74的整数余数分频，平均Fs严格48kHz。50MHz时BCK半周期为8或9拍，
// 帧间隔为1041或1042拍；这是显式记录的时钟量化变化，不是“整机零抖动”。
// WS翻转后一位发送MSB，32位时隙中16位有效；左右样本同一帧锁存。
module i2s48_stereo #(parameter integer CLK_HZ=50_000_000,SAMPLE_HZ=48_000)(
    input wire clk,rst_n,
    input wire signed [15:0] sample_left,sample_right,
    output reg bck,ws,din,
    output wire frame_tick
);
    localparam integer EDGE_HZ=SAMPLE_HZ*128;
    localparam integer W=$clog2(CLK_HZ+EDGE_HZ);
    reg [W-1:0] accumulator;
    wire [W-1:0] sum=accumulator+EDGE_HZ[W-1:0];
    wire advance=sum>=CLK_HZ;
    reg [5:0] bit_index;
    reg [15:0] left_hold,right_hold;
    assign frame_tick=rst_n&&advance&&!bck&&bit_index==63;
    always @(posedge clk)begin
        if(!rst_n)begin accumulator<=0;bit_index<=0;left_hold<=0;right_hold<=0;bck<=1;ws<=1;din<=0;end
        else if(advance)begin
            accumulator<=sum-CLK_HZ[W-1:0];bck<=!bck;
            if(bck)begin
                ws<=bit_index[5];
                if(bit_index==0)begin left_hold<=sample_left;right_hold<=sample_right;end
                if(bit_index[4:0]>=1&&bit_index[4:0]<=16)
                    din<=bit_index[5] ? right_hold[16-bit_index[4:0]]:left_hold[16-bit_index[4:0]];
                else din<=0;
            end else bit_index<=bit_index+1'b1;
        end else accumulator<=sum;
    end
endmodule
`default_nettype wire
