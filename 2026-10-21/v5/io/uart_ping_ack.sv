`default_nettype none

// PING 的固定 ACK 回复器。
// ACK payload 为：原消息类型 01、状态 00、原样返回的 32 位 nonce。
// 每次只发送一帧，等待上一个 ACK 完成后才接收下一次 ping。
module uart_ping_ack #(
    parameter integer CLKS_PER_BIT = 434
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        ping_valid,
    input  wire [15:0] ping_seq,
    input  wire [31:0] ping_nonce,
    output wire        tx,
    output reg         tx_busy
);
    reg [15:0] seq_reg;
    reg [31:0] nonce_reg;
    reg [3:0]  byte_index;
    reg        byte_pending;
    reg        start;
    reg [7:0]  tx_data;
    wire       uart_busy;
    wire       uart_done;

    function automatic [15:0] crc16_next;
        input [15:0] crc_in;
        input [7:0]  byte_in;
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

    function automatic [15:0] ack_crc;
        input [15:0] seq;
        input [31:0] nonce;
        reg [15:0] c;
        begin
            c = 16'hffff;
            c = crc16_next(c, 8'h01);
            c = crc16_next(c, 8'h81);
            c = crc16_next(c, seq[7:0]);
            c = crc16_next(c, seq[15:8]);
            c = crc16_next(c, 8'd6);
            c = crc16_next(c, 8'd0);
            c = crc16_next(c, 8'h01);
            c = crc16_next(c, 8'h00);
            c = crc16_next(c, nonce[7:0]);
            c = crc16_next(c, nonce[15:8]);
            c = crc16_next(c, nonce[23:16]);
            c = crc16_next(c, nonce[31:24]);
            ack_crc = c;
        end
    endfunction

    wire [15:0] response_crc = ack_crc(seq_reg, nonce_reg);

    always @(*) begin
        case (byte_index)
            4'd0:  tx_data = 8'h55;
            4'd1:  tx_data = 8'haa;
            4'd2:  tx_data = 8'h01;
            4'd3:  tx_data = 8'h81;
            4'd4:  tx_data = seq_reg[7:0];
            4'd5:  tx_data = seq_reg[15:8];
            4'd6:  tx_data = 8'd6;
            4'd7:  tx_data = 8'd0;
            4'd8:  tx_data = 8'h01;
            4'd9:  tx_data = 8'h00;
            4'd10: tx_data = nonce_reg[7:0];
            4'd11: tx_data = nonce_reg[15:8];
            4'd12: tx_data = nonce_reg[23:16];
            4'd13: tx_data = nonce_reg[31:24];
            4'd14: tx_data = response_crc[7:0];
            default: tx_data = response_crc[15:8];
        endcase
    end

    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) tx_inst (
        .clk(clk), .rst_n(rst_n), .start(start), .data(tx_data),
        .tx(tx), .busy(uart_busy), .done(uart_done)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            seq_reg      <= 16'd0;
            nonce_reg    <= 32'd0;
            byte_index   <= 4'd0;
            byte_pending <= 1'b0;
            start        <= 1'b0;
            tx_busy      <= 1'b0;
        end else begin
            start <= 1'b0;

            if (ping_valid && !tx_busy) begin
                seq_reg      <= ping_seq;
                nonce_reg    <= ping_nonce;
                byte_index   <= 4'd0;
                byte_pending <= 1'b0;
                tx_busy      <= 1'b1;
            end

            if (tx_busy && !uart_busy && !byte_pending) begin
                start        <= 1'b1;
                byte_pending <= 1'b1;
            end

            if (tx_busy && uart_done) begin
                byte_pending <= 1'b0;
                if (byte_index == 4'd15) begin
                    tx_busy <= 1'b0;
                end else begin
                    byte_index <= byte_index + 1'b1;
                end
            end
        end
    end
endmodule

`default_nettype wire
