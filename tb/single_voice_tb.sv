`timescale 1ns/1ps

module single_voice_tb;
    reg clk = 1'b0;
    always #10 clk = ~clk;
    reg rst_n = 1'b0;
    reg key_n = 1'b1;
    wire bck, ws, din, pa_en;

    tang_mega_60k_top dut (
        .sys_clk(clk), .sys_rst_n(rst_n), .key_n(key_n),
        .HP_BCK(bck), .HP_WS(ws), .HP_DIN(din), .PA_EN(pa_en)
    );

    integer note_on_count = 0;
    integer note_off_count = 0;
    integer nonzero_frames = 0;
    integer stereo_frames = 0;
    integer bit_index = 0;
    reg [15:0] right_word = 16'd0;
    reg [15:0] left_word = 16'd0;
    reg [15:0] gain_before_release;
    reg test_pass = 1'b0;

    always @(posedge clk) begin
        if (dut.note_on === 1'b1) note_on_count = note_on_count + 1;
        if (dut.note_off === 1'b1) note_off_count = note_off_count + 1;
    end

    always @(negedge dut.audio_rst_n) begin
        bit_index = 0;
        right_word = 16'd0;
        left_word = 16'd0;
    end

    // 观察实际串行引脚，包括左右声道是否一致以及复位是否静音。
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
                    $fatal(1, "Left and right PCM samples differ");
                stereo_frames = stereo_frames + 1;
                if (right_word != 16'd0)
                    nonzero_frames = nonzero_frames + 1;
                if (dut.adsr_gain == 16'd0 && right_word != 16'd0)
                    $fatal(1, "Nonzero PCM while envelope is silent");
            end
            bit_index = (bit_index + 1) % 32;
        end
    end

    initial begin
        repeat (5) @(negedge clk);
        rst_n = 1'b1;
        wait (pa_en == 1'b0);
        @(negedge clk);
        if (note_on_count != 0 || dut.adsr_gain != 16'd0 || nonzero_frames != 0)
            $fatal(1, "Voice was audible without a key press");

        // 三次短促的触点抖动不能产生任何音符。
        repeat (3) begin
            key_n = 1'b0;
            repeat (5000) @(negedge clk);
            key_n = 1'b1;
            repeat (5000) @(negedge clk);
        end
        if (note_on_count != 0 || dut.key_state != 1'b0)
            $fatal(1, "Short key bounce passed the 5 ms filter");

        key_n = 1'b0;
        repeat (250_050) @(negedge clk);
        if (note_on_count != 1 || dut.key_state != 1'b1)
            $fatal(1, "Stable key press did not start the note");
        repeat (600) @(posedge dut.frame_tick);
        @(negedge clk);
        if (dut.adsr_gain < 16'd60_000 || nonzero_frames < 100)
            $fatal(1, "Attack did not produce a sustained sine wave");

        key_n = 1'b1;
        repeat (250_050) @(negedge clk);
        if (note_off_count != 1 || dut.key_state != 1'b0)
            $fatal(1, "Stable key release did not end the note");
        gain_before_release = dut.adsr_gain;
        repeat (100) @(posedge dut.frame_tick);
        @(negedge clk);
        if (dut.adsr_gain >= gain_before_release || dut.adsr_gain == 16'd0)
            $fatal(1, "Release did not gradually lower the volume");

        // 原 ADSR 的释音步长是每个 48 kHz 帧 4 个单位。
        repeat (16_000) @(posedge dut.frame_tick);
        @(negedge clk);
        if (dut.adsr_gain != 16'd0 || dut.tone_sample != 16'sd0 ||
            note_on_count != 1 || note_off_count != 1)
            $fatal(1, "Released voice did not return to silence");
        if (stereo_frames < 17_000)
            $fatal(1, "Serial stream stopped during the ADSR test");

        rst_n = 1'b0;
        #1;
        if (pa_en !== 1'b1 || dut.tone_sample !== 16'sd0)
            $fatal(1, "Logic reset did not mute the output");

        test_pass = 1'b1;
        $display("PASS: key debounce, one DDS voice, ADSR, stereo PT8211 and reset");
        $finish;
    end
endmodule

