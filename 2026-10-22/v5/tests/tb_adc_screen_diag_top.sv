`timescale 1ns/1ps
`default_nettype none

// 端到端检查：两个 SPI ADC 模型 -> 完整帧 -> 基线 -> UART 引脚上的屏幕命令。
// 两片 ADC 分别模拟上升/下降 0x100 码，诊断必须同时保留两种变化。
module tb_adc_screen_diag_top;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg mode_key_n = 1'b1;
    reg [11:0] stimulus0 = 12'h800;
    reg [11:0] stimulus1 = 12'ha00;
    wire sclk0, sclk1, mosi0, mosi1, cs0, cs1, miso0, miso1;
    wire screen_tx, usb_tx, hp_bck, hp_ws, hp_din, pa_en;
    reg [7:0] received [0:4095];
    reg [7:0] decoded;
    integer received_count = 0;
    integer checked_count = 0;
    integer bit_index;
    integer key_index;
    always #5 clk = ~clk;
    adc_screen_diag_top #(
        .SPI_HALF_PERIOD(3), .CALIBRATION_SAMPLES(4), .BUTTON_STABLE_CYCLES(4),
        .SCREEN_CLKS_PER_BIT(16), .SCREEN_STARTUP_CYCLES(20000),
        .SCREEN_UPDATE_CYCLES(20000)
    ) dut (
        .sys_clk(clk), .sys_rst_n(rst_n), .mode_key_n(mode_key_n),
        .screen_tx_o(screen_tx), .uart_tx_o(usb_tx),
        .mcp0_sclk(sclk0), .mcp1_sclk(sclk1), .mcp0_mosi(mosi0), .mcp1_mosi(mosi1),
        .mcp0_cs_n(cs0), .mcp1_cs_n(cs1), .mcp0_miso(miso0), .mcp1_miso(miso1),
        .hp_bck(hp_bck), .hp_ws(hp_ws), .hp_din(hp_din), .pa_en(pa_en)
    );
    mcp3208_model adc0 (.cs_n(cs0), .sclk(sclk0), .mosi(mosi0), .miso(miso0));
    mcp3208_model adc1 (.cs_n(cs1), .sclk(sclk1), .mosi(mosi1), .miso(miso1));
    initial begin
        // 每片全部通道用同一电压；仍通过真实 SPI 位序进入被测顶层。
        force adc0.active_sample = stimulus0;
        force adc1.active_sample = stimulus1;
    end
    initial forever begin
        @(negedge screen_tx);
        if (rst_n) begin
            #80;
            if (screen_tx !== 1'b0) $fatal(1, "bad start bit");
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                #160;
                decoded[bit_index] = screen_tx;
            end
            #160;
            if (screen_tx !== 1'b1) $fatal(1, "bad stop bit");
            received[received_count] = decoded;
            received_count = received_count + 1;
        end
    end
    always @(negedge clk) begin
        if (rst_n && (usb_tx !== screen_tx || pa_en !== 1'b0 ||
            hp_bck !== 1'b0 || hp_ws !== 1'b0 || hp_din !== 1'b0))
            $fatal(1, "diagnostic USB mirror or muted audio outputs wrong");
    end
    task automatic expect_byte(input [7:0] expected);
        begin
            wait (received_count > checked_count);
            if (received[checked_count] !== expected)
                $fatal(1, "byte %0d got %02x expected %02x", checked_count,
                    received[checked_count], expected);
            checked_count = checked_count + 1;
        end
    endtask
    task automatic expect_command(input integer component, input string value);
        string command_text;
        integer index;
        begin
            command_text = $sformatf("t%0d.txt=\"%s\"", component, value);
            for (index = 0; index < command_text.len(); index = index + 1)
                expect_byte(command_text[index]);
            expect_byte(8'hff); expect_byte(8'hff); expect_byte(8'hff);
        end
    endtask
    initial begin
        repeat (4) @(negedge clk);
        rst_n = 1'b1;
        expect_command(0, "RAW "); expect_command(1, "0"); expect_command(2, "READY");
        for (key_index = 0; key_index < 13; key_index = key_index + 1)
            expect_command(key_index + 3, key_index < 8 ? "800" : "A00");
        // 上升和下降都应反映到 RAW，并进入变化计数。
        stimulus0 = 12'h900;
        stimulus1 = 12'h900;
        expect_command(0, "RAW "); expect_command(1, "D"); expect_command(2, "READY");
        for (key_index = 3; key_index <= 15; key_index = key_index + 1)
            expect_command(key_index, "900");
        mode_key_n = 1'b0;
        repeat (20) @(negedge clk);
        mode_key_n = 1'b1;
        expect_command(0, "DIFF"); expect_command(1, "D"); expect_command(2, "READY");
        for (key_index = 3; key_index <= 15; key_index = key_index + 1)
            expect_command(key_index, "100");
        stimulus0 = 12'h800;
        stimulus1 = 12'ha00;
        expect_command(0, "DIFF"); expect_command(1, "0"); expect_command(2, "READY");
        for (key_index = 3; key_index <= 15; key_index = key_index + 1)
            expect_command(key_index, "000");
        $display("PASS tb_adc_screen_diag_top raw SPI mapping, both polarities, UART and release");
        $finish;
    end
    initial begin
        #15000000;
        $fatal(1, "timeout");
    end
endmodule
`default_nettype wire
