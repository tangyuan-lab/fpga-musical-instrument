`default_nettype none

// 比赛统一工程的 1024x600 状态页。
// 实时模式显示 13 路压力柱；MIDI 模式把前四根柱改为四个硬件声部的门控状态，
// 顶部状态块显示文件就绪、解析和播放状态。该模块只负责显示，不参与音频控制。
module instrument_ui_1024x600 #(
    parameter integer KEY_COUNT = 13
) (
    input  wire               clk,
    input  wire [10:0]        x,
    input  wire [9:0]         y,
    input  wire [KEY_COUNT*9-1:0] bar_levels,
    input  wire [KEY_COUNT-1:0] key_down,
    input  wire [$clog2(KEY_COUNT+1)-1:0] active_key_count,
    input  wire               scan_ready,
    input  wire               calibrated,
    input  wire               audio_ready,
    input  wire               fault,
    input  wire               midi_mode,
    input  wire               midi_file_ready,
    input  wire               midi_parser_busy,
    input  wire               midi_playing,
    input  wire [3:0]         midi_voice_gate,
    output reg  [23:0]        rgb
);
    localparam integer INDEX_WIDTH = $clog2(KEY_COUNT+1);
    localparam integer COLUMN_PITCH = (KEY_COUNT == 16) ? 61 : 76;
    localparam integer COLUMN_WIDTH = (KEY_COUNT == 16) ? 48 : 60;
    integer i;
    integer key_index_c;
    reg system_ready_c;

    reg [10:0] x_q;
    reg [9:0]  y_q;
    reg [INDEX_WIDTH-1:0] key_index_q;
    reg        scan_ready_q;
    reg        calibrated_q;
    reg        audio_ready_q;
    reg        fault_q;
    reg [INDEX_WIDTH-1:0] active_key_count_q;
    reg        system_ready_q;
    reg        midi_mode_q;
    reg        midi_file_ready_q;
    reg        midi_parser_busy_q;
    reg        midi_playing_q;
    reg [3:0]  midi_voice_gate_q;

    reg [10:0] x_qq;
    reg [9:0]  y_qq;
    reg [8:0]  bar_height_qq;
    reg        selected_down_qq;
    reg        scan_ready_qq;
    reg        calibrated_qq;
    reg        audio_ready_qq;
    reg        fault_qq;
    reg [INDEX_WIDTH-1:0] active_key_count_qq;
    reg        system_ready_qq;
    reg        midi_mode_qq;
    reg        midi_file_ready_qq;
    reg        midi_parser_busy_qq;
    reg        midi_playing_qq;

    reg [8:0] selected_bar_c;
    reg selected_down_c;
    reg [23:0] rgb_next;

    always @(*) begin
        // 使用 KEY_COUNT 作无列命中哨兵，16 键不能再使用合法键号 15。
        key_index_c = KEY_COUNT;
        system_ready_c = midi_mode ? (audio_ready && midi_file_ready) :
                                     (scan_ready && calibrated && audio_ready && !fault);
        for (i = 0; i < KEY_COUNT; i = i + 1)
            if (x >= (20 + i*COLUMN_PITCH) && x < (20 + COLUMN_WIDTH + i*COLUMN_PITCH))
                key_index_c = i;
    end

    always @(posedge clk) begin
        x_q                 <= x;
        y_q                 <= y;
        key_index_q         <= key_index_c[INDEX_WIDTH-1:0];
        scan_ready_q        <= scan_ready;
        calibrated_q        <= calibrated;
        audio_ready_q       <= audio_ready;
        fault_q             <= fault;
        active_key_count_q  <= active_key_count;
        system_ready_q      <= system_ready_c;
        midi_mode_q         <= midi_mode;
        midi_file_ready_q   <= midi_file_ready;
        midi_parser_busy_q  <= midi_parser_busy;
        midi_playing_q      <= midi_playing;
        midi_voice_gate_q   <= midi_voice_gate;
    end

    // MIDI 模式只用前四列表示四个并行声部；实时模式显示 13 路压力。
    always @(*) begin
        selected_bar_c  = 9'd0;
        selected_down_c = 1'b0;
        if (key_index_q < KEY_COUNT) begin
            if (midi_mode_q) begin
                if (key_index_q < 4) begin
                    selected_down_c = midi_voice_gate_q[key_index_q];
                    selected_bar_c  = midi_voice_gate_q[key_index_q] ? 9'd300 : 9'd0;
                end
            end else begin
                selected_bar_c  = bar_levels[key_index_q*9 +: 9];
                selected_down_c = key_down[key_index_q];
            end
        end
    end

    always @(posedge clk) begin
        x_qq                 <= x_q;
        y_qq                 <= y_q;
        bar_height_qq       <= selected_bar_c;
        selected_down_qq    <= selected_down_c;
        scan_ready_qq       <= scan_ready_q;
        calibrated_qq       <= calibrated_q;
        audio_ready_qq      <= audio_ready_q;
        fault_qq            <= fault_q;
        active_key_count_qq <= active_key_count_q;
        system_ready_qq     <= system_ready_q;
        midi_mode_qq        <= midi_mode_q;
        midi_file_ready_qq  <= midi_file_ready_q;
        midi_parser_busy_qq <= midi_parser_busy_q;
        midi_playing_qq     <= midi_playing_q;
    end

    always @(*) begin
        rgb_next = 24'h08_10_1c;

        // 绿色表示实时演奏就绪，紫色表示 MIDI 文件已经就绪，橙色表示等待。
        if (x_qq >= 20 && x_qq < 1004 && y_qq >= 20 && y_qq < 58)
            rgb_next = (!midi_mode_qq && fault_qq) ? 24'he8_45_45 :
                       system_ready_qq ? (midi_mode_qq ? 24'h8a_5c_e6 : 24'h20_c8_88) :
                                         24'he8_a8_32;

        // 四块状态区在 MIDI 模式下依次代表：模式、文件、解析器、播放。
        if (y_qq >= 76 && y_qq < 112) begin
            if (x_qq >= 40 && x_qq < 230)
                rgb_next = midi_mode_qq ? 24'h8a_5c_e6 :
                           (scan_ready_qq ? 24'h36_b9_ef : 24'h2a_3a_50);
            if (x_qq >= 270 && x_qq < 460)
                rgb_next = midi_mode_qq ?
                           (midi_file_ready_qq ? 24'h36_b9_ef : 24'h2a_3a_50) :
                           (calibrated_qq ? 24'h36_b9_ef : 24'h2a_3a_50);
            if (x_qq >= 500 && x_qq < 690)
                rgb_next = midi_mode_qq ?
                           (midi_parser_busy_qq ? 24'he8_a8_32 : 24'h36_b9_ef) :
                           (audio_ready_qq ? 24'hb0_72_ff : 24'h2a_3a_50);
            if (x_qq >= 730 && x_qq < 984)
                rgb_next = midi_mode_qq ?
                           (midi_playing_qq ? 24'h20_d8_9b : 24'h2a_3a_50) :
                           ((active_key_count_qq != 0) ? 24'h20_d8_9b : 24'h2a_3a_50);
        end

        if (x_qq >= 20 && x_qq < 1004) begin
            if (y_qq >= 140 && y_qq < 520)
                rgb_next = 24'h18_2a_42;
            if (y_qq >= (506 - bar_height_qq) && y_qq < 506)
                rgb_next = selected_down_qq ?
                           (midi_mode_qq ? 24'hb0_72_ff : 24'h32_d7_a2) : 24'h2c_75_98;
            if (y_qq >= 526 && y_qq < 548)
                rgb_next = selected_down_qq ?
                           (midi_mode_qq ? 24'h8a_5c_e6 : 24'h20_d8_9b) : 24'h30_3a_50;
        end

        if (y_qq >= 560 && y_qq < 564 && x_qq >= 20 && x_qq < 1004)
            rgb_next = midi_mode_qq ? 24'h8a_5c_e6 : 24'h20_d8_9b;
    end

    always @(posedge clk)
        rgb <= rgb_next;
endmodule

`default_nettype wire
