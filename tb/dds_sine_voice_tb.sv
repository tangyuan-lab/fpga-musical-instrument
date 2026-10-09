`timescale 1ns/1ps

module dds_sine_voice_tb;
    reg clk = 1'b0;
    always #10 clk = ~clk;
    reg rst_n = 1'b0;
    wire bck, ws, din, frame_tick;
    wire signed [15:0] sample;

    dds_sine_voice voice (
        .clk(clk), .rst_n(rst_n),
        .sample_tick(frame_tick), .sample_out(sample)
    );
    pt8211_tx tx (
        .clk(clk), .rst_n(rst_n), .sample_in(sample),
        .bck(bck), .ws(ws), .din(din), .frame_tick(frame_tick)
    );

    reg [15:0] source_sine [0:4095];
    reg [31:0] expected_phase = 32'd0;
    reg [15:0] expected_word;
    integer frame_no;
    integer bit_no;
    integer sample_value;
    integer min_sample = 32767;
    integer max_sample = -32768;
    integer previous_sample = 0;
    integer last_zero_cross = -1;
    integer zero_cross_count = 0;
    time last_bck_rise = 0;
    time frame_time [0:2];
    reg test_pass = 1'b0;

    initial begin
        $readmemh("../rtl/mem/sine_4096x16.ver", source_sine);
        repeat (5) @(negedge clk);
        rst_n = 1'b1;

        for (frame_no = 0; frame_no < 1600; frame_no = frame_no + 1) begin
            expected_word = source_sine[expected_phase[31:20]];
            sample_value = $signed(expected_word);
            if (sample_value < min_sample) min_sample = sample_value;
            if (sample_value > max_sample) max_sample = sample_value;
            if (previous_sample < 0 && sample_value >= 0) begin
                if (last_zero_cross >= 0 &&
                    (frame_no - last_zero_cross < 109 ||
                     frame_no - last_zero_cross > 110))
                    $fatal(1, "DDS pitch period wrong at frame %0d", frame_no);
                last_zero_cross = frame_no;
                zero_cross_count = zero_cross_count + 1;
            end
            previous_sample = sample_value;

            for (bit_no = 0; bit_no < 32; bit_no = bit_no + 1) begin
                @(posedge bck);
                if (last_bck_rise != 0 &&
                    $time - last_bck_rise != 640 &&
                    $time - last_bck_rise != 660)
                    $fatal(1, "Fractional BCK period wrong at frame %0d", frame_no);
                last_bck_rise = $time;
                if (bit_no == 0) begin
                    if (frame_no >= 3 &&
                        $time - frame_time[frame_no % 3] != 62500)
                        $fatal(1, "Three frames must last exactly 3125 clocks");
                    frame_time[frame_no % 3] = $time;
                end
                if (ws !== (bit_no >= 16))
                    $fatal(1, "WS wrong at frame %0d bit %0d", frame_no, bit_no);
                if (din !== expected_word[15 - (bit_no % 16)])
                    $fatal(1, "DIN wrong at frame %0d bit %0d", frame_no, bit_no);
            end
            expected_phase = expected_phase + 32'd39370534;
        end

        if (max_sample < 4000 || min_sample > -4000 ||
            zero_cross_count < 12 || zero_cross_count > 15)
            $fatal(1, "Sine level or 440 Hz frequency wrong");
        rst_n = 1'b0;
        #1;
        if (sample !== 16'sd0)
            $fatal(1, "Reset did not mute the sample");
        test_pass = 1'b1;
        $display("PASS: 48 kHz DDS sine and PT8211 serial output");
        $finish;
    end
endmodule

