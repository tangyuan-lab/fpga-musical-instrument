`timescale 1ns/1ps

module tb_step5;
    reg clk = 1'b0;
    always #10 clk = ~clk;
    reg rst_n = 1'b0;
    reg key_n = 1'b1;
    wire bck, ws, din, pa_en;

    tang_mega_60k_top #(.KEY_FILTER_MAX(5_000)) dut (
        .sys_clk(clk), .sys_rst_n(rst_n), .key_n(key_n),
        .HP_BCK(bck), .HP_WS(ws), .HP_DIN(din), .PA_EN(pa_en)
    );

    integer on_count = 0;
    integer off_count = 0;
    integer bit_index = 0;
    integer stereo_frames = 0;
    integer peak_level = 0;
    integer sample_magnitude;
    reg signed [16:0] expected_gain;
    reg [15:0] right_word = 16'd0;
    reg [15:0] left_word = 16'd0;
    reg [15:0] gain_before_release;
    reg test_pass = 1'b0;

    always @(posedge clk) begin
        if (dut.note_on === 1'b1) on_count = on_count + 1;
        if (dut.note_off === 1'b1) off_count = off_count + 1;
    end

    always @(posedge dut.frame_tick) begin
        #1;
        if (dut.audio_rst_n) begin
            expected_gain = $signed(dut.shaped_sample) * 2;
            if (expected_gain > 17'sd32767 ||
                expected_gain < -17'sd32768)
                $fatal(1, "Output gain would clip a sine sample");
            if (dut.tone_sample !== expected_gain[15:0])
                $fatal(1, "Output was not amplified by two");
        end
    end

    // 每一个音都从实际串行接口上观察。
    always @(posedge bck) begin
        if (dut.audio_rst_n) begin
            if (ws !== (bit_index >= 16))
                $fatal(1, "WS wrong at serial bit %0d", bit_index);
            if (bit_index < 16)
                right_word = {right_word[14:0], din};
            else
                left_word = {left_word[14:0], din};
            if (bit_index == 31) begin
                if (right_word !== left_word ||
                    right_word !== dut.audio_tx.sample_hold)
                    $fatal(1, "Serialized PCM mismatch");
                stereo_frames = stereo_frames + 1;
                sample_magnitude = $signed(right_word);
                if (sample_magnitude < 0)
                    sample_magnitude = -sample_magnitude;
                if (sample_magnitude > peak_level)
                    peak_level = sample_magnitude;
            end
            bit_index = (bit_index + 1) % 32;
        end
    end

    task measure_pitch;
        input integer shortest;
        input integer longest;
        integer i, last_cross, crossings;
        reg signed [15:0] previous, current;
        begin
            last_cross = -1;
            crossings = 0;
            previous = $signed(right_word);
            for (i = 0; i < 600; i = i + 1) begin
                @(posedge dut.frame_tick);
                @(negedge clk);
                current = $signed(right_word);
                if (previous <= 0 && current > 0) begin
                    if (last_cross >= 0 &&
                        (i-last_cross < shortest || i-last_cross > longest))
                        $fatal(1, "Wrong output pitch: period %0d frames", i-last_cross);
                    last_cross = i;
                    crossings = crossings + 1;
                end
                previous = current;
            end
            if (crossings < 4)
                $fatal(1, "Too few output periods for selected note");
        end
    endtask

    task press_note;
        input integer press_number;
        input [1:0] expected_index;
        input integer shortest;
        input integer longest;
        begin
            key_n = 1'b0;
            repeat (5_050) @(negedge clk);
            if (on_count != press_number ||
                dut.current_note_index !== expected_index)
                $fatal(1, "Press %0d selected wrong note", press_number);
            repeat (500) @(posedge dut.frame_tick);
            @(negedge clk);
            if (dut.adsr_gain < 16'd50_000)
                $fatal(1, "Press %0d did not sound", press_number);
            measure_pitch(shortest, longest);

            key_n = 1'b1;
            repeat (5_050) @(negedge clk);
            if (off_count != press_number)
                $fatal(1, "Release %0d was not detected", press_number);
            gain_before_release = dut.adsr_gain;
            repeat (100) @(posedge dut.frame_tick);
            @(negedge clk);
            if (dut.adsr_gain >= gain_before_release)
                $fatal(1, "Release %0d did not fade", press_number);
        end
    endtask

    initial begin
        repeat (5) @(negedge clk);
        rst_n = 1'b1;
        wait (pa_en == 1'b0);
        repeat (100) @(posedge dut.frame_tick);
        @(negedge clk);
        if (dut.tone_sample !== 16'sd0 || on_count != 0)
            $fatal(1, "Idle: tone=%0d gain=%0d raw=%0d on=%0d phase=%h step=%h addr=%h ar=%b idx=%b next=%b note_on=%b",
                   $signed(dut.tone_sample), dut.adsr_gain,
                   $signed(dut.raw_sample), on_count, dut.voice_0.phase_acc,
                   dut.phase_step, dut.voice_0.rom_addr, dut.audio_rst_n,
                   dut.current_note_index, dut.next_note_index, dut.note_on);

        press_note(1, 2'd0, 106, 112); // A4 440 Hz
        press_note(2, 2'd1, 94, 100);  // B4 493.88 Hz
        press_note(3, 2'd2, 89, 95);   // C5 523.25 Hz
        press_note(4, 2'd3, 79, 85);   // D5 587.33 Hz
        press_note(5, 2'd0, 106, 112); // 回绕到 A4

        repeat (16_000) @(posedge dut.frame_tick);
        @(negedge clk);
        if (dut.adsr_gain != 0 || dut.tone_sample != 0 ||
            on_count != 5 || off_count != 5 || stereo_frames < 20_000 ||
            peak_level < 7_000 || peak_level > 8_200)
            $fatal(1, "Five-press cycle did not finish in silence");

        rst_n = 1'b0;
        #1;
        if (pa_en !== 1'b1 || dut.tone_sample !== 16'sd0)
            $fatal(1, "Logic reset did not mute the output");

        test_pass = 1'b1;
        $display("PASS: S2 cycles A4/B4/C5/D5/A4, serial stereo pitch and release");
        $finish;
    end
endmodule
