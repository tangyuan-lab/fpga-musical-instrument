`default_nettype none

// 115200/8N1 UART 接收器。
// 输入空闲为高电平；检测到起始位后在位中心采样，收到完整字节时
// 产生一个 clk 周期的 rx_valid 脉冲。当前工程使用 50 MHz 时钟和
// CLKS_PER_BIT=434（50 MHz / 115200 baud 的整数近似值）。
module uart_rx #(
    parameter integer CLKS_PER_BIT = 434
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx,
    output reg [7:0]  data,
    output reg        valid,
    output reg        framing_error
);
    localparam integer HALF_BIT = (CLKS_PER_BIT / 2 < 1) ? 1 : CLKS_PER_BIT / 2;

    localparam [1:0] ST_IDLE  = 2'd0;
    localparam [1:0] ST_START = 2'd1;
    localparam [1:0] ST_DATA  = 2'd2;
    localparam [1:0] ST_STOP  = 2'd3;

    reg [1:0]  state;
    reg [15:0] tick_count;
    reg [2:0]  bit_index;
    reg [7:0]  shift_data;
    reg        rx_meta;
    reg        rx_sync;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_meta       <= 1'b1;
            rx_sync       <= 1'b1;
            state         <= ST_IDLE;
            tick_count    <= 16'd0;
            bit_index     <= 3'd0;
            shift_data    <= 8'd0;
            data          <= 8'd0;
            valid         <= 1'b0;
            framing_error <= 1'b0;
        end else begin
            rx_meta       <= rx;
            rx_sync       <= rx_meta;
            valid         <= 1'b0;
            framing_error <= 1'b0;

            case (state)
                ST_IDLE: begin
                    tick_count <= 16'd0;
                    if (!rx_sync) begin
                        state      <= ST_START;
                        tick_count <= HALF_BIT - 1;
                    end
                end

                ST_START: begin
                    if (tick_count != 0) begin
                        tick_count <= tick_count - 1'b1;
                    end else if (!rx_sync) begin
                        state      <= ST_DATA;
                        bit_index  <= 3'd0;
                        tick_count <= CLKS_PER_BIT - 1;
                    end else begin
                        state <= ST_IDLE;
                    end
                end

                ST_DATA: begin
                    if (tick_count != 0) begin
                        tick_count <= tick_count - 1'b1;
                    end else begin
                        shift_data[bit_index] <= rx_sync;
                        tick_count            <= CLKS_PER_BIT - 1;
                        if (bit_index == 3'd7)
                            state <= ST_STOP;
                        else
                            bit_index <= bit_index + 1'b1;
                    end
                end

                ST_STOP: begin
                    if (tick_count != 0) begin
                        tick_count <= tick_count - 1'b1;
                    end else begin
                        state <= ST_IDLE;
                        if (rx_sync) begin
                            data  <= shift_data;
                            valid <= 1'b1;
                        end else begin
                            framing_error <= 1'b1;
                        end
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule

`default_nettype wire
