`default_nettype none

// 通用 ACK/NACK 发送器。响应 payload 的前两个字节必须是原消息类型和状态码，
// 其余字节由具体命令使用；PING 会额外带回 4 字节 nonce。
module uart_frame_tx #(
    parameter integer CLKS_PER_BIT = 434,
    parameter integer MAX_RESPONSE = 16
) (
    input  wire                          clk,
    input  wire                          rst_n,
    input  wire                          response_valid,
    input  wire [7:0]                    response_type,
    input  wire [15:0]                   response_seq,
    input  wire [7:0]                    response_length,
    input  wire [MAX_RESPONSE*8-1:0]     response_payload,
    output wire                          tx,
    output reg                           busy
);
    reg [7:0] type_reg;
    reg [15:0] seq_reg;
    reg [7:0] length_reg;
    reg [MAX_RESPONSE*8-1:0] payload_reg;
    reg [4:0] byte_index;
    // 帧总字节数 = 2 同步 + 6 头部 + payload + 2 CRC，payload 最多 16 字节。
    // 使用 8 位计数器，避免 5 位表达式接收 8 位长度时发生隐式截断。
    reg [7:0] total_bytes;
    reg byte_pending;
    reg start;
    reg [7:0] tx_data;
    localparam integer MAX_FRAME_BYTES = 10 + MAX_RESPONSE;
    reg [7:0] frame_mem [0:MAX_FRAME_BYTES-1];
    reg [5:0] crc_build_index;
    reg [15:0] crc_build_value;
    reg crc_build_active;
    reg crc_build_wait;
    wire uart_busy;
    wire uart_done;
    wire [7:0] crc_build_byte = frame_mem[2 + crc_build_index];
    wire [15:0] crc_build_next = crc16_next(crc_build_value, crc_build_byte);
    integer frame_index;

    function automatic [15:0] crc16_next;
        input [15:0] crc_in;
        input [7:0] byte_in;
        reg [15:0] c;
        integer bit_index;
        begin
            c = crc_in ^ {byte_in, 8'd0};
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1)
                if (c[15]) c = (c << 1) ^ 16'h1021;
                else c = c << 1;
            crc16_next = c;
        end
    endfunction

    always @(*) begin
        tx_data = 8'hff;
        if (byte_index < MAX_FRAME_BYTES)
            tx_data = frame_mem[byte_index];
    end

    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) tx_inst (
        .clk(clk), .rst_n(rst_n), .start(start), .data(tx_data),
        .tx(tx), .busy(uart_busy), .done(uart_done)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            type_reg      <= 8'd0;
            seq_reg       <= 16'd0;
            length_reg    <= 8'd0;
            payload_reg   <= {(MAX_RESPONSE*8){1'b0}};
            byte_index    <= 5'd0;
            total_bytes   <= 8'd0;
            byte_pending  <= 1'b0;
            start         <= 1'b0;
            busy          <= 1'b0;
            crc_build_index <= 6'd0;
            crc_build_value <= 16'hffff;
            crc_build_active <= 1'b0;
            crc_build_wait <= 1'b0;
            for (frame_index = 0; frame_index < MAX_FRAME_BYTES; frame_index = frame_index + 1)
                frame_mem[frame_index] <= 8'd0;
        end else begin
            start <= 1'b0;
            if (response_valid && !busy) begin
                type_reg     <= response_type;
                seq_reg      <= response_seq;
                length_reg   <= response_length;
                payload_reg  <= response_payload;
                byte_index   <= 5'd0;
                total_bytes  <= 8'd10 + response_length;
                byte_pending <= 1'b0;
                busy         <= 1'b1;
                // 先锁存完整帧的固定字段和 payload，再用一个字节一个字节的
                // CRC 状态机计算校验值。发送阶段只读取小型帧缓存，避免把
                // 可变位选和 16 字节 CRC 展开到 UART 移位寄存器的同一条路径。
                frame_mem[0] <= 8'h55;
                frame_mem[1] <= 8'haa;
                frame_mem[2] <= 8'd1;
                frame_mem[3] <= response_type;
                frame_mem[4] <= response_seq[7:0];
                frame_mem[5] <= response_seq[15:8];
                frame_mem[6] <= response_length;
                frame_mem[7] <= 8'd0;
                for (frame_index = 0; frame_index < MAX_RESPONSE; frame_index = frame_index + 1)
                    frame_mem[8 + frame_index] <= response_payload[frame_index*8 +: 8];
                crc_build_index <= 6'd0;
                crc_build_value <= 16'hffff;
                crc_build_active <= 1'b1;
                crc_build_wait <= 1'b1;
            end
            if (busy) begin
                if (crc_build_active) begin
                    if (crc_build_wait) begin
                        // 等待上一个时钟写入的帧缓存字段稳定。
                        crc_build_wait <= 1'b0;
                    end else if (crc_build_index == (6'd5 + length_reg)) begin
                        crc_build_value <= crc_build_next;
                        frame_mem[8 + length_reg] <= crc_build_next[7:0];
                        frame_mem[9 + length_reg] <= crc_build_next[15:8];
                        crc_build_active <= 1'b0;
                    end else begin
                        crc_build_value <= crc_build_next;
                        crc_build_index <= crc_build_index + 1'b1;
                    end
                end else begin
                    if (!uart_busy && !byte_pending) begin
                        start <= 1'b1;
                        byte_pending <= 1'b1;
                    end
                    if (uart_done) begin
                        byte_pending <= 1'b0;
                        if (byte_index == total_bytes - 1'b1)
                            busy <= 1'b0;
                        else
                            byte_index <= byte_index + 1'b1;
                    end
                end
            end
        end
    end
endmodule

`default_nettype wire
