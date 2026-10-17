`timescale 1ns/1ps
module tb_sample_store;
    reg clk = 1'b0;
    always #10 clk = ~clk;
    reg rst_n = 1'b0;
    reg key_n = 1'b1;
    wire bck, ws, din, pa_en;
    tang_mega_60k_top #(.KEY_FILTER_MAX(5_000)) dut (
        .sys_clk(clk), .sys_rst_n(rst_n), .key_n(key_n),
        .HP_BCK(bck), .HP_WS(ws), .HP_DIN(din), .PA_EN(pa_en)
    );

    integer output_file;
    integer bit_index = 0;
    integer press_count = 0;
    integer active_frames = 0;
    integer peak = 0;
    integer magnitude;
    reg [15:0] right_word = 16'd0;
    reg [15:0] left_word = 16'd0;
    reg test_pass = 1'b0;

    always @(posedge clk) begin
        if (dut.note_on) press_count = press_count + 1;
    end

    always @(posedge bck) begin
        if (dut.audio_rst_n) begin
            if (ws !== (bit_index >= 16))
                $fatal(1, "PT8211 word select mismatch");
            if (bit_index < 16)
                right_word = {right_word[14:0], din};
            else
                left_word = {left_word[14:0], din};
            if (bit_index == 31) begin
                if (right_word !== left_word ||
                    right_word !== dut.audio_tx.sample_hold)
                    $fatal(1, "PT8211 stereo PCM mismatch");
                magnitude = $signed(right_word);
                if (magnitude < 0) magnitude = -magnitude;
                if (magnitude >= 32767) $fatal(1, "PCM clipped");
                if (dut.key_state) begin
                    $fwrite(output_file, "%0d %0d\n",
                            press_count, $signed(right_word));
                    active_frames = active_frames + 1;
                    if (magnitude > peak) peak = magnitude;
                end
            end
            bit_index = (bit_index + 1) % 32;
        end
    end

    task press_and_release;
        input integer expected_count;
        input integer hold_frames;
        input integer release_frames;
        begin
            key_n = 1'b0;
            repeat (5_050) @(negedge clk);
            if (press_count != expected_count ||
                dut.sample_voice.long_tail_enable !== 1'b1)
                $fatal(1, "S2 did not select the long A4 sample");
            repeat (hold_frames) @(posedge dut.frame_tick);
            if (dut.sample_voice.elapsed_frames < (hold_frames - 100))
                $fatal(1, "Sample ROM did not advance");
            key_n = 1'b1;
            repeat (5_050) @(negedge clk);
            repeat (release_frames) @(posedge dut.frame_tick);
        end
    endtask

    initial begin
        output_file = $fopen("sim/sample_store_serial_samples.txt", "w");
        if (output_file == 0) $fatal(1, "Cannot open PCM capture");
        repeat (5) @(negedge clk);
        rst_n = 1'b1;
        wait (pa_en == 1'b0);
        repeat (100) @(posedge dut.frame_tick);
        if (dut.tone_sample !== 16'sd0) $fatal(1, "Idle PCM not zero");
        press_and_release(1, 300, 2_100);
        if (dut.sample_voice.release_level != 11'd0)
            $fatal(1, "Sample release did not fade to zero");
        press_and_release(2, 300, 100);
        press_and_release(3, 300, 2_100);
        press_and_release(4, 300, 100);
        if (active_frames < 1_000 || peak < 1_000 || peak > 5_100)
            $fatal(1, "PCM level wrong: frames=%0d peak=%0d",
                   active_frames, peak);
        rst_n = 1'b0;
        #1;
        if (pa_en !== 1'b1 || dut.tone_sample !== 16'sd0)
            $fatal(1, "Reset did not mute audio");
        $fclose(output_file);
        test_pass = 1'b1;
        $display("PASS: isolated sample store; four long A4 presses, stereo, release, reset and safe levels");
        $finish;
    end
endmodule
