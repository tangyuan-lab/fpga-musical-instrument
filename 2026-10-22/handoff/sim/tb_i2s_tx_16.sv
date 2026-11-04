`timescale 1ns/1ps
module tb_i2s_tx_16;
    reg clk = 0;
    always #10 clk = ~clk;
    reg rst_n = 0;
    reg signed [15:0] sample_in = 16'sh1234;
    wire bck, ws, din, frame_tick;
    integer bit_index = 0, frames = 0;
    reg [15:0] left_word = 0, right_word = 0;
    i2s_tx_16 dut (
        .clk(clk), .rst_n(rst_n), .sample_in(sample_in),
        .bck(bck), .ws(ws), .din(din), .frame_tick(frame_tick)
    );
    always @(posedge bck) if (rst_n) begin
        if (ws !== (bit_index >= 32)) $fatal(1, "WS wrong at %0d", bit_index);
        if (bit_index == 0 || bit_index == 32) begin
            if (din !== 0) $fatal(1, "missing I2S one-bit delay");
        end else if (bit_index >= 1 && bit_index <= 16)
            left_word = {left_word[14:0], din};
        else if (bit_index >= 33 && bit_index <= 48)
            right_word = {right_word[14:0], din};
        else if (din !== 0) $fatal(1, "I2S pad bit is nonzero");
        if (bit_index == 63) begin
            if (left_word !== dut.sample_hold || right_word !== left_word)
                $fatal(1, "I2S stereo sample mismatch frame %0d", frames);
            frames = frames + 1;
        end
        bit_index = (bit_index + 1) % 64;
    end
    initial begin
        repeat (8) @(negedge clk);
        rst_n = 1;
        // Sample the combinational clock-enable on clk; delta-cycle edges can double-count.
        repeat (200) begin @(posedge clk); while (!frame_tick) @(posedge clk); end
        sample_in = -16'sd12345;
        repeat (200) begin @(posedge clk); while (!frame_tick) @(posedge clk); end
        if (frames < 399) $fatal(1, "lost I2S frames");
        $display("PASS I2S stereo framing, one-bit WS delay, 16-bit data, 48 kHz accumulator");
        $finish;
    end
endmodule
