`default_nettype none
// UART、帧协议与触键服务的兼容接线入口。
module screen_touch_keys_rx #(
    parameter integer CLKS_PER_BIT = 434,
    parameter integer KEY_COUNT = 13,
    parameter integer POLYPHONIC = 0,
    parameter integer PERFORMANCE_CONTROLS = 0,
    parameter integer WORKSTATION_CONTROLS = 0,
    // 两个字节间最多约 2.8 ms（50 MHz 默认值），防止残缺帧跨事件拼接。
    parameter integer FRAME_TIMEOUT_CYCLES = CLKS_PER_BIT * 320,
    // 50 MHz 时为 750 ms；屏幕需在按住期间周期发送 OP=01 保活。
    parameter integer WATCHDOG_CYCLES = 37_500_000
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        screen_rx_i,
    output wire  [KEY_COUNT-1:0] held_keys,
    // 每收到一个完整 UART 字节翻转，用于板上链路活动指示。
    output wire         rx_activity,
    // 候选帧校验/字段错误、UART 停止位错误时脉冲一拍；普通噪声忽略。
    output wire         frame_error,
    output wire [1:0]   octave_shift,
    output wire         test_mode,
    output wire         command_valid,
    output wire [7:0]   command_op,
    output wire [7:0]   command_value,
    output wire [4:0]   command_cancel_flags
);
    wire [7:0] rx_data,frame_op,frame_value;
    wire rx_valid,rx_framing_error,frame_valid,parse_error,unsupported_frame;
    uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) uart_receiver(
        .clk(clk),.rst_n(rst_n),.rx(screen_rx_i),.data(rx_data),.valid(rx_valid),.framing_error(rx_framing_error));
    screen_frame_rx #(.FRAME_TIMEOUT_CYCLES(FRAME_TIMEOUT_CYCLES)) frames(
        .clk(clk),.rst_n(rst_n),.rx_data(rx_data),.rx_valid(rx_valid),.rx_framing_error(rx_framing_error),
        .frame_valid(frame_valid),.frame_op(frame_op),.frame_value(frame_value),.rx_activity(rx_activity),.frame_error(parse_error));
    screen_touch_service #(.KEY_COUNT(KEY_COUNT),.POLYPHONIC(POLYPHONIC),
        .PERFORMANCE_CONTROLS(PERFORMANCE_CONTROLS),.WORKSTATION_CONTROLS(WORKSTATION_CONTROLS),
        .WATCHDOG_CYCLES(WATCHDOG_CYCLES)) touch_service(
        .clk(clk),.rst_n(rst_n),.frame_valid(frame_valid),.frame_op(frame_op),.frame_value(frame_value),
        .held_keys(held_keys),.octave_shift(octave_shift),.test_mode(test_mode),
        .command_valid(command_valid),.command_op(command_op),.command_value(command_value),
        .command_cancel_flags(command_cancel_flags),.unsupported_frame(unsupported_frame));
    assign frame_error=parse_error||unsupported_frame;
endmodule
`default_nettype wire
