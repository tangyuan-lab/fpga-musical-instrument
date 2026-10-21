`timescale 1ns/1ps
`default_nettype none

// 两片 MCP3208 + 13 个压力键 + 四声部音频 + HDMI 状态显示。
//
// 通道映射：
//   MCP3208-0 CH0..CH7 -> 键 0..7（C4..G4）
//   MCP3208-1 CH0..CH4 -> 键 8..12（G#4..C5）
//   MCP3208-1 CH5..CH7 保留不用。
//
// HDMI 只显示扫描状态、13 路压力柱和按键状态，不接入触摸 USB，也不参与
// 音频控制。压力键矩阵在系统时钟域完成校准、滤波和迟滞，视频域只接收快照。
module mcp3208_13key_hdmi_top #(
    parameter integer STARTUP_CYCLES = 5_000_000,
    parameter [11:0] PRESS_ON         = 12'd16,
    parameter [11:0] PRESS_OFF        = 12'd8,
    // 3.3 V 参考下扩大压力有效区间，避免轻按后很快饱和到最大音量。
    parameter [11:0] PRESS_FULL       = 12'd2048,
    // 1 表示松开基线减去当前值；FSR 分压方向相反时改成 13'd0。
    parameter [12:0] ACTIVE_LOW_MASK  = 13'h1fff
) (
    input  wire       sys_clk,
    input  wire       sys_rst_n,
    output wire       uart_tx_o,
    output wire [7:0] led_n,
    output wire       hp_bck,
    output wire       hp_ws,
    output wire       hp_din,
    output wire       pa_en,
    // PMOD1 上的 MCP3208 SPI 数字接口。
    // 两块成品模块各接自己的一组 CLK/DIN/CS/OUT，不要求现场制作一分二线。
    output wire       mcp0_sclk,
    output wire       mcp0_mosi,
    output wire       mcp1_sclk,
    output wire       mcp1_mosi,
    output wire       mcp0_cs_n,
    output wire       mcp1_cs_n,
    input  wire       mcp0_miso,
    input  wire       mcp1_miso,
    // HDMI/DVI 输出。
    output wire [2:0] tmds_p,
    output wire [2:0] tmds_n,
    output wire       tmds_clk_p,
    output wire       tmds_clk_n,
    output wire       hpd_en
);
    localparam integer KEY_COUNT = 13;
    localparam integer ADC_BITS  = 12;
    localparam integer ADC_BUS_WIDTH = KEY_COUNT * ADC_BITS;
    localparam integer BAR_BITS = 9;
    localparam integer BAR_BUS_WIDTH = KEY_COUNT * BAR_BITS;
    localparam integer DISPLAY_WIDTH = BAR_BUS_WIDTH + KEY_COUNT + 4 + 4;

    wire rst_n;
    wire [95:0] mcp0_samples;
    wire [95:0] mcp1_samples;
    wire [ADC_BUS_WIDTH-1:0] adc_samples;
    wire sample_frame_valid;
    wire adc_ready;
    wire adc_fault;
    wire mcp_sclk_int;
    wire mcp_mosi_int;

    wire calibrated;
    wire [ADC_BUS_WIDTH-1:0] baseline_values;
    wire [ADC_BUS_WIDTH-1:0] pressure_values;
    wire [KEY_COUNT*8-1:0] velocity_values;
    wire [KEY_COUNT-1:0] key_down;
    wire [KEY_COUNT-1:0] key_on_pulse;
    wire [KEY_COUNT-1:0] key_off_pulse;
    wire [$clog2(KEY_COUNT+1)-1:0] active_key_count;

    wire audio_ready;
    wire sample_tick;
    wire signed [15:0] mixed_sample;
    wire [3:0] voice_gate;
    wire [3:0] voice_assigned;
    wire [15:0] voice_keys;
    wire [51:0] voice_levels;
    wire [31:0] timbre_blends;
    wire [127:0] voice_phase_steps;

    reg [12:0] max_pressure;
    reg [6:0] pressure_bar;
    reg [24:0] blink_counter;
    reg [BAR_BUS_WIDTH-1:0] bar_levels_reg;
    integer key_index;
    integer bar_index;

    wire audio_system_ready = adc_ready && calibrated && audio_ready && !adc_fault;

    // HDMI 1024x600 视频域。
    wire pixel_clk;
    wire serial_clk;
    wire pll_locked;
    wire video_rst_n;
    wire [DISPLAY_WIDTH-1:0] display_data;
    wire display_update;
    reg  [DISPLAY_WIDTH-1:0] frame_data;
    wire [10:0] pixel_x;
    wire [9:0]  pixel_y;
    wire video_de;
    wire hsync_n;
    wire vsync_n;
    wire frame_start;
    wire [23:0] video_rgb;
    reg video_de_d;
    reg hsync_n_d;
    reg vsync_n_d;
    reg video_de_d2;
    reg hsync_n_d2;
    reg vsync_n_d2;
    reg video_de_d3;
    reg hsync_n_d3;
    reg vsync_n_d3;

    // NEO Dock 的 HDMI HPD 控制脚必须拉高，保持原已验证工程的设置。
    assign hpd_en = 1'b1;

    reset_sync reset_sync_inst (
        .clk(sys_clk), .arst_n(sys_rst_n), .rst_n(rst_n)
    );

    mcp3208_dual_scan #(.HALF_PERIOD(25)) adc_spi (
        .clk(sys_clk), .rst_n(rst_n),
        .mcp0_miso(mcp0_miso), .mcp1_miso(mcp1_miso),
        .mcp_sclk(mcp_sclk_int), .mcp_mosi(mcp_mosi_int),
        .mcp0_cs_n(mcp0_cs_n), .mcp1_cs_n(mcp1_cs_n),
        .samples0(mcp0_samples), .samples1(mcp1_samples),
        .frame_valid(sample_frame_valid), .ready(adc_ready), .fault(adc_fault)
    );

    // 扫描器内部只有一套 SPI 时序；这里把同样的逻辑波形送到两组独立
    // FPGA 输出脚。这样每块成品 ADC 都能用一根独立杜邦线接 CLK/DIN。
    assign mcp0_sclk = mcp_sclk_int;
    assign mcp1_sclk = mcp_sclk_int;
    assign mcp0_mosi = mcp_mosi_int;
    assign mcp1_mosi = mcp_mosi_int;

    // 低位优先把两片 ADC 的通道拼为键 0..12；第二片的 CH5..CH7 不接入。
    genvar bus_index;
    generate
        for (bus_index = 0; bus_index < 8; bus_index = bus_index + 1) begin : g_adc0_bus
            assign adc_samples[bus_index*ADC_BITS +: ADC_BITS] =
                mcp0_samples[bus_index*ADC_BITS +: ADC_BITS];
        end
        for (bus_index = 0; bus_index < 5; bus_index = bus_index + 1) begin : g_adc1_bus
            assign adc_samples[(bus_index+8)*ADC_BITS +: ADC_BITS] =
                mcp1_samples[bus_index*ADC_BITS +: ADC_BITS];
        end
    endgenerate

    pressure_key_matrix #(
        .KEY_COUNT(KEY_COUNT),
        .ADC_BITS(ADC_BITS),
        .CALIBRATION_SAMPLES(64),
        .FILTER_SHIFT(2),
        .PRESS_ON(PRESS_ON),
        .PRESS_OFF(PRESS_OFF),
        .PRESS_FULL(PRESS_FULL),
        .ACTIVE_LOW_MASK(ACTIVE_LOW_MASK)
    ) key_matrix (
        .clk(sys_clk), .rst_n(rst_n), .adc_ready(adc_ready),
        .sample_frame_valid(sample_frame_valid), .adc_samples(adc_samples),
        .calibrated(calibrated), .baseline_values(baseline_values),
        .pressure_values(pressure_values), .velocity_values(velocity_values),
        .key_down(key_down), .key_on_pulse(key_on_pulse),
        .key_off_pulse(key_off_pulse), .active_key_count(active_key_count)
    );

    audio_startup #(.STARTUP_CYCLES(STARTUP_CYCLES)) audio_startup_inst (
        .clk(sys_clk), .rst_n(rst_n), .audio_ready(audio_ready), .pa_en(pa_en)
    );

    // 当前版本固定使用三角波；后续可以把 timbre 接到按键或 HDMI 控件。
    // 当前默认输出仍留有余量；MIX_SHIFT 从 1 改为 0，使单声部最大幅度提高约 2 倍。
    // 四声部叠加仍由 poly_synth_4voice 内的 16 位饱和器保护。
    poly_synth_4voice #(.MIX_SHIFT(0)) synth (
        .clk(sys_clk), .rst_n(rst_n), .sample_tick(sample_tick), .timbre(1'b0),
        .key_on_pulse(key_on_pulse), .key_off_pulse(key_off_pulse),
        .velocity_values(velocity_values), .sample_out(mixed_sample),
        .voice_gate(voice_gate), .voice_assigned(voice_assigned),
        .voice_keys(voice_keys), .voice_levels(voice_levels),
        .timbre_blends(timbre_blends), .voice_phase_steps(voice_phase_steps)
    );

    pt8211_tx audio_tx (
        .clk(sys_clk), .rst_n(rst_n),
        .sample_left(mixed_sample), .sample_right(mixed_sample),
        .sample_tick(sample_tick), .hp_bck(hp_bck), .hp_ws(hp_ws), .hp_din(hp_din)
    );

    // UART 仍保留，方便不接 HDMI 时检查第 1 个键（MCP0-CH0）：
    // R 是原始 12 位 ADC 码，P 是基线扣除并滤波后的压力码，G 是门控，
    // V 是 8 位力度。PMOD0/HDMI 仍显示 13 键中的最大压力。
    pressure_audio_telemetry telemetry (
        .clk(sys_clk), .rst_n(rst_n),
        .raw_adc({2'b00, adc_samples[11:0]}),
        .pressure(pressure_values[11:0]), .gate(key_down[0]),
        .volume({5'b0, velocity_values[7:0]}),
        .status({adc_fault, audio_ready, calibrated, adc_ready}),
        .tx(uart_tx_o)
    );

    // 计算 13 个键中的最大压力，用于 PMOD0 七段压力指示和串口摘要。
    always @(*) begin
        max_pressure = 13'd0;
        for (key_index = 0; key_index < KEY_COUNT; key_index = key_index + 1) begin
            if (pressure_values[key_index*ADC_BITS +: ADC_BITS] > max_pressure[11:0])
                max_pressure = {1'b0, pressure_values[key_index*ADC_BITS +: ADC_BITS]};
        end

        if      (max_pressure >= 13'd224) pressure_bar = 7'b111_1111;
        else if (max_pressure >= 13'd144) pressure_bar = 7'b011_1111;
        else if (max_pressure >= 13'd96)  pressure_bar = 7'b001_1111;
        else if (max_pressure >= 13'd64)  pressure_bar = 7'b000_1111;
        else if (max_pressure >= 13'd48)  pressure_bar = 7'b000_0111;
        else if (max_pressure >= 13'd32)  pressure_bar = 7'b000_0011;
        else if (max_pressure >= 13'd16)  pressure_bar = 7'b000_0001;
        else                              pressure_bar = 7'b000_0000;
    end

    // 在系统时钟域预先计算每个键的显示柱高。视频域只需做一次小型字段选择，
    // 避免把 12 位压力移位/饱和运算放在像素时序路径上。
    always @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            bar_levels_reg <= {BAR_BUS_WIDTH{1'b0}};
        end else begin
            for (bar_index = 0; bar_index < KEY_COUNT; bar_index = bar_index + 1) begin
                if (pressure_values[bar_index*ADC_BITS +: ADC_BITS] >= 12'd467)
                    bar_levels_reg[bar_index*BAR_BITS +: BAR_BITS] <= 9'd350;
                else
                    bar_levels_reg[bar_index*BAR_BITS +: BAR_BITS] <=
                        // 467 以下的压力只需要 9 位柱高；用位段表达右移，
                        // 让加法器本身保持 9 位，不依赖隐式截断。
                        pressure_values[bar_index*ADC_BITS + 8 -: 8] +
                        {2'b0, pressure_values[bar_index*ADC_BITS + 8 -: 7]};
            end
        end
    end

    always @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n)
            blink_counter <= 25'd0;
        else
            blink_counter <= blink_counter + 1'b1;
    end

    // PMOD0 LED 为低电平点亮：LED7 表示系统就绪，LED0..6 表示最大压力档位。
    assign led_n = adc_fault ? ~(blink_counter[24] ? 8'hAA : 8'h55) :
                   audio_system_ready ? ~{1'b1, pressure_bar} :
                   ~(blink_counter[24] ? 8'h80 : 8'h00);

    // 把系统域快照整包送入像素域；数据在握手期间保持不变。
    snapshot_cdc #(.WIDTH(DISPLAY_WIDTH)) display_bridge (
        .src_clk(sys_clk), .src_rst_n(rst_n),
        .src_data({adc_fault, audio_ready, calibrated, adc_ready,
                   active_key_count, key_down, bar_levels_reg}),
        .dst_clk(pixel_clk), .dst_rst_n(video_rst_n),
        .dst_data(display_data), .dst_valid(display_update)
    );

    video_pll video_clocks (
        .clkin(sys_clk), .reset(!sys_rst_n),
        .pixel_clk(pixel_clk), .serial_clk(serial_clk), .locked(pll_locked)
    );
    reset_sync video_reset (
        .clk(pixel_clk), .arst_n(sys_rst_n && pll_locked), .rst_n(video_rst_n)
    );
    video_timing raster (
        .clk(pixel_clk), .rst_n(video_rst_n),
        .x(pixel_x), .y(pixel_y), .de(video_de),
        .hs_n(hsync_n), .vs_n(vsync_n), .frame_start(frame_start)
    );

    always @(posedge pixel_clk or negedge video_rst_n) begin
        if (!video_rst_n)
            frame_data <= {DISPLAY_WIDTH{1'b0}};
        else if (frame_start)
            frame_data <= display_data;
    end

    pressure_keys_ui_1024x600 ui (
        .clk(pixel_clk),
        .x(pixel_x), .y(pixel_y),
        .bar_levels(frame_data[BAR_BUS_WIDTH-1:0]),
        .key_down(frame_data[BAR_BUS_WIDTH+KEY_COUNT-1:BAR_BUS_WIDTH]),
        .active_key_count(frame_data[BAR_BUS_WIDTH+KEY_COUNT+4-1:
                                      BAR_BUS_WIDTH+KEY_COUNT]),
        .scan_ready(frame_data[DISPLAY_WIDTH-4]),
        .calibrated(frame_data[DISPLAY_WIDTH-3]),
        .audio_ready(frame_data[DISPLAY_WIDTH-2]),
        .fault(frame_data[DISPLAY_WIDTH-1]), .rgb(video_rgb)
    );

    always @(posedge pixel_clk or negedge video_rst_n) begin
        if (!video_rst_n) begin
            video_de_d <= 1'b0;
            hsync_n_d  <= 1'b1;
            vsync_n_d  <= 1'b1;
            video_de_d2 <= 1'b0;
            hsync_n_d2  <= 1'b1;
            vsync_n_d2  <= 1'b1;
            video_de_d3 <= 1'b0;
            hsync_n_d3  <= 1'b1;
            vsync_n_d3  <= 1'b1;
        end else begin
            video_de_d <= video_de;
            hsync_n_d  <= hsync_n;
            vsync_n_d  <= vsync_n;
            video_de_d2 <= video_de_d;
            hsync_n_d2  <= hsync_n_d;
            vsync_n_d2  <= vsync_n_d;
            video_de_d3 <= video_de_d2;
            hsync_n_d3  <= hsync_n_d2;
            vsync_n_d3  <= vsync_n_d2;
        end
    end

    DVI_TX_Top transmitter (
        .I_rst_n(video_rst_n), .I_serial_clk(serial_clk), .I_rgb_clk(pixel_clk),
        .I_rgb_vs(vsync_n_d3), .I_rgb_hs(hsync_n_d3), .I_rgb_de(video_de_d3),
        .I_rgb_r(video_rgb[23:16]), .I_rgb_g(video_rgb[15:8]),
        .I_rgb_b(video_rgb[7:0]), .O_tmds_clk_p(tmds_clk_p),
        .O_tmds_clk_n(tmds_clk_n), .O_tmds_data_p(tmds_p),
        .O_tmds_data_n(tmds_n)
    );

    wire _unused = &{1'b0, baseline_values, display_update, voice_assigned,
                     voice_keys, voice_levels, timbre_blends, voice_phase_steps};
endmodule

`default_nettype wire
