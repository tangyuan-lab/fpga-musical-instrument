`timescale 1ns/1ps
`default_nettype none
// MCP3208通道调度与采样发布；SPI位移和引脚时序由独立引擎负责。
// 原MISO两级同步器保留在本层，约束入口保持adc_spi/mcp*_miso_meta。
module mcp3208_dual_scan #(parameter integer HALF_PERIOD=25,parameter [1:0] ADC_PRESENT_MASK=2'b11)(
    input wire clk,rst_n,mcp0_miso,mcp1_miso,
    output wire mcp_sclk,mcp_mosi,mcp0_cs_n,mcp1_cs_n,
    output reg [95:0] samples0,samples1,output reg frame_valid,ready,output wire fault);
    reg [2:0] channel;reg chip;
    (* ASYNC_REG="TRUE" *) reg mcp0_miso_meta,mcp0_miso_sync,mcp1_miso_meta,mcp1_miso_sync;
    wire transfer_done;wire [11:0] sample_data;
    assign fault=ADC_PRESENT_MASK==0&&rst_n;
    mcp3208_spi24 #(.HALF_PERIOD(HALF_PERIOD)) spi(
        .clk(clk),.rst_n(rst_n),.enable(ADC_PRESENT_MASK!=0),.chip(chip),.channel(channel),
        .miso(chip ? mcp1_miso_sync:mcp0_miso_sync),.sclk(mcp_sclk),.mosi(mcp_mosi),
        .cs0_n(mcp0_cs_n),.cs1_n(mcp1_cs_n),.sample_data(sample_data),.done(transfer_done));
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            channel<=0;chip<=!ADC_PRESENT_MASK[0];samples0<=0;samples1<=0;frame_valid<=0;ready<=0;
            mcp0_miso_meta<=0;mcp0_miso_sync<=0;mcp1_miso_meta<=0;mcp1_miso_sync<=0;
        end else begin
            mcp0_miso_meta<=mcp0_miso;mcp0_miso_sync<=mcp0_miso_meta;
            mcp1_miso_meta<=mcp1_miso;mcp1_miso_sync<=mcp1_miso_meta;
            frame_valid<=0;
            if(transfer_done)begin
                if(!chip)samples0[channel*12+:12]<=sample_data;else samples1[channel*12+:12]<=sample_data;
                if(channel==7&&(chip||!ADC_PRESENT_MASK[1]))begin
                    frame_valid<=1;ready<=1;chip<=!ADC_PRESENT_MASK[0];channel<=0;
                end else if(!chip&&channel==7)begin chip<=1;channel<=0;end
                else channel<=channel+1'b1;
            end
        end
    end
endmodule
`default_nettype wire
