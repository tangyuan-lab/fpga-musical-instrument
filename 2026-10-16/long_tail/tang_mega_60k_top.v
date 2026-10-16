module tang_mega_60k_top #(
    parameter integer KEY_FILTER_MAX = 250_000
) (
    input  wire sys_clk,
    input  wire sys_rst_n,
    input  wire key_n,
    output wire HP_BCK,
    output wire HP_WS,
    output wire HP_DIN,
    output wire PA_EN
);
    reg [3:0] init_shift = 4'd0;
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) init_shift <= 4'd0;
        else init_shift <= {init_shift[2:0], 1'b1};
    end
    wire audio_rst_n = sys_rst_n && init_shift[3];

    wire frame_tick;
    wire key_state;
    wire note_on;
    wire note_off;
    key_debounce #(.KEY_FILTER_MAX(KEY_FILTER_MAX)) key_0 (
        .sys_clk(sys_clk), .sys_rst_n(audio_rst_n), .key_n(key_n),
        .key_state(key_state), .note_on(note_on), .note_off(note_off)
    );

    // 第 1 次按下：已认可的短音。第 2 次按下：同一次击弦，
    // 后一档接同一段录音 1.415 秒之后的延续部分。
    reg long_tail_selected = 1'b1;
    always @(posedge sys_clk or negedge audio_rst_n) begin
        if (!audio_rst_n) long_tail_selected <= 1'b1;
        else if (note_on) long_tail_selected <= !long_tail_selected;
    end

    wire signed [15:0] recorded_pcm;
    sampled_piano_a4 sample_voice (
        .clk(sys_clk), .rst_n(audio_rst_n), .sample_tick(frame_tick),
        .note_on(note_on),
        .note_active(key_state),
        .long_tail_enable(long_tail_selected),
        .sample_out(recorded_pcm)
    );
    wire signed [15:0] tone_sample = recorded_pcm;
    pt8211_tx audio_tx (
        .clk(sys_clk), .rst_n(audio_rst_n), .sample_in(tone_sample),
        .bck(HP_BCK), .ws(HP_WS), .din(HP_DIN), .frame_tick(frame_tick)
    );

    reg [10:0] startup_frames = 11'd0;
    always @(posedge sys_clk) begin
        if (!audio_rst_n) startup_frames <= 11'd0;
        else if (frame_tick && startup_frames != 11'd1024)
            startup_frames <= startup_frames + 11'd1;
    end
    assign PA_EN = !audio_rst_n || (startup_frames != 11'd1024);
endmodule
