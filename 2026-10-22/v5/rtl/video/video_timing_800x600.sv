`default_nettype none

// VESA 800x600@60：40 MHz，1056x628，总同步为正极性。
module video_timing_800x600 (
    input  wire        clk,
    input  wire        rst_n,
    output reg  [10:0] x,
    output reg  [9:0]  y,
    output wire        de,
    output wire        hs,
    output wire        vs
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x <= 11'd0;
            y <= 10'd0;
        end else if (x == 11'd1055) begin
            x <= 11'd0;
            y <= (y == 10'd627) ? 10'd0 : y + 1'b1;
        end else begin
            x <= x + 1'b1;
        end
    end

    assign de = (x < 11'd800) && (y < 10'd600);
    assign hs = (x >= 11'd840) && (x < 11'd968);
    assign vs = (y >= 10'd601) && (y < 10'd605);
endmodule

`default_nettype wire
