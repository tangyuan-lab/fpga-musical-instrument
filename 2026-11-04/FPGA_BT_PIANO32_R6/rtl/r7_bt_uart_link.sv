`default_nettype none
// 独立蓝牙物理链：8N1字节接收 → 有界帧检查 → 会话 → 原r7控制接口。
// 50MHz下默认5208拍/位（约9600 baud）。必须与HC-05实际透传速率一致。
// rst_n由整机复位同步释放链提供；异步RX在uart_rx内两级同步。
module r7_bt_uart_link #(
    parameter integer CLKS_PER_BIT=5208,
    parameter [31:0] BUILD_ID=0
)(
    input wire clk,rst_n,bt_rx_i,
    output wire bt_tx_o,
    input wire usb_idle,external_cancel,
    input wire [255:0] status_data,
    output wire lease_active,command_valid,
    output wire [7:0] command_op,
    output wire [31:0] command_value,command_aux,
    input wire command_ready,command_done,
    input wire [7:0] command_result,
    output wire command_cancel,emergency,
    output wire [31:0] accepted_commands,
    output wire bad_frame
);
    wire [7:0] rx_data,frame_type,response_length;
    wire rx_valid,framing_error,frame_valid,response_valid,response_busy;
    wire [15:0] frame_seq,frame_length,response_seq;
    wire [255:0] frame_payload;
    wire [511:0] response_payload;
    uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) receiver(
        .clk(clk),.rst_n(rst_n),.rx(bt_rx_i),.data(rx_data),
        .valid(rx_valid),.framing_error(framing_error));
    r7_bt_frame_rx parser(
        .clk(clk),.rst_n(rst_n),.rx_data(rx_data),.rx_valid(rx_valid),.framing_error(framing_error),
        .frame_valid(frame_valid),.bad_frame(bad_frame),.frame_type(frame_type),
        .frame_seq(frame_seq),.frame_length(frame_length),.frame_payload(frame_payload));
    r7_bt_control #(.BUILD_ID(BUILD_ID)) control(
        .clk(clk),.rst_n(rst_n),.frame_valid(frame_valid),.frame_type(frame_type),
        .frame_seq(frame_seq),.frame_length(frame_length),.payload(frame_payload),
        .usb_idle(usb_idle),.external_cancel(external_cancel),.status_data(status_data),
        .lease_active(lease_active),.response_valid(response_valid),.response_seq(response_seq),
        .response_length(response_length),.response_payload(response_payload),.response_busy(response_busy),
        .command_valid(command_valid),.command_op(command_op),.command_value(command_value),
        .command_aux(command_aux),.command_ready(command_ready),.command_done(command_done),
        .command_result(command_result),.command_cancel(command_cancel),.emergency(emergency),
        .accepted_commands(accepted_commands));
    uart_frame_tx_v2 #(.CLKS_PER_BIT(CLKS_PER_BIT),.MAX_RESPONSE(64)) sender(
        .clk(clk),.rst_n(rst_n),.response_valid(response_valid),.response_type(8'h81),
        .response_seq(response_seq),.response_length(response_length),.response_payload(response_payload),
        .tx(bt_tx_o),.busy(response_busy));
endmodule
`default_nettype wire
