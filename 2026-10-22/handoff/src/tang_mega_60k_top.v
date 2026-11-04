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

    // Unified bank: old IDs 0..15 stay C4..D#5; new ID 16 is C3.
    // S2 demonstration order is C3, C4, C#4, ... D#5, then C3 again.
    // The voice captures the pre-increment ID on the note_on edge.
    reg [4:0] next_note_index = 5'd16;
    always @(posedge sys_clk or negedge audio_rst_n) begin
        if (!audio_rst_n) next_note_index <= 5'd16;
        else if (note_on)
            next_note_index <= next_note_index == 5'd16 ? 5'd0 : next_note_index + 5'd1;
    end

    // Accepted fitted timbres, unchanged gain and natural decay.
    // Hold S2 to sustain; release applies the original fitted damper.
    wire signed [15:0] tone_sample;
    piano_accepted_voice #(.ADSR_ENABLE(0)) voice (
        .clk(sys_clk), .rst_n(audio_rst_n), .sample_tick(frame_tick),
        .note_on(note_on), .note_off(note_off),
        .note_active(key_state),
        .note_index(next_note_index),
        .velocity(7'd112),
        .pitch_ratio_q15(16'd32768),
        .sample_out(tone_sample), .sample_valid()
    );
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

