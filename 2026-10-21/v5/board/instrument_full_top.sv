`timescale 1ns/1ps
`default_nettype none

// 比赛统一演示顶层：
//   1. 实时模式：两片 MCP3208 采集 16 个 FSR，压力决定力度，四声部实时合成；
//   2. MIDI 模式：电脑只上传完整 MIDI/FTB，FPGA 自行解析、调度并合成；
//   3. C18/C19 独立 UART 更新屏幕，并接收固定力度触摸弹奏；HDMI 也保留输出。
//
// AB13 功能键切换实时/MIDI 模式；AA13 功能键切换实时模式的三角波/柔和方波。
// MIDI 音色仍由 PLAY 命令指定。两个音频引擎都在 FPGA 内，输出在 PT8211 引脚前选择。
module instrument_full_top #(
    parameter integer KEY_COUNT = 16,
    parameter integer AUDIO_I2S = 0,
    parameter integer STARTUP_CYCLES = 5_000_000,
    parameter [11:0] PRESS_ON         = 12'd16,
    parameter [11:0] PRESS_OFF        = 12'd8,
    parameter [11:0] PRESS_FULL       = 12'd2048,
    parameter [KEY_COUNT-1:0] ACTIVE_LOW_MASK = {KEY_COUNT{1'b1}},
    // 50 MHz 时钟：434=115200 baud；5208=9600 baud。应与屏幕设置一致。
    parameter integer SCREEN_CLKS_PER_BIT = 434,
    parameter integer SCREEN_STARTUP_CYCLES = 50_000_000,
    parameter integer SCREEN_UPDATE_CYCLES = 5_000_000
) (
    input  wire       sys_clk,
    input  wire       sys_rst_n,
    input  wire       uart_rx_i,
    output wire       uart_tx_o,
    input  wire       mode_key_n,
    input  wire       timbre_key_n,
    output wire [5:0] led_n,
    output wire       hp_bck,
    output wire       hp_ws,
    output wire       hp_din,
    output wire       pa_en,
    input  wire       screen_rx_i,
    output wire       screen_tx_o,
    output wire       mcp0_sclk,
    output wire       mcp0_mosi,
    output wire       mcp1_sclk,
    output wire       mcp1_mosi,
    output wire       mcp0_cs_n,
    output wire       mcp1_cs_n,
    input  wire       mcp0_miso,
    input  wire       mcp1_miso,
    output wire [2:0] tmds_p,
    output wire [2:0] tmds_n,
    output wire       tmds_clk_p,
    output wire       tmds_clk_n,
    output wire       hpd_en
);
    localparam integer ACTIVE_COUNT_WIDTH = $clog2(KEY_COUNT+1);
    localparam integer ADC_BITS = 12;
    localparam integer ADC_BUS_WIDTH = KEY_COUNT * ADC_BITS;
    localparam integer BAR_BITS = 9;
    localparam integer BAR_BUS_WIDTH = KEY_COUNT * BAR_BITS;
    localparam integer FLAG_BASE = BAR_BUS_WIDTH + KEY_COUNT + ACTIVE_COUNT_WIDTH;
    localparam integer DISPLAY_WIDTH = FLAG_BASE + 12;

    wire rst_n;
    wire mode_pressed;
    wire timbre_pressed;
    reg midi_mode;
    reg live_timbre;

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
    wire [ACTIVE_COUNT_WIDTH-1:0] active_key_count;
    wire [KEY_COUNT-1:0] screen_touch_keys;
    wire [1:0] live_octave_shift;
    wire live_test_mode;
    wire [KEY_COUNT-1:0] live_keys;
    wire [KEY_COUNT-1:0] live_key_on;
    wire [KEY_COUNT-1:0] live_key_off;
    wire [KEY_COUNT*8-1:0] live_velocity;
    wire [ACTIVE_COUNT_WIDTH-1:0] live_active_key_count;

    wire live_audio_ready;
    wire live_sample_tick;
    wire signed [15:0] live_sample;
    wire [3:0] live_voice_gate;
    wire [3:0] live_voice_assigned;
    wire [15:0] live_voice_keys;
    wire [51:0] live_voice_levels;
    wire [31:0] live_timbre_blends;
    wire [127:0] live_voice_phase_steps;
    wire live_hp_bck;
    wire live_hp_ws;
    wire live_hp_din;
    wire live_pa_en;
    wire live_synth_rst_n = rst_n && !midi_mode;

    wire [7:0] midi_led_n;
    wire midi_hp_bck;
    wire midi_hp_ws;
    wire midi_hp_din;
    wire midi_pa_en;
    wire midi_audio_ready = ~midi_led_n[7];
    wire midi_file_ready = ~midi_led_n[6];
    wire midi_parser_busy = ~midi_led_n[5];
    wire midi_playing = ~midi_led_n[4];
    wire [3:0] midi_voice_gate = {4{midi_playing}} & ~midi_led_n[3:0];
    wire [3:0] midi_active_voice_count = {3'd0, midi_voice_gate[0]} +
                                       {3'd0, midi_voice_gate[1]} +
                                       {3'd0, midi_voice_gate[2]} +
                                       {3'd0, midi_voice_gate[3]};
    wire screen_rx_activity;

    reg [12:0] max_pressure;
    reg [6:0] pressure_bar;
    reg [24:0] blink_counter;
    reg [BAR_BUS_WIDTH-1:0] bar_levels_reg;
    integer key_index;
    integer bar_index;

    wire live_system_ready = adc_ready && calibrated && live_audio_ready && !adc_fault;
    wire selected_audio_ready = midi_mode ? midi_audio_ready : live_audio_ready;
    wire [7:0] live_led_n = adc_fault ? ~(blink_counter[24] ? 8'hAA : 8'h55) :
                                 live_system_ready ? ~{1'b1, pressure_bar} :
                                 ~(blink_counter[24] ? 8'h80 : 8'h00);

    // HDMI 1024x600 视频域和状态快照。
    wire pixel_clk;
    wire serial_clk;
    wire pll_locked;
    wire video_rst_n;
    wire [DISPLAY_WIDTH-1:0] display_data;
    wire display_update;
    reg  [DISPLAY_WIDTH-1:0] frame_data;
    wire [10:0] pixel_x;
    wire [9:0] pixel_y;
    wire video_de;
    wire hsync_n;
    wire vsync_n;
    wire frame_start;
    wire [23:0] video_rgb;
    reg video_de_d, hsync_n_d, vsync_n_d;
    reg video_de_d2, hsync_n_d2, vsync_n_d2;
    reg video_de_d3, hsync_n_d3, vsync_n_d3;

    assign hpd_en = 1'b1;
    assign mcp0_sclk = mcp_sclk_int;
    assign mcp1_sclk = mcp_sclk_int;
    assign mcp0_mosi = mcp_mosi_int;
    assign mcp1_mosi = mcp_mosi_int;

    // 两个 PT8211 发送器使用相同系统时钟和分频。功能键只在用户操作时切换，
    // 输出选择不会让电脑参与音频生成。
    assign hp_bck = midi_mode ? midi_hp_bck : live_hp_bck;
    assign hp_ws  = midi_mode ? midi_hp_ws  : live_hp_ws;
    assign hp_din = midi_mode ? midi_hp_din : live_hp_din;
    assign pa_en  = midi_mode ? midi_pa_en  : live_pa_en;
    // PMOD0 LED2 每收到一个有效屏幕回传字节翻转，LED3..LED7 显示原先状态。
    // IO0/IO1 当前未使用；串口屏改用 C18/C19，不占用 PMOD0 LED。
    assign led_n[0] = ~screen_rx_activity;
    assign led_n[5:1] = midi_mode ? midi_led_n[7:3] : live_led_n[7:3];

    reset_sync reset_sync_inst (
        .clk(sys_clk), .arst_n(sys_rst_n), .rst_n(rst_n)
    );
    button_filter mode_button (
        .clk(sys_clk), .rst_n(rst_n), .key_n(mode_key_n), .pressed(mode_pressed)
    );
    button_filter timbre_button (
        .clk(sys_clk), .rst_n(rst_n), .key_n(timbre_key_n), .pressed(timbre_pressed)
    );

    always @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            midi_mode   <= 1'b0;
            live_timbre <= 1'b0;
        end else begin
            if (mode_pressed)
                midi_mode <= ~midi_mode;
            if (timbre_pressed)
                live_timbre <= ~live_timbre;
        end
    end

    mcp3208_dual_scan #(.HALF_PERIOD(25)) adc_spi (
        .clk(sys_clk), .rst_n(rst_n),
        .mcp0_miso(mcp0_miso), .mcp1_miso(mcp1_miso),
        .mcp_sclk(mcp_sclk_int), .mcp_mosi(mcp_mosi_int),
        .mcp0_cs_n(mcp0_cs_n), .mcp1_cs_n(mcp1_cs_n),
        .samples0(mcp0_samples), .samples1(mcp1_samples),
        .frame_valid(sample_frame_valid), .ready(adc_ready), .fault(adc_fault)
    );

    genvar bus_index;
    generate
        for (bus_index = 0; bus_index < 8; bus_index = bus_index + 1) begin : g_adc0_bus
            assign adc_samples[bus_index*ADC_BITS +: ADC_BITS] =
                mcp0_samples[bus_index*ADC_BITS +: ADC_BITS];
        end
        // 键 8..15 对应第二片 CH0..CH7；原 13 键工程丢弃的 CH5..CH7 现在接入。
        for (bus_index = 0; bus_index < KEY_COUNT-8; bus_index = bus_index + 1) begin : g_adc1_bus
            assign adc_samples[(bus_index+8)*ADC_BITS +: ADC_BITS] =
                mcp1_samples[bus_index*ADC_BITS +: ADC_BITS];
        end
    endgenerate

    pressure_key_matrix #(
        .KEY_COUNT(KEY_COUNT), .ADC_BITS(ADC_BITS), .CALIBRATION_SAMPLES(64),
        .FILTER_SHIFT(2), .PRESS_ON(PRESS_ON), .PRESS_OFF(PRESS_OFF),
        .PRESS_FULL(PRESS_FULL), .ACTIVE_LOW_MASK(ACTIVE_LOW_MASK)
    ) key_matrix (
        .clk(sys_clk), .rst_n(rst_n), .adc_ready(adc_ready),
        .sample_frame_valid(sample_frame_valid), .adc_samples(adc_samples),
        .calibrated(calibrated), .baseline_values(baseline_values),
        .pressure_values(pressure_values), .velocity_values(velocity_values),
        .key_down(key_down), .key_on_pulse(key_on_pulse),
        .key_off_pulse(key_off_pulse), .active_key_count(active_key_count)
    );

    audio_startup #(.STARTUP_CYCLES(STARTUP_CYCLES)) live_audio_startup (
        .clk(sys_clk), .rst_n(rst_n), .audio_ready(live_audio_ready), .pa_en(live_pa_en)
    );
    // C19 屏幕回传独立于 USB-C MIDI UART；MIDI 模式期间清空触摸保持状态。
    // 实体 ADC 缺失或未标定不阻止屏幕弹奏，音频功放仍按原上电延时启动。
    // 多音接收不替换其他触摸键；实际同时发声上限由四声部合成器决定。
    screen_touch_keys_rx #(.CLKS_PER_BIT(SCREEN_CLKS_PER_BIT), .KEY_COUNT(KEY_COUNT), .POLYPHONIC(1), .PERFORMANCE_CONTROLS(1)) screen_touch_rx (
        .clk(sys_clk), .rst_n(live_synth_rst_n), .screen_rx_i(screen_rx_i),
        .held_keys(screen_touch_keys), .octave_shift(live_octave_shift), .test_mode(live_test_mode)
    );
    live_touch_key_merge #(.KEY_COUNT(KEY_COUNT), .TOUCH_VELOCITY(8'd160)) live_inputs (
        .clk(sys_clk), .rst_n(rst_n), .live_enable(!midi_mode),
        // 四频测试参考 synth-piano：C4/E4/G4/B4，四个独立声部，固定中等力度。
        .physical_keys(live_test_mode ? KEY_COUNT'(16'h0891) : key_down),
        .physical_velocity(live_test_mode ? {KEY_COUNT{8'd176}} : velocity_values),
        .touch_keys(live_test_mode ? {KEY_COUNT{1'b0}} : screen_touch_keys), .held_keys(live_keys),
        .key_on_pulse(live_key_on), .key_off_pulse(live_key_off),
        .velocity_values(live_velocity), .active_key_count(live_active_key_count)
    );
    poly_synth_4voice #(.KEY_COUNT(KEY_COUNT), .MIX_SHIFT(0), .ADSR_ENABLE(1), .PIPELINE_INPUTS(1), .OCTAVE_CONTROL(1)) live_synth (
        .clk(sys_clk), .rst_n(live_synth_rst_n), .sample_tick(live_sample_tick),
        .timbre(live_timbre), .octave_shift(live_test_mode ? 2'd0 : live_octave_shift),
        .key_on_pulse(live_key_on), .key_off_pulse(live_key_off),
        .velocity_values(live_velocity), .key_notes({KEY_COUNT*8{1'b0}}),
        .key_timbres({KEY_COUNT*6{1'b0}}), .sample_out(live_sample),
        .voice_gate(live_voice_gate), .voice_assigned(live_voice_assigned),
        .voice_keys(live_voice_keys), .voice_levels(live_voice_levels),
        .timbre_blends(live_timbre_blends), .voice_phase_steps(live_voice_phase_steps)
    );
    generate if (AUDIO_I2S) begin : g_i2s
    i2s_tx live_audio_tx (
        .clk(sys_clk), .rst_n(rst_n), .sample_left(live_sample), .sample_right(live_sample),
        .sample_tick(live_sample_tick), .hp_bck(live_hp_bck),
        .hp_ws(live_hp_ws), .hp_din(live_hp_din)
    );
    end else begin : g_pt8211
    pt8211_tx live_audio_tx (
        .clk(sys_clk), .rst_n(rst_n), .sample_left(live_sample), .sample_right(live_sample),
        .sample_tick(live_sample_tick), .hp_bck(live_hp_bck),
        .hp_ws(live_hp_ws), .hp_din(live_hp_din)
    );
    end endgenerate

    // V11 的完整 MIDI 上传、解析、四声部和自定义波表链路作为子系统复用。
    // 它只接收 MIDI/FTB 和控制命令，不接收 PCM 或逐音符串流。
    midi_player_top #(.AUDIO_I2S(AUDIO_I2S)) midi_core (
        .sys_clk(sys_clk), .sys_rst_n(sys_rst_n), .uart_rx_i(uart_rx_i),
        .uart_tx_o(uart_tx_o), .led_n(midi_led_n),
        .hp_bck(midi_hp_bck), .hp_ws(midi_hp_ws), .hp_din(midi_hp_din),
        .pa_en(midi_pa_en)
    );

    // 外部 C18 为 FPGA TX -> 屏幕 RX，C19 为 FPGA RX <- 屏幕 TX。
    // 默认 115200/8N1；16 键页面压力组件扩展为 t3..t18，t1 容量需容纳 10（十六进制16）。
    serial_screen_nextion_tx #(
        .KEY_COUNT(KEY_COUNT),
        .CLKS_PER_BIT(SCREEN_CLKS_PER_BIT),
        .STARTUP_DELAY_CYCLES(SCREEN_STARTUP_CYCLES),
        .UPDATE_PERIOD_CYCLES(SCREEN_UPDATE_CYCLES)
    ) screen_link (
        .clk(sys_clk), .rst_n(rst_n), .pressure_values(pressure_values),
        .active_key_count(midi_mode ? midi_active_voice_count : live_active_key_count), .midi_mode(midi_mode),
        // READY 表示所选音频链路就绪；触摸弹奏无需 ADC 标定，实体 ADC 状态由 LED/HDMI 保留。
        .audio_ready(midi_mode ? midi_audio_ready : live_audio_ready), .file_ready(midi_file_ready),
        .parser_busy(midi_parser_busy), .playing(midi_mode ? midi_playing : (|live_voice_gate)),
        .screen_rx_i(screen_rx_i),
        .screen_tx_o(screen_tx_o), .rx_activity(screen_rx_activity)
    );

    always @(*) begin
        max_pressure = 13'd0;
        for (key_index = 0; key_index < KEY_COUNT; key_index = key_index + 1)
            if (pressure_values[key_index*ADC_BITS +: ADC_BITS] > max_pressure[11:0])
                max_pressure = {1'b0, pressure_values[key_index*ADC_BITS +: ADC_BITS]};

        if      (max_pressure >= 13'd224) pressure_bar = 7'b111_1111;
        else if (max_pressure >= 13'd144) pressure_bar = 7'b011_1111;
        else if (max_pressure >= 13'd96)  pressure_bar = 7'b001_1111;
        else if (max_pressure >= 13'd64)  pressure_bar = 7'b000_1111;
        else if (max_pressure >= 13'd48)  pressure_bar = 7'b000_0111;
        else if (max_pressure >= 13'd32)  pressure_bar = 7'b000_0011;
        else if (max_pressure >= 13'd16)  pressure_bar = 7'b000_0001;
        else                              pressure_bar = 7'b000_0000;
    end

    always @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            bar_levels_reg <= {BAR_BUS_WIDTH{1'b0}};
            blink_counter  <= 25'd0;
        end else begin
            blink_counter <= blink_counter + 1'b1;
            for (bar_index = 0; bar_index < KEY_COUNT; bar_index = bar_index + 1) begin
                if (pressure_values[bar_index*ADC_BITS +: ADC_BITS] >= 12'd467)
                    bar_levels_reg[bar_index*BAR_BITS +: BAR_BITS] <= 9'd350;
                else
                    bar_levels_reg[bar_index*BAR_BITS +: BAR_BITS] <=
                        pressure_values[bar_index*ADC_BITS + 8 -: 8] +
                        {2'b0, pressure_values[bar_index*ADC_BITS + 8 -: 7]};
            end
        end
    end

    snapshot_cdc #(.WIDTH(DISPLAY_WIDTH)) display_bridge (
        .src_clk(sys_clk), .src_rst_n(rst_n),
        .src_data({midi_voice_gate, midi_playing, midi_parser_busy,
                   midi_file_ready, midi_mode, adc_fault, selected_audio_ready,
                   calibrated, adc_ready, live_active_key_count, live_keys, bar_levels_reg}),
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
        .clk(pixel_clk), .rst_n(video_rst_n), .x(pixel_x), .y(pixel_y),
        .de(video_de), .hs_n(hsync_n), .vs_n(vsync_n), .frame_start(frame_start)
    );

    always @(posedge pixel_clk or negedge video_rst_n) begin
        if (!video_rst_n)
            frame_data <= {DISPLAY_WIDTH{1'b0}};
        else if (frame_start)
            frame_data <= display_data;
    end

    instrument_ui_1024x600 #(.KEY_COUNT(KEY_COUNT)) ui (
        .clk(pixel_clk), .x(pixel_x), .y(pixel_y),
        .bar_levels(frame_data[BAR_BUS_WIDTH-1:0]),
        .key_down(frame_data[BAR_BUS_WIDTH +: KEY_COUNT]),
        .active_key_count(frame_data[BAR_BUS_WIDTH+KEY_COUNT +: ACTIVE_COUNT_WIDTH]),
        .scan_ready(frame_data[FLAG_BASE]), .calibrated(frame_data[FLAG_BASE+1]),
        .audio_ready(frame_data[FLAG_BASE+2]), .fault(frame_data[FLAG_BASE+3]),
        .midi_mode(frame_data[FLAG_BASE+4]), .midi_file_ready(frame_data[FLAG_BASE+5]),
        .midi_parser_busy(frame_data[FLAG_BASE+6]), .midi_playing(frame_data[FLAG_BASE+7]),
        .midi_voice_gate(frame_data[FLAG_BASE+8 +: 4]), .rgb(video_rgb)
    );

    always @(posedge pixel_clk or negedge video_rst_n) begin
        if (!video_rst_n) begin
            video_de_d <= 1'b0;  hsync_n_d <= 1'b1;  vsync_n_d <= 1'b1;
            video_de_d2 <= 1'b0; hsync_n_d2 <= 1'b1; vsync_n_d2 <= 1'b1;
            video_de_d3 <= 1'b0; hsync_n_d3 <= 1'b1; vsync_n_d3 <= 1'b1;
        end else begin
            video_de_d <= video_de;    hsync_n_d <= hsync_n;    vsync_n_d <= vsync_n;
            video_de_d2 <= video_de_d; hsync_n_d2 <= hsync_n_d; vsync_n_d2 <= vsync_n_d;
            video_de_d3 <= video_de_d2; hsync_n_d3 <= hsync_n_d2; vsync_n_d3 <= vsync_n_d2;
        end
    end

    DVI_TX_Top transmitter (
        .I_rst_n(video_rst_n), .I_serial_clk(serial_clk), .I_rgb_clk(pixel_clk),
        .I_rgb_vs(vsync_n_d3), .I_rgb_hs(hsync_n_d3), .I_rgb_de(video_de_d3),
        .I_rgb_r(video_rgb[23:16]), .I_rgb_g(video_rgb[15:8]), .I_rgb_b(video_rgb[7:0]),
        .O_tmds_clk_p(tmds_clk_p), .O_tmds_clk_n(tmds_clk_n),
        .O_tmds_data_p(tmds_p), .O_tmds_data_n(tmds_n)
    );

    wire _unused = &{1'b0, baseline_values, display_update, screen_rx_activity,
                     live_voice_gate,
                     live_voice_assigned, live_voice_keys, live_voice_levels,
                     live_timbre_blends, live_voice_phase_steps};
endmodule

`default_nettype wire
