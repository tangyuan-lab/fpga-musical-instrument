`default_nettype none

// 第一阶段上位机通信验证顶层。
// LED7 常亮表示复位已释放；每收到一个合法 PING，LED0 翻转一次。
// 本顶层不连接压力、MCP3208、HDMI 或音频，避免影响已经验证的 V10 工程。
module uart_ping_echo_top (
    input  wire       sys_clk,
    input  wire       sys_rst_n,
    input  wire       uart_rx_i,
    output wire       uart_tx_o,
    output wire [7:0] led_n
);
    wire rst_n;
    wire [7:0] rx_data;
    wire       rx_valid;
    wire       framing_error;
    wire       ping_valid;
    wire [15:0] ping_seq;
    wire [31:0] ping_nonce;
    wire       bad_frame;
    wire       tx_busy;
    reg        ping_led;
    reg        error_led;

    reset_sync reset_inst (
        .clk(sys_clk), .arst_n(sys_rst_n), .rst_n(rst_n)
    );

    uart_rx #(.CLKS_PER_BIT(434)) rx_inst (
        .clk(sys_clk), .rst_n(rst_n), .rx(uart_rx_i),
        .data(rx_data), .valid(rx_valid), .framing_error(framing_error)
    );

    uart_ping_protocol protocol_inst (
        .clk(sys_clk), .rst_n(rst_n), .rx_data(rx_data), .rx_valid(rx_valid),
        .ping_valid(ping_valid), .ping_seq(ping_seq), .ping_nonce(ping_nonce),
        .bad_frame(bad_frame)
    );

    uart_ping_ack #(.CLKS_PER_BIT(434)) ack_inst (
        .clk(sys_clk), .rst_n(rst_n), .ping_valid(ping_valid),
        .ping_seq(ping_seq), .ping_nonce(ping_nonce),
        .tx(uart_tx_o), .tx_busy(tx_busy)
    );

    always @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            ping_led  <= 1'b0;
            error_led <= 1'b0;
        end else begin
            if (ping_valid)
                ping_led <= ~ping_led;
            if (bad_frame || framing_error)
                error_led <= ~error_led;
        end
    end

    // PMOD0 LED 为低电平点亮：LED7=复位完成，LED1=错误翻转，LED0=PING翻转。
    assign led_n = {~rst_n, 5'b11111, error_led, ping_led};

    wire _unused = &{1'b0, tx_busy};
endmodule

`default_nettype wire
