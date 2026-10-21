`default_nettype none

// 通用二进制帧接收器，供 MIDI 文件上传和后续音色参数上传复用。
// 最大帧 payload 为 132 字节：FILE_DATA 的 4 字节偏移加最多 128 字节文件数据。
module uart_frame_protocol #(
    parameter integer MAX_PAYLOAD = 132
) (
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire [7:0]                   rx_data,
    input  wire                         rx_valid,
    output reg                          frame_valid,
    output reg                          bad_frame,
    output reg [7:0]                    frame_type,
    output reg [15:0]                   frame_seq,
    output reg [15:0]                   frame_length,
    output wire [MAX_PAYLOAD*8-1:0]     frame_payload
);
    localparam [3:0] ST_SYNC1 = 4'd0;
    localparam [3:0] ST_SYNC2 = 4'd1;
    localparam [3:0] ST_VERSION = 4'd2;
    localparam [3:0] ST_TYPE = 4'd3;
    localparam [3:0] ST_SEQ0 = 4'd4;
    localparam [3:0] ST_SEQ1 = 4'd5;
    localparam [3:0] ST_LEN0 = 4'd6;
    localparam [3:0] ST_LEN1 = 4'd7;
    localparam [3:0] ST_PAYLOAD = 4'd8;
    localparam [3:0] ST_CRC0 = 4'd9;
    localparam [3:0] ST_CRC1 = 4'd10;

    reg [3:0] state;
    reg [7:0] version_reg;
    reg [7:0] type_reg;
    reg [15:0] seq_reg;
    reg [15:0] length_reg;
    reg [15:0] remaining_reg;
    reg [15:0] crc_reg;
    reg [15:0] received_crc;
    reg oversize_reg;
    reg [15:0] payload_index;
    reg [7:0] payload_mem [0:MAX_PAYLOAD-1];
    genvar payload_bus_index;

    generate
        for (payload_bus_index = 0; payload_bus_index < MAX_PAYLOAD; payload_bus_index = payload_bus_index + 1) begin : g_payload_bus
            assign frame_payload[payload_bus_index*8 +: 8] = payload_mem[payload_bus_index];
        end
    endgenerate

    function automatic [15:0] crc16_next;
        input [15:0] crc_in;
        input [7:0] byte_in;
        reg [15:0] c;
        integer bit_index;
        begin
            c = crc_in ^ {byte_in, 8'd0};
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                if (c[15]) c = (c << 1) ^ 16'h1021;
                else       c = c << 1;
            end
            crc16_next = c;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= ST_SYNC1;
            version_reg   <= 8'd0;
            type_reg      <= 8'd0;
            seq_reg       <= 16'd0;
            length_reg    <= 16'd0;
            remaining_reg <= 16'd0;
            crc_reg       <= 16'hffff;
            received_crc  <= 16'd0;
            oversize_reg  <= 1'b0;
            payload_index <= 16'd0;
            frame_valid   <= 1'b0;
            bad_frame     <= 1'b0;
            frame_type    <= 8'd0;
            frame_seq     <= 16'd0;
            frame_length  <= 16'd0;
        end else begin
            frame_valid <= 1'b0;
            bad_frame   <= 1'b0;

            if (rx_valid) begin
                case (state)
                    ST_SYNC1: begin
                        if (rx_data == 8'h55) state <= ST_SYNC2;
                    end
                    ST_SYNC2: begin
                        if (rx_data == 8'haa) state <= ST_VERSION;
                        else if (rx_data == 8'h55) state <= ST_SYNC2;
                        else state <= ST_SYNC1;
                    end
                    ST_VERSION: begin
                        version_reg <= rx_data;
                        crc_reg <= crc16_next(16'hffff, rx_data);
                        state <= ST_TYPE;
                    end
                    ST_TYPE: begin
                        type_reg <= rx_data;
                        crc_reg <= crc16_next(crc_reg, rx_data);
                        state <= ST_SEQ0;
                    end
                    ST_SEQ0: begin
                        seq_reg[7:0] <= rx_data;
                        crc_reg <= crc16_next(crc_reg, rx_data);
                        state <= ST_SEQ1;
                    end
                    ST_SEQ1: begin
                        seq_reg[15:8] <= rx_data;
                        crc_reg <= crc16_next(crc_reg, rx_data);
                        state <= ST_LEN0;
                    end
                    ST_LEN0: begin
                        length_reg[7:0] <= rx_data;
                        crc_reg <= crc16_next(crc_reg, rx_data);
                        state <= ST_LEN1;
                    end
                    ST_LEN1: begin
                        length_reg[15:8] <= rx_data;
                        remaining_reg <= {rx_data, length_reg[7:0]};
                        crc_reg <= crc16_next(crc_reg, rx_data);
                        oversize_reg <= ({rx_data, length_reg[7:0]} > MAX_PAYLOAD);
                        payload_index <= 16'd0;
                        if ({rx_data, length_reg[7:0]} == 16'd0) state <= ST_CRC0;
                        else state <= ST_PAYLOAD;
                    end
                    ST_PAYLOAD: begin
                        crc_reg <= crc16_next(crc_reg, rx_data);
                        if (payload_index < MAX_PAYLOAD)
                            payload_mem[payload_index] <= rx_data;
                        payload_index <= payload_index + 1'b1;
                        if (remaining_reg == 16'd1) begin
                            remaining_reg <= 16'd0;
                            state <= ST_CRC0;
                        end else begin
                            remaining_reg <= remaining_reg - 1'b1;
                        end
                    end
                    ST_CRC0: begin
                        received_crc[7:0] <= rx_data;
                        state <= ST_CRC1;
                    end
                    ST_CRC1: begin
                        received_crc[15:8] <= rx_data;
                        state <= ST_SYNC1;
                        if (!oversize_reg && version_reg == 8'd1 &&
                            {rx_data, received_crc[7:0]} == crc_reg) begin
                            frame_valid  <= 1'b1;
                            frame_type   <= type_reg;
                            frame_seq    <= seq_reg;
                            frame_length <= length_reg;
                        end else begin
                            bad_frame <= 1'b1;
                        end
                    end
                    default: state <= ST_SYNC1;
                endcase
            end
        end
    end
endmodule

`default_nettype wire
