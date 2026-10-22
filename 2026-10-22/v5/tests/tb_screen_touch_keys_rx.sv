`timescale 1ns/1ps
`default_nettype none

// 从 UART 引脚驱动，不绕过串口接收器：验证单点固定力度演奏的按下、
// 松开、保活、重同步及失联松键行为。计时参数缩短以保持测试快速。
module tb_screen_touch_keys_rx;
    localparam integer CLKS_PER_BIT = 16;
    localparam integer FRAME_TIMEOUT_CYCLES = 480;
    localparam integer WATCHDOG_CYCLES = 8000;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg screen_rx_i = 1'b1;
    wire [12:0] held_keys;
    wire rx_activity;
    wire frame_error;
    integer error_count = 0;
    integer on_transitions = 0;
    reg [12:0] last_keys = 13'd0;
    integer key;

    always #10 clk = ~clk;
    screen_touch_keys_rx #(
        .CLKS_PER_BIT(CLKS_PER_BIT),
        .FRAME_TIMEOUT_CYCLES(FRAME_TIMEOUT_CYCLES),
        .WATCHDOG_CYCLES(WATCHDOG_CYCLES)
    ) dut (
        .clk(clk), .rst_n(rst_n), .screen_rx_i(screen_rx_i),
        .held_keys(held_keys), .rx_activity(rx_activity), .frame_error(frame_error)
    );

    always @(negedge clk) begin
        if (frame_error) begin
            error_count = error_count + 1;
        end
        if (rst_n && (held_keys != 0) && (held_keys != last_keys)) begin
            on_transitions = on_transitions + 1;
        end
        last_keys = held_keys;
    end

    task automatic send_byte(input [7:0] value);
        integer bit_index;
        begin
            @(negedge clk);
            screen_rx_i = 1'b0;
            repeat (CLKS_PER_BIT) @(negedge clk);
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                screen_rx_i = value[bit_index];
                repeat (CLKS_PER_BIT) @(negedge clk);
            end
            screen_rx_i = 1'b1;
            repeat (CLKS_PER_BIT) @(negedge clk);
        end
    endtask

    task automatic send_frame(input [7:0] operation, input [7:0] note);
        begin
            send_byte(8'ha5);
            send_byte(8'h5a);
            send_byte(operation);
            send_byte(note);
            send_byte(8'hff ^ operation ^ note);
            repeat (4) @(negedge clk);
        end
    endtask

    task automatic send_bad_stop(input [7:0] value);
        integer bit_index;
        begin
            @(negedge clk);
            screen_rx_i = 1'b0;
            repeat (CLKS_PER_BIT) @(negedge clk);
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                screen_rx_i = value[bit_index];
                repeat (CLKS_PER_BIT) @(negedge clk);
            end
            screen_rx_i = 1'b0;
            repeat (CLKS_PER_BIT) @(negedge clk);
            screen_rx_i = 1'b1;
            repeat (2 * CLKS_PER_BIT) @(negedge clk);
        end
    endtask

    task automatic expect_keys(input [12:0] expected, input [255:0] test_context);
        begin
            if (held_keys !== expected) begin
                $fatal(1, "%0s keys=%04x expected=%04x", test_context, held_keys, expected);
            end
        end
    endtask

    task automatic reset_receiver;
        begin
            rst_n = 1'b0;
            repeat (5) @(negedge clk);
            expect_keys(13'd0, "reset");
            rst_n = 1'b1;
            repeat (5) @(negedge clk);
        end
    endtask

    initial begin
        reset_receiver();
        // 逐个验证 13 键映射及对应松开。
        for (key = 0; key < 13; key = key + 1) begin
            send_frame(8'h01, key);
            expect_keys(13'b1 << key, "key mapping ON");
            send_frame(8'h00, key);
            expect_keys(13'd0, "key mapping OFF");
        end

        send_frame(8'h01, 8'd2);
        key = on_transitions;
        repeat (WATCHDOG_CYCLES / 2) @(negedge clk);
        send_frame(8'h01, 8'd2);
        repeat (WATCHDOG_CYCLES / 2) @(negedge clk);
        expect_keys(13'b1 << 2, "heartbeat extended hold");
        if (on_transitions != key) begin
            $fatal(1, "same-key heartbeat retriggered key");
        end

        send_frame(8'h01, 8'd12);
        expect_keys(13'b1 << 12, "new key replaces old key");
        send_frame(8'h00, 8'd2);
        expect_keys(13'b1 << 12, "late old-key OFF ignored");
        send_frame(8'h02, 8'hff);
        expect_keys(13'd0, "all off");

        // 随机字节和重复 A5 后，下一帧仍必须匹配。
        send_byte(8'h88);
        send_byte(8'hff);
        send_byte(8'ha5);
        send_byte(8'ha5);
        send_frame(8'h01, 8'd4);
        expect_keys(13'b1 << 4, "noise prefix resynchronization");
        // 坏帧末尾为 A5，紧邻的下一帧头仍完整保留。
        send_byte(8'ha5);
        send_byte(8'h5a);
        send_byte(8'h01);
        send_byte(8'h00);
        send_byte(8'ha5);
        expect_keys(13'b1 << 4, "bad checksum ignored");
        send_frame(8'h01, 8'd6);
        expect_keys(13'b1 << 6, "checksum A5 resynchronization");
        send_frame(8'h01, 8'd13);
        expect_keys(13'b1 << 6, "out-of-range key ignored");
        send_frame(8'h03, 8'd6);
        expect_keys(13'b1 << 6, "invalid operation ignored");
        send_frame(8'h02, 8'd0);
        expect_keys(13'b1 << 6, "invalid all-off key ignored");
        send_frame(8'h00, 8'd6);

        // 残帧超时后，旧前缀不能与后续字节拼成 ON。
        send_byte(8'ha5);
        send_byte(8'h5a);
        send_byte(8'h01);
        repeat (FRAME_TIMEOUT_CYCLES + 20) @(negedge clk);
        send_byte(8'd7);
        send_byte(8'hff ^ 8'h01 ^ 8'd7);
        expect_keys(13'd0, "partial frame timeout");
        send_frame(8'h01, 8'd7);
        expect_keys(13'b1 << 7, "complete frame after timeout");
        send_bad_stop(8'ha5);
        expect_keys(13'b1 << 7, "UART stop-bit error ignored");
        send_frame(8'h02, 8'hff);
        expect_keys(13'd0, "frame after UART stop-bit error");

        // 非匹配 OFF、越界 ON 和坏校验不能保活旧音符。
        send_frame(8'h01, 8'd1);
        repeat (WATCHDOG_CYCLES / 2) @(negedge clk);
        send_frame(8'h00, 8'd8);
        send_frame(8'h01, 8'hff);
        send_byte(8'ha5);
        send_byte(8'h5a);
        send_byte(8'h01);
        send_byte(8'h01);
        send_byte(8'h00);
        repeat (WATCHDOG_CYCLES / 2) @(negedge clk);
        expect_keys(13'd0, "invalid traffic cannot extend watchdog");

        send_frame(8'h01, 8'd3);
        repeat (WATCHDOG_CYCLES + 20) @(negedge clk);
        expect_keys(13'd0, "stuck-touch timeout");
        send_frame(8'h01, 8'd10);
        reset_receiver();
        if (error_count < 5) begin
            $fatal(1, "missing malformed frame indication: %0d", error_count);
        end
        $display("PASS tb_screen_touch_keys_rx keys=13 malformed=%0d heartbeat=PASS watchdog=PASS", error_count);
        $finish;
    end

    initial begin
        #5_000_000;
        $fatal(1, "test timeout");
    end
endmodule

`default_nettype wire
