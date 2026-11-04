`timescale 1ns/1ps
module tb_retrigger;
    reg clk = 1'b0;
    always #5 clk = ~clk;
    reg rst_n = 1'b0;
    reg note_on = 1'b0;
    reg note_active = 1'b0;
    reg [4:0] divider = 5'd0;
    always @(posedge clk) divider <= divider + 5'd1;
    wire sample_tick = (divider == 5'd31);
    wire signed [15:0] pcm;
    reg test_pass = 1'b0;
    integer i, magnitude, prior, delta, max_jump;

    sampled_piano_a4 dut (
        .clk(clk), .rst_n(rst_n), .sample_tick(sample_tick),
        .note_on(note_on), .note_active(note_active),
        .long_tail_enable(1'b1), .sample_out(pcm)
    );

    task next_frame;
        begin
            @(posedge sample_tick);
            @(negedge clk);
        end
    endtask

    initial begin
        repeat (5) @(negedge clk);
        rst_n = 1'b1;
        note_active = 1'b1;
        note_on = 1'b1;
        @(negedge clk);
        note_on = 1'b0;
        if (dut.restart_phase !== 6'd0)
            $fatal(1, "First strike from silence was crossfaded");
        repeat (300) next_frame();
        note_active = 1'b0;
        repeat (120) next_frame();
        magnitude = pcm;
        if (magnitude < 0) magnitude = -magnitude;
        for (i = 0; i < 200 && magnitude < 500; i = i + 1) begin
            next_frame();
            magnitude = pcm;
            if (magnitude < 0) magnitude = -magnitude;
        end
        if (magnitude < 500)
            $fatal(1, "Could not exercise a nonzero rapid retrigger");

        prior = pcm;
        note_active = 1'b1;
        note_on = 1'b1;
        @(negedge clk);
        note_on = 1'b0;
        if (dut.restart_phase !== 6'd32 || pcm !== prior)
            $fatal(1, "Retrigger failed to hold the previous output");
        max_jump = 0;
        for (i = 0; i < 40; i = i + 1) begin
            next_frame();
            delta = pcm - prior;
            if (delta < 0) delta = -delta;
            if (delta > max_jump) max_jump = delta;
            prior = pcm;
            magnitude = pcm;
            if (magnitude < 0) magnitude = -magnitude;
            if (magnitude > 5_100)
                $fatal(1, "Retrigger PCM exceeded accepted peak");
        end
        if (dut.restart_phase !== 6'd0 || max_jump > 800)
            $fatal(1, "Rapid retrigger transition too sharp: %0d", max_jump);
        rst_n = 1'b0;
        #1;
        if (pcm !== 16'sd0) $fatal(1, "Reset did not mute");
        test_pass = 1'b1;
        $display("PASS: silent first strike, rapid retrigger held and crossfaded; maximum frame jump %0d", max_jump);
        $finish;
    end
endmodule
