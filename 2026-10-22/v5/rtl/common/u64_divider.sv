`default_nettype none

// 无乘法器/通用除法器的 64 次迭代无符号除法。
// 用于 MIDI 播放器在 Tempo 改变时计算“每个音频采样对应多少 tick”。
// 除法只在 Tempo 事件发生时运行，常规音频采样路径不经过该模块。
module u64_divider (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [63:0] dividend,
    input  wire [63:0] divisor,
    output reg         busy,
    output reg         done,
    output reg  [63:0] quotient
);
    reg [63:0] dividend_reg;
    reg [64:0] remainder_reg;
    reg [63:0] divisor_reg;
    reg [6:0]  count;
    reg [63:0] quotient_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dividend_reg <= 64'd0;
            remainder_reg <= 65'd0;
            divisor_reg <= 64'd0;
            count <= 7'd0;
            quotient_reg <= 64'd0;
            quotient <= 64'd0;
            busy <= 1'b0;
            done <= 1'b0;
        end else begin
            done <= 1'b0;
            if (start && !busy) begin
                dividend_reg <= dividend;
                divisor_reg <= (divisor == 0) ? 64'd1 : divisor;
                remainder_reg <= 65'd0;
                quotient_reg <= 64'd0;
                count <= 7'd0;
                busy <= 1'b1;
            end else if (busy) begin
                // 每轮从 dividend 的最高位取一位，形成标准 restoring division。
                if ({remainder_reg[63:0], dividend_reg[63]} >= {1'b0, divisor_reg}) begin
                    remainder_reg <= {remainder_reg[63:0], dividend_reg[63]} - {1'b0, divisor_reg};
                    quotient_reg <= {quotient_reg[62:0], 1'b1};
                end else begin
                    remainder_reg <= {remainder_reg[63:0], dividend_reg[63]};
                    quotient_reg <= {quotient_reg[62:0], 1'b0};
                end
                dividend_reg <= {dividend_reg[62:0], 1'b0};
                if (count == 7'd63) begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    quotient <= quotient_reg;
                end else begin
                    count <= count + 1'b1;
                end
            end
        end
    end
endmodule

`default_nettype wire
