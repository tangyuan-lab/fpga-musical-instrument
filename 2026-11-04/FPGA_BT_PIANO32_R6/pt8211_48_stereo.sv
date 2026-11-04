`timescale 1ns/1ps
`default_nettype none
// 板载PT8211兼容构建：16位右对齐，左右同帧锁存，平均48kHz。
// 50MHz整数余数分频与v74相同；不把右对齐输出标称为Philips I2S。
module pt8211_48_stereo #(parameter integer CLK_HZ=50_000_000,SAMPLE_HZ=48_000)(
    input wire clk,rst_n,input wire signed [15:0] sample_left,sample_right,
    output reg bck,ws,din,output wire frame_tick
);
    localparam integer EDGE_HZ=SAMPLE_HZ*64,W=$clog2(CLK_HZ+EDGE_HZ);
    reg [W-1:0] acc;wire [W-1:0] sum=acc+EDGE_HZ[W-1:0];wire advance=sum>=CLK_HZ;
    reg [4:0] bit_index;reg [15:0] left_hold,right_hold;
    assign frame_tick=rst_n&&advance&&!bck&&bit_index==31;
    always @(posedge clk)begin
        if(!rst_n)begin acc<=0;bit_index<=0;left_hold<=0;right_hold<=0;bck<=1;ws<=0;din<=0;end
        else if(advance)begin
            acc<=sum-CLK_HZ[W-1:0];bck<=!bck;
            if(bck)begin
                ws<=bit_index[4];
                if(bit_index==0)begin left_hold<=sample_left;right_hold<=sample_right;din<=sample_right[15];end
                else din<=bit_index[4] ? left_hold[15-bit_index[3:0]]:right_hold[15-bit_index[3:0]];
            end else bit_index<=bit_index+1'b1;
        end else acc<=sum;
    end
endmodule
`default_nettype wire
