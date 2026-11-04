`default_nettype none

// 串口屏触摸演奏接收器，与 MCP3208 压力采集互不依赖。
// 115200/8N1，固定五字节：A5 5A OP KEY CHECK。
// CHECK = A5 ^ 5A ^ OP ^ KEY；KEY=0..KEY_COUNT-1，16 键时对应 C4..D#5。
// OP=01：按下/保活；OP=00：松开指定键；OP=02、KEY=FF：全部松开。
// POLYPHONIC=1 时各键独立保持、释音和超时；默认保留旧单音协议行为。
// 重复按下同键只保活、不重新触发。实际多指能力还取决于屏幕事件源。
// 音量/力度由上层给固定值，本模块只输出 held_keys（保持按键位图）。
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
    output reg  [KEY_COUNT-1:0] held_keys,
    // 每收到一个完整 UART 字节翻转，用于板上链路活动指示。
    output reg         rx_activity,
    // 候选帧校验/字段错误、UART 停止位错误时脉冲一拍；普通噪声忽略。
    output reg         frame_error,
    output reg [1:0]   octave_shift,
    output reg         test_mode,
    output reg         command_valid,
    output reg [7:0]   command_op,
    output reg [7:0]   command_value
);
    localparam integer FRAME_COUNT_WIDTH = (FRAME_TIMEOUT_CYCLES < 2) ? 1 : $clog2(FRAME_TIMEOUT_CYCLES);
    localparam integer WATCHDOG_COUNT_WIDTH = (WATCHDOG_CYCLES < 2) ? 1 : $clog2(WATCHDOG_CYCLES);

    wire [7:0] rx_data;
    wire rx_valid;
    wire rx_framing_error;
    reg [31:0] byte_window;
    reg [2:0] window_count;
    reg [FRAME_COUNT_WIDTH-1:0] frame_gap_count;
    reg [WATCHDOG_COUNT_WIDTH-1:0] watchdog_count;

    uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) uart_receiver (
        .clk(clk), .rst_n(rst_n), .rx(screen_rx_i),
        .data(rx_data), .valid(rx_valid), .framing_error(rx_framing_error)
    );

    // 滑动窗口保留最近四个字节，每个新字节都能形成候选五字节帧。
    // 不在收到 A5 时盲目重新开始，因此校验字节为 A5、噪声重复 A5，
    // 以及坏帧之后立即到来的完整帧都不会丢失正确帧头。
    wire candidate = rx_valid && (window_count == 3'd4) &&
                     (byte_window[31:16] == 16'ha55a);
    wire checksum_ok = rx_data == (8'hff ^ byte_window[15:8] ^ byte_window[7:0]);
    wire key_in_range = byte_window[7:0] < KEY_COUNT;
    wire key_on = candidate && checksum_ok && key_in_range && (byte_window[15:8] == 8'h01);
    wire key_off = candidate && checksum_ok && key_in_range && (byte_window[15:8] == 8'h00);
    wire all_off = candidate && checksum_ok && ((byte_window[15:0] == 16'h02ff) ||
                   (WORKSTATION_CONTROLS && byte_window[15:8]==8'h05 && byte_window[7:0]<=4));
    // 通用服务接口仅交付完整且校验正确的帧；上层服务再校验各字段范围。
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin command_valid<=0;command_op<=0;command_value<=0;end
        else begin
            command_valid<=candidate && checksum_ok;
            if(candidate && checksum_ok) begin command_op<=byte_window[15:8];command_value<=byte_window[7:0];end
        end
    end
    // OP=03：0 原八度、1 高八度、2 低八度；OP=04：0 退出、1 四频测试/保活。
    wire octave_command = PERFORMANCE_CONTROLS && candidate && checksum_ok &&
        byte_window[15:8] == 8'h03 && byte_window[7:0] <= 2;
    wire test_command = PERFORMANCE_CONTROLS && candidate && checksum_ok &&
        byte_window[15:8] == 8'h04 && byte_window[7:0] <= 1;
    reg [WATCHDOG_COUNT_WIDTH-1:0] test_watchdog;
    wire [KEY_COUNT-1:0] key_mask = {{(KEY_COUNT-1){1'b0}}, 1'b1} << byte_window[7:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            octave_shift <= 0; test_mode <= 0; test_watchdog <= 0;
        end else if (all_off) begin
            octave_shift <= 0; test_mode <= 0; test_watchdog <= 0;
        end else begin
            if (octave_command) octave_shift <= byte_window[1:0];
            if (test_command) begin
                test_mode <= byte_window[0]; test_watchdog <= 0;
            end else if (test_mode) begin
                // 诊断连续发声也必须由页面保活，断线后恢复正常演奏输入。
                if (test_watchdog >= WATCHDOG_CYCLES-1) begin
                    test_mode <= 0; test_watchdog <= 0;
                end else test_watchdog <= test_watchdog+1'b1;
            end else test_watchdog <= 0;
        end
    end

    generate if (POLYPHONIC != 0) begin : polyphonic_hold
        reg [WATCHDOG_COUNT_WIDTH-1:0] key_watchdog [0:KEY_COUNT-1];
        integer k;
        // 每键单独保活：某一个键持续发心跳不能延长其他已丢失松开事件的键。
        // 计数器属于控制寄存器，不是音频 BRAM，因此允许复位。
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                held_keys <= {KEY_COUNT{1'b0}};
                for (k = 0; k < KEY_COUNT; k = k + 1) begin
                    key_watchdog[k] <= {WATCHDOG_COUNT_WIDTH{1'b0}};
                end
            end else begin
                for (k = 0; k < KEY_COUNT; k = k + 1) begin
                    if (all_off || (key_off && key_mask[k])) begin
                        held_keys[k] <= 1'b0;
                        key_watchdog[k] <= {WATCHDOG_COUNT_WIDTH{1'b0}};
                    end else if (key_on && key_mask[k]) begin
                        held_keys[k] <= 1'b1;
                        key_watchdog[k] <= {WATCHDOG_COUNT_WIDTH{1'b0}};
                    end else if (held_keys[k]) begin
                        if (key_watchdog[k] >= WATCHDOG_CYCLES - 1) begin
                            held_keys[k] <= 1'b0;
                            key_watchdog[k] <= {WATCHDOG_COUNT_WIDTH{1'b0}};
                        end else begin
                            key_watchdog[k] <= key_watchdog[k] + 1'b1;
                        end
                    end else begin
                        key_watchdog[k] <= {WATCHDOG_COUNT_WIDTH{1'b0}};
                    end
                end
            end
        end
    end endgenerate
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            byte_window     <= 32'd0;
            window_count    <= 3'd0;
            frame_gap_count <= {FRAME_COUNT_WIDTH{1'b0}};
            rx_activity     <= 1'b0;
            frame_error     <= 1'b0;
        end else begin
            frame_error <= 1'b0;
            if (rx_framing_error) begin
                byte_window     <= 32'd0;
                window_count    <= 3'd0;
                frame_gap_count <= {FRAME_COUNT_WIDTH{1'b0}};
                frame_error     <= 1'b1;
            end else if (rx_valid) begin
                byte_window     <= {byte_window[23:0], rx_data};
                frame_gap_count <= {FRAME_COUNT_WIDTH{1'b0}};
                rx_activity     <= ~rx_activity;
                if (window_count < 3'd4) begin
                    window_count <= window_count + 1'b1;
                end
                if (candidate && !(key_on || key_off || all_off || octave_command || test_command ||
                                   (WORKSTATION_CONTROLS && checksum_ok))) begin
                    frame_error <= 1'b1;
                end
            end else if (window_count != 0) begin
                if (frame_gap_count >= FRAME_TIMEOUT_CYCLES - 1) begin
                    byte_window     <= 32'd0;
                    window_count    <= 3'd0;
                    frame_gap_count <= {FRAME_COUNT_WIDTH{1'b0}};
                end else begin
                    frame_gap_count <= frame_gap_count + 1'b1;
                end
            end
        end
    end

    generate if (POLYPHONIC == 0) begin : monophonic_hold
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            held_keys      <= {KEY_COUNT{1'b0}};
            watchdog_count <= {WATCHDOG_COUNT_WIDTH{1'b0}};
        end else if (key_on) begin
            // 合法 ON 可以切换到另一键；只有合法 ON/同键保活延长保持时间。
            held_keys      <= key_mask;
            watchdog_count <= {WATCHDOG_COUNT_WIDTH{1'b0}};
        end else if (all_off || (key_off && ((held_keys & key_mask) != 0))) begin
            // 迟到的旧键 OFF 不影响新键，防止滑动/事件乱序误松开。
            held_keys      <= {KEY_COUNT{1'b0}};
            watchdog_count <= {WATCHDOG_COUNT_WIDTH{1'b0}};
        end else if (held_keys != 0) begin
            // 坏校验、越界键、噪声、非匹配 OFF 均不重置 watchdog。
            if (watchdog_count >= WATCHDOG_CYCLES - 1) begin
                held_keys      <= {KEY_COUNT{1'b0}};
                watchdog_count <= {WATCHDOG_COUNT_WIDTH{1'b0}};
            end else begin
                watchdog_count <= watchdog_count + 1'b1;
            end
        end else begin
            watchdog_count <= {WATCHDOG_COUNT_WIDTH{1'b0}};
        end
    end
    end endgenerate
endmodule

`default_nettype wire
