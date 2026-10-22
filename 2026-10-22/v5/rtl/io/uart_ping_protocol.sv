`default_nettype none

// 第一阶段的最小二进制协议接收器。
// 帧格式：55 AA | version | type | seq[15:0] | len[15:0] |
// payload[len] | crc16[15:0]，多字节字段均为小端序。
// CRC-CCITT 初值为 FFFF，覆盖 version 到 payload，不覆盖同步字。
// 当前只接受 type=01、length=4 的 PING；其余帧统一报告 bad_frame。
module uart_ping_protocol (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [7:0]  rx_data,
    input  wire        rx_valid,
    output reg         ping_valid,
    output reg [15:0]  ping_seq,
    output reg [31:0]  ping_nonce,
    output reg         bad_frame
);
    localparam [3:0] ST_SYNC_1 = 4'd0;
    localparam [3:0] ST_SYNC_2 = 4'd1;
    localparam [3:0] ST_VERSION = 4'd2;
    localparam [3:0] ST_TYPE = 4'd3;
    localparam [3:0] ST_SEQ0 = 4'd4;
    localparam [3:0] ST_SEQ1 = 4'd5;
    localparam [3:0] ST_LEN0 = 4'd6;
    localparam [3:0] ST_LEN1 = 4'd7;
    localparam [3:0] ST_PAYLOAD = 4'd8;
    localparam [3:0] ST_CRC0 = 4'd9;
    localparam [3:0] ST_CRC1 = 4'd10;

    reg [3:0]  state;
    reg [7:0]  version_reg;
    reg [7:0]  type_reg;
    reg [15:0] seq_reg;
    reg [15:0] length_reg;
    reg [15:0] remaining_reg;
    reg [15:0] crc_reg;
    reg [15:0] received_crc;
    reg [31:0] nonce_reg;
    reg        oversize_reg;
    reg [1:0]  payload_index;

    function automatic [15:0] crc16_next;
        input [15:0] crc_in;
        input [7:0]  byte_in;
        reg [15:0] c;
        integer bit_index;
        begin
            c = crc_in ^ {byte_in, 8'd0};
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                if (c[15])
                    c = (c << 1) ^ 16'h1021;
                else
                    c = c << 1;
            end
            crc16_next = c;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= ST_SYNC_1;
            version_reg   <= 8'd0;
            type_reg      <= 8'd0;
            seq_reg       <= 16'd0;
            length_reg    <= 16'd0;
            remaining_reg <= 16'd0;
            crc_reg       <= 16'hffff;
            received_crc  <= 16'd0;
            nonce_reg     <= 32'd0;
            oversize_reg  <= 1'b0;
            payload_index <= 2'd0;
            ping_valid    <= 1'b0;
            ping_seq      <= 16'd0;
            ping_nonce    <= 32'd0;
            bad_frame     <= 1'b0;
        end else begin
            ping_valid <= 1'b0;
            bad_frame  <= 1'b0;

            if (rx_valid) begin
                case (state)
                    ST_SYNC_1: begin
                        if (rx_data == 8'h55)
                            state <= ST_SYNC_2;
                    end

                    ST_SYNC_2: begin
                        if (rx_data == 8'haa)
                            state <= ST_VERSION;
                        else if (rx_data == 8'h55)
                            state <= ST_SYNC_2;
                        else
                            state <= ST_SYNC_1;
                    end

                    ST_VERSION: begin
                        version_reg <= rx_data;
                        crc_reg     <= crc16_next(16'hffff, rx_data);
                        state       <= ST_TYPE;
                    end

                    ST_TYPE: begin
                        type_reg <= rx_data;
                        crc_reg  <= crc16_next(crc_reg, rx_data);
                        state    <= ST_SEQ0;
                    end

                    ST_SEQ0: begin
                        seq_reg[7:0] <= rx_data;
                        crc_reg      <= crc16_next(crc_reg, rx_data);
                        state        <= ST_SEQ1;
                    end

                    ST_SEQ1: begin
                        seq_reg[15:8] <= rx_data;
                        crc_reg        <= crc16_next(crc_reg, rx_data);
                        state          <= ST_LEN0;
                    end

                    ST_LEN0: begin
                        length_reg[7:0] <= rx_data;
                        crc_reg         <= crc16_next(crc_reg, rx_data);
                        state           <= ST_LEN1;
                    end

                    ST_LEN1: begin
                        length_reg[15:8]    <= rx_data;
                        remaining_reg       <= {rx_data, length_reg[7:0]};
                        crc_reg             <= crc16_next(crc_reg, rx_data);
                        oversize_reg        <= ({rx_data, length_reg[7:0]} > 16'd4);
                        payload_index       <= 2'd0;
                        if ({rx_data, length_reg[7:0]} == 16'd0)
                            state <= ST_CRC0;
                        else
                            state <= ST_PAYLOAD;
                    end

                    ST_PAYLOAD: begin
                        crc_reg <= crc16_next(crc_reg, rx_data);
                        if (payload_index < 4)
                            nonce_reg[payload_index*8 +: 8] <= rx_data;
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
                        state              <= ST_CRC1;
                    end

                    ST_CRC1: begin
                        received_crc[15:8] <= rx_data;
                        state              <= ST_SYNC_1;
                        if (!oversize_reg &&
                            version_reg == 8'd1 &&
                            type_reg == 8'h01 &&
                            length_reg == 16'd4 &&
                            {rx_data, received_crc[7:0]} == crc_reg) begin
                            ping_valid <= 1'b1;
                            ping_seq   <= seq_reg;
                            ping_nonce <= nonce_reg;
                        end else begin
                            bad_frame <= 1'b1;
                        end
                    end

                    default: state <= ST_SYNC_1;
                endcase
            end
        end
    end
endmodule

`default_nettype wire
