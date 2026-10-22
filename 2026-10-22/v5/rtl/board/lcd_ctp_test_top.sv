`timescale 1ns/1ps
`default_nettype none

// NEO Dock 板载 RGB LCD + 独立 CTP 首次联调顶层。
// J5 的 R0/R1、G0/G1、B0/B1 已在底板接地，因此这里输出 18 bit RGB666。
module lcd_ctp_test_top #(
    parameter integer CTP_RESET_CYCLES = 500_000,
    parameter integer CTP_STARTUP_CYCLES = 5_000_000
) (
    input  wire       sys_clk,
    input  wire       sys_rst_n,
    output wire [5:0] lcd_r,
    output wire [5:0] lcd_g,
    output wire [5:0] lcd_b,
    output wire       lcd_pclk,
    output wire       lcd_hsync,
    output wire       lcd_vsync,
    output wire       lcd_de,
    output wire       lcd_bl,
    inout  wire       ctp_scl,
    inout  wire       ctp_sda,
    input  wire       ctp_int,
    output wire       ctp_rst,
    output wire [7:0] led_n
);
    wire pixel_clk;
    wire serial_clk_unused;
    wire pll_locked;
    // PLL 锁定信号来自 sys_clk 域。让复位在 pixel_clk 域同步释放，
    // 避免直接用组合表达式驱动像素逻辑的异步复位。
    reg [1:0] pixel_reset_pipe;
    wire pixel_rst_n = pixel_reset_pipe[1];
    wire [10:0] x;
    wire [9:0]  y;
    wire de;
    wire hsync_n;
    wire vsync_n;
    wire [5:0] red;
    wire [5:0] green;
    wire [5:0] blue;

    wire ctp_ready;
    wire ctp_error;
    wire touch_down;
    wire touch_valid_unused;
    wire [2:0] touch_count;
    wire [11:0] touch_x;
    wire [11:0] touch_y;

    // 像素域同步触摸状态；坐标在一次 I2C 读取后保持，跨域同步足够稳定。
    reg touch_down_p1, touch_down_p2;
    reg [11:0] touch_x_p1, touch_x_p2;
    reg [11:0] touch_y_p1, touch_y_p2;
    reg [24:0] ctp_debug_counter;

    video_pll lcd_pll (
        .clkin(sys_clk), .reset(!sys_rst_n),
        .pixel_clk(pixel_clk), .serial_clk(serial_clk_unused), .locked(pll_locked)
    );

    always @(posedge pixel_clk or negedge sys_rst_n) begin
        if (!sys_rst_n)
            pixel_reset_pipe <= 2'b00;
        else
            pixel_reset_pipe <= {pixel_reset_pipe[0], pll_locked};
    end

    lcd_timing_1024x600 timing (
        .pixel_clk(pixel_clk), .rst_n(pixel_rst_n),
        .x(x), .y(y), .de(de), .hsync_n(hsync_n), .vsync_n(vsync_n)
    );

    always @(posedge pixel_clk or negedge pixel_rst_n) begin
        if (!pixel_rst_n) begin
            touch_down_p1 <= 1'b0;
            touch_down_p2 <= 1'b0;
            touch_x_p1 <= 12'd0;
            touch_x_p2 <= 12'd0;
            touch_y_p1 <= 12'd0;
            touch_y_p2 <= 12'd0;
        end else begin
            touch_down_p1 <= touch_down;
            touch_down_p2 <= touch_down_p1;
            touch_x_p1 <= touch_x;
            touch_x_p2 <= touch_x_p1;
            touch_y_p1 <= touch_y;
            touch_y_p2 <= touch_y_p1;
        end
    end

    // CTP 状态指示计数器。只用于 LED 诊断，不参与 LCD 时序。
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n)
            ctp_debug_counter <= 25'd0;
        else
            ctp_debug_counter <= ctp_debug_counter + 1'b1;
    end

    lcd_colorbar_1024x600 colorbar (
        .pixel_clk(pixel_clk), .rst_n(pixel_rst_n), .de(de), .x(x), .y(y),
        .touch_down(touch_down_p2), .touch_x(touch_x_p2), .touch_y(touch_y_p2),
        .red(red), .green(green), .blue(blue)
    );

    gt911_controller #(
        .CLK_HZ(50_000_000),
        .RESET_CYCLES(CTP_RESET_CYCLES),
        .STARTUP_CYCLES(CTP_STARTUP_CYCLES),
        .POLL_CYCLES(250_000)
    ) ctp (
        .clk(sys_clk), .rst_n(sys_rst_n), .ctp_int(ctp_int), .ctp_rst(ctp_rst),
        .ctp_scl(ctp_scl), .ctp_sda(ctp_sda),
        .ready(ctp_ready), .error(ctp_error), .touch_down(touch_down),
        .touch_valid(touch_valid_unused), .touch_count(touch_count),
        .touch_x(touch_x), .touch_y(touch_y)
    );

    assign lcd_r     = red;
    assign lcd_g     = green;
    assign lcd_b     = blue;
    assign lcd_pclk  = pixel_clk;
    assign lcd_hsync = hsync_n;
    assign lcd_vsync = vsync_n;
    assign lcd_de    = de;
    // LCD_DPI_BL 接到背光驱动 EN。PLL 锁定且系统未复位后再打开背光，
    // 避免上电期间向屏幕送入未稳定的时序。
    assign lcd_bl    = sys_rst_n && pll_locked;

    // PMOD0 低电平点亮，使用只看数量的互斥图案：
    //   未识别：1 颗慢闪；已就绪：4 颗常亮；错误：8 颗一起闪；触摸：8 颗常亮。
    assign led_n = touch_down ? 8'h00 :
                   ctp_error ? (ctp_debug_counter[24] ? 8'h00 : 8'hFF) :
                   ctp_ready ? 8'hF0 :
                   (ctp_debug_counter[24] ? 8'hFE : 8'hFF);

    wire _unused = &{1'b0, touch_valid_unused, touch_count};
endmodule

`default_nettype wire
