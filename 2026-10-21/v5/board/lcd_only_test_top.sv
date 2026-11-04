`timescale 1ns/1ps
`default_nettype none

// J5 RGB LCD 独立诊断顶层。
//
// 本模块故意不实例化 CTP、I2C、压力传感器和音频逻辑，只验证：
//   1. 50 MHz 系统时钟能够锁定 LCD 像素 PLL；
//   2. J5 的 RGB666、HSYNC、VSYNC、DE 和 PCLK 线序正确；
//   3. J5 背光使能能够打开。
//
// LED 采用低电平点亮：
//   LED7：PLL 锁定；
//   LED0：约 1 Hz 心跳，证明系统时钟仍在运行；
//   LED6..LED1：关闭。
module lcd_only_test_top (
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
    output wire [7:0] led_n
);
    wire pixel_clk;
    wire serial_clk_unused;
    wire pll_locked;
    wire pixel_rst_n;
    reg [1:0] pixel_reset_pipe;

    wire [10:0] x;
    wire [9:0]  y;
    wire        de;
    wire        hsync_n;
    wire        vsync_n;
    wire [5:0]  red;
    wire [5:0]  green;
    wire [5:0]  blue;

    // 50 MHz 时钟下约 1 秒翻转一次，供上板观察。
    reg [25:0] heartbeat_counter;
    reg        heartbeat;

    video_pll lcd_pll (
        .clkin(sys_clk),
        .reset(!sys_rst_n),
        .pixel_clk(pixel_clk),
        .serial_clk(serial_clk_unused),
        .locked(pll_locked)
    );

    always @(posedge pixel_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            pixel_reset_pipe <= 2'b00;
        end else begin
            pixel_reset_pipe <= {pixel_reset_pipe[0], pll_locked};
        end
    end

    assign pixel_rst_n = pixel_reset_pipe[1];

    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            heartbeat_counter <= 26'd0;
            heartbeat         <= 1'b0;
        end else if (heartbeat_counter == 26'd49_999_999) begin
            heartbeat_counter <= 26'd0;
            heartbeat         <= ~heartbeat;
        end else begin
            heartbeat_counter <= heartbeat_counter + 1'b1;
        end
    end

    lcd_timing_1024x600 timing (
        .pixel_clk(pixel_clk),
        .rst_n(pixel_rst_n),
        .x(x),
        .y(y),
        .de(de),
        .hsync_n(hsync_n),
        .vsync_n(vsync_n)
    );

    // 彩条模块没有触摸输入时输出固定彩条；这里直接给出释放状态。
    lcd_colorbar_1024x600 colorbar (
        .pixel_clk(pixel_clk),
        .rst_n(pixel_rst_n),
        .de(de),
        .x(x),
        .y(y),
        .touch_down(1'b0),
        .touch_x(12'd512),
        .touch_y(12'd300),
        .red(red),
        .green(green),
        .blue(blue)
    );

    assign lcd_r     = red;
    assign lcd_g     = green;
    assign lcd_b     = blue;
    assign lcd_pclk  = pixel_clk;
    assign lcd_hsync = hsync_n;
    assign lcd_vsync = vsync_n;
    assign lcd_de    = de;

    // 诊断阶段强制打开背光。实际板卡由 LP3320 根据该 EN 信号供电。
    assign lcd_bl = sys_rst_n && pll_locked;

    // LED 低电平点亮：LED7 显示 PLL 锁定，LED0 显示系统心跳。
    assign led_n[7]   = ~pll_locked;
    assign led_n[6:1] = 6'b111111;
    assign led_n[0]   = ~heartbeat;
endmodule

`default_nettype wire
