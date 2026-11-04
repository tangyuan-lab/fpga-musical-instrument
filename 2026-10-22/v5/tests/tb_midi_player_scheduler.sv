`timescale 1ns/1ps
`default_nettype none

module tb_midi_player_scheduler;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg sample_tick = 1'b0;
    reg start = 1'b0;
    reg stop = 1'b0;
    wire [8:0] event_read_index;
    reg [31:0] event_start [0:2];
    reg [31:0] event_end [0:2];
    reg [6:0] event_notes [0:2];
    reg [7:0] event_velocities [0:2];
    wire [31:0] event_start_tick = event_start[event_read_index];
    wire [31:0] event_end_tick = event_end[event_read_index];
    wire [6:0] event_note = event_notes[event_read_index];
    wire [7:0] event_velocity = event_velocities[event_read_index];
    wire [5:0] tempo_read_index;
    wire note_on_valid;
    wire [6:0] note_on_note;
    wire [7:0] note_on_velocity;
    wire note_off_valid;
    wire [6:0] note_off_note;
    wire playing;
    wire finished;
    wire [7:0] current_voice_count;
    integer on_count = 0;
    integer off_count = 0;
    reg [127:0] seen_on = 0;
    integer cycles;

    always #10 clk = ~clk;
    always @(posedge clk) begin
        sample_tick <= ~sample_tick;
        if (note_on_valid) begin
            on_count <= on_count + 1;
            if (seen_on[note_on_note]) $fatal(1, "duplicate Note On %0d", note_on_note);
            seen_on[note_on_note] <= 1'b1;
        end
        if (note_off_valid) off_count <= off_count + 1;
    end

    midi_player_scheduler #(.SAMPLE_RATE(1000)) dut (
        .clk(clk), .rst_n(rst_n), .sample_tick(sample_tick), .start(start), .stop(stop),
        .parser_ready(1'b1), .division_ppqn(16'd480), .event_count(9'd3),
        .event_read_index(event_read_index), .event_start_tick(event_start_tick),
        .event_end_tick(event_end_tick), .event_note(event_note), .event_velocity(event_velocity),
        .tempo_count(6'd1), .tempo_read_index(tempo_read_index),
        .tempo_tick(32'd0), .tempo_us_per_quarter(24'd500000),
        .note_on_valid(note_on_valid), .note_on_note(note_on_note),
        .note_on_velocity(note_on_velocity), .note_off_valid(note_off_valid),
        .note_off_note(note_off_note), .playing(playing), .finished(finished),
        .current_voice_count(current_voice_count)
    );

    initial begin
        event_start[0] = 0; event_end[0] = 10; event_notes[0] = 60; event_velocities[0] = 100;
        event_start[1] = 0; event_end[1] = 10; event_notes[1] = 64; event_velocities[1] = 90;
        event_start[2] = 5; event_end[2] = 12; event_notes[2] = 67; event_velocities[2] = 80;
        repeat (4) @(negedge clk);
        rst_n = 1'b1;
        @(negedge clk); start = 1'b1;
        @(negedge clk); start = 1'b0;
        cycles = 0;
        while (!finished && cycles < 2500) begin
            @(negedge clk);
            cycles = cycles + 1;
        end
        if (!finished) $fatal(1, "scheduler did not finish");
        if (on_count != 3 || seen_on[60] != 1 || seen_on[64] != 1 || seen_on[67] != 1)
            $fatal(1, "Note On sequence failed count=%0d", on_count);
        if (off_count != 3) $fatal(1, "Note Off count=%0d", off_count);
        if (current_voice_count != 0) $fatal(1, "voice count did not return to zero");
        $display("PASS tb_midi_player_scheduler on=%0d off=%0d cycles=%0d", on_count, off_count, cycles);
        $finish;
    end
endmodule

`default_nettype wire
