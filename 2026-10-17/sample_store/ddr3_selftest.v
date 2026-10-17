// Gowin DDR3 原生用户接口上最小的 BL8 写/读检查。
// 全部跑在控制器的 clk_out 时钟域里。
module ddr3_selftest #(
    parameter integer WATCHDOG_BIT = 27
) (
    input  wire         clk,
    input  wire         rst,
    input  wire         init_calib_complete,
    input  wire         cmd_ready,
    input  wire         wr_data_rdy,
    input  wire [127:0] rd_data,
    input  wire         rd_data_valid,
    output wire         cmd_en,
    output wire [2:0]   cmd,
    output wire [27:0]  addr,
    output wire         wr_data_en,
    output wire [127:0] wr_data,
    output wire [15:0]  wr_data_mask,
    output wire         wr_data_end,
    output reg  [1:0]   status = 2'd0
);
    localparam [127:0] PATTERN_0 = 128'hA55A_0123_89AB_CDEF_1357_2468_FEDC_BA98;
    localparam [127:0] PATTERN_1 = 128'h5AA5_F0E1_D2C3_B4A5_1020_3040_5060_7080;
    localparam [27:0] ADDR_0 = 28'h0000000;
    localparam [27:0] ADDR_1 = 28'h0000040;
    localparam [3:0] WAIT_CAL = 4'd0;
    localparam [3:0] WRITE_0 = 4'd1;
    localparam [3:0] WRITE_1 = 4'd2;
    localparam [3:0] SETTLE = 4'd3;
    localparam [3:0] READ_0 = 4'd4;
    localparam [3:0] READ_0_DATA = 4'd5;
    localparam [3:0] READ_1 = 4'd6;
    localparam [3:0] READ_1_DATA = 4'd7;
    localparam [3:0] FINISHED = 4'd8;

    reg [3:0] state = WAIT_CAL;
    reg [WATCHDOG_BIT:0] watchdog = 0;
    reg [7:0] settle_count = 8'd0;

    wire writing = (state == WRITE_0 || state == WRITE_1);
    wire reading = (state == READ_0 || state == READ_1);
    wire write_fire = writing && cmd_ready && wr_data_rdy;
    wire read_fire = reading && cmd_ready;
    assign cmd_en = write_fire || read_fire;
    assign cmd = writing ? 3'b000 : 3'b001;
    assign addr = (state == WRITE_1 || state == READ_1 ||
                   state == READ_1_DATA) ? ADDR_1 : ADDR_0;
    assign wr_data_en = write_fire;
    assign wr_data = (state == WRITE_1) ? PATTERN_1 : PATTERN_0;
    assign wr_data_mask = 16'd0;
    assign wr_data_end = 1'b1;

    always @(posedge clk) begin
        if (rst) begin
            state <= WAIT_CAL;
            status <= 2'd0;
            watchdog <= 0;
            settle_count <= 8'd0;
        end else if (state != FINISHED) begin
            watchdog <= watchdog + 1'b1;
            if (watchdog[WATCHDOG_BIT]) begin
                // 1 = 通过，2 = 校准超时，3 = 数据或命令错误。
                status <= (state == WAIT_CAL) ? 2'd2 : 2'd3;
                state <= FINISHED;
            end else begin
                case (state)
                    WAIT_CAL: if (init_calib_complete) begin
                        state <= WRITE_0;
                        watchdog <= 0;
                    end
                    WRITE_0: if (write_fire) begin
                        state <= WRITE_1;
                        watchdog <= 0;
                    end
                    WRITE_1: if (write_fire) begin
                        state <= SETTLE;
                        watchdog <= 0;
                    end
                    SETTLE: if (settle_count == 8'd255) begin
                        state <= READ_0;
                        watchdog <= 0;
                    end else settle_count <= settle_count + 8'd1;
                    READ_0: if (read_fire) begin
                        state <= READ_0_DATA;
                        watchdog <= 0;
                    end
                    READ_0_DATA: if (rd_data_valid) begin
                        if (rd_data == PATTERN_0) begin
                            state <= READ_1;
                            watchdog <= 0;
                        end else begin
                            status <= 2'd3;
                            state <= FINISHED;
                        end
                    end
                    READ_1: if (read_fire) begin
                        state <= READ_1_DATA;
                        watchdog <= 0;
                    end
                    READ_1_DATA: if (rd_data_valid) begin
                        status <= (rd_data == PATTERN_1) ? 2'd1 : 2'd3;
                        state <= FINISHED;
                    end
                    default: begin
                        status <= 2'd3;
                        state <= FINISHED;
                    end
                endcase
            end
        end
    end
endmodule
