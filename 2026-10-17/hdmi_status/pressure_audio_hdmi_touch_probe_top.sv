`default_nettype none

// 触摸屏联合调试顶层：保留已经验证的压力、音频和 HDMI 功能，
// 同时运行全速 USB Host 探针，并将 USB 枚举信息送到板载串口。
module pressure_audio_hdmi_touch_probe_top (
    input  wire       sys_clk,
    input  wire       sys_rst_n,
    inout  wire       usb_dp,
    inout  wire       usb_dm,
    output wire       uart_tx_o,
    output wire [7:0] led_n,
    output wire       hp_bck,
    output wire       hp_ws,
    output wire       hp_din,
    output wire       pa_en,
    output wire [2:0] tmds_p,
    output wire [2:0] tmds_n,
    output wire       tmds_clk_p,
    output wire       tmds_clk_n,
    output wire       hpd_en
);
    wire main_uart_unused;
    wire [7:0] main_led_n;
    wire usb_clk;
    wire usb_uart;
    wire usb_cpu_fetch_seen;
    wire usb_uart_write_seen;
    wire [1:0] usb_linestate;
    wire [31:0] usb_debug_mailbox;
    wire [3:0] usb_failure_code;
    reg [15:0] usb_reset_counter;
    reg        usb_rst_n;
    reg [24:0] usb_heartbeat_counter;
    reg [31:0] usb_debug_mailbox_d;
    reg [23:0] touch_flash_counter;
    wire [7:0] debug_led_on;

    // 原来的主工程保持完整运行，因此屏幕、耳机和压力 LED 的现象不变。
    pressure_audio_hdmi_top u_main (
        .sys_clk(sys_clk),
        .sys_rst_n(sys_rst_n),
        .uart_tx_o(main_uart_unused),
        .led_n(main_led_n),
        .hp_bck(hp_bck),
        .hp_ws(hp_ws),
        .hp_din(hp_din),
        .pa_en(pa_en),
        .tmds_p(tmds_p),
        .tmds_n(tmds_n),
        .tmds_clk_p(tmds_clk_p),
        .tmds_clk_n(tmds_clk_n),
        .hpd_en(hpd_en)
    );

    // 全速 USB Host PHY 使用 48 MHz 独立时钟。
    pll u_usb_pll (
        .clkin(sys_clk),
        .clkout0(usb_clk)
    );

    // 延迟约 1.37 ms 释放 USB CPU/控制器，避开 PLL 的上电过渡阶段。
    always @(posedge usb_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            usb_reset_counter <= 16'd0;
            usb_rst_n         <= 1'b0;
        end else if (!usb_rst_n) begin
            if (usb_reset_counter == 16'hffff)
                usb_rst_n <= 1'b1;
            else
                usb_reset_counter <= usb_reset_counter + 16'd1;
        end
    end

    always @(posedge usb_clk or negedge usb_rst_n) begin
        if (!usb_rst_n) begin
            usb_heartbeat_counter <= 25'd0;
            usb_debug_mailbox_d   <= 32'd0;
            touch_flash_counter   <= 24'd0;
        end else begin
            usb_heartbeat_counter <= usb_heartbeat_counter + 25'd1;
            usb_debug_mailbox_d   <= usb_debug_mailbox;
            if ((usb_debug_mailbox != usb_debug_mailbox_d) && usb_debug_mailbox[31])
                touch_flash_counter <= 24'hffffff;
            else if (touch_flash_counter != 24'd0)
                touch_flash_counter <= touch_flash_counter - 24'd1;
        end
    end

    iosys2 u_usb_host_soc (
        .clk(usb_clk),
        .resetn(usb_rst_n),
        .debug_cpu_fetch_seen(usb_cpu_fetch_seen),
        .debug_uart_write_seen(usb_uart_write_seen),
        .debug_usb_linestate(usb_linestate),
        .debug_mailbox(usb_debug_mailbox),
        .uart_rx(1'b1),
        .uart_tx(usb_uart),
        .usb_dm(usb_dm),
        .usb_dp(usb_dp)
    );

    // 联合调试阶段让串口专门输出 USB 描述符，便于确认触摸报告格式。
    assign uart_tx_o = usb_uart;

    assign usb_failure_code =
        (usb_debug_mailbox[31:28] == 4'he) ? usb_debug_mailbox[27:24] : 4'd0;

    // USB 失败状态直接保持显示：
    // 常亮 1/2/3 颗分别表示配置、描述符枚举、HID 端点选择失败；
    // 常亮 4 颗表示 HID 已就绪，收到触摸报告时八颗同时短暂点亮。
    assign debug_led_on =
        (usb_failure_code == 4'd1) ? 8'b0000_0001 :
        (usb_failure_code == 4'd2) ? 8'b0000_0011 :
        (usb_failure_code == 4'd3) ? 8'b0000_0111 :
        ((usb_debug_mailbox[31:28] == 4'h3) ||
         (usb_debug_mailbox[31:28] == 4'h8)) ?
            ((touch_flash_counter != 24'd0) ? 8'hff : 8'h0f) :
        (usb_heartbeat_counter[24] ? 8'b0000_0001 : 8'b0000_0000);
    assign led_n = ~debug_led_on;

    wire _unused = &{1'b0, main_uart_unused};
endmodule

`default_nettype wire

