`timescale 1ns/1ps
// 仅用于测试：采样保持阶段锁存动态输入，按真实 SPI 边沿发送 12 位结果。
module mcp3208_dynamic_model(
    input wire cs_n,sclk,mosi,input wire [95:0] values,output reg miso=0
);
    integer rises=0;
    reg [2:0] channel=0;
    reg [11:0] sample_value=0;
    always @(negedge cs_n) begin rises=0; channel=0; sample_value=0; miso=0; end
    always @(posedge sclk) if(!cs_n) begin
        if(rises>=7 && rises<=9) channel={channel[1:0],mosi};
        rises=rises+1;
    end
    always @(negedge sclk) if(!cs_n) begin
        if(rises==12) begin sample_value=values[channel*12+:12]; miso=sample_value[11]; end
        else if(rises>=13 && rises<=23) miso=sample_value[23-rises];
        else miso=0;
    end
endmodule
