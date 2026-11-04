`include "sim/mcp3208_model.sv"
`timescale 1ns/1ps
`default_nettype none

// 双 MCP3208 扫描器协议自检：
// 1. 每个 CS 事务恰好 24 个 SCLK；
// 2. 两个 CS 不会同时有效；
// 3. 命令顺序为 ADC0 CH0..CH7、ADC1 CH0..CH7；
// 4. 采样结果没有左/右移一位；
// 5. 第二片 CH7 完成时才产生 frame_valid。
module tb_mcp3208_dual_scan;
    `include "sim/result.svh"
    localparam integer HALF_PERIOD = 3;

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    wire mcp_sclk;
    wire mcp_mosi;
    wire mcp0_cs_n;
    wire mcp1_cs_n;
    wire mcp0_miso;
    wire mcp1_miso;
    wire [95:0] samples0;
    wire [95:0] samples1;
    wire frame_valid;
    wire ready;
    wire fault;

    integer cs0_sclk_count;
    integer cs1_sclk_count;
    integer transaction_count;
    integer expected_chip;
    integer expected_channel;
    reg [23:0] cs0_command;
    reg [23:0] cs1_command;
    integer decoded_channel;
    integer frame_count;

    always #10 clk = ~clk; // 50 MHz

    mcp3208_dual_scan #(
        .HALF_PERIOD(HALF_PERIOD)
    ) dut (
        .clk         (clk),
        .rst_n       (rst_n),
        .mcp0_miso   (mcp0_miso),
        .mcp1_miso   (mcp1_miso),
        .mcp_sclk    (mcp_sclk),
        .mcp_mosi    (mcp_mosi),
        .mcp0_cs_n   (mcp0_cs_n),
        .mcp1_cs_n   (mcp1_cs_n),
        .samples0    (samples0),
        .samples1    (samples1),
        .frame_valid (frame_valid),
        .ready       (ready),
        .fault       (fault)
    );

    mcp3208_model #(
        .CH0(12'h100), .CH1(12'h201), .CH2(12'h302), .CH3(12'h403),
        .CH4(12'h504), .CH5(12'h605), .CH6(12'h706), .CH7(12'h807)
    ) adc0 (
        .cs_n (mcp0_cs_n), .sclk(mcp_sclk), .mosi(mcp_mosi), .miso(mcp0_miso)
    );

    mcp3208_model #(
        .CH0(12'h900), .CH1(12'ha01), .CH2(12'ha02), .CH3(12'ha03),
        .CH4(12'ha04), .CH5(12'ha05), .CH6(12'ha06), .CH7(12'ha07)
    ) adc1 (
        .cs_n (mcp1_cs_n), .sclk(mcp_sclk), .mosi(mcp_mosi), .miso(mcp1_miso)
    );

    initial begin
        cs0_sclk_count = 0;
        cs1_sclk_count = 0;
        transaction_count = 0;
        expected_chip = 0;
        expected_channel = 0;
        cs0_command = 24'd0;
        cs1_command = 24'd0;
        frame_count = 0;
    end

    // 只在有效 CS 下统计 SCLK 上升沿并捕获主机发送的 24 位命令。
    always @(posedge mcp_sclk) begin
        if (!mcp0_cs_n && !mcp1_cs_n)
            $fatal(1, "CS0 and CS1 were low simultaneously");
        if (!mcp0_cs_n) begin
            if (cs0_sclk_count >= 24)
                $fatal(1, "ADC0 transaction has more than 24 clocks");
            cs0_command = {cs0_command[22:0], mcp_mosi};
            cs0_sclk_count = cs0_sclk_count + 1;
        end else if (!mcp1_cs_n) begin
            if (cs1_sclk_count >= 24)
                $fatal(1, "ADC1 transaction has more than 24 clocks");
            cs1_command = {cs1_command[22:0], mcp_mosi};
            cs1_sclk_count = cs1_sclk_count + 1;
        end else begin
            $fatal(1, "SCLK toggled while both CS signals were high");
        end
    end

    task check_command;
        input integer chip_number;
        input integer channel_number;
        input [23:0] command_word;
        begin
            if (command_word[23:19] !== 5'b00000)
                $fatal(1, "leading command zeros wrong: chip=%0d ch=%0d word=%h",
                       chip_number, channel_number, command_word);
            if (command_word[18:17] !== 2'b11)
                $fatal(1, "start/SGL bits wrong: chip=%0d ch=%0d word=%h",
                       chip_number, channel_number, command_word);
            decoded_channel = {command_word[16], command_word[15], command_word[14]};
            if (decoded_channel != channel_number)
                $fatal(1, "channel command wrong: chip=%0d expected=%0d got=%0d word=%h",
                       chip_number, channel_number, decoded_channel, command_word);
        end
    endtask

    // CS 上升沿是一个事务的结束点，此时检查时钟数和通道顺序。
    always @(posedge mcp0_cs_n) begin
        // 复位期间 DUT 会把 CS 从 X 初始化为 1，这不是一次 SPI 事务。
        if (!rst_n) begin
            cs0_sclk_count = 0;
            cs0_command = 24'd0;
        end else if (cs0_sclk_count != 24)
            $fatal(1, "ADC0 transaction clock count=%0d, expected 24", cs0_sclk_count);
        else if (expected_chip != 0)
            $fatal(1, "ADC0 selected while ADC1 was expected");
        else begin
            check_command(0, expected_channel, cs0_command);
            expected_channel = expected_channel + 1;
            if (expected_channel == 8) begin
                expected_channel = 0;
                expected_chip = 1;
            end
            transaction_count = transaction_count + 1;
            cs0_sclk_count = 0;
            cs0_command = 24'd0;
        end
    end

    always @(posedge mcp1_cs_n) begin
        if (!rst_n) begin
            cs1_sclk_count = 0;
            cs1_command = 24'd0;
        end else if (cs1_sclk_count != 24)
            $fatal(1, "ADC1 transaction clock count=%0d, expected 24", cs1_sclk_count);
        else if (expected_chip != 1)
            $fatal(1, "ADC1 selected while ADC0 was expected");
        else begin
            check_command(1, expected_channel, cs1_command);
            expected_channel = expected_channel + 1;
            if (expected_channel == 8) begin
                expected_channel = 0;
                expected_chip = 0;
            end
            transaction_count = transaction_count + 1;
            cs1_sclk_count = 0;
            cs1_command = 24'd0;
        end
    end

    always @(posedge frame_valid) begin
        frame_count = frame_count + 1;
        #1;
        if (!ready || fault)
            $fatal(1, "frame_valid without ready, or fault asserted");
        if (samples0[0*12 +: 12] !== 12'h100 ||
            samples0[1*12 +: 12] !== 12'h201 ||
            samples0[2*12 +: 12] !== 12'h302 ||
            samples0[3*12 +: 12] !== 12'h403 ||
            samples0[4*12 +: 12] !== 12'h504 ||
            samples0[5*12 +: 12] !== 12'h605 ||
            samples0[6*12 +: 12] !== 12'h706 ||
            samples0[7*12 +: 12] !== 12'h807)
            $fatal(1, "ADC0 sample bits/order wrong: %h", samples0);
        if (samples1[0*12 +: 12] !== 12'h900 ||
            samples1[1*12 +: 12] !== 12'ha01 ||
            samples1[2*12 +: 12] !== 12'ha02 ||
            samples1[3*12 +: 12] !== 12'ha03 ||
            samples1[4*12 +: 12] !== 12'ha04 ||
            samples1[5*12 +: 12] !== 12'ha05 ||
            samples1[6*12 +: 12] !== 12'ha06 ||
            samples1[7*12 +: 12] !== 12'ha07)
            $fatal(1, "ADC1 sample bits/order wrong: %h", samples1);
    end

    initial begin
        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        // 一帧约 47 us；超时预算足够覆盖两帧，避免测试因参数变化卡死。
        fork
            begin
                @(posedge frame_valid);
                #2;
                if (transaction_count < 16)
                    $fatal(1, "frame_valid came before all 16 transactions");
                if (expected_chip != 0 || expected_channel != 0)
                    $fatal(1, "channel sequence did not return to ADC0 CH0");
                complete_test("tb_mcp3208_dual_scan",5);
                $display("PASS tb_mcp3208_dual_scan transactions=%0d frames=%0d samples0=%h samples1=%h",
                         transaction_count, frame_count, samples0, samples1);
                $finish;
            end
            begin
                repeat (30000) @(posedge clk);
                $fatal(1, "timeout waiting for frame_valid");
            end
        join_any
        disable fork;
    end
endmodule

`default_nettype wire
