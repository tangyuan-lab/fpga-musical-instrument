`timescale 1ns/1ps
`default_nettype none

// MCP3208 到货前的四声部上板试听工程。
// 它自动循环播放 Cmaj7、Fmaj7、G7、Am7，每个和弦保持约一秒，直接使用
// NEO Dock 的 PT8211-S 和耳机接口。该顶层不读取片内 ADC，也不改正式压力工程。
module polyphony_demo_top #(
    parameter integer STARTUP_CYCLES = 5_000_000,
    parameter integer CHORD_CYCLES   = 50_000_000
) (
    input  wire       sys_clk,
    input  wire       sys_rst_n,
    output wire [7:0] led_n,
    output wire       hp_bck,
    output wire       hp_ws,
    output wire       hp_din,
    output wire       pa_en
);
    localparam integer CHORD_COUNT_WIDTH =
        (CHORD_CYCLES <= 1) ? 1 : $clog2(CHORD_CYCLES);

    wire rst_n;
    wire audio_ready;
    wire sample_tick;
    wire signed [15:0] mixed_sample;
    wire [3:0] voice_gate;
    wire [3:0] voice_assigned;
    wire [15:0] voice_keys;
    wire [51:0] voice_levels;
    wire [31:0] timbre_blends;
    wire [127:0] voice_phase_steps;
    wire [13*8-1:0] fixed_velocities;
    reg [12:0] key_on_pulse;
    reg [12:0] key_off_pulse;
    reg [12:0] held_keys;
    reg [1:0] chord_index;
    reg [CHORD_COUNT_WIDTH-1:0] chord_counter;
    reg sequence_started;

    function automatic [12:0] chord_mask;
        input [1:0] chord_number;
        begin
            case (chord_number)
                2'd0: chord_mask = 13'b0_1000_1001_0001; // Cmaj7: C E G B
                2'd1: chord_mask = 13'b0_0010_0011_0001; // Fmaj7: F A C E
                2'd2: chord_mask = 13'b0_1000_1010_0100; // G7:    G B D F
                2'd3: chord_mask = 13'b1_0010_1001_0000; // Am7:   A C E G（C5 转位）
                default: chord_mask = 13'd0;
            endcase
        end
    endfunction

    reset_sync reset_sync_inst (
        .clk(sys_clk), .arst_n(sys_rst_n), .rst_n(rst_n)
    );

    audio_startup #(.STARTUP_CYCLES(STARTUP_CYCLES)) startup (
        .clk(sys_clk), .rst_n(rst_n), .audio_ready(audio_ready), .pa_en(pa_en)
    );

    // 所有自动演示键使用中等力度，保留足够耳机音量余量。
    assign fixed_velocities = {13{8'd176}};

    always @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            key_on_pulse    <= 13'd0;
            key_off_pulse   <= 13'd0;
            held_keys       <= 13'd0;
            chord_index     <= 2'd0;
            chord_counter   <= {CHORD_COUNT_WIDTH{1'b0}};
            sequence_started <= 1'b0;
        end else begin
            key_on_pulse  <= 13'd0;
            key_off_pulse <= 13'd0;

            if (!audio_ready) begin
                chord_counter <= {CHORD_COUNT_WIDTH{1'b0}};
            end else if (!sequence_started) begin
                held_keys        <= chord_mask(2'd0);
                key_on_pulse     <= chord_mask(2'd0);
                sequence_started <= 1'b1;
            end else if (CHORD_CYCLES <= 1 || chord_counter == CHORD_CYCLES - 1) begin
                chord_counter <= {CHORD_COUNT_WIDTH{1'b0}};
                key_off_pulse <= held_keys & ~chord_mask(chord_index + 2'd1);
                chord_index   <= chord_index + 2'd1;
                held_keys     <= chord_mask(chord_index + 2'd1);
                key_on_pulse  <= chord_mask(chord_index + 2'd1) & ~held_keys;
            end else begin
                chord_counter <= chord_counter + 1'b1;
            end
        end
    end

    poly_synth_4voice synth (
        .clk(sys_clk), .rst_n(rst_n), .sample_tick(sample_tick), .timbre(1'b0),
        .key_on_pulse(key_on_pulse), .key_off_pulse(key_off_pulse),
        .velocity_values(fixed_velocities), .sample_out(mixed_sample),
        .voice_gate(voice_gate), .voice_assigned(voice_assigned),
        .voice_keys(voice_keys), .voice_levels(voice_levels),
        .timbre_blends(timbre_blends),
        .voice_phase_steps(voice_phase_steps)
    );

    pt8211_tx audio_tx (
        .clk(sys_clk), .rst_n(rst_n),
        .sample_left(mixed_sample), .sample_right(mixed_sample),
        .sample_tick(sample_tick), .hp_bck(hp_bck),
        .hp_ws(hp_ws), .hp_din(hp_din)
    );

    // LED7=音频就绪，LED6～3=四个声部门控，LED1～0=当前和弦编号。
    assign led_n = ~{audio_ready, voice_gate, 1'b0, chord_index};

    wire _unused = &{1'b0, voice_assigned, voice_keys, voice_levels,
                     timbre_blends, voice_phase_steps};
endmodule

`default_nettype wire
