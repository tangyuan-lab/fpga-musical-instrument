`timescale 1ns/1ps
`default_nettype none

// 压力链路诊断：沿用正式工程的 MCP3208 引脚、扫描时序和串口屏页面。
// RAW 显示未扣基线的 12 bit ADC；AB13 切换 DIFF，显示 |ADC-松开基线|。
// ACTIVE 为变化量 >=16 码的通道数，与按压方向无关，不代表正式演奏键状态。
// 松开全部压力键后复位，前 64 帧重新取基线；READY 仅表示校准流程完成。
// USB UART 同步输出屏幕命令，供电脑读取原始值；本诊断不接收 MIDI，不发声。
module adc_screen_diag_top #(
    parameter integer SPI_HALF_PERIOD = 25,
    parameter integer CALIBRATION_SAMPLES = 64,
    parameter integer BUTTON_STABLE_CYCLES = 500_000,
    parameter integer SCREEN_CLKS_PER_BIT = 434,
    parameter integer SCREEN_STARTUP_CYCLES = 50_000_000,
    parameter integer SCREEN_UPDATE_CYCLES = 5_000_000
) (
    input wire sys_clk,
    input wire sys_rst_n,
    input wire mode_key_n,
    output wire screen_tx_o,
    output wire uart_tx_o,
    output wire mcp0_sclk,
    output wire mcp0_mosi,
    output wire mcp1_sclk,
    output wire mcp1_mosi,
    output wire mcp0_cs_n,
    output wire mcp1_cs_n,
    input wire mcp0_miso,
    input wire mcp1_miso,
    output wire hp_bck,
    output wire hp_ws,
    output wire hp_din,
    output wire pa_en
);
    wire rst_n;
    wire mode_pressed;
    reg diff_mode;
    wire [95:0] samples0, samples1;
    wire [155:0] adc_values = {samples1[59:0], samples0};
    wire frame_valid, adc_ready, adc_fault;
    wire calibrated;
    wire [155:0] baseline_values;
    reg [155:0] raw_values;
    wire [155:0] difference_values;
    wire [12:0] changed;
    reg [3:0] changed_count;
    integer count_index;
    wire scan_sclk, scan_mosi;
    wire [155:0] display_values = diff_mode ? difference_values : raw_values;

    assign mcp0_sclk = scan_sclk;
    assign mcp1_sclk = scan_sclk;
    assign mcp0_mosi = scan_mosi;
    assign mcp1_mosi = scan_mosi;
    assign uart_tx_o = screen_tx_o;
    assign hp_bck = 1'b0;
    assign hp_ws = 1'b0;
    assign hp_din = 1'b0;
    assign pa_en = 1'b0;

    reset_sync reset_inst (.clk(sys_clk), .arst_n(sys_rst_n), .rst_n(rst_n));
    button_filter #(.STABLE_CYCLES(BUTTON_STABLE_CYCLES)) mode_button (
        .clk(sys_clk), .rst_n(rst_n), .key_n(mode_key_n), .pressed(mode_pressed)
    );
    always @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            diff_mode <= 1'b0;
            raw_values <= 156'd0;
        end else begin
            if (mode_pressed)
                diff_mode <= ~diff_mode;
            // 只显示完整扫描帧，避免屏幕刷新跨越两轮采样。
            if (frame_valid)
                raw_values <= adc_values;
        end
    end

    mcp3208_dual_scan #(.HALF_PERIOD(SPI_HALF_PERIOD)) adc_spi (
        .clk(sys_clk), .rst_n(rst_n), .mcp0_miso(mcp0_miso), .mcp1_miso(mcp1_miso),
        .mcp_sclk(scan_sclk), .mcp_mosi(scan_mosi),
        .mcp0_cs_n(mcp0_cs_n), .mcp1_cs_n(mcp1_cs_n),
        .samples0(samples0), .samples1(samples1), .frame_valid(frame_valid),
        .ready(adc_ready), .fault(adc_fault)
    );
    // 使用正式工程的校准模块；诊断变化量独立计算，避免方向掩码把上升信号截零。
    pressure_key_matrix #(.CALIBRATION_SAMPLES(CALIBRATION_SAMPLES)) baseline_capture (
        .clk(sys_clk), .rst_n(rst_n), .adc_ready(adc_ready),
        .sample_frame_valid(frame_valid), .adc_samples(adc_values),
        .calibrated(calibrated), .baseline_values(baseline_values),
        .pressure_values(), .velocity_values(), .key_down(),
        .key_on_pulse(), .key_off_pulse(), .active_key_count()
    );
    genvar key_index;
    generate
        for (key_index = 0; key_index < 13; key_index = key_index + 1) begin : g_difference
            wire [11:0] raw_value = raw_values[key_index*12 +: 12];
            wire [11:0] baseline = baseline_values[key_index*12 +: 12];
            wire [11:0] difference = !calibrated ? 12'd0 :
                (raw_value >= baseline ? raw_value - baseline : baseline - raw_value);
            assign difference_values[key_index*12 +: 12] = difference;
            assign changed[key_index] = calibrated && difference >= 12'd16;
        end
    endgenerate
    always @(*) begin
        changed_count = 4'd0;
        for (count_index = 0; count_index < 13; count_index = count_index + 1)
            changed_count = changed_count + {3'd0, changed[count_index]};
    end

    serial_screen_nextion_tx #(
        .CLKS_PER_BIT(SCREEN_CLKS_PER_BIT),
        .STARTUP_DELAY_CYCLES(SCREEN_STARTUP_CYCLES),
        .UPDATE_PERIOD_CYCLES(SCREEN_UPDATE_CYCLES),
        .MODE_0_TEXT("RAW "), .MODE_1_TEXT("DIFF")
    ) screen_link (
        .clk(sys_clk), .rst_n(rst_n), .pressure_values(display_values),
        .active_key_count(changed_count), .midi_mode(diff_mode),
        .audio_ready(calibrated && adc_ready && !adc_fault), .file_ready(1'b1),
        .parser_busy(1'b0), .playing(1'b0), .screen_rx_i(1'b1),
        .screen_tx_o(screen_tx_o), .rx_activity()
    );
endmodule

`default_nettype wire
