`timescale 1ns/1ps
module tb_piano_long_tail;
    reg clk = 1'b0;
    always #5 clk = ~clk;
    reg rst_n = 1'b0;
    reg note_on = 1'b0;
    reg note_active = 1'b0;
    wire signed [15:0] short_pcm, long_pcm;
    reg test_pass = 1'b0;
    integer frame_no;
    integer long_tail_energy = 0;
    integer late_tail_energy = 0;
    integer prior_long = 0;
    integer delta;
    integer max_boundary_delta = 0;

    sampled_piano_a4 short_voice (
        .clk(clk), .rst_n(rst_n), .sample_tick(1'b1),
        .note_on(note_on), .note_active(note_active),
        .long_tail_enable(1'b0), .sample_out(short_pcm)
    );
    sampled_piano_a4 long_voice (
        .clk(clk), .rst_n(rst_n), .sample_tick(1'b1),
        .note_on(note_on), .note_active(note_active),
        .long_tail_enable(1'b1), .sample_out(long_pcm)
    );

    initial begin
        repeat (5) @(negedge clk);
        rst_n = 1'b1;
        note_active = 1'b1;
        note_on = 1'b1;
        @(negedge clk);
        note_on = 1'b0;
        for (frame_no = 0; frame_no < 192_100; frame_no = frame_no + 1) begin
            @(negedge clk);
            if (frame_no < 67_900 && short_pcm !== long_pcm)
                $fatal(1, "Accepted attack changed at frame %0d", frame_no);
            if (frame_no > 72_020 && short_pcm !== 16'sd0)
                $fatal(1, "Short mode continued after 1.5 s");
            if (frame_no >= 80_000 && frame_no < 100_000) begin
                if (long_pcm < 0) long_tail_energy -= long_pcm;
                else long_tail_energy += long_pcm;
            end
            if (frame_no >= 170_000 && frame_no < 185_000) begin
                if (long_pcm < 0) late_tail_energy -= long_pcm;
                else late_tail_energy += long_pcm;
            end
            if (frame_no >= 67_900 && frame_no <= 72_020) begin
                delta = long_pcm - prior_long;
                if (delta < 0) delta = -delta;
                if (delta > max_boundary_delta) max_boundary_delta = delta;
            end
            prior_long = long_pcm;
        end
        if (long_tail_energy < 100_000 ||
            late_tail_energy < 10_000 ||
            max_boundary_delta > 800 ||
            long_pcm !== 16'sd0)
            $fatal(1, "Long tail invalid: energy=%0d late=%0d jump=%0d end=%0d",
                   long_tail_energy, late_tail_energy,
                   max_boundary_delta, long_pcm);

        note_active = 1'b0;
        repeat (2_100) @(negedge clk);
        if (long_voice.release_level !== 11'd0 ||
            short_voice.release_level !== 11'd0 ||
            long_pcm !== 16'sd0)
            $fatal(1, "Release did not mute");

        note_active = 1'b1;
        note_on = 1'b1;
        @(negedge clk);
        note_on = 1'b0;
        repeat (50) @(negedge clk);
        if (long_voice.elapsed_frames < 18'd45 ||
            long_voice.tail_index !== 16'd0)
            $fatal(1, "Retrigger did not restart recording");
        rst_n = 1'b0;
        #1;
        if (long_pcm !== 16'sd0 || short_pcm !== 16'sd0)
            $fatal(1, "Reset did not mute");
        test_pass = 1'b1;
        $display("PASS: identical accepted attack, quiet 4 s tail, smooth join, release and retrigger");
        $finish;
    end
endmodule
