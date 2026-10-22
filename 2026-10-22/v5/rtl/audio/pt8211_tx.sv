`default_nettype none

// PT8211-S 串行发送器。
// - 输入时钟：50 MHz。
// - BCK_HALF_DIV=16 时，BCK=50 MHz/(2*16)=1.5625 MHz。
// - 每声道恰好 16 个 BCK，WS=48.828125 kHz。
// - WS=0 发送右声道，WS=1 发送左声道；MSB 先发，LSB 紧贴 WS 翻转边界。
// 这属于 PT8211 的 LSBJ/右对齐格式，不是标准 I2S 的一位延迟格式。
module pt8211_tx #(
    parameter integer BCK_HALF_DIV = 16
) (
    input  wire               clk,
    input  wire               rst_n,
    input  wire signed [15:0] sample_left,
    input  wire signed [15:0] sample_right,
    output reg                sample_tick,
    output reg                hp_bck,
    output reg                hp_ws,
    output reg                hp_din
);
    localparam integer DIV_WIDTH = (BCK_HALF_DIV <= 1) ? 1 : $clog2(BCK_HALF_DIV);

    reg [DIV_WIDTH-1:0] half_count;
    reg [4:0] bit_index;
    reg signed [15:0] left_latched;
    reg signed [15:0] right_latched;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            half_count    <= {DIV_WIDTH{1'b0}};
            bit_index     <= 5'd0;
            left_latched  <= 16'sd0;
            right_latched <= 16'sd0;
            sample_tick   <= 1'b0;
            hp_bck        <= 1'b0;
            hp_ws         <= 1'b0;
            hp_din        <= 1'b0;
        end else begin
            sample_tick <= 1'b0;

            if (BCK_HALF_DIV <= 1 || half_count == BCK_HALF_DIV - 1) begin
                half_count <= {DIV_WIDTH{1'b0}};
                hp_bck <= ~hp_bck;

                // PT8211 在 BCK 上升沿采样；只在下降沿改变 WS 和 DIN，保证建立时间。
                if (hp_bck) begin
                    if (bit_index == 5'd0) begin
                        left_latched  <= sample_left;
                        right_latched <= sample_right;
                        hp_ws         <= 1'b0;
                        hp_din        <= sample_right[15];
                        bit_index     <= 5'd1;
                        sample_tick   <= 1'b1;
                    end else if (bit_index < 5'd16) begin
                        hp_din    <= right_latched[15-bit_index];
                        bit_index <= bit_index + 5'd1;
                    end else if (bit_index == 5'd16) begin
                        hp_ws     <= 1'b1;
                        hp_din    <= left_latched[15];
                        bit_index <= 5'd17;
                    end else if (bit_index < 5'd31) begin
                        hp_din    <= left_latched[31-bit_index];
                        bit_index <= bit_index + 5'd1;
                    end else begin
                        hp_din    <= left_latched[0];
                        bit_index <= 5'd0;
                    end
                end
            end else begin
                half_count <= half_count + {{(DIV_WIDTH-1){1'b0}}, 1'b1};
            end
        end
    end
endmodule

`default_nettype wire

