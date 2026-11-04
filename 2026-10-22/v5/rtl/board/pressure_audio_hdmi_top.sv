`default_nettype none

module pressure_audio_hdmi_top #(
    parameter integer STARTUP_CYCLES = 5_000_000
) (
    input  wire       sys_clk,
    input  wire       sys_rst_n,
    output wire       uart_tx_o,
    output wire [7:0] led_n,
    output wire       hp_bck,
    output wire       hp_ws,
    output wire       hp_din,
    output wire       pa_en,
    output wire [2:0] tmds_p,
    output wire [2:0] tmds_n,
    output wire       tmds_clk_p,
    output wire       tmds_clk_n,
    output wire       hpd_en
);
    localparam [31:0] PHASE_STEP_A4 = 32'd38_702_809;

    wire rst_n;
    wire [13:0] adc0;
    wire [13:0] adc1;
    wire sample_valid;
    wire adc_ready;
    wire adc_fault;
    wire audio_ready;
    wire calibrated;
    wire [12:0] baseline;
    wire [12:0] pressure_drop;
    wire [11:0] pressure_value;
    wire note_gate;
    wire safe_gate;
    wire [12:0] volume_target;
    wire [12:0] volume_level;
    wire sample_tick;
    wire signed [15:0] sample_value;
    reg [6:0] pressure_bar;
    reg [24:0] blink_counter;

    wire pixel_clk;
    wire serial_clk;
    wire pll_locked;
    wire video_rst_n;
    wire [29:0] display_data;
    wire display_update;
    reg  [29:0] frame_data;
    wire [10:0] pixel_x;
    wire [9:0] pixel_y;
    wire video_de;
    wire hsync_n;
    wire vsync_n;
    wire frame_start;
    wire [23:0] video_rgb;

    // NEO Dock 的 HDMI 发送端需要 K13 保持高电平。Sipeed 官方 60K cam_dvi
    // 工程也固定拉高此信号；若悬空，部分 HDMI 屏会反复掉线并重新锁定。
    assign hpd_en = 1'b1;

    reset_sync u_reset_sync (
        .clk(sys_clk), .arst_n(sys_rst_n), .rst_n(rst_n)
    );

    onchip_adc_scan u_adc (
        .clk(sys_clk), .rst_n(rst_n),
        .sample0(adc0), .sample1(adc1), .sample_valid(sample_valid),
        .ready(adc_ready), .timeout_fault(adc_fault)
    );

    audio_startup #(.STARTUP_CYCLES(STARTUP_CYCLES)) u_audio_startup (
        .clk(sys_clk), .rst_n(rst_n),
        .audio_ready(audio_ready), .pa_en(pa_en)
    );

    pressure_control u_pressure_control (
        .clk(sys_clk), .rst_n(rst_n),
        .sample_valid(sample_valid), .adc_ready(adc_ready),
        .audio_ready(audio_ready), .adc_sample(adc0[12:0]),
        .calibrated(calibrated), .baseline(baseline),
        .pressure_drop(pressure_drop), .pressure_value(pressure_value),
        .note_gate(note_gate), .volume_target(volume_target)
    );

    assign safe_gate = note_gate && audio_ready && !adc_fault;

    pressure_tone u_pressure_tone (
        .clk(sys_clk), .rst_n(rst_n), .sample_tick(sample_tick),
        .gate(safe_gate), .phase_step(PHASE_STEP_A4),
        .target_level(volume_target), .sample_out(sample_value),
        .current_level(volume_level)
    );

    pt8211_tx u_pt8211_tx (
        .clk(sys_clk), .rst_n(rst_n),
        .sample_left(sample_value), .sample_right(sample_value),
        .sample_tick(sample_tick), .hp_bck(hp_bck),
        .hp_ws(hp_ws), .hp_din(hp_din)
    );

    pressure_audio_telemetry u_telemetry (
        .clk(sys_clk), .rst_n(rst_n), .raw_adc(adc0),
        .pressure(pressure_value), .gate(safe_gate), .volume(volume_level),
        .status({adc_fault, audio_ready, calibrated, adc_ready}),
        .tx(uart_tx_o)
    );

    // HDMI 只接收旁路快照；音频门控和采样从不等待视频时钟或帧刷新。
    video_pll video_clocks (
        .clkin(sys_clk), .reset(!sys_rst_n),
        .pixel_clk(pixel_clk), .serial_clk(serial_clk), .locked(pll_locked)
    );
    reset_sync video_reset (
        .clk(pixel_clk), .arst_n(sys_rst_n && pll_locked), .rst_n(video_rst_n)
    );
    snapshot_cdc #(.WIDTH(30)) bridge (
        .src_clk(sys_clk), .src_rst_n(rst_n),
        .src_data({adc_fault, audio_ready, calibrated, adc_ready,
                   safe_gate, pressure_value, volume_level}),
        .dst_clk(pixel_clk), .dst_rst_n(video_rst_n),
        .dst_data(display_data), .dst_valid(display_update)
    );
    video_timing raster (
        .clk(pixel_clk), .rst_n(video_rst_n),
        .x(pixel_x), .y(pixel_y), .de(video_de),
        .hs_n(hsync_n), .vs_n(vsync_n), .frame_start(frame_start)
    );

    always @(posedge pixel_clk or negedge video_rst_n) begin
        if (!video_rst_n)
            frame_data <= 30'd0;
        else if (frame_start)
            frame_data <= display_data;
    end

    pressure_audio_ui_1024x600 ui (
        .x(pixel_x), .y(pixel_y),
        .pressure(frame_data[24:13]), .volume(frame_data[12:0]),
        .gate(frame_data[25]), .adc_ready(frame_data[26]),
        .calibrated(frame_data[27]), .audio_ready(frame_data[28]),
        .fault(frame_data[29]), .rgb(video_rgb)
    );
    // 使用 Sipeed 官方 Tang Mega 60K cam_dvi 工程同款 Gowin DVI TX IP。
    // 该 IP 已针对 GW5AT 的 OSER10 和 TMDS 差分输出做过板级验证。
    DVI_TX_Top transmitter (
        .I_rst_n(video_rst_n), .I_serial_clk(serial_clk),
        .I_rgb_clk(pixel_clk), .I_rgb_vs(vsync_n), .I_rgb_hs(hsync_n),
        .I_rgb_de(video_de), .I_rgb_r(video_rgb[23:16]),
        .I_rgb_g(video_rgb[15:8]), .I_rgb_b(video_rgb[7:0]),
        .O_tmds_clk_p(tmds_clk_p), .O_tmds_clk_n(tmds_clk_n),
        .O_tmds_data_p(tmds_p), .O_tmds_data_n(tmds_n)
    );

    always @(*) begin
        if      (pressure_drop >= 13'd224) pressure_bar = 7'b111_1111;
        else if (pressure_drop >= 13'd144) pressure_bar = 7'b011_1111;
        else if (pressure_drop >= 13'd96)  pressure_bar = 7'b001_1111;
        else if (pressure_drop >= 13'd64)  pressure_bar = 7'b000_1111;
        else if (pressure_drop >= 13'd48)  pressure_bar = 7'b000_0111;
        else if (pressure_drop >= 13'd32)  pressure_bar = 7'b000_0011;
        else if (pressure_drop >= 13'd16)  pressure_bar = 7'b000_0001;
        else                                pressure_bar = 7'b000_0000;
    end

    always @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n)
            blink_counter <= 25'd0;
        else
            blink_counter <= blink_counter + 1'b1;
    end

    assign led_n = adc_fault ? ~(blink_counter[24] ? 8'hAA : 8'h55) :
                   (adc_ready && calibrated && audio_ready) ? ~{1'b1, pressure_bar} :
                   ~(blink_counter[24] ? 8'h80 : 8'h00);

    wire _unused = &{1'b0, adc1, baseline, display_update};
endmodule

`default_nettype wire
