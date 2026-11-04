`default_nettype none

// MIDI 事件调度器。
//
// event_start/end_tick 已由 FPGA MIDI 解析器生成。播放时 song_tick_q16 由
// 音频采样节拍推进，调度器只在 sample_tick 上发出 Note On/Off 脉冲；电脑
// 在 PLAY 之后不再发送逐音符命令。Tempo 表按 tick 顺序扫描，Tempo 改变时
// 用独立迭代除法器计算新的 tick_step，避免在 48.8 kHz 音频路径中使用除法。
module midi_player_scheduler #(
    parameter integer SAMPLE_RATE = 48828,
    parameter integer MAX_EVENTS = 256,
    parameter integer MAX_TEMPOS = 32
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        sample_tick,
    input  wire        start,
    input  wire        stop,
    input  wire        parser_ready,
    input  wire [15:0] division_ppqn,
    input  wire [8:0]  event_count,
    output reg  [8:0]  event_read_index,
    input  wire [31:0] event_start_tick,
    input  wire [31:0] event_end_tick,
    input  wire [6:0]  event_note,
    input  wire [7:0]  event_velocity,
    input  wire [5:0]  tempo_count,
    output reg  [5:0]  tempo_read_index,
    input  wire [31:0] tempo_tick,
    input  wire [23:0] tempo_us_per_quarter,
    output reg         note_on_valid,
    output reg  [6:0]  note_on_note,
    output reg  [7:0]  note_on_velocity,
    output reg         note_off_valid,
    output reg  [6:0]  note_off_note,
    output reg         playing,
    output reg         finished,
    output reg  [7:0]  current_voice_count
);
    reg [47:0] song_tick_q16;
    reg [31:0] tick_step_q16;
    // PLAY 启动时锁存事件总数，避免解析器 event_count 直接扇出到
    // 128 个活动音符槽的写使能组合逻辑。
    reg [8:0]  event_count_reg;
    reg [8:0]  start_index;
    reg [5:0]  next_tempo_index;
    reg [6:0]  off_scan_note;
    reg [127:0] active_notes;
    reg [31:0] note_end_tick [0:127];
    reg [7:0]  note_velocity [0:127];
    reg        off_scan_active;
    reg [31:0] off_scan_end_tick;
    reg        divider_start;
    reg        divider_waiting;
    reg [63:0] divider_dividend;
    reg [63:0] divider_divisor;
    wire       divider_busy;
    wire       divider_done;
    wire [63:0] divider_quotient;
    reg [15:0] ppqn_reg;
    reg [23:0] tempo_reg;
    reg        tempo_change_pending;
    reg        tempo_data_waited;
    reg        event_prefetch_wait;
    integer i;

    wire event_due = start_index < event_count_reg &&
                     event_start_tick <= song_tick_q16[47:16];
    wire note_off_due = off_scan_active &&
                        off_scan_end_tick <= song_tick_q16[47:16];
    wire same_note_retrigger = event_due && note_off_due &&
                               event_note == off_scan_note;
    wire count_note_on = event_due && !active_notes[event_note];
    wire count_note_off = note_off_due && !same_note_retrigger;

    u64_divider tempo_divider (
        .clk(clk), .rst_n(rst_n), .start(divider_start),
        .dividend(divider_dividend), .divisor(divider_divisor),
        .busy(divider_busy), .done(divider_done), .quotient(divider_quotient)
    );

    // 先同步选出当前释音槽，再比较结束 tick；避免 128 路选择器与
    // 32 位比较器串在一条路径上。sample_tick 间隔至少两拍：扫描索引
    // 在采样拍更新，下一系统时钟装载槽数据，再下一采样拍消费。
    // 实机采样间隔为 1024 个 50 MHz 系统时钟。
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            off_scan_active <= 1'b0;
            off_scan_end_tick <= 32'd0;
        end else begin
            off_scan_active <= active_notes[off_scan_note];
            off_scan_end_tick <= note_end_tick[off_scan_note];
        end
    end

    // numerator = PPQN * 1,000,000 * 2^16；denominator = tempo_us * sample_rate。
    // 结果单位为 tick/sample 的 Q16.16。
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            song_tick_q16 <= 48'd0;
            tick_step_q16 <= 32'd1;
            event_count_reg <= 9'd0;
            start_index <= 9'd0;
            next_tempo_index <= 6'd1;
            tempo_read_index <= 6'd0;
            event_read_index <= 9'd0;
            off_scan_note <= 7'd0;
            active_notes <= 128'd0;
            playing <= 1'b0;
            finished <= 1'b0;
            note_on_valid <= 1'b0;
            note_off_valid <= 1'b0;
            note_on_note <= 7'd0;
            note_on_velocity <= 8'd0;
            note_off_note <= 7'd0;
            current_voice_count <= 8'd0;
            divider_start <= 1'b0;
            divider_waiting <= 1'b0;
            divider_dividend <= 64'd0;
            divider_divisor <= 64'd1;
            ppqn_reg <= 16'd480;
            tempo_reg <= 24'd500000;
            tempo_change_pending <= 1'b0;
            tempo_data_waited <= 1'b0;
            event_prefetch_wait <= 1'b0;
            for (i = 0; i < 128; i = i + 1) begin
                note_end_tick[i] <= 32'd0;
                note_velocity[i] <= 8'd0;
            end
        end else begin
            divider_start <= 1'b0;
            note_on_valid <= 1'b0;
            note_off_valid <= 1'b0;

            if (stop) begin
                playing <= 1'b0;
                finished <= 1'b0;
                active_notes <= 128'd0;
                current_voice_count <= 8'd0;
            end

            if (start && parser_ready && !playing) begin
                playing <= 1'b1;
                finished <= 1'b0;
                song_tick_q16 <= 48'd0;
                start_index <= 9'd0;
                event_count_reg <= event_count;
                event_read_index <= 9'd0;
                tempo_read_index <= 6'd0;
                next_tempo_index <= 6'd1;
                off_scan_note <= 7'd0;
                active_notes <= 128'd0;
                current_voice_count <= 8'd0;
                ppqn_reg <= (division_ppqn == 0) ? 16'd480 : division_ppqn;
                tempo_reg <= (tempo_us_per_quarter == 0) ? 24'd500000 : tempo_us_per_quarter;
                divider_dividend <= ((division_ppqn == 0 ? 16'd480 : division_ppqn) * 64'd1_000_000) << 16;
                divider_divisor <= (tempo_us_per_quarter == 0 ? 24'd500000 : tempo_us_per_quarter) * SAMPLE_RATE;
                divider_start <= 1'b1;
                divider_waiting <= 1'b1;
                tempo_change_pending <= 1'b0;
                tempo_data_waited <= 1'b0;
                // midi_type0_parser 的事件 RAM 是同步读口；给它至少两个
                // 系统时钟装载 event 0，再开始消费音频采样节拍。
                event_prefetch_wait <= 1'b1;
                for (i = 0; i < 128; i = i + 1) begin
                    note_end_tick[i] <= 32'd0;
                    note_velocity[i] <= 8'd0;
                end
            end

            if (divider_done) begin
                tick_step_q16 <= (divider_quotient[31:0] == 0) ? 32'd1 : divider_quotient[31:0];
                divider_waiting <= 1'b0;
            end

            // Tempo 表为同步读口。索引改变后的第一拍让解析器锁存新数据，
            // 第二拍才启动除法器，避免把上一条 Tempo 用到下一段乐谱。
            if (tempo_change_pending && !divider_waiting) begin
                if (!tempo_data_waited) begin
                    tempo_data_waited <= 1'b1;
                end else begin
                    divider_dividend <= (ppqn_reg * 64'd1_000_000) << 16;
                    divider_divisor <= (tempo_us_per_quarter == 0 ? 24'd500000 : tempo_us_per_quarter) * SAMPLE_RATE;
                    divider_start <= 1'b1;
                    divider_waiting <= 1'b1;
                    tempo_change_pending <= 1'b0;
                    tempo_data_waited <= 1'b0;
                end
            end

            if (event_prefetch_wait)
                event_prefetch_wait <= 1'b0;

            if (playing && sample_tick && !divider_waiting && !event_prefetch_wait) begin
                // 一个采样周期最多发一个起音和一个释音，多个同 tick 事件会在后续采样
                // 连续发出，间隔远小于人耳可感知的 10 ms 控制指标。
                if (event_due) begin
                    note_on_valid <= 1'b1;
                    note_on_note <= event_note;
                    note_on_velocity <= event_velocity;
                    note_end_tick[event_note] <= event_end_tick;
                    note_velocity[event_note] <= event_velocity;
                    active_notes[event_note] <= 1'b1;
                    start_index <= start_index + 1'b1;
                    if (start_index + 1'b1 < event_count_reg)
                        event_read_index <= start_index + 1'b1;
                end

                if (note_off_due) begin
                    note_off_valid <= 1'b1;
                    note_off_note <= off_scan_note;
                    if (!same_note_retrigger)
                        active_notes[off_scan_note] <= 1'b0;
                end
                off_scan_note <= (off_scan_note == 7'd127) ? 7'd0 : off_scan_note + 1'b1;

                if (next_tempo_index < tempo_count &&
                    tempo_tick <= song_tick_q16[47:16] && !tempo_change_pending) begin
                    tempo_read_index <= next_tempo_index;
                    tempo_change_pending <= 1'b1;
                    tempo_data_waited <= 1'b0;
                    next_tempo_index <= next_tempo_index + 1'b1;
                end

                song_tick_q16 <= song_tick_q16 + tick_step_q16;
                case ({count_note_on, count_note_off})
                    2'b10: current_voice_count <= current_voice_count + 1'b1;
                    2'b01: current_voice_count <= current_voice_count - 1'b1;
                    default: current_voice_count <= current_voice_count;
                endcase
                if (start_index >= event_count_reg && active_notes == 0) begin
                    playing <= 1'b0;
                    finished <= 1'b1;
                end
            end

            if (!playing && !start)
                current_voice_count <= 8'd0;
        end
    end
endmodule

`default_nettype wire
