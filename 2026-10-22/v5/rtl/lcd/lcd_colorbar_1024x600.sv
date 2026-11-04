`default_nettype none

// LCD 首次上板测试画面：六段彩条和触摸点动态波纹。
module lcd_colorbar_1024x600 (
    input  wire       pixel_clk,
    input  wire       rst_n,
    input  wire       de,
    input  wire [10:0] x,
    input  wire [9:0]  y,
    input  wire        touch_down,
    input  wire [11:0] touch_x,
    input  wire [11:0] touch_y,
    output reg [5:0]   red,
    output reg [5:0]   green,
    output reg [5:0]   blue
);
    // 动画相位每帧递增。触摸释放后清零，使下一次按下从小波纹重新开始。
    reg [7:0] anim_phase;

    always @(posedge pixel_clk or negedge rst_n) begin
        if (!rst_n) begin
            anim_phase <= 8'd0;
        end else if (!touch_down) begin
            anim_phase <= 8'd0;
        end else if ((x == 11'd0) && (y == 10'd0)) begin
            anim_phase <= anim_phase + 1'b1;
        end
    end

    // 用 |dx|+|dy| 代替开平方，得到资源开销较小的菱形扩散波纹。
    // 半径每帧增加 1 像素，达到最大值后自然回绕，形成连续动画。
    wire [11:0] x_ext = {1'b0, x};
    wire [11:0] y_ext = {2'b00, y};
    wire [11:0] touch_x_abs = (x_ext >= touch_x) ? (x_ext - touch_x) : (touch_x - x_ext);
    wire [11:0] touch_y_abs = (y_ext >= touch_y) ? (y_ext - touch_y) : (touch_y - y_ext);
    wire [12:0] touch_distance = {1'b0, touch_x_abs} + {1'b0, touch_y_abs};
    wire [11:0] ripple_radius = 12'd24 + {4'd0, anim_phase};
    wire [12:0] ripple_low = (ripple_radius > 12'd4) ? ripple_radius - 12'd4 : 13'd0;
    wire [12:0] ripple_high = ripple_radius + 12'd4;
    wire ripple_hit = touch_down &&
                      (touch_distance >= ripple_low) &&
                      (touch_distance <= ripple_high);
    wire touch_core = touch_down && (touch_distance <= 13'd18);
    // RGB 数据与 DE/坐标保持同一像素周期。原先把 RGB 再寄存一拍，
    // 但没有同步延迟 DE/HSYNC/VSYNC，会造成画面整体错一列。
    always @(*) begin
        red   = 6'd0;
        green = 6'd0;
        blue  = 6'd0;
        if (de) begin
            if (ripple_hit) begin
                // 波纹使用白色，便于在任何彩条背景上观察。
                red   = 6'h3f;
                green = 6'h3f;
                blue  = 6'h3f;
            end else if (touch_core) begin
                // 触摸中心使用亮青色，与外圈波纹区分。
                red   = 6'd0;
                green = 6'h3f;
                blue  = 6'h3f;
            end else if (x < 11'd171) begin
                red = 6'h3f;
            end else if (x < 11'd342) begin
                red   = 6'h3f;
                green = 6'h3f;
            end else if (x < 11'd513) begin
                green = 6'h3f;
            end else if (x < 11'd684) begin
                green = 6'h3f;
                blue  = 6'h3f;
            end else if (x < 11'd855) begin
                blue = 6'h3f;
            end else begin
                red  = 6'h3f;
                blue = 6'h3f;
            end
        end
    end
endmodule

`default_nettype wire
