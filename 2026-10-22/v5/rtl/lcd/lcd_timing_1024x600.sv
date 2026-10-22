`default_nettype none

// 1024x600 DE 模式时序，51.25 MHz 像素时钟，约 60 Hz 刷新。
module lcd_timing_1024x600 (
    input  wire       pixel_clk,
    input  wire       rst_n,
    output reg [10:0] x,
    output reg [9:0]  y,
    output wire       de,
    output wire       hsync_n,
    output wire       vsync_n
);
    localparam integer H_ACTIVE = 1024;
    localparam integer H_FP     = 144;
    localparam integer H_SYNC   = 20;
    localparam integer H_BP     = 156;
    localparam integer H_TOTAL  = H_ACTIVE + H_FP + H_SYNC + H_BP;
    localparam integer V_ACTIVE = 600;
    localparam integer V_FP     = 12;
    localparam integer V_SYNC   = 3;
    localparam integer V_BP     = 20;
    localparam integer V_TOTAL  = V_ACTIVE + V_FP + V_SYNC + V_BP;

    always @(posedge pixel_clk or negedge rst_n) begin
        if (!rst_n) begin
            x <= 11'd0;
            y <= 10'd0;
        end else if (x == H_TOTAL-1) begin
            x <= 11'd0;
            y <= (y == V_TOTAL-1) ? 10'd0 : y + 1'b1;
        end else begin
            x <= x + 1'b1;
        end
    end

    assign de      = (x < H_ACTIVE) && (y < V_ACTIVE);
    assign hsync_n  = !((x >= H_ACTIVE+H_FP) && (x < H_ACTIVE+H_FP+H_SYNC));
    assign vsync_n  = !((y >= V_ACTIVE+V_FP) && (y < V_ACTIVE+V_FP+V_SYNC));
endmodule

`default_nettype wire
