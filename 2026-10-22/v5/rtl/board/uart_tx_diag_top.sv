`default_nettype none

// UART 实物链路诊断顶层。
//
// 上电后每隔 DIAG_PERIOD_CYCLES 个 50 MHz 时钟发送一次固定 ASCII：
//     UART_LINK_OK\r\n
// LED7 表示复位已经释放；LED0 每发送完一条字符串翻转一次；
// LED1 每收到一个完整 UART 字节翻转一次；LED2 在 UART 帧错误时翻转。
// 这样无需依赖二进制 PING 协议，就能分别确认 TX 和 RX 是否接通。
module uart_tx_diag_top #(
    parameter integer DIAG_PERIOD_CYCLES = 25_000_000
) (
    input  wire       sys_clk,
    input  wire       uart_rx_i,
    output wire       uart_tx_o,
    output wire [7:0] led_n
);
    localparam integer MESSAGE_LENGTH = 14;

    localparam [1:0] ST_WAIT  = 2'd0;
    localparam [1:0] ST_START = 2'd1;
    localparam [1:0] ST_DONE  = 2'd2;

    // 故意不依赖 Y12 外部复位：如果 USER_BUTTON0 卡住，诊断位流仍应能发送。
    // Gowin FPGA 上电寄存器初始化为 0，计满 65536 个系统时钟后释放本地复位。
    reg  [15:0] power_on_reset_counter = 16'd0;
    wire rst_n = &power_on_reset_counter;
    wire [7:0] rx_data;
    wire       rx_valid;
    wire       framing_error;
    wire       uart_busy;
    wire       uart_done;

    reg [31:0] period_count;
    reg [1:0]  state;
    reg [4:0]  byte_index;
    reg        tx_start;
    reg [7:0]  tx_data;
    reg        tx_led;
    reg        rx_led;
    reg        error_led;

    uart_rx #(.CLKS_PER_BIT(434)) rx_inst (
        .clk(sys_clk), .rst_n(rst_n), .rx(uart_rx_i),
        .data(rx_data), .valid(rx_valid), .framing_error(framing_error)
    );

    uart_tx #(.CLKS_PER_BIT(434)) tx_inst (
        .clk(sys_clk), .rst_n(rst_n), .start(tx_start), .data(tx_data),
        .tx(uart_tx_o), .busy(uart_busy), .done(uart_done)
    );

    // 固定诊断字符串，逐字节送入 uart_tx；不使用除法或大块存储器。
    always @(*) begin
        case (byte_index)
            5'd0:  tx_data = "U";
            5'd1:  tx_data = "A";
            5'd2:  tx_data = "R";
            5'd3:  tx_data = "T";
            5'd4:  tx_data = "_";
            5'd5:  tx_data = "L";
            5'd6:  tx_data = "I";
            5'd7:  tx_data = "N";
            5'd8:  tx_data = "K";
            5'd9:  tx_data = "_";
            5'd10: tx_data = "O";
            5'd11: tx_data = "K";
            5'd12: tx_data = 8'h0d;
            default: tx_data = 8'h0a;
        endcase
    end

    always @(posedge sys_clk) begin
        if (!rst_n)
            power_on_reset_counter <= power_on_reset_counter + 1'b1;
    end

    always @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            period_count <= 32'd0;
            state        <= ST_WAIT;
            byte_index   <= 5'd0;
            tx_start     <= 1'b0;
            tx_led       <= 1'b0;
            rx_led       <= 1'b0;
            error_led    <= 1'b0;
        end else begin
            tx_start <= 1'b0;

            if (rx_valid)
                rx_led <= ~rx_led;
            if (framing_error)
                error_led <= ~error_led;

            case (state)
                ST_WAIT: begin
                    if (period_count == DIAG_PERIOD_CYCLES - 1) begin
                        period_count <= 32'd0;
                        byte_index   <= 5'd0;
                        state        <= ST_START;
                    end else begin
                        period_count <= period_count + 1'b1;
                    end
                end

                ST_START: begin
                    if (!uart_busy) begin
                        tx_start <= 1'b1;
                        state    <= ST_DONE;
                    end
                end

                ST_DONE: begin
                    if (uart_done) begin
                        if (byte_index == MESSAGE_LENGTH - 1) begin
                            tx_led <= ~tx_led;
                            state  <= ST_WAIT;
                        end else begin
                            byte_index <= byte_index + 1'b1;
                            state      <= ST_START;
                        end
                    end
                end

                default: state <= ST_WAIT;
            endcase
        end
    end

    // PMOD0 LED 为低电平点亮：LED7=复位完成，LED2=帧错误，
    // LED1=收到字节，LED0=发送完成。
    assign led_n = {~rst_n, 4'b1111, error_led, rx_led, tx_led};

    wire _unused = &{1'b0, rx_data, uart_busy};
endmodule

`default_nettype wire
