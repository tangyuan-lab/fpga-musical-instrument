`default_nettype none

// MIDI Type 0 文件接收存储器。
// 文件内容通过 FILE_BEGIN/FILE_DATA/FILE_END 写入片内 RAM；写入完成后
// file_ready 才允许 PLAY。CRC32 在接收过程中逐字节更新，避免把电脑端
// 的文件校验结果直接当成 FPGA 的有效性证明。
module midi_file_store #(
    parameter integer FILE_BYTES = 65536,
    parameter integer MAX_PAYLOAD = 132
) (
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire                         frame_valid,
    input  wire [7:0]                   frame_type,
    input  wire [15:0]                  frame_seq,
    input  wire [15:0]                  frame_length,
    input  wire [MAX_PAYLOAD*8-1:0]     frame_payload,
    output reg                          file_ready,
    output reg                          play_request,
    output reg                          stop_request,
    output reg [1:0]                    last_status,
    output reg                          write_busy,
    output reg                          mem_write_en,
    output reg  [15:0]                  mem_write_address,
    output reg  [7:0]                   mem_write_data,
    output wire [16:0]                  file_size,
    input  wire [15:0]                  read_address,
    input  wire [7:0]                   read_data
);
    localparam [7:0] FILE_BEGIN = 8'h10;
    localparam [7:0] FILE_DATA  = 8'h11;
    localparam [7:0] FILE_END   = 8'h12;
    localparam [7:0] PLAY       = 8'h13;
    localparam [7:0] STOP       = 8'h14;

    reg [31:0] expected_size;
    reg [31:0] expected_crc;
    reg [31:0] received_bytes;
    reg [31:0] running_crc;
    reg [31:0] pending_offset;
    reg [7:0] pending_data [0:127];
    reg [7:0] pending_count;
    reg [7:0] pending_index;
    reg       last_data_valid;
    reg [15:0] last_data_seq;
    reg [31:0] last_data_offset;
    reg [7:0]  last_data_count;
    integer index;

    // 64 KiB 上限需要 17 位表示，65536 代表完整 RAM 容量。
    assign file_size = (expected_size > FILE_BYTES) ? 17'd65536 : expected_size[16:0];

    function automatic [31:0] crc32_next;
        input [31:0] crc_in;
        input [7:0] byte_in;
        reg [31:0] c;
        integer bit_index;
        begin
            c = crc_in ^ byte_in;
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1)
                if (c[0]) c = (c >> 1) ^ 32'hedb88320;
                else c = c >> 1;
            crc32_next = c;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            expected_size  <= 32'd0;
            expected_crc   <= 32'd0;
            received_bytes <= 32'd0;
            running_crc    <= 32'hffffffff;
            pending_offset <= 32'd0;
            pending_count  <= 8'd0;
            pending_index  <= 8'd0;
            last_data_valid  <= 1'b0;
            last_data_seq    <= 16'd0;
            last_data_offset <= 32'd0;
            last_data_count  <= 8'd0;
            file_ready     <= 1'b0;
            play_request   <= 1'b0;
            stop_request   <= 1'b0;
            last_status    <= 2'd0;
            write_busy     <= 1'b0;
            mem_write_en   <= 1'b0;
            mem_write_address <= 16'd0;
            mem_write_data <= 8'd0;
        end else begin
            play_request <= 1'b0;
            stop_request <= 1'b0;
            mem_write_en <= 1'b0;

            if (write_busy) begin
                mem_write_en <= 1'b1;
                mem_write_address <= pending_offset[15:0] + pending_index;
                mem_write_data <= pending_data[pending_index];
                running_crc <= crc32_next(running_crc, pending_data[pending_index]);
                received_bytes <= received_bytes + 1'b1;
                if (pending_index == pending_count - 1'b1) begin
                    write_busy <= 1'b0;
                    pending_index <= 8'd0;
                end else begin
                    pending_index <= pending_index + 1'b1;
                end
            end

            if (frame_valid && !write_busy) begin
                case (frame_type)
                    8'h01: begin
                        if (frame_length == 16'd4) last_status <= 2'd0;
                        else last_status <= 2'd1;
                    end
                    FILE_BEGIN: begin
                        if (frame_length == 16'd12 && frame_payload[31:0] == 32'h3044494d &&
                            frame_payload[63:32] <= FILE_BYTES) begin
                            expected_size  <= frame_payload[63:32];
                            expected_crc   <= frame_payload[95:64];
                            received_bytes <= 32'd0;
                            running_crc    <= 32'hffffffff;
                            file_ready     <= 1'b0;
                            last_data_valid <= 1'b0;
                            last_status    <= 2'd0;
                        end else begin
                            last_status <= 2'd1;
                        end
                    end
                    FILE_DATA: begin
                        if (frame_length >= 16'd5 && frame_length <= 16'd132 &&
                            frame_payload[31:0] == received_bytes &&
                            frame_payload[31:0] + (frame_length - 4) <= expected_size) begin
                            pending_offset <= frame_payload[31:0];
                            pending_count <= frame_length[7:0] - 8'd4;
                            pending_index <= 8'd0;
                            // 暂存区固定写满 128 字节，实际向文件 RAM 输出的字节数仍由
                            // pending_count 控制。这样避免 frame_length 参与 128 路写使能，
                            // 缩短 UART 帧长度寄存器到暂存 RAM 的时序路径。
                            for (index = 0; index < 128; index = index + 1)
                                pending_data[index] <= frame_payload[(index+4)*8 +: 8];
                            write_busy <= 1'b1;
                            last_data_valid  <= 1'b1;
                            last_data_seq    <= frame_seq;
                            last_data_offset <= frame_payload[31:0];
                            last_data_count  <= frame_length[7:0] - 8'd4;
                            last_status <= 2'd0;
                        end else if (last_data_valid && frame_seq == last_data_seq &&
                                     frame_payload[31:0] == last_data_offset &&
                                     frame_length == {8'd0, last_data_count} + 16'd4 &&
                                     received_bytes == last_data_offset + last_data_count) begin
                            // 上位机在 ACK 丢失后会用相同序号重发完整帧。上一块
                            // 已经写入 RAM 时只重新应答，不重复更新 CRC 或字节数。
                            last_status <= 2'd0;
                        end else begin
                            last_status <= 2'd1;
                        end
                    end
                    FILE_END: begin
                        if (frame_length == 16'd4 && received_bytes == expected_size &&
                            ~running_crc == frame_payload[31:0]) begin
                            file_ready <= 1'b1;
                            last_status <= 2'd0;
                        end else begin
                            file_ready <= 1'b0;
                            last_status <= 2'd2;
                        end
                    end
                    PLAY: begin
                        // PLAY 的 payload 只有一个字节（音色编号）。长度错误时
                        // 不产生延后一拍的 play_request，避免顶层误用上一次
                        // 合法请求留下的音色编号启动播放。
                        if (file_ready && frame_length == 16'd1) begin
                            play_request <= 1'b1;
                            last_status <= 2'd0;
                        end else if (file_ready) begin
                            last_status <= 2'd1;
                        end else begin
                            last_status <= 2'd3;
                        end
                    end
                    STOP: begin
                        stop_request <= 1'b1;
                        last_status <= 2'd0;
                    end
                    default: last_status <= 2'd1;
                endcase
            end
        end
    end
endmodule

`default_nettype wire
