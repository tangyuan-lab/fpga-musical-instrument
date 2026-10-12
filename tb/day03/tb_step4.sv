`timescale 1ns/1ps

module tb_step4;
    reg clk = 1'b0;
    always #10 clk = ~clk;
    reg rst_n = 1'b0;
    reg key_n = 1'b1;
    reg key2_n = 1'b1;
    wire bck, ws, din, pa_en;

    // 较短的消抖时间使功能音频测试可以在合理时间内完成。
    tang_mega_60k_top #(.KEY_FILTER_MAX(5_000)) dut (
        .sys_clk(clk), .sys_rst_n(rst_n),
        .key_n(key_n), .key2_n(key2_n),
        .HP_BCK(bck), .HP_WS(ws), .HP_DIN(din), .PA_EN(pa_en)
    );

    integer on_0 = 0;
    integer off_0 = 0;
    integer on_1 = 0;
    integer off_1 = 0;
    integer stereo_frames = 0;
    integer nonzero_frames = 0;
    integer bit_index = 0;
    integer signed expected_sum;
    reg [15:0] right_word = 16'd0;
    reg [15:0] left_word = 16'd0;
    reg test_pass = 1'b0;

    always @(posedge clk) begin
        if (dut.note_on === 1'b1) on_0 = on_0 + 1;
        if (dut.note_off === 1'b1) off_0 = off_0 + 1;
        if (dut.note_on_1 === 1'b1) on_1 = on_1 + 1;
        if (dut.note_off_1 === 1'b1) off_1 = off_1 + 1;
    end

    // 两个幅值为 4096 的声部相加不会接近 16 位削波。
    // 检查所有稳定后的采样，包括两个按键同时按下的时间段。
    always @(negedge clk) begin
        if (dut.audio_rst_n) begin
            expected_sum = $signed(dut.voice_sample_0) +
                           $signed(dut.voice_sample_1);
            if (dut.tone_sample !== expected_sum[15:0])
                $fatal(1, "Two-voice mixer changed the signed sample");
            if (dut.mixed_pcm[7:0] !== 8'd0)
                $fatal(1, "Mixer 24-bit alignment is wrong");
        end
    end

    // 解码实际的 PT8211 引脚，而不是只检查内部 PCM 信号。
    always @(posedge bck) begin
        if (dut.audio_rst_n) begin
            if (ws !== (bit_index >= 16))
                $fatal(1, "WS wrong at serial bit %0d", bit_index);
            if (bit_index < 16)
                right_word = {right_word[14:0], din};
            else
                left_word = {left_word[14:0], din};
            if (bit_index == 31) begin
                if (right_word !== left_word)
                    $fatal(1, "Left and right serialized samples differ");
                if (right_word !== dut.audio_tx.sample_hold)
                    $fatal(1, "Serial pins differ from the mixed PCM sample");
                stereo_frames = stereo_frames + 1;
                if (right_word != 16'd0)
                    nonzero_frames = nonzero_frames + 1;
            end
            bit_index = (bit_index + 1) % 32;
        end
    end

    task measure_pitch;
        input integer shortest;
        input integer longest;
        integer i;
        integer last_cross;
        integer crossings;
        reg signed [15:0] previous;
        reg signed [15:0] current;
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
                        (i - last_cross < shortest || i - last_cross > longest))
                        $fatal(1, "Unexpected sine period: %0d frames", i-last_cross);
                    last_cross = i;
                    crossings = crossings + 1;
                end
                previous = current;
            end
            if (crossings < 4)
                $fatal(1, "Too few sine periods in serial output");
        end
    endtask

    initial begin
        repeat (5) @(negedge clk);
        rst_n = 1'b1;
        wait (pa_en == 1'b0);
        repeat (100) @(posedge dut.frame_tick);
        @(negedge clk);
        if (on_0 != 0 || on_1 != 0 || nonzero_frames != 0)
            $fatal(1, "Output was not silent with both keys released");

        // 只按 S1：野火的第二个调音字，约 494 Hz。
        key2_n = 1'b0;
        repeat (5_050) @(negedge clk);
        repeat (500) @(posedge dut.frame_tick);
        @(negedge clk);
        if (on_1 != 1 || on_0 != 0 ||
            dut.adsr_gain_1 == 0 || dut.adsr_gain != 0)
            $fatal(1, "S1 did not start only the second voice");
        measure_pitch(94, 100);

        // 再按下 S2。两个包络和它们的有符号和都必须保持有效。
        key_n = 1'b0;
        repeat (5_050) @(negedge clk);
        repeat (500) @(posedge dut.frame_tick);
        @(negedge clk);
        if (on_0 != 1 || on_1 != 1 ||
            dut.adsr_gain == 0 || dut.adsr_gain_1 == 0 ||
            dut.voice_sample_0 == 0 || dut.voice_sample_1 == 0)
            $fatal(1, "Both voices were not active together");

        // 松开 S1 之后，S2 的 440 Hz 必须继续响，不能被打断。
        key2_n = 1'b1;
        repeat (5_050) @(negedge clk);
        repeat (16_000) @(posedge dut.frame_tick);
        @(negedge clk);
        if (off_1 != 1 || off_0 != 0 ||
            dut.adsr_gain_1 != 0 || dut.adsr_gain == 0)
            $fatal(1, "Releasing S1 affected the S2 voice");
        measure_pitch(106, 112);

        key_n = 1'b1;
        repeat (5_050) @(negedge clk);
        repeat (16_000) @(posedge dut.frame_tick);
        @(negedge clk);
        if (off_0 != 1 || dut.adsr_gain != 0 ||
            dut.tone_sample != 0 || nonzero_frames < 1_000)
            $fatal(1, "Both released voices did not return to silence");

        rst_n = 1'b0;
        #1;
        if (pa_en !== 1'b1 || dut.tone_sample !== 16'sd0)
            $fatal(1, "Logic reset did not mute both voices");

        test_pass = 1'b1;
        $display("PASS: S1 494 Hz, S2 440 Hz, two-voice mixing, stereo serial output and independent release");
        $finish;
    end
endmodule

