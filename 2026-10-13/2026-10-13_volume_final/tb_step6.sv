`timescale 1ns/1ps

module tb_step6;
    reg clk = 1'b0;
    always #10 clk = ~clk;
    reg rst_n = 1'b0;
    reg key_n = 1'b1;
    wire bck, ws, din, pa_en;

    tang_mega_60k_top #(.KEY_FILTER_MAX(5_000)) dut (
        .sys_clk(clk), .sys_rst_n(rst_n), .key_n(key_n),
        .HP_BCK(bck), .HP_WS(ws), .HP_DIN(din), .PA_EN(pa_en)
    );

    piano_voice soft_voice (
        .clk(clk), .rst_n(dut.audio_rst_n),
        .sample_tick(dut.frame_tick),
        .note_on(dut.note_on), .note_active(dut.key_state),
        .phase_step(dut.phase_step), .velocity(7'd32),
        .sample_out()
    );
    piano_voice hard_voice (
        .clk(clk), .rst_n(dut.audio_rst_n),
        .sample_tick(dut.frame_tick),
        .note_on(dut.note_on), .note_active(dut.key_state),
        .phase_step(dut.phase_step), .velocity(7'd127),
        .sample_out()
    );

    integer output_file;
    integer bit_index = 0;
    integer on_count = 0;
    integer off_count = 0;
    integer stereo_frames = 0;
    integer captured_frames = 0;
    integer peak_level = 0;
    integer soft_energy = 0;
    integer hard_energy = 0;
    integer energy_frames = 0;
    integer early_energy = 0;
    integer late_energy = 0;
    integer first_note_frames = 0;
    integer current_value;
    integer soft_value;
    integer hard_value;
    reg capture = 1'b0;
    reg [15:0] right_word = 16'd0;
    reg [15:0] left_word = 16'd0;
    reg test_pass = 1'b0;

    always @(posedge clk) begin
        if (dut.note_on === 1'b1) on_count = on_count + 1;
        if (dut.note_off === 1'b1) off_count = off_count + 1;
    end

    always @(posedge bck) begin
        if (dut.audio_rst_n) begin
            if (ws !== (bit_index >= 16))
                $fatal(1, "PT8211 WS wrong at bit %0d", bit_index);
            if (bit_index < 16)
                right_word = {right_word[14:0], din};
            else
                left_word = {left_word[14:0], din};
            if (bit_index == 31) begin
                if (right_word !== left_word ||
                    right_word !== dut.audio_tx.sample_hold)
                    $fatal(1, "Piano PCM differs on the two serial channels");
                stereo_frames = stereo_frames + 1;
                current_value = $signed(right_word);
                if (current_value == 32767 || current_value == -32768)
                    $fatal(1, "Output gain clipped the piano signal");
                if (current_value < 0) current_value = -current_value;
                if (current_value > peak_level) peak_level = current_value;

                if (capture) begin
                    $fwrite(output_file, "%0d %0d %0d\n",
                            dut.current_note_index, dut.key_state,
                            $signed(right_word));
                    captured_frames = captured_frames + 1;
                end

                if (dut.key_state && on_count == 1) begin
                    first_note_frames = first_note_frames + 1;
                    if (first_note_frames >= 100 && first_note_frames < 1100)
                        early_energy = early_energy + current_value;
                    if (first_note_frames >= 10_000 && first_note_frames < 11_000)
                        late_energy = late_energy + current_value;
                    if (first_note_frames >= 200 && first_note_frames < 2_200) begin
                        soft_value = $signed(soft_voice.sample_out);
                        hard_value = $signed(hard_voice.sample_out);
                        if (soft_value < 0) soft_value = -soft_value;
                        if (hard_value < 0) hard_value = -hard_value;
                        soft_energy = soft_energy + soft_value;
                        hard_energy = hard_energy + hard_value;
                        energy_frames = energy_frames + 1;
                    end
                end
            end
            bit_index = (bit_index + 1) % 32;
        end
    end

    task play_note;
        input integer press_number;
        input [1:0] expected_index;
        input [31:0] expected_step;
        input integer hold_frames;
        begin
            key_n = 1'b0;
            repeat (5_050) @(negedge clk);
            if (on_count != press_number ||
                dut.current_note_index !== expected_index ||
                dut.phase_step !== expected_step)
                $fatal(1, "S2 press %0d chose the wrong pitch", press_number);
            repeat (hold_frames) @(posedge dut.frame_tick);
            @(negedge clk);
            if (dut.voice_0.amplitude == 0 || dut.tone_sample === 16'sd0)
                $fatal(1, "Piano note %0d did not sound", press_number);

            key_n = 1'b1;
            repeat (5_050) @(negedge clk);
            if (off_count != press_number)
                $fatal(1, "S2 release %0d was not detected", press_number);
            repeat (2_000) @(posedge dut.frame_tick);
        end
    endtask

    initial begin
        output_file = $fopen("sim/piano_serial_samples.txt", "w");
        if (output_file == 0) $fatal(1, "Could not create PCM capture");
        repeat (5) @(negedge clk);
        rst_n = 1'b1;
        wait (pa_en == 1'b0);
        repeat (100) @(posedge dut.frame_tick);
        @(negedge clk);
        if (dut.tone_sample !== 16'sd0)
            $fatal(1, "Piano was not silent at idle");
        capture = 1'b1;

        play_note(1, 2'd0, 32'd39_370_534, 48_000);
        if (energy_frames != 2_000 || hard_energy <= soft_energy * 2 ||
            late_energy >= early_energy || early_energy == 0)
            $fatal(1, "Velocity/decay wrong: frames=%0d soft=%0d hard=%0d early=%0d late=%0d",
                   energy_frames, soft_energy, hard_energy,
                   early_energy, late_energy);
        play_note(2, 2'd1, 32'd44_191_930, 4_000);
        play_note(3, 2'd2, 32'd46_819_716, 4_000);
        play_note(4, 2'd3, 32'd52_553_354, 4_000);

        repeat (10_000) @(posedge dut.frame_tick);
        @(negedge clk);
        capture = 1'b0;
        if (dut.voice_0.amplitude > 24'd120_000 ||
            peak_level < (5_000 << dut.output_gain.GAIN_SHIFT) ||
            peak_level > (7_500 << dut.output_gain.GAIN_SHIFT) ||
            captured_frames < 35_000 || stereo_frames < 35_000)
            $fatal(1, "Piano release, loudness or serial stream is wrong");
        rst_n = 1'b0;
        #1;
        if (pa_en !== 1'b1 || dut.tone_sample !== 16'sd0)
            $fatal(1, "Logic reset did not mute the piano");
        $fclose(output_file);
        test_pass = 1'b1;
        $display("PASS: piano attack/decay, velocity, four audition notes, unclipped PT8211 stereo");
        $finish;
    end
endmodule

