`default_nettype none

// 面向 GT911 类触摸控制器的 16 位寄存器 I2C 主机。
// 一次命令完成：START、器件写地址、寄存器高/低字节、
// 可选重复 START、器件读地址、连续读 1~6 字节、STOP。
// SDA/SCL 均采用开漏方式：输出 0 时拉低，输出 1 时释放，由板上的上拉电阻拉高。
module i2c_reg_master #(
    parameter integer CLK_HZ = 50_000_000,
    parameter integer I2C_HZ = 100_000
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       cmd_valid,
    input  wire       cmd_read,
    input  wire [6:0] cmd_dev_addr,
    input  wire [15:0] cmd_reg_addr,
    input  wire [7:0] cmd_write_data,
    input  wire [2:0] cmd_read_len,
    output reg        busy,
    output reg        done,
    output reg        error,
    output reg [7:0]  read_data0,
    output reg [7:0]  read_data1,
    output reg [7:0]  read_data2,
    output reg [7:0]  read_data3,
    output reg [7:0]  read_data4,
    output reg [7:0]  read_data5,
    inout  wire       scl,
    inout  wire       sda
);
    localparam integer TICK_DIV = (CLK_HZ / (I2C_HZ * 4));

    // 发送状态明确拆出数据位低电平、ACK 准备、ACK 高电平和 ACK 采样。
    // 这样每个发送字节都严格包含 8 个数据位时钟和第 9 个 ACK 时钟。
    localparam [5:0] ST_IDLE           = 6'd0;
    localparam [5:0] ST_START_A        = 6'd1;
    localparam [5:0] ST_START_B        = 6'd2;
    localparam [5:0] ST_SEND_BIT       = 6'd3;
    localparam [5:0] ST_SEND_HIGH      = 6'd4;
    localparam [5:0] ST_SEND_LOW       = 6'd5;
    localparam [5:0] ST_SEND_ACK_PREP  = 6'd6;
    localparam [5:0] ST_SEND_ACK_HIGH  = 6'd7;
    localparam [5:0] ST_SEND_ACK_SAMPLE = 6'd8;
    localparam [5:0] ST_SEND_ACK_LOW   = 6'd9;
    localparam [5:0] ST_REPEAT_A       = 6'd10;
    localparam [5:0] ST_REPEAT_B       = 6'd11;
    localparam [5:0] ST_REPEAT_C       = 6'd12;
    localparam [5:0] ST_REPEAT_D       = 6'd13;
    localparam [5:0] ST_READ_BIT       = 6'd14;
    localparam [5:0] ST_READ_HIGH      = 6'd15;
    localparam [5:0] ST_READ_SAMPLE    = 6'd16;
    localparam [5:0] ST_READ_ADV       = 6'd17;
    localparam [5:0] ST_READ_ACK_HIGH  = 6'd18;
    localparam [5:0] ST_READ_ACK_LOW   = 6'd19;
    localparam [5:0] ST_STOP_A         = 6'd20;
    localparam [5:0] ST_STOP_B         = 6'd21;
    localparam [5:0] ST_STOP_C         = 6'd22;

    localparam [2:0] PH_ADDR_W = 3'd0;
    localparam [2:0] PH_REG_H  = 3'd1;
    localparam [2:0] PH_REG_L  = 3'd2;
    localparam [2:0] PH_ADDR_R = 3'd3;
    localparam [2:0] PH_WR_DATA = 3'd4;

    reg [15:0] tick_count;
    reg [5:0]  state;
    reg [2:0]  bit_index;
    reg [2:0]  byte_index;
    reg [2:0]  byte_phase;
    reg [6:0]  dev_addr;
    reg [15:0] reg_addr;
    reg [7:0]  write_data;
    reg [2:0]  read_len;
    reg        read_mode;
    reg [7:0]  tx_byte;
    reg [7:0]  rx_shift;
    reg        scl_low;
    reg        sda_low;
    reg        ack_ok;

    wire sda_in = sda;

    assign scl = scl_low ? 1'b0 : 1'bz;
    assign sda = sda_low ? 1'b0 : 1'bz;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tick_count <= 16'd0;
            state      <= ST_IDLE;
            busy       <= 1'b0;
            done       <= 1'b0;
            error      <= 1'b0;
            bit_index  <= 3'd0;
            byte_index <= 3'd0;
            byte_phase <= PH_ADDR_W;
            dev_addr   <= 7'd0;
            reg_addr   <= 16'd0;
            write_data <= 8'd0;
            read_len   <= 3'd1;
            read_mode  <= 1'b0;
            tx_byte    <= 8'd0;
            rx_shift   <= 8'd0;
            scl_low    <= 1'b0;
            sda_low    <= 1'b0;
            ack_ok     <= 1'b0;
            read_data0 <= 8'd0;
            read_data1 <= 8'd0;
            read_data2 <= 8'd0;
            read_data3 <= 8'd0;
            read_data4 <= 8'd0;
            read_data5 <= 8'd0;
        end else begin
            done <= 1'b0;

            if (!busy) begin
                tick_count <= 16'd0;
                scl_low    <= 1'b0;
                sda_low    <= 1'b0;
                if (cmd_valid) begin
                    busy       <= 1'b1;
                    error      <= 1'b0;
                    dev_addr   <= cmd_dev_addr;
                    reg_addr   <= cmd_reg_addr;
                    write_data <= cmd_write_data;
                    // 当前接口只导出 6 个接收字节；超出范围时截断，
                    // 避免主机继续产生没有对应寄存器的读周期。
                    read_len   <= (cmd_read_len == 3'd0) ? 3'd1 :
                                  ((cmd_read_len > 3'd6) ? 3'd6 : cmd_read_len);
                    read_mode  <= cmd_read;
                    byte_index <= 3'd0;
                    bit_index  <= 3'd0;
                    byte_phase <= PH_ADDR_W;
                    tx_byte    <= {cmd_dev_addr, 1'b0};
                    state      <= ST_START_A;
                end
            end else if (tick_count == TICK_DIV-1) begin
                tick_count <= 16'd0;
                case (state)
                    ST_START_A: begin
                        // 总线空闲时先保持 SCL 高，再把 SDA 拉低产生 START。
                        scl_low <= 1'b0;
                        sda_low <= 1'b1;
                        state   <= ST_START_B;
                    end
                    ST_START_B: begin
                        scl_low   <= 1'b1;
                        bit_index <= 3'd0;
                        state     <= ST_SEND_BIT;
                    end
                    ST_SEND_BIT: begin
                        scl_low <= 1'b1;
                        sda_low <= (tx_byte[7-bit_index] == 1'b0);
                        state   <= ST_SEND_HIGH;
                    end
                    ST_SEND_HIGH: begin
                        scl_low <= 1'b0;
                        // 第 0~6 位结束后先拉低 SCL，再发送下一位。
                        // 第 7 位结束后必须另起第 9 个 ACK 时钟。
                        if (bit_index == 3'd7)
                            state <= ST_SEND_ACK_PREP;
                        else
                            state <= ST_SEND_LOW;
                    end
                    ST_SEND_LOW: begin
                        scl_low <= 1'b1;
                        bit_index <= bit_index + 1'b1;
                        state     <= ST_SEND_BIT;
                    end
                    ST_SEND_ACK_PREP: begin
                        // ACK 位开始前 SCL 必须保持低，主机释放 SDA，
                        // 从设备才有机会在第 9 个高电平期间拉低 SDA。
                        scl_low <= 1'b1;
                        sda_low <= 1'b0;
                        state   <= ST_SEND_ACK_HIGH;
                    end
                    ST_SEND_ACK_HIGH: begin
                        scl_low <= 1'b0;
                        state   <= ST_SEND_ACK_SAMPLE;
                    end
                    ST_SEND_ACK_SAMPLE: begin
                        // 此时第 9 个时钟仍为高电平，采样从设备 ACK。
                        scl_low <= 1'b0;
                        ack_ok  <= ~sda_in;
                        state   <= ST_SEND_ACK_LOW;
                    end
                    ST_SEND_ACK_LOW: begin
                        scl_low <= 1'b1;
                        if (!ack_ok) begin
                            // 从设备没有应答，结束本次事务。
                            error <= 1'b1;
                            state <= ST_STOP_A;
                        end else begin
                            bit_index <= 3'd0;
                            case (byte_phase)
                                PH_ADDR_W: begin
                                    tx_byte    <= reg_addr[15:8];
                                    byte_phase <= PH_REG_H;
                                    state      <= ST_SEND_BIT;
                                end
                                PH_REG_H: begin
                                    tx_byte    <= reg_addr[7:0];
                                    byte_phase <= PH_REG_L;
                                    state      <= ST_SEND_BIT;
                                end
                                PH_REG_L: begin
                                    if (read_mode) begin
                                        state <= ST_REPEAT_A;
                                    end else begin
                                        tx_byte    <= write_data;
                                        byte_phase <= PH_WR_DATA;
                                        state      <= ST_SEND_BIT;
                                    end
                                end
                                PH_ADDR_R: begin
                                    byte_index <= 3'd0;
                                    rx_shift   <= 8'd0;
                                    state      <= ST_READ_BIT;
                                end
                                default: begin
                                    state <= ST_STOP_A;
                                end
                            endcase
                        end
                    end
                    ST_REPEAT_A: begin
                        // ACK 后先在 SCL 仍为低时释放 SDA，避免把
                        // SDA 与 SCL 同时拉高误解为 STOP。
                        scl_low <= 1'b1;
                        sda_low <= 1'b0;
                        state   <= ST_REPEAT_B;
                    end
                    ST_REPEAT_B: begin
                        // SDA 已经释放，再把 SCL 拉高，建立总线空闲相位。
                        scl_low <= 1'b0;
                        sda_low <= 1'b0;
                        state   <= ST_REPEAT_C;
                    end
                    ST_REPEAT_C: begin
                        // SCL 为高时拉低 SDA，产生合法的重复 START。
                        scl_low <= 1'b0;
                        sda_low <= 1'b1;
                        state   <= ST_REPEAT_D;
                    end
                    ST_REPEAT_D: begin
                        scl_low   <= 1'b1;
                        sda_low   <= 1'b1;
                        tx_byte   <= {dev_addr, 1'b1};
                        bit_index <= 3'd0;
                        byte_phase <= PH_ADDR_R;
                        state     <= ST_SEND_BIT;
                    end
                    ST_READ_BIT: begin
                        scl_low <= 1'b1;
                        sda_low <= 1'b0;
                        state   <= ST_READ_HIGH;
                    end
                    ST_READ_HIGH: begin
                        scl_low <= 1'b0;
                        state   <= ST_READ_SAMPLE;
                    end
                    ST_READ_SAMPLE: begin
                        scl_low <= 1'b1;
                        rx_shift <= {rx_shift[6:0], sda_in};
                        state   <= ST_READ_ADV;
                    end
                    ST_READ_ADV: begin
                        if (bit_index != 3'd7) begin
                            bit_index <= bit_index + 1'b1;
                            state     <= ST_READ_BIT;
                        end else begin
                            bit_index <= 3'd0;
                            case (byte_index)
                                3'd0: read_data0 <= {rx_shift[6:0], sda_in};
                                3'd1: read_data1 <= {rx_shift[6:0], sda_in};
                                3'd2: read_data2 <= {rx_shift[6:0], sda_in};
                                3'd3: read_data3 <= {rx_shift[6:0], sda_in};
                                3'd4: read_data4 <= {rx_shift[6:0], sda_in};
                                3'd5: read_data5 <= {rx_shift[6:0], sda_in};
                                default: ;
                            endcase
                            // 最后一个字节发送 NACK，其余字节发送 ACK。
                            sda_low <= ((byte_index + 1'b1) < read_len);
                            state   <= ST_READ_ACK_HIGH;
                        end
                    end
                    ST_READ_ACK_HIGH: begin
                        scl_low <= 1'b0;
                        state   <= ST_READ_ACK_LOW;
                    end
                    ST_READ_ACK_LOW: begin
                        scl_low <= 1'b1;
                        if ((byte_index + 1'b1) >= read_len) begin
                            sda_low <= 1'b1;
                            state   <= ST_STOP_A;
                        end else begin
                            byte_index <= byte_index + 1'b1;
                            state      <= ST_READ_BIT;
                        end
                    end
                    ST_STOP_A: begin
                        scl_low <= 1'b1;
                        sda_low <= 1'b1;
                        state   <= ST_STOP_B;
                    end
                    ST_STOP_B: begin
                        scl_low <= 1'b0;
                        state   <= ST_STOP_C;
                    end
                    ST_STOP_C: begin
                        sda_low <= 1'b0;
                        busy    <= 1'b0;
                        done    <= 1'b1;
                        state   <= ST_IDLE;
                    end
                    default: state <= ST_IDLE;
                endcase
            end else begin
                tick_count <= tick_count + 1'b1;
            end
        end
    end
endmodule

`default_nettype wire
