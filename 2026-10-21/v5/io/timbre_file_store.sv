`default_nettype none

// FTB1 单周期音色接收器。
//
// TIMBRE_DATA 到达后先暂存最多 128 字节，再逐字节计算 CRC32、检查 FTB
// 头并写入 256x16 波表。CRC 每个时钟只处理一个字节，避免把整块 128 字节
// 展开为数百级组合逻辑。write_busy 为 1 时，上层必须推迟本帧 ACK。
module timbre_file_store #(
    parameter integer MAX_PAYLOAD = 132
) (
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire                         frame_valid,
    input  wire [7:0]                   frame_type,
    input  wire [15:0]                  frame_seq,
    input  wire [15:0]                  frame_length,
    input  wire [MAX_PAYLOAD*8-1:0]     frame_payload,
    output reg                          timbre_ready,
    output reg [1:0]                    last_status,
    output reg [7:0]                    attack_step,
    output reg [7:0]                    release_step,
    output wire                         write_busy,
    output reg                          wave_write_enable,
    output reg [7:0]                    wave_write_address,
    output reg signed [15:0]            wave_write_data
);
    localparam [7:0] TIMBRE_BEGIN  = 8'h20;
    localparam [7:0] TIMBRE_DATA   = 8'h21;
    localparam [7:0] TIMBRE_COMMIT = 8'h22;

    reg [31:0] expected_crc;
    reg [31:0] running_crc;
    reg [31:0] received_bytes;
    reg [7:0]  pending_data [0:127];
    reg [7:0]  pending_count;
    reg [7:0]  pending_index;
    reg [31:0] pending_offset;
    reg        pending_write;
    // TIMBRE_DATA 先锁存元数据，下一拍再复制 payload；这会把帧长度路径
    // 与 128 字节暂存 RAM 的写使能隔开，同时 write_busy 覆盖等待拍。
    reg        frame_accept_pending;
    reg [15:0] accepted_length;
    reg [15:0] accepted_seq;
    reg [31:0] accepted_offset;
    reg        format_error;
    reg [7:0]  low_byte;
    reg        low_valid;
    reg        last_data_valid;
    reg [15:0] last_data_seq;
    reg [31:0] last_data_offset;
    reg [7:0]  last_data_count;
    integer i;

    wire [31:0] current_byte_offset = pending_offset + pending_index;
    wire [7:0] current_byte = pending_data[pending_index];
    wire [31:0] current_wave_index = (current_byte_offset - 32'd40) >> 1;
    assign write_busy = pending_write | frame_accept_pending;

    function automatic [31:0] crc32_next;
        input [31:0] crc_in;
        input [7:0] byte_in;
        reg [31:0] c;
        integer bit_index;
        begin
            c = crc_in ^ byte_in;
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1)
                c = c[0] ? ((c >> 1) ^ 32'hedb88320) : (c >> 1);
            crc32_next = c;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            timbre_ready       <= 1'b0;
            last_status        <= 2'd0;
            attack_step        <= 8'd32;
            release_step       <= 8'd16;
            expected_crc       <= 32'd0;
            running_crc        <= 32'hffff_ffff;
            received_bytes     <= 32'd0;
            pending_count      <= 8'd0;
            pending_index      <= 8'd0;
            pending_offset     <= 32'd0;
            pending_write      <= 1'b0;
            frame_accept_pending <= 1'b0;
            accepted_length   <= 16'd0;
            accepted_seq      <= 16'd0;
            accepted_offset   <= 32'd0;
            format_error       <= 1'b0;
            low_byte           <= 8'd0;
            low_valid          <= 1'b0;
            last_data_valid    <= 1'b0;
            last_data_seq      <= 16'd0;
            last_data_offset   <= 32'd0;
            last_data_count    <= 8'd0;
            wave_write_enable  <= 1'b0;
            wave_write_address <= 8'd0;
            wave_write_data    <= 16'sd0;
        end else begin
            wave_write_enable <= 1'b0;

            if (frame_accept_pending) begin
                // frame_payload 由协议解析器保持到下一帧完成；此处只使用已锁存
                // 的元数据，避免让 RAM 写使能重新依赖输入 frame_length。
                for (i = 0; i < 128; i = i + 1)
                    pending_data[i] <= frame_payload[(i+4)*8 +: 8];
                pending_offset <= accepted_offset;
                pending_count  <= accepted_length[7:0] - 8'd4;
                pending_index  <= 8'd0;
                pending_write  <= 1'b1;
                frame_accept_pending <= 1'b0;
            end

            if (pending_write) begin
                running_crc    <= crc32_next(running_crc, current_byte);
                received_bytes <= received_bytes + 1'b1;

                // FTB 固定头："FTB1"、版本 1、256 点（log2=8）。
                case (current_byte_offset)
                    32'd0: if (current_byte != 8'h46) format_error <= 1'b1;
                    32'd1: if (current_byte != 8'h54) format_error <= 1'b1;
                    32'd2: if (current_byte != 8'h42) format_error <= 1'b1;
                    32'd3: if (current_byte != 8'h31) format_error <= 1'b1;
                    32'd4: if (current_byte != 8'd1)  format_error <= 1'b1;
                    32'd5: if (current_byte != 8'd8)  format_error <= 1'b1;
                    // 0 会使包络不再前进，因此按最小步长 1 处理。
                    32'd6: attack_step  <= (current_byte == 0) ? 8'd1 : current_byte;
                    32'd7: release_step <= (current_byte == 0) ? 8'd1 : current_byte;
                    default: begin end
                endcase

                // 波表从偏移 40 开始，采用小端 int16：先低字节、后高字节。
                if (current_byte_offset >= 32'd40 && current_byte_offset < 32'd552) begin
                    if (!low_valid) begin
                        low_byte  <= current_byte;
                        low_valid <= 1'b1;
                    end else begin
                        wave_write_enable  <= 1'b1;
                        wave_write_address <= current_wave_index[7:0];
                        wave_write_data    <= {current_byte, low_byte};
                        low_valid          <= 1'b0;
                    end
                end

                if (pending_index == pending_count - 1'b1) begin
                    pending_write <= 1'b0;
                    pending_index <= 8'd0;
                end else begin
                    pending_index <= pending_index + 1'b1;
                end
            end

            if (frame_valid && !pending_write && !frame_accept_pending) begin
                case (frame_type)
                    TIMBRE_BEGIN: begin
                        if (frame_length == 16'd12 &&
                            frame_payload[31:0] == 32'h31425446 &&
                            frame_payload[63:32] == 32'd552) begin
                            expected_crc   <= frame_payload[95:64];
                            running_crc    <= 32'hffff_ffff;
                            received_bytes <= 32'd0;
                            pending_count  <= 8'd0;
                            pending_index  <= 8'd0;
                            timbre_ready   <= 1'b0;
                            format_error   <= 1'b0;
                            low_valid      <= 1'b0;
                            last_data_valid <= 1'b0;
                            attack_step    <= 8'd32;
                            release_step   <= 8'd16;
                            last_status    <= 2'd0;
                        end else begin
                            timbre_ready <= 1'b0;
                            last_status  <= 2'd1;
                        end
                    end

                    TIMBRE_DATA: begin
                        if (frame_length >= 16'd5 && frame_length <= 16'd132 &&
                            frame_payload[31:0] == received_bytes &&
                            received_bytes + (frame_length - 16'd4) <= 32'd552) begin
                            accepted_offset <= received_bytes;
                            accepted_length <= frame_length;
                            accepted_seq    <= frame_seq;
                            frame_accept_pending <= 1'b1;
                            last_data_valid  <= 1'b1;
                            last_data_seq    <= frame_seq;
                            last_data_offset <= frame_payload[31:0];
                            last_data_count  <= frame_length[7:0] - 8'd4;
                            last_status    <= 2'd0;
                        end else if (last_data_valid && frame_seq == last_data_seq &&
                                     frame_payload[31:0] == last_data_offset &&
                                     frame_length == {8'd0, last_data_count} + 16'd4 &&
                                     received_bytes == last_data_offset + last_data_count) begin
                            // ACK 丢失后的同序号重发只重新确认，不再次写波表或 CRC。
                            last_status <= 2'd0;
                        end else begin
                            last_status <= 2'd1;
                        end
                    end

                    TIMBRE_COMMIT: begin
                        if (frame_length == 16'd4 && received_bytes == 32'd552 &&
                            !format_error && !low_valid &&
                            (~running_crc == frame_payload[31:0]) &&
                            (expected_crc == frame_payload[31:0])) begin
                            timbre_ready <= 1'b1;
                            last_status  <= 2'd0;
                        end else begin
                            timbre_ready <= 1'b0;
                            last_status  <= 2'd2;
                        end
                    end

                    default: begin end
                endcase
            end
        end
    end
endmodule

`default_nettype wire
