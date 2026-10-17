`default_nettype none

// 1024x600 的 13 键压力显示页。
//
// 采用三级像素流水：第一级译码 x 到键号，第二级选择该键的柱高，第三级
// 绘制颜色。这样把 13 路字段选择从 50 MHz TMDS 输入路径中拆开。
module pressure_keys_ui_1024x600 (
    input  wire               clk,
    input  wire [10:0]        x,
    input  wire [9:0]         y,
    input  wire [13*9-1:0]    bar_levels,
    input  wire [12:0]        key_down,
    input  wire [3:0]         active_key_count,
    input  wire               scan_ready,
    input  wire               calibrated,
    input  wire               audio_ready,
    input  wire               fault,
    output reg  [23:0]        rgb
);
    integer i;
    integer key_index_c;
    reg system_ready_c;

    reg [10:0] x_q;
    reg [9:0]  y_q;
    reg [3:0]  key_index_q;
    reg        scan_ready_q;
    reg        calibrated_q;
    reg        audio_ready_q;
    reg        fault_q;
    reg [3:0]  active_key_count_q;
    reg        system_ready_q;

    reg [10:0] x_qq;
    reg [9:0]  y_qq;
    reg [8:0]  bar_height_qq;
    reg        selected_down_qq;
    reg        scan_ready_qq;
    reg        calibrated_qq;
    reg        audio_ready_qq;
    reg        fault_qq;
    reg [3:0]  active_key_count_qq;
    reg        system_ready_qq;

    reg [8:0] selected_bar_c;
    reg selected_down_c;
    reg [23:0] rgb_next;

    // 第一级只做固定的区间译码，不读取压力总线。
    always @(*) begin
        key_index_c    = 15;
        system_ready_c = scan_ready && calibrated && audio_ready && !fault;
        for (i = 0; i < 13; i = i + 1) begin
            if (x >= (20 + i*76) && x < (80 + i*76))
                key_index_c = i;
        end
    end

    always @(posedge clk) begin
        x_q                <= x;
        y_q                <= y;
        key_index_q        <= key_index_c[3:0];
        scan_ready_q       <= scan_ready;
        calibrated_q       <= calibrated;
        audio_ready_q      <= audio_ready;
        fault_q            <= fault;
        active_key_count_q <= active_key_count;
        system_ready_q     <= system_ready_c;
    end

    // 第二级做一次 13:1 小型字段选择，并把坐标/状态同步延后一拍。
    always @(*) begin
        selected_bar_c  = 9'd0;
        selected_down_c = 1'b0;
        if (key_index_q < 13) begin
            selected_bar_c  = bar_levels[key_index_q*9 +: 9];
            selected_down_c = key_down[key_index_q];
        end
    end

    always @(posedge clk) begin
        x_qq                <= x_q;
        y_qq                <= y_q;
        bar_height_qq      <= selected_bar_c;
        selected_down_qq   <= selected_down_c;
        scan_ready_qq      <= scan_ready_q;
        calibrated_qq      <= calibrated_q;
        audio_ready_qq     <= audio_ready_q;
        fault_qq           <= fault_q;
        active_key_count_qq <= active_key_count_q;
        system_ready_qq    <= system_ready_q;
    end

    // 第三级：只使用寄存后的量绘制画面。
    always @(*) begin
        rgb_next = 24'h08_10_1c;

        if (x_qq >= 20 && x_qq < 1004 && y_qq >= 20 && y_qq < 58)
            rgb_next = fault_qq ? 24'he8_45_45 :
                       system_ready_qq ? 24'h20_c8_88 : 24'he8_a8_32;

        if (y_qq >= 76 && y_qq < 112) begin
            if (x_qq >= 40  && x_qq < 230)
                rgb_next = scan_ready_qq ? 24'h36_b9_ef : 24'h2a_3a_50;
            if (x_qq >= 270 && x_qq < 460)
                rgb_next = calibrated_qq ? 24'h36_b9_ef : 24'h2a_3a_50;
            if (x_qq >= 500 && x_qq < 690)
                rgb_next = audio_ready_qq ? 24'hb0_72_ff : 24'h2a_3a_50;
            if (x_qq >= 730 && x_qq < 984)
                rgb_next = (active_key_count_qq != 0) ? 24'h20_d8_9b : 24'h2a_3a_50;
        end

        if (x_qq >= 20 && x_qq < 1004) begin
            if (y_qq >= 140 && y_qq < 520)
                rgb_next = 24'h18_2a_42;
            if (y_qq >= 154 && y_qq < 506)
                rgb_next = 24'h18_2a_42;
            if (y_qq >= (506 - bar_height_qq) && y_qq < 506)
                rgb_next = selected_down_qq ? 24'h32_d7_a2 : 24'h2c_75_98;
            if (y_qq >= 526 && y_qq < 548)
                rgb_next = selected_down_qq ? 24'h20_d8_9b : 24'h30_3a_50;
        end

        if (y_qq >= 560 && y_qq < 564 && x_qq >= 20 && x_qq < 1004)
            rgb_next = selected_down_qq ? 24'h20_d8_9b : 24'h6c_7b_91;
    end

    always @(posedge clk) begin
        rgb <= rgb_next;
    end
endmodule

`default_nettype wire

