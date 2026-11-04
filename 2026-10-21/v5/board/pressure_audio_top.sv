`default_nettype none

module pressure_audio_top #(
    parameter integer STARTUP_CYCLES = 5_000_000
) (
    input  wire       sys_clk,
    input  wire       sys_rst_n,
    output wire       uart_tx_o,
    output wire [7:0] led_n,
    output wire       hp_bck,
    output wire       hp_ws,
    output wire       hp_din,
    output wire       pa_en
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

    // ADC 超时后立即阻止新声音；已有声音仍经约 5.2 ms 释音归零。
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

    // LED7 表示 ADC、校准和音频均就绪；LED0～6 是压力条，低电平点亮。
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

    wire _unused = &{1'b0, adc1, baseline};
endmodule

`default_nettype wire
