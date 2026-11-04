`default_nettype none

// MIDI 文件上传阶段的 FPGA 端探针。
// 它已经能接收完整 MIDI Type 0 文件、逐块写入片内 RAM、校验 CRC32，
// 并接受 PLAY/STOP；真正的 MIDI 解析器和音频声部将在下一阶段接入同一存储器。
module midi_upload_probe_top (
    input  wire       sys_clk,
    input  wire       sys_rst_n,
    input  wire       uart_rx_i,
    output wire       uart_tx_o,
    output wire [7:0] led_n
);
    localparam integer MAX_PAYLOAD = 132;
    wire rst_n;
    wire [7:0] rx_data;
    wire rx_valid;
    wire framing_error;
    wire frame_valid;
    wire bad_frame;
    wire [7:0] frame_type;
    wire [15:0] frame_seq;
    wire [15:0] frame_length;
    wire [MAX_PAYLOAD*8-1:0] frame_payload;
    wire file_ready;
    wire play_request;
    wire stop_request;
    wire write_busy;
    wire [1:0] store_status;
    wire [7:0] store_read_data;
    reg [31:0] play_counter;
    reg play_led;
    reg error_led;
    reg response_valid;
    reg [7:0] response_type;
    reg [15:0] response_seq;
    reg [7:0] response_length;
    reg [127:0] response_payload;
    wire response_busy;
    integer response_index;

    reset_sync reset_inst (.clk(sys_clk), .arst_n(sys_rst_n), .rst_n(rst_n));
    uart_rx #(.CLKS_PER_BIT(434)) rx_inst (
        .clk(sys_clk), .rst_n(rst_n), .rx(uart_rx_i),
        .data(rx_data), .valid(rx_valid), .framing_error(framing_error)
    );
    uart_frame_protocol #(.MAX_PAYLOAD(MAX_PAYLOAD)) protocol_inst (
        .clk(sys_clk), .rst_n(rst_n), .rx_data(rx_data), .rx_valid(rx_valid),
        .frame_valid(frame_valid), .bad_frame(bad_frame), .frame_type(frame_type),
        .frame_seq(frame_seq), .frame_length(frame_length), .frame_payload(frame_payload)
    );
    midi_file_store #(.FILE_BYTES(65536), .MAX_PAYLOAD(MAX_PAYLOAD)) store_inst (
        .clk(sys_clk), .rst_n(rst_n), .frame_valid(frame_valid), .frame_type(frame_type),
        .frame_seq(frame_seq),
        .frame_length(frame_length), .frame_payload(frame_payload), .file_ready(file_ready),
        .play_request(play_request), .stop_request(stop_request), .last_status(store_status),
        .write_busy(write_busy), .mem_write_en(), .mem_write_address(), .mem_write_data(),
        .file_size(), .read_address(16'd0), .read_data(store_read_data)
    );
    uart_frame_tx #(.CLKS_PER_BIT(434), .MAX_RESPONSE(16)) response_tx (
        .clk(sys_clk), .rst_n(rst_n), .response_valid(response_valid),
        .response_type(response_type), .response_seq(response_seq),
        .response_length(response_length), .response_payload(response_payload),
        .tx(uart_tx_o), .busy(response_busy)
    );

    // ACK payload 前两个字节固定为原命令类型和状态码；PING 另外回传 nonce。
    always @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            response_valid  <= 1'b0;
            response_type   <= 8'h81;
            response_seq    <= 16'd0;
            response_length <= 8'd0;
            response_payload <= 128'd0;
            play_counter    <= 32'd0;
            play_led        <= 1'b0;
            error_led       <= 1'b0;
        end else begin
            response_valid <= 1'b0;
            if (play_counter != 0) play_counter <= play_counter - 1'b1;
            else play_led <= 1'b0;
            if (bad_frame || framing_error) error_led <= ~error_led;
            if (play_request) begin
                play_led <= 1'b1;
                play_counter <= 32'd25_000_000;
            end
            if (stop_request) play_led <= 1'b0;

            if (frame_valid && !response_busy) begin
                response_valid <= 1'b1;
                response_type <= 8'h81;
                response_seq <= frame_seq;
                response_payload <= 128'd0;
                response_payload[7:0] <= frame_type;
                response_payload[15:8] <= store_status;
                if (frame_type == 8'h01 && frame_length == 16'd4) begin
                    response_length <= 8'd6;
                    response_payload[47:16] <= frame_payload[31:0];
                end else begin
                    response_length <= 8'd2;
                end
            end
        end
    end

    // LED7=UART 工程运行；LED6=文件已校验；LED5=PLAY 活跃；LED0=错误翻转。
    assign led_n = {1'b0, ~file_ready, ~play_led, 3'b111, error_led, 1'b0};
    wire _unused = &{1'b0, write_busy, response_index};
endmodule

`default_nettype wire
