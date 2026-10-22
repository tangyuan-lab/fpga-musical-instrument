`timescale 1ns/1ps
`default_nettype none

module tb_timbre_file_store;
    localparam integer MAX_PAYLOAD = 132;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg frame_valid = 1'b0;
    reg [7:0] frame_type = 8'd0;
    reg [15:0] frame_seq = 16'd0;
    reg [15:0] frame_length = 16'd0;
    reg [MAX_PAYLOAD*8-1:0] frame_payload = 0;
    wire timbre_ready;
    wire [1:0] last_status;
    wire [7:0] attack_step;
    wire [7:0] release_step;
    wire write_busy;
    wire wave_write_enable;
    wire [7:0] wave_write_address;
    wire signed [15:0] wave_write_data;

    reg [7:0] ftb [0:551];
    reg [31:0] crc;
    integer i;
    integer offset;
    integer chunk;
    integer write_count = 0;
    reg signed [15:0] first_sample;
    reg signed [15:0] last_sample;

    always #10 clk = ~clk;

    timbre_file_store #(.MAX_PAYLOAD(MAX_PAYLOAD)) dut (
        .clk(clk), .rst_n(rst_n), .frame_valid(frame_valid),
        .frame_type(frame_type), .frame_seq(frame_seq), .frame_length(frame_length),
        .frame_payload(frame_payload), .timbre_ready(timbre_ready),
        .last_status(last_status), .attack_step(attack_step),
        .release_step(release_step), .write_busy(write_busy),
        .wave_write_enable(wave_write_enable),
        .wave_write_address(wave_write_address), .wave_write_data(wave_write_data)
    );

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

    task automatic send_frame;
        input [7:0] kind;
        input [15:0] seq_value;
        input [15:0] length;
        begin
            @(negedge clk);
            frame_type = kind;
            frame_seq = seq_value;
            frame_length = length;
            frame_valid = 1'b1;
            @(negedge clk);
            frame_valid = 1'b0;
        end
    endtask

    always @(posedge clk) begin
        if (wave_write_enable) begin
            write_count <= write_count + 1;
            if (wave_write_address == 8'd0) first_sample <= wave_write_data;
            if (wave_write_address == 8'd255) last_sample <= wave_write_data;
        end
    end

    initial begin
        for (i = 0; i < 552; i = i + 1) ftb[i] = 8'd0;
        ftb[0] = "F"; ftb[1] = "T"; ftb[2] = "B"; ftb[3] = "1";
        ftb[4] = 8'd1; ftb[5] = 8'd8; ftb[6] = 8'd10; ftb[7] = 8'd5;
        for (i = 0; i < 256; i = i + 1) begin
            ftb[40+i*2] = i[7:0];
            ftb[41+i*2] = 8'h10;
        end
        crc = 32'hffff_ffff;
        for (i = 0; i < 552; i = i + 1) crc = crc32_next(crc, ftb[i]);
        crc = ~crc;

        repeat (4) @(negedge clk);
        rst_n = 1'b1;

        frame_payload = 0;
        frame_payload[31:0] = 32'h31425446;
        frame_payload[63:32] = 32'd552;
        frame_payload[95:64] = crc;
        send_frame(8'h20, 16'd1, 16'd12);
        repeat (2) @(negedge clk);
        if (last_status != 0) $fatal(1, "TIMBRE_BEGIN rejected");

        offset = 0;
        while (offset < 552) begin
            chunk = ((552 - offset) > 128) ? 128 : (552 - offset);
            frame_payload = 0;
            frame_payload[31:0] = offset;
            for (i = 0; i < chunk; i = i + 1)
                frame_payload[(i+4)*8 +: 8] = ftb[offset+i];
            send_frame(8'h21, 16'd2 + offset[15:7], chunk + 4);
            wait (write_busy == 1'b1);
            wait (write_busy == 1'b0);
            if (offset == 0) begin
                // 同一个数据块、同一个序号代表 ACK 丢失后的重试。
                // 重试只能重新确认，不能让 44 个波表点再写一次。
                send_frame(8'h21, 16'd2, chunk + 4);
                repeat (3) @(negedge clk);
                if (write_busy || last_status != 0 || write_count != 44)
                    $fatal(1, "duplicate FTB block rewrote wavetable");
            end
            offset = offset + chunk;
        end

        repeat (2) @(negedge clk);
        frame_payload = 0;
        frame_payload[31:0] = crc;
        send_frame(8'h22, 16'd10, 16'd4);
        repeat (2) @(negedge clk);

        if (!timbre_ready || last_status != 0) $fatal(1, "TIMBRE_COMMIT failed");
        if (attack_step != 8'd10 || release_step != 8'd5)
            $fatal(1, "ADSR parameters mismatch");
        if (write_count != 256) $fatal(1, "wavetable write count=%0d", write_count);
        if (first_sample != 16'sh1000 || last_sample != 16'sh10ff)
            $fatal(1, "wavetable endian/address mismatch first=%h last=%h", first_sample, last_sample);
        $display("PASS tb_timbre_file_store writes=%0d crc=%08x", write_count, crc);
        $finish;
    end
endmodule

`default_nettype wire
