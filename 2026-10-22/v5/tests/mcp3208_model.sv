`timescale 1ns/1ps
`default_nettype none

// MCP3208 的最小行为模型，仅用于 RTL 仿真，不用于综合。
//
// 模型按数据手册的 SPI mode 0 时序工作：主机在上升沿送入命令，
// ADC 在第 12 个时钟的下降沿开始推出 B11，主机在第 13～24 个
// 上升沿采到 B11～B0。前两个 DOUT 时钟以及 Null bit 都以 0 表示；
// 这不会改变被测扫描器对有效 12 位结果的采样位置。
module mcp3208_model #(
    parameter [11:0] CH0 = 12'h100,
    parameter [11:0] CH1 = 12'h201,
    parameter [11:0] CH2 = 12'h302,
    parameter [11:0] CH3 = 12'h403,
    parameter [11:0] CH4 = 12'h504,
    parameter [11:0] CH5 = 12'h605,
    parameter [11:0] CH6 = 12'h706,
    parameter [11:0] CH7 = 12'h807
) (
    input  wire       cs_n,
    input  wire       sclk,
    input  wire       mosi,
    output reg        miso
);
    reg [4:0]  rise_count;
    reg        d2;
    reg        d1;
    reg        d0;
    reg [2:0]  selected_channel;
    reg [11:0] active_sample;

    function automatic [11:0] channel_value;
        input [2:0] channel_number;
        begin
            case (channel_number)
                3'd0: channel_value = CH0;
                3'd1: channel_value = CH1;
                3'd2: channel_value = CH2;
                3'd3: channel_value = CH3;
                3'd4: channel_value = CH4;
                3'd5: channel_value = CH5;
                3'd6: channel_value = CH6;
                default: channel_value = CH7;
            endcase
        end
    endfunction

    initial begin
        rise_count       = 5'd0;
        d2               = 1'b0;
        d1               = 1'b0;
        d0               = 1'b0;
        selected_channel = 3'd0;
        active_sample    = 12'd0;
        miso             = 1'b0;
    end

    // CS 的上升沿结束一次转换；下一次 CS 拉低时重新从命令第 1 位开始。
    always @(negedge cs_n) begin
        rise_count       = 5'd0;
        d2               = 1'b0;
        d1               = 1'b0;
        d0               = 1'b0;
        selected_channel = 3'd0;
        active_sample    = 12'd0;
        miso             = 1'b0;
    end

    // MCP3208 在上升沿接收 DIN。命令前 5 位是补零，随后是
    // Start、SGL/DIFF、D2、D1、D0；因此 D2/D1/D0 出现在第 8/9/10 个上升沿。
    always @(posedge sclk) begin
        if (!cs_n) begin
            if (rise_count == 5'd7)
                d2 = mosi;
            else if (rise_count == 5'd8)
                d1 = mosi;
            else if (rise_count == 5'd9)
                d0 = mosi;
            rise_count = rise_count + 1'b1;
        end
    end

    // 数据手册规定 B11 在第 12 个时钟的下降沿推出，随后每个下降沿
    // 推出下一位。因此上升沿 13～24 正好对应 B11～B0。
    always @(negedge sclk) begin
        if (!cs_n) begin
            if (rise_count == 5'd12) begin
                selected_channel = {d2, d1, d0};
                active_sample    = channel_value({d2, d1, d0});
                // 不能直接对函数调用结果做位选，使用已经锁存的寄存器
                // 可同时兼容 Icarus、ModelSim 和 Gowin 仿真器。
                miso             = active_sample[11];
            end else if ((rise_count >= 5'd13) && (rise_count <= 5'd23)) begin
                miso = active_sample[23-rise_count];
            end else begin
                // 前导高阻、Null bit 和转换结束后的无效时间在本模型中拉低。
                miso = 1'b0;
            end
        end
    end
endmodule

`default_nettype wire
