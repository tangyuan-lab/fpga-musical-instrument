`default_nettype none

// 标准 I2S：WS=0 左声道、WS=1 右声道；WS 翻转一位 BCK 后发送 MSB。
// 每声道 32 位时隙，16 位有符号有效数据置高位，其余补零。
// 50 MHz、BCK_HALF_DIV=8 时 Fs=48.828125 kHz，与现有相位表一致。
// 输出端口名沿用板级接口；必须搭配 I2S DAC，不能直接驱动 PT8211。
module i2s_tx #(
    parameter integer BCK_HALF_DIV = 8
) (
    input wire clk, input wire rst_n,
    input wire signed [15:0] sample_left, input wire signed [15:0] sample_right,
    output reg sample_tick,
    output reg hp_bck, output reg hp_ws, output reg hp_din
);
    localparam integer DIV_WIDTH = (BCK_HALF_DIV <= 1) ? 1 : $clog2(BCK_HALF_DIV);
    reg [DIV_WIDTH-1:0] half_count;
    reg [5:0] bit_index;
    reg [15:0] left_latched, right_latched;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            half_count <= {DIV_WIDTH{1'b0}};
            bit_index <= 6'd0;
            left_latched <= 16'd0;
            right_latched <= 16'd0;
            sample_tick <= 1'b0;
            hp_bck <= 1'b0;
            hp_ws <= 1'b1;
            hp_din <= 1'b0;
        end else begin
            sample_tick <= 1'b0;
            if (BCK_HALF_DIV <= 1 || half_count == BCK_HALF_DIV-1) begin
                half_count <= {DIV_WIDTH{1'b0}};
                hp_bck <= ~hp_bck;
                // 只在 BCK 下降沿切换数据；接收 DAC 在上升沿采样。
                if (hp_bck) begin
                    bit_index <= bit_index+1'b1;
                    if (bit_index == 0) begin
                        hp_ws <= 1'b0;
                        hp_din <= 1'b0;
                        left_latched <= sample_left;
                        right_latched <= sample_right;
                        sample_tick <= 1'b1;
                    end else if (bit_index <= 16) begin
                        hp_din <= left_latched[16-bit_index];
                    end else if (bit_index == 32) begin
                        hp_ws <= 1'b1;
                        hp_din <= 1'b0;
                    end else if (bit_index >= 33 && bit_index <= 48) begin
                        hp_din <= right_latched[48-bit_index];
                    end else begin
                        hp_din <= 1'b0;
                    end
                end
            end else begin
                half_count <= half_count+1'b1;
            end
        end
    end
endmodule
`default_nettype wire
