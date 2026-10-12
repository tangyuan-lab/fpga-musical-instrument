module top_step4_dual_voice #(
    parameter integer KEY_FILTER_MAX = 250_000
) (
    input  wire sys_clk,
    input  wire sys_rst_n,
    input  wire key_n,
    input  wire key2_n,

    output wire HP_BCK,
    output wire HP_WS,
    output wire HP_DIN,
    output wire PA_EN
);

    // 每个开发板按键通过独立的 ADSR 控制一个 Wildfire DDS 声部。
    // 48 kHz 的 PT8211 帧边界同时驱动包络和声部。
    reg [3:0] init_shift = 4'd0;
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n)
            init_shift <= 4'd0;
        else
            init_shift <= {init_shift[2:0], 1'b1};
    end
    wire audio_rst_n = sys_rst_n && init_shift[3];

    wire frame_tick;
    reg [10:0] startup_frames = 11'd0;
    wire signed [15:0] raw_sample;
    wire signed [15:0] raw_sample_1;
    wire signed [15:0] voice_sample_0;
    wire signed [15:0] voice_sample_1;
    wire signed [15:0] tone_sample;
    wire signed [23:0] mixed_pcm;
    wire key_state;
    wire note_on;
    wire note_off;
    wire [15:0] adsr_gain;
    wire key_state_1;
    wire note_on_1;
    wire note_off_1;
    wire [15:0] adsr_gain_1;

    key_debounce #(.KEY_FILTER_MAX(KEY_FILTER_MAX)) key_0 (
        .sys_clk   (sys_clk),
        .sys_rst_n (audio_rst_n),
        .key_n     (key_n),
        .key_state (key_state),
        .note_on   (note_on),
        .note_off  (note_off)
    );

    key_debounce #(.KEY_FILTER_MAX(KEY_FILTER_MAX)) key_1 (
        .sys_clk   (sys_clk),
        .sys_rst_n (audio_rst_n),
        .key_n     (key2_n),
        .key_state (key_state_1),
        .note_on   (note_on_1),
        .note_off  (note_off_1)
    );

    adsr envelope_0 (
        .sys_clk      (sys_clk),
        .sys_rst_n    (audio_rst_n),
        .sample_tick  (frame_tick),
        .note_on      (note_on),
        .note_off     (note_off),
        .note_active  (key_state),
        .gain         (adsr_gain),
        .voice_active ()
    );

    adsr envelope_1 (
        .sys_clk      (sys_clk),
        .sys_rst_n    (audio_rst_n),
        .sample_tick  (frame_tick),
        .note_on      (note_on_1),
        .note_off     (note_off_1),
        .note_active  (key_state_1),
        .gain         (adsr_gain_1),
        .voice_active ()
    );

    dds_sine_voice voice_0 (
        .clk         (sys_clk),
        .rst_n       (audio_rst_n),
        .sample_tick (frame_tick),
        .sample_out  (raw_sample)
    );

    dds_sine_voice #(.PHASE_STEP(32'd44_191_930)) voice_1 (
        .clk         (sys_clk),
        .rst_n       (audio_rst_n),
        .sample_tick (frame_tick),
        .sample_out  (raw_sample_1)
    );

    // 和野火 synth_voice.v 里的有符号 16 位增益缩放保持一致。
    wire signed [32:0] sample_product = $signed(raw_sample) *
                                        $signed({1'b0, adsr_gain});
    wire signed [32:0] sample_product_1 = $signed(raw_sample_1) *
                                          $signed({1'b0, adsr_gain_1});
    assign voice_sample_0 = sample_product[31:16];
    assign voice_sample_1 = sample_product_1[31:16];

    // 原混音器输出是 24 位。这里右移 8 位，使它
    // 高 16 位正好保持原来单声部的电平。
    audio_mixer_4ch #(.GAIN_SHIFT(8)) mixer (
        .sample_0   (voice_sample_0),
        .sample_1   (voice_sample_1),
        .sample_2   (16'sd0),
        .sample_3   (16'sd0),
        .sample_out (mixed_pcm)
    );
    assign tone_sample = mixed_pcm[23:8];

    always @(posedge sys_clk) begin
        if (!audio_rst_n) begin
            startup_frames <= 11'd0;
        end else if (frame_tick) begin
            if (startup_frames != 11'd1024)
                startup_frames <= startup_frames + 11'd1;
        end
    end

    pt8211_tx audio_tx (
        .clk        (sys_clk),
        .rst_n      (audio_rst_n),
        .sample_in  (tone_sample),
        .bck        (HP_BCK),
        .ws         (HP_WS),
        .din        (HP_DIN),
        .frame_tick (frame_tick)
    );

    // NS4263 的关断是高有效。等 1024 个有效帧（约 21.3 ms）之后才使能，
    // 复位期间立刻关断。
    assign PA_EN = !audio_rst_n || (startup_frames != 11'd1024);

endmodule

