// 真实 A4 录音的播放器，可选接一段低采样率的延音。
// 前 1.415 秒（67904 个 48 kHz 字）与已认可的 A4 对照版 版本逐字相同——
// 起音被认可之后就不要碰它，出问题才好判断是尾音交接的问题还是音头变了。
//
// 修正记录（原工程 快速重触发修正，板上实测过的真 bug）：
// 原来的 note_on 会把输出寄存器立刻清零（因为新音要从 ROM 0 号地址重播）。
// 但快速连按时上一个音的松键淡出还没走完，输出可能还有几百个 PCM 的幅度，
// 从非零直接打到零就是一个垂直跳变，板上听是"咔"的一声。
// 现在的做法：note_on 时先把当前输出存进 restart_from，只有 |输出| > 32 PCM
// 才启用交叠，在新音开始后的 32 个采样帧（48 kHz 下约 0.67 ms）内把权重
// 从旧走到新。
// 从静音开始的第一次按键不走这段交叠——本来就是零，没有不连续可言，
// 走了反而白给起音加 0.67 ms 延迟。
module sampled_piano_a4 (
    input  wire               clk,
    input  wire               rst_n,
    input  wire               sample_tick,
    input  wire               note_on,
    input  wire               note_active,
    input  wire               long_tail_enable,
    output wire signed [15:0] sample_out
);
    localparam [17:0] FRONT_END = 18'd72000;
    localparam [17:0] TAIL_START = 18'd67904;
    localparam [17:0] TAIL_END = 18'd192000;
    localparam [15:0] TAIL_LAST = 16'd41366;

    reg signed [15:0] front_rom [0:72000];
    reg signed [7:0] tail_rom [0:41366];
    initial begin
        $readmemh("mem/sample_a4_v16_front_72001x16.mem", front_rom);
        $readmemh("mem/sample_a4_v16_tail_41367x8.mem", tail_rom);
    end

    reg [17:0] elapsed_frames = 18'd0;
    wire [17:0] next_elapsed = (elapsed_frames < TAIL_END) ?
                               elapsed_frames + 18'd1 : elapsed_frames;
    wire [17:0] read_elapsed = sample_tick ? next_elapsed : elapsed_frames;
    wire [16:0] front_addr = (read_elapsed < FRONT_END) ?
                             read_elapsed[16:0] : 17'd72000;
    reg signed [15:0] front_q = 16'sd0;
    reg [15:0] tail_index = 16'd0;
    reg [1:0] tail_div = 2'd0;
    reg signed [7:0] tail_q = 8'sd0;
    reg [10:0] release_level = 11'd0;

    always @(posedge clk) begin
        front_q <= front_rom[front_addr];
        tail_q <= tail_rom[tail_index];
        if (!rst_n) begin
            elapsed_frames <= 18'd0;
            tail_index <= 16'd0;
            tail_div <= 2'd0;
            release_level <= 11'd0;
        end else if (note_on) begin
            elapsed_frames <= 18'd0;
            tail_index <= 16'd0;
            tail_div <= 2'd0;
            release_level <= 11'd2047;
        end else if (sample_tick) begin
            elapsed_frames <= next_elapsed;
            if (elapsed_frames >= TAIL_START && elapsed_frames < TAIL_END) begin
                if (tail_div == 2'd2) begin
                    tail_div <= 2'd0;
                    if (tail_index < TAIL_LAST)
                        tail_index <= tail_index + 16'd1;
                end else begin
                    tail_div <= tail_div + 2'd1;
                end
            end
            if (!note_active && release_level != 11'd0)
                release_level <= release_level - 11'd1;
        end
    end

    // 前段录音在最后 4096 帧里淡出，所以在这段时间内把
    // 16 kHz 的延续部分按互补的幅度抬起来。
    wire [17:0] tail_elapsed = elapsed_frames - TAIL_START;
    wire signed [10:0] tail_scaled =
        $signed(tail_q) * 11'sd3;
    wire signed [19:0] tail_ramp_product =
        tail_scaled * $signed({1'b0, tail_elapsed[11:4]});
    wire signed [11:0] tail_ramped = tail_ramp_product >>> 8;
    reg signed [17:0] tail_add;
    always @* begin
        if (!long_tail_enable || elapsed_frames < TAIL_START)
            tail_add = 18'sd0;
        else if (elapsed_frames >= FRONT_END)
            tail_add = tail_scaled;
        else
            tail_add = tail_ramped;
    end
    wire signed [17:0] mixed_sample =
        $signed({{2{front_q[15]}}, front_q}) + tail_add;
    reg signed [17:0] mixed_q = 18'sd0;
    always @(posedge clk) begin
        if (!rst_n || note_on)
            mixed_q <= 18'sd0;
        else
            mixed_q <= mixed_sample;
    end
    wire signed [29:0] release_product =
        mixed_q * $signed({1'b0, release_level});
    wire signed [15:0] fresh_pcm = release_product[26:11];
    reg signed [15:0] fresh_q = 16'sd0;
    always @(posedge clk) begin
        if (!rst_n || note_on)
            fresh_q <= 16'sd0;
        else
            fresh_q <= fresh_pcm;
    end

    // 快速重触发时，把当前输出带进这一次新的击弦，
    // 在 32 个采样帧内完成交接。从静音开始的第一次击弦不走这段。
    reg signed [15:0] restart_from = 16'sd0;
    reg [5:0] restart_phase = 6'd0;
    wire signed [16:0] restart_difference =
        $signed({restart_from[15], restart_from}) -
        $signed({fresh_q[15], fresh_q});
    wire signed [6:0] restart_weight = $signed({1'b0, restart_phase});
    wire signed [23:0] restart_product =
        restart_difference * restart_weight;
    wire signed [17:0] restart_delta = restart_product[22:5];
    wire signed [17:0] blended_pcm =
        $signed({{2{fresh_q[15]}}, fresh_q}) + restart_delta;

    // 让 ROM/混音、音量和重触发这几级各自占一个 50 MHz 周期。
    // 这点延迟相对一个 48 kHz 帧可以忽略。
    reg signed [15:0] output_q = 16'sd0;
    always @(posedge clk) begin
        if (!rst_n) begin
            output_q <= 16'sd0;
            restart_from <= 16'sd0;
            restart_phase <= 6'd0;
        end else if (note_on) begin
            restart_from <= output_q;
            if (output_q > 16'sd32 || output_q < -16'sd32)
                restart_phase <= 6'd32;
            else
                restart_phase <= 6'd0;
            // ROM 重新开始播放之前，先保持旧输出不动。
        end else begin
            output_q <= (restart_phase != 6'd0) ?
                        blended_pcm[15:0] : fresh_q;
            if (sample_tick && restart_phase != 6'd0)
                restart_phase <= restart_phase - 6'd1;
        end
    end
    assign sample_out = rst_n ? output_q : 16'sd0;
endmodule
