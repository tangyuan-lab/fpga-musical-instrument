`default_nettype none

// Nextion/TJC 风格 UART 屏幕发送器。
//
// 每次刷新发送 KEY_COUNT+3 条文本属性：
//   t0 = LIVE/MIDI
//   t1 = 活动键数（十六进制）
//   t2 = READY/PLAY/WAIT
//   t3..t18 = 16 个压力值（13 键配置截止 t15），000..FFF。
//
// 命令格式为：tN.txt="VALUE" 0xFF 0xFF 0xFF。
// 默认 115200/8N1；若屏幕保持出厂 9600 波特率，把 CLKS_PER_BIT 改为 5208，
// 或在上层工程中传入相应参数。screen_rx_i 收到的有效字节只翻转 rx_activity，
// 供 LED 观察链路活动；触摸/应答协议尚未解析。
// 首帧前等待 STARTUP_DELAY_CYCLES，后续每整帧发送完再等待刷新间隔。
module serial_screen_nextion_tx #(
    parameter integer KEY_COUNT = 13,
    parameter integer CLKS_PER_BIT = 434,
    parameter integer STARTUP_DELAY_CYCLES = 50_000_000,
    parameter integer UPDATE_PERIOD_CYCLES = 5_000_000,
    // 四字节 ASCII 模式名；诊断顶层可复用现有页面显示 RAW / DIFF。
    parameter [31:0] MODE_0_TEXT = "LIVE",
    parameter [31:0] MODE_1_TEXT = "MIDI"
) (
    input  wire         clk,
    input  wire         rst_n,
    input  wire [KEY_COUNT*12-1:0] pressure_values,
    input  wire [$clog2(KEY_COUNT+1)-1:0] active_key_count,
    input  wire         midi_mode,
    input  wire         audio_ready,
    input  wire         file_ready,
    input  wire         parser_busy,
    input  wire         playing,
    input  wire         screen_rx_i,
    output wire         screen_tx_o,
    output wire         rx_activity
);
    localparam [2:0] ST_WAIT   = 3'd0;
    localparam [2:0] ST_PREFIX = 3'd1;
    localparam [2:0] ST_VALUE  = 3'd2;
    localparam [2:0] ST_TERM   = 3'd3;
    localparam [2:0] ST_QUOTE  = 3'd4;
    localparam [2:0] ST_DRAIN  = 3'd5;

    reg [31:0] period_count;
    reg [2:0] state;
    reg [4:0] field_index;
    reg [3:0] byte_index;
    reg [1:0] term_index;
    reg [2:0] value_index;
    reg [KEY_COUNT*12-1:0] pressure_snapshot;
    reg [$clog2(KEY_COUNT+1)-1:0] active_snapshot;
    wire [7:0] active_hex = active_snapshot;
    reg midi_snapshot;
    reg audio_snapshot;
    reg file_snapshot;
    reg parser_snapshot;
    reg playing_snapshot;
    reg first_refresh;
    reg tx_start;
    reg [7:0] tx_data;
    wire tx_busy;
    wire tx_done;
    wire [7:0] rx_data;
    wire rx_valid;
    wire rx_framing_error;
    // tx_start 为寄存器脉冲，下一拍才被 UART 接收；期间也必须阻止加载新字节。
    wire tx_can_load = !tx_busy && !tx_start;
    wire [31:0] wait_cycles = first_refresh ? STARTUP_DELAY_CYCLES : UPDATE_PERIOD_CYCLES;

    reg [7:0] current_prefix_byte;
    reg [3:0] current_prefix_length;
    reg [7:0] current_value_byte;
    reg [3:0] current_value_length;
    reg [11:0] selected_pressure;
    wire [31:0] mode_text = midi_snapshot ? MODE_1_TEXT : MODE_0_TEXT;

    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) screen_tx (
        .clk(clk), .rst_n(rst_n), .start(tx_start), .data(tx_data),
        .tx(screen_tx_o), .busy(tx_busy), .done(tx_done)
    );

    uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) screen_rx (
        .clk(clk), .rst_n(rst_n), .rx(screen_rx_i), .data(rx_data),
        .valid(rx_valid), .framing_error(rx_framing_error)
    );

    reg rx_activity_reg;
    assign rx_activity = rx_activity_reg;

    function automatic [7:0] hex_ascii(input [3:0] value);
        begin
            hex_ascii = (value < 4'd10) ? (8'h30 + {4'd0, value}) :
                        (8'h41 + {4'd0, value} - 8'd10);
        end
    endfunction

    // 组件名前缀：t0.txt=" 或 t10.txt="。
    always @(*) begin
        current_prefix_length = (field_index >= 10) ? 4'd9 : 4'd8;
        case (byte_index)
            4'd0: current_prefix_byte = "t";
            4'd1: current_prefix_byte = (field_index >= 10) ? "1" : (8'h30 + {3'd0, field_index});
            4'd2: current_prefix_byte = (field_index >= 10) ? (8'h30 + {3'd0, field_index} - 8'd10) : ".";
            4'd3: current_prefix_byte = (field_index >= 10) ? "." : "t";
            4'd4: current_prefix_byte = (field_index >= 10) ? "t" : "x";
            4'd5: current_prefix_byte = (field_index >= 10) ? "x" : "t";
            4'd6: current_prefix_byte = (field_index >= 10) ? "t" : "=";
            4'd7: current_prefix_byte = (field_index >= 10) ? "=" : "\"";
            default: current_prefix_byte = "\"";
        endcase
    end

    // 选择一个压力值，避免在时序状态机中使用可变宽度的长组合切片。
    integer pressure_index;
    always @(*) begin
        selected_pressure = 12'd0;
        for (pressure_index = 0; pressure_index < KEY_COUNT; pressure_index = pressure_index+1)
            if (field_index == pressure_index+3)
                selected_pressure = pressure_snapshot[pressure_index*12 +: 12];
    end

    always @(*) begin
        current_value_length = 4'd1;
        current_value_byte = "0";
        if (field_index == 0) begin
            current_value_length = 4'd4;
            case (value_index)
                3'd0: current_value_byte = mode_text[31:24];
                3'd1: current_value_byte = mode_text[23:16];
                3'd2: current_value_byte = mode_text[15:8];
                default: current_value_byte = mode_text[7:0];
            endcase
        end else if (field_index == 1) begin
            // 16 个活动键发送 "10"；少于 16 时保留单字符兼容协议。
            current_value_length = (active_hex >= 16) ? 4'd2 : 4'd1;
            current_value_byte = (active_hex >= 16 && value_index == 0) ?
                                 hex_ascii(active_hex[7:4]) : hex_ascii(active_hex[3:0]);
        end else if (field_index == 2) begin
            if (playing_snapshot) begin
                current_value_length = 4'd4;
                case (value_index)
                    3'd0: current_value_byte = "P";
                    3'd1: current_value_byte = "L";
                    3'd2: current_value_byte = "A";
                    default: current_value_byte = "Y";
                endcase
            end else if (midi_snapshot && parser_snapshot) begin
                current_value_length = 4'd4;
                case (value_index)
                    3'd0: current_value_byte = "W";
                    3'd1: current_value_byte = "A";
                    3'd2: current_value_byte = "I";
                    default: current_value_byte = "T";
                endcase
            end else if (audio_snapshot && (!midi_snapshot || file_snapshot)) begin
                current_value_length = 4'd5;
                case (value_index)
                    3'd0: current_value_byte = "R";
                    3'd1: current_value_byte = "E";
                    3'd2: current_value_byte = "A";
                    3'd3: current_value_byte = "D";
                    default: current_value_byte = "Y";
                endcase
            end else begin
                current_value_length = 4'd4;
                case (value_index)
                    3'd0: current_value_byte = "W";
                    3'd1: current_value_byte = "A";
                    3'd2: current_value_byte = "I";
                    default: current_value_byte = "T";
                endcase
            end
        end else begin
            current_value_length = 4'd3;
            case (value_index)
                3'd0: current_value_byte = hex_ascii(selected_pressure[11:8]);
                3'd1: current_value_byte = hex_ascii(selected_pressure[7:4]);
                default: current_value_byte = hex_ascii(selected_pressure[3:0]);
            endcase
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            period_count       <= 32'd0;
            state              <= ST_WAIT;
            field_index        <= 5'd0;
            byte_index         <= 4'd0;
            term_index         <= 2'd0;
            value_index        <= 3'd0;
            pressure_snapshot  <= {KEY_COUNT*12{1'b0}};
            active_snapshot    <= {$clog2(KEY_COUNT+1){1'b0}};
            midi_snapshot      <= 1'b0;
            audio_snapshot     <= 1'b0;
            file_snapshot      <= 1'b0;
            parser_snapshot    <= 1'b0;
            playing_snapshot   <= 1'b0;
            first_refresh      <= 1'b1;
            tx_start           <= 1'b0;
            tx_data            <= 8'hff;
            rx_activity_reg    <= 1'b0;
        end else begin
            tx_start <= 1'b0;
            if (rx_valid)
                rx_activity_reg <= ~rx_activity_reg;

            case (state)
                ST_WAIT: begin
                    if (wait_cycles <= 1 || period_count >= wait_cycles - 1'b1) begin
                        period_count      <= 32'd0;
                        pressure_snapshot <= pressure_values;
                        active_snapshot   <= active_key_count;
                        midi_snapshot     <= midi_mode;
                        audio_snapshot    <= audio_ready;
                        file_snapshot     <= file_ready;
                        parser_snapshot   <= parser_busy;
                        playing_snapshot  <= playing;
                        first_refresh     <= 1'b0;
                        field_index       <= 5'd0;
                        byte_index        <= 4'd0;
                        value_index       <= 3'd0;
                        state             <= ST_PREFIX;
                    end else begin
                        period_count <= period_count + 1'b1;
                    end
                end
                ST_PREFIX: begin
                    if (tx_can_load) begin
                        tx_data  <= current_prefix_byte;
                        tx_start <= 1'b1;
                        if (byte_index + 1'b1 >= current_prefix_length) begin
                            byte_index  <= 4'd0;
                            value_index <= 3'd0;
                            state       <= ST_VALUE;
                        end else begin
                            byte_index <= byte_index + 1'b1;
                        end
                    end
                end
                ST_VALUE: begin
                    if (tx_can_load) begin
                        tx_data  <= current_value_byte;
                        tx_start <= 1'b1;
                        if (value_index + 1'b1 >= current_value_length) begin
                            term_index <= 2'd0;
                            state      <= ST_QUOTE;
                        end else begin
                            value_index <= value_index + 1'b1;
                        end
                    end
                end
                ST_QUOTE: begin
                    if (tx_can_load) begin
                        tx_data  <= "\"";
                        tx_start <= 1'b1;
                        state    <= ST_TERM;
                    end
                end
                ST_TERM: begin
                    if (tx_can_load) begin
                        tx_data  <= 8'hff;
                        tx_start <= 1'b1;
                        if (term_index == 2'd2) begin
                            if (field_index == KEY_COUNT+2) begin
                                state <= ST_DRAIN;
                            end else begin
                                field_index <= field_index + 1'b1;
                                byte_index  <= 4'd0;
                                value_index <= 3'd0;
                                state       <= ST_PREFIX;
                            end
                        end else begin
                            term_index <= term_index + 1'b1;
                        end
                    end
                end
                ST_DRAIN: begin
                    // 最后一个结束字节的停止位发完后，才开始下一次刷新间隔。
                    if (tx_done) begin
                        period_count <= 32'd0;
                        state <= ST_WAIT;
                    end
                end
                default: begin
                    period_count <= 32'd0;
                    state <= ST_WAIT;
                end
            endcase
        end
    end

    wire _unused = &{1'b0, rx_data, rx_framing_error};
endmodule

`default_nettype wire
