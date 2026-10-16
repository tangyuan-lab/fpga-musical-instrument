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

    // S2 循环四个试听音高。钢琴声部独立接受一个音
    // 频率字和 7 位力度，和这个板载按键演示是解耦的。
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
    wire signed [15:0] tone_sample;
    wire key_state;
    wire note_on;
    wire note_off;
    reg [1:0] next_note_index = 2'd0;
    reg [1:0] current_note_index = 2'd0;
    wire [31:0] phase_step;

    key_debounce #(.KEY_FILTER_MAX(KEY_FILTER_MAX)) key_0 (
        .sys_clk   (sys_clk),
        .sys_rst_n (audio_rst_n),
        .key_n     (key_n),
        .key_state (key_state),
        .note_on   (note_on),
        .note_off  (note_off)
    );

    // 第一次按下放 A4，之后 B4、C5、D5；两位计数回绕到 A4。
    // 松键进 ADSR 释放期间不要换频率，让尾音把音高保持住。
    always @(posedge sys_clk or negedge audio_rst_n) begin
        if (!audio_rst_n) begin
            next_note_index <= 2'd0;
            current_note_index <= 2'd0;
        end else if (note_on) begin
            current_note_index <= next_note_index;
            next_note_index <= next_note_index + 2'd1;
        end
    end

    assign phase_step = (current_note_index == 2'd0) ? 32'd39_370_534 : // A4
                        (current_note_index == 2'd1) ? 32'd44_191_930 : // B4
                        (current_note_index == 2'd2) ? 32'd46_819_716 : // C5
                                                        32'd52_553_354;  // D5

    piano_voice voice_0 (
        .clk         (sys_clk),
        .rst_n       (audio_rst_n),
        .sample_tick (frame_tick),
        .phase_step  (phase_step),
        .note_on     (note_on),
        .note_active(key_state),
        .velocity    (7'd112),
        .sample_out  (raw_sample)
    );

    // 阶段五：阶段四 的 2 倍用户还是觉得大，这里降到 1 倍（GAIN_SHIFT=0），
    // 也就是原始声部幅度。相对 阶段二 v2 累计降了约 12 dB。
    // 综合器会把增益为 1 倍的 audio_gain 整个优化掉，这是预期行为，
    // 不是逻辑漏了——别看到综合报告里没这个实例就去"修"。
    audio_gain #(.GAIN_SHIFT(0)) output_gain (
        .sample_in  (raw_sample),
        .sample_out (tone_sample)
    );

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

