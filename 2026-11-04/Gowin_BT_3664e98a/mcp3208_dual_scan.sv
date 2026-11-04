`timescale 1ns/1ps
`default_nettype none

// 两片 MCP3208 的连续扫描器。
//
// MCP3208 使用 SPI mode 0/0：SCLK 空闲为低，DIN 在下降沿附近更新，
// DOUT 在下降沿更新并由主机在上升沿采样。每个通道固定发送 24 个时钟：
// 5 个前导/命令位、采样保持位、空位和 12 位转换结果。每次转换都重新拉低
// CS，符合 MCP3208 要求的“一个 CS 对应一次转换”。
//
// 两片 ADC 共用 SCLK 和 MOSI，但各自使用独立 CS 与 MISO。独立 MISO 比把
// 两块廉价成品模块的 DOUT 直接并线更稳妥；若模块明确保证 CS 高时 DOUT 为
// 高阻态，也可以在硬件上共用 MISO，但本工程约束保留两根输入线。
//
// samples0：第一片 MCP3208 的 CH0..CH7，低位优先，每路 12 bit。
// samples1：第二片 MCP3208 的 CH0..CH7，低位优先；13 键工程只使用 CH0..CH4。
// frame_valid：第二片 CH7 完成后产生一个 clk 周期脉冲，表示两片 16 路快照均更新。
module mcp3208_dual_scan #(
    parameter integer HALF_PERIOD = 25, // 50 MHz 下约 1 MHz SPI 时钟
    parameter [1:0] ADC_PRESENT_MASK = 2'b11
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        mcp0_miso,
    input  wire        mcp1_miso,
    output reg         mcp_sclk,
    output reg         mcp_mosi,
    output reg         mcp0_cs_n,
    output reg         mcp1_cs_n,
    output reg [95:0]  samples0,
    output reg [95:0]  samples1,
    output reg         frame_valid,
    output reg         ready,
    output reg         fault
);
    localparam integer HALF_COUNT_WIDTH = (HALF_PERIOD <= 1) ? 1 : $clog2(HALF_PERIOD+1);

    localparam [1:0] ST_IDLE   = 2'd0;
    localparam [1:0] ST_ACTIVE = 2'd1;

    reg [1:0] state;
    reg [HALF_COUNT_WIDTH-1:0] half_count;
    reg [4:0] bit_count;
    reg [2:0] channel;
    reg       chip;
    reg [23:0] tx_shift;
    reg [23:0] rx_shift;
    (* ASYNC_REG = "TRUE" *) reg mcp0_miso_meta;
    (* ASYNC_REG = "TRUE" *) reg mcp0_miso_sync;
    (* ASYNC_REG = "TRUE" *) reg mcp1_miso_meta;
    (* ASYNC_REG = "TRUE" *) reg mcp1_miso_sync;
    wire selected_miso = chip ? mcp1_miso_sync : mcp0_miso_sync;

    function automatic [23:0] make_command;
        input [2:0] channel_number;
        reg [7:0] first_byte;
        reg [7:0] second_byte;
        begin
            // 第一字节按 MSB 先发：00000（补零）1（Start）1（单端）D2，
            // 即 CH0～CH3 为 8'h06、CH4～CH7 为 8'h07；第二字节
            // 的最高两位依次为 D1/D0。这样可与 MCP3208 数据手册图 6-1
            // 的 24 时钟、mode 0/0 对齐。
            first_byte  = 8'h06 | (channel_number[2] ? 8'h01 : 8'h00);
            second_byte = {channel_number[1:0], 6'b0};
            make_command = {first_byte, second_byte, 8'h00};
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= ST_IDLE;
            half_count     <= {HALF_COUNT_WIDTH{1'b0}};
            bit_count      <= 5'd0;
            channel        <= 3'd0;
            chip           <= !ADC_PRESENT_MASK[0];
            tx_shift       <= 24'd0;
            rx_shift       <= 24'd0;
            mcp_sclk       <= 1'b0;
            mcp_mosi       <= 1'b0;
            mcp0_cs_n      <= 1'b1;
            mcp1_cs_n      <= 1'b1;
            samples0       <= 96'd0;
            samples1       <= 96'd0;
            frame_valid    <= 1'b0;
            ready          <= 1'b0;
            fault          <= 1'b0;
            mcp0_miso_meta <= 1'b0;
            mcp0_miso_sync <= 1'b0;
            mcp1_miso_meta <= 1'b0;
            mcp1_miso_sync <= 1'b0;
        end else begin
            // MISO 来自外部 ADC，先经过两级同步；1 MHz SPI 给同步延迟留下了
            // 充足裕量。frame_valid 是单周期脉冲，其他状态保持到下一轮。
            mcp0_miso_meta <= mcp0_miso;
            mcp0_miso_sync <= mcp0_miso_meta;
            mcp1_miso_meta <= mcp1_miso;
            mcp1_miso_sync <= mcp1_miso_meta;
            frame_valid    <= 1'b0;
            fault          <= 1'b0;

            if(ADC_PRESENT_MASK==0)begin
                ready<=0;fault<=1;frame_valid<=0;mcp0_cs_n<=1;mcp1_cs_n<=1;mcp_sclk<=0;
            end else if (state == ST_IDLE) begin
                // 转换之间让CS保持HALF_PERIOD+1拍高；25+1拍对应520ns，
                // 在手册500ns间隔之外留一拍引脚边沿余量；SPI高低半周期不变。
                mcp_sclk  <= 1'b0;
                mcp_mosi  <= 1'b0;
                mcp0_cs_n <= 1'b1;
                mcp1_cs_n <= 1'b1;
                if (half_count == HALF_PERIOD) begin
                    half_count <= {HALF_COUNT_WIDTH{1'b0}};
                    state      <= ST_ACTIVE;
                    bit_count  <= 5'd0;
                    rx_shift   <= 24'd0;
                    tx_shift   <= make_command(channel);
                    // 命令的最高位是前导 0；第一位在第一个上升沿前已经稳定。
                    mcp_mosi   <= 1'b0;
                    if (chip == 1'b0)
                        mcp0_cs_n <= 1'b0;
                    else
                        mcp1_cs_n <= 1'b0;
                end else begin
                    half_count <= half_count + 1'b1;
                end
            end else begin
                if (HALF_PERIOD <= 1 || half_count == HALF_PERIOD - 1) begin
                    half_count <= {HALF_COUNT_WIDTH{1'b0}};

                    if (mcp_sclk == 1'b0) begin
                        // 当前为低电平，翻到高电平：主机采样 DOUT。
                        mcp_sclk <= 1'b1;
                        // 24 个时钟中第 13～24 个上升沿（0-based 12～23）
                        // 对应 B11..B0；前两字节包含前导、命令和空位。
                        if (bit_count >= 5'd12 && bit_count <= 5'd23)
                            rx_shift <= {rx_shift[22:0], selected_miso};
                        bit_count <= bit_count + 1'b1;
                    end else begin
                        // 当前为高电平，翻到低电平：为下一个上升沿准备 DIN。
                        mcp_sclk <= 1'b0;
                        if (bit_count == 5'd24) begin
                            state     <= ST_IDLE;
                            mcp_mosi  <= 1'b0;
                            mcp0_cs_n <= 1'b1;
                            mcp1_cs_n <= 1'b1;

                            if (chip == 1'b0)
                                samples0[channel*12 +: 12] <= rx_shift[11:0];
                            else
                                samples1[channel*12 +: 12] <= rx_shift[11:0];

                            if (channel == 3'd7 && (chip == 1'b1 || !ADC_PRESENT_MASK[1])) begin
                                // 第二片最后一个通道完成后，整轮快照有效。
                                frame_valid <= 1'b1;
                                ready       <= 1'b1;
                                chip        <= !ADC_PRESENT_MASK[0];
                                channel     <= 3'd0;
                            end else if (chip == 1'b0 && channel == 3'd7) begin
                                chip    <= 1'b1;
                                channel <= 3'd0;
                            end else begin
                                channel <= channel + 3'd1;
                            end
                        end else begin
                            tx_shift <= {tx_shift[22:0], 1'b0};
                            mcp_mosi <= tx_shift[22];
                        end
                    end
                end else begin
                    half_count <= half_count + 1'b1;
                end
            end
        end
    end
endmodule

`default_nettype wire
