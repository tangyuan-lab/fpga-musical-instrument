`default_nettype none

// GT911/GT9271 类电容触摸控制器的最小稳定读取器。
// 读取 0x814E 状态寄存器和 0x8150 第一触点坐标，并写 0 清除状态。
// 常用地址 0x5D；连续三次 NACK 后自动尝试备用地址 0x14。
module gt911_controller #(
    parameter integer CLK_HZ = 50_000_000,
    parameter integer RESET_CYCLES = 500_000,
    parameter integer STARTUP_CYCLES = 5_000_000,
    parameter integer POLL_CYCLES = 250_000
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       ctp_int,
    output reg        ctp_rst,
    inout  wire       ctp_scl,
    inout  wire       ctp_sda,
    output reg        ready,
    output reg        error,
    output reg        touch_down,
    output reg        touch_valid,
    output reg [2:0]  touch_count,
    output reg [11:0] touch_x,
    output reg [11:0] touch_y
);
    localparam [3:0] ST_RESET_LOW  = 4'd0;
    localparam [3:0] ST_START_WAIT = 4'd1;
    localparam [3:0] ST_POLL_WAIT  = 4'd2;
    localparam [3:0] ST_STATUS_CMD = 4'd3;
    localparam [3:0] ST_STATUS_WAIT = 4'd4;
    localparam [3:0] ST_POINTS_CMD = 4'd5;
    localparam [3:0] ST_POINTS_WAIT = 4'd6;
    localparam [3:0] ST_CLEAR_CMD = 4'd7;
    localparam [3:0] ST_CLEAR_WAIT = 4'd8;

    reg [3:0] state;
    reg [31:0] timer;
    reg [1:0] nack_count;
    reg       use_backup_addr;
    reg       i2c_cmd_valid;
    reg       i2c_cmd_read;
    reg [6:0] i2c_addr;
    reg [15:0] i2c_reg;
    reg [7:0] i2c_write_data;
    reg [2:0] i2c_read_len;
    wire i2c_busy;
    wire i2c_done;
    wire i2c_error;
    wire [7:0] rx0, rx1, rx2, rx3, rx4, rx5;

    wire [6:0] active_addr = use_backup_addr ? 7'h14 : 7'h5d;

    i2c_reg_master #(.CLK_HZ(CLK_HZ), .I2C_HZ(100_000)) i2c_master (
        .clk(clk), .rst_n(rst_n),
        .cmd_valid(i2c_cmd_valid), .cmd_read(i2c_cmd_read),
        .cmd_dev_addr(i2c_addr), .cmd_reg_addr(i2c_reg),
        .cmd_write_data(i2c_write_data), .cmd_read_len(i2c_read_len),
        .busy(i2c_busy), .done(i2c_done), .error(i2c_error),
        .read_data0(rx0), .read_data1(rx1), .read_data2(rx2),
        .read_data3(rx3), .read_data4(rx4), .read_data5(rx5),
        .scl(ctp_scl), .sda(ctp_sda)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= ST_RESET_LOW;
            timer          <= 32'd0;
            nack_count     <= 2'd0;
            use_backup_addr <= 1'b0;
            i2c_cmd_valid  <= 1'b0;
            i2c_cmd_read   <= 1'b0;
            i2c_addr       <= 7'h5d;
            i2c_reg        <= 16'h814e;
            i2c_write_data <= 8'h00;
            i2c_read_len   <= 3'd1;
            ctp_rst        <= 1'b0;
            ready          <= 1'b0;
            error          <= 1'b0;
            touch_down     <= 1'b0;
            touch_valid    <= 1'b0;
            touch_count    <= 3'd0;
            touch_x        <= 12'd0;
            touch_y        <= 12'd0;
        end else begin
            i2c_cmd_valid <= 1'b0;
            touch_valid   <= 1'b0;

            case (state)
                ST_RESET_LOW: begin
                    ctp_rst <= 1'b0;
                    if (timer == RESET_CYCLES-1) begin
                        timer <= 32'd0;
                        ctp_rst <= 1'b1;
                        state <= ST_START_WAIT;
                    end else timer <= timer + 1'b1;
                end
                ST_START_WAIT: begin
                    ctp_rst <= 1'b1;
                    if (timer == STARTUP_CYCLES-1) begin
                        timer <= 32'd0;
                        state <= ST_STATUS_CMD;
                    end else timer <= timer + 1'b1;
                end
                ST_POLL_WAIT: begin
                    if (timer == POLL_CYCLES-1) begin
                        timer <= 32'd0;
                        state <= ST_STATUS_CMD;
                    end else timer <= timer + 1'b1;
                end
                ST_STATUS_CMD: begin
                    if (!i2c_busy) begin
                        i2c_cmd_valid <= 1'b1;
                        i2c_cmd_read  <= 1'b1;
                        i2c_addr      <= active_addr;
                        i2c_reg       <= 16'h814e;
                        i2c_read_len  <= 3'd1;
                        state         <= ST_STATUS_WAIT;
                    end
                end
                ST_STATUS_WAIT: begin
                    if (i2c_done) begin
                        if (i2c_error) begin
                            error <= 1'b1;
                            ready <= 1'b0;
                            touch_down <= 1'b0;
                            if (nack_count == 2'd2) begin
                                nack_count <= 2'd0;
                                use_backup_addr <= ~use_backup_addr;
                            end else nack_count <= nack_count + 1'b1;
                            state <= ST_POLL_WAIT;
                        end else begin
                            nack_count <= 2'd0;
                            ready <= 1'b1;
                            error <= 1'b0;
                            touch_count <= rx0[2:0];
                            if (rx0[7] && (rx0[3:0] != 4'd0))
                                state <= ST_POINTS_CMD;
                            else begin
                                touch_down <= 1'b0;
                                state <= ST_POLL_WAIT;
                            end
                        end
                    end
                end
                ST_POINTS_CMD: begin
                    if (!i2c_busy) begin
                        i2c_cmd_valid <= 1'b1;
                        i2c_cmd_read  <= 1'b1;
                        i2c_addr      <= active_addr;
                        i2c_reg       <= 16'h8150;
                        i2c_read_len  <= 3'd6;
                        state         <= ST_POINTS_WAIT;
                    end
                end
                ST_POINTS_WAIT: begin
                    if (i2c_done) begin
                        if (i2c_error) begin
                            error <= 1'b1;
                            touch_down <= 1'b0;
                        end else begin
                            touch_down  <= 1'b1;
                            touch_valid <= 1'b1;
                            // GT911 坐标按低字节在前返回；屏幕坐标使用 12 位。
                            // 这样明确截取高字节低四位，避免综合器隐式截断 16 位表达式。
                            touch_x     <= {rx1[3:0], rx0};
                            touch_y     <= {rx3[3:0], rx2};
                        end
                        state <= ST_CLEAR_CMD;
                    end
                end
                ST_CLEAR_CMD: begin
                    if (!i2c_busy) begin
                        i2c_cmd_valid <= 1'b1;
                        i2c_cmd_read  <= 1'b0;
                        i2c_addr      <= active_addr;
                        i2c_reg       <= 16'h814e;
                        i2c_write_data <= 8'h00;
                        i2c_read_len  <= 3'd1;
                        state <= ST_CLEAR_WAIT;
                    end
                end
                ST_CLEAR_WAIT: begin
                    if (i2c_done) begin
                        if (i2c_error) begin
                            error <= 1'b1;
                            ready <= 1'b0;
                        end
                        state <= ST_POLL_WAIT;
                    end
                end
                default: state <= ST_RESET_LOW;
            endcase
        end
    end
endmodule

`default_nettype wire
