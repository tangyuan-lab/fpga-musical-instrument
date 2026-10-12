// 第 03 阶段顶层：一个消抖过的按键控制一个正弦声部和它的包络。
module tang_mega_60k_top (
    input wire sys_clk, input wire sys_rst_n, input wire key_n,
    output wire HP_BCK, output wire HP_WS, output wire HP_DIN, output wire PA_EN
);
    wire audio_rst_n = sys_rst_n;
    wire frame_tick, key_state, note_on, note_off;
    wire [15:0] envelope_gain;
    wire signed [15:0] sine_sample;
    wire signed [32:0] product = $signed(sine_sample) * $signed({1'b0, envelope_gain});
    wire signed [15:0] shaped_sample = product[31:16];
    // 沿用历史 testbench 用过的名字，纯粹为了好观察，
    // 只是别名，不是音频路径里多出来的逻辑。
    wire [15:0] adsr_gain = envelope_gain;
    wire signed [15:0] tone_sample = shaped_sample;
    reg [10:0] startup_frames = 11'd0;
    key_debounce key_filter (.sys_clk(sys_clk), .sys_rst_n(sys_rst_n), .key_n(key_n),
        .key_state(key_state), .note_on(note_on), .note_off(note_off));
    adsr envelope (.sys_clk(sys_clk), .sys_rst_n(sys_rst_n), .sample_tick(frame_tick),
        .note_on(note_on), .note_off(note_off), .note_active(key_state),
        .gain(envelope_gain), .voice_active());
    dds_sine_voice voice (.clk(sys_clk), .rst_n(sys_rst_n),
        .sample_tick(frame_tick), .sample_out(sine_sample));
    pt8211_tx audio_tx (.clk(sys_clk), .rst_n(sys_rst_n), .sample_in(tone_sample),
        .bck(HP_BCK), .ws(HP_WS), .din(HP_DIN), .frame_tick(frame_tick));
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) startup_frames <= 11'd0;
        else if (frame_tick && startup_frames != 11'd1024)
            startup_frames <= startup_frames + 1'b1;
    end
    assign PA_EN = !sys_rst_n || (startup_frames != 11'd1024);
endmodule

