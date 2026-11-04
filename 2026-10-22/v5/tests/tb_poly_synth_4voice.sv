`timescale 1ns/1ps
`default_nettype none

module tb_poly_synth_4voice;
    localparam integer KEY_COUNT = 13;

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg sample_tick = 1'b0;
    reg timbre = 1'b0;
    reg [KEY_COUNT-1:0] key_on_pulse = {KEY_COUNT{1'b0}};
    reg [KEY_COUNT-1:0] key_off_pulse = {KEY_COUNT{1'b0}};
    reg [KEY_COUNT*8-1:0] velocity_values = {(KEY_COUNT*8){1'b0}};
    wire signed [15:0] sample_out;
    wire [3:0] voice_gate;
    wire [3:0] voice_assigned;
    wire [15:0] voice_keys;
    wire [51:0] voice_levels;
    wire [31:0] timbre_blends;
    wire [127:0] voice_phase_steps;

    integer sample_index;
    integer nonzero_samples;
    integer magnitude;
    integer peak;

    always #5 clk = ~clk;

    poly_synth_4voice dut (
        .clk(clk), .rst_n(rst_n), .sample_tick(sample_tick), .timbre(timbre),
        .key_on_pulse(key_on_pulse), .key_off_pulse(key_off_pulse),
        .velocity_values(velocity_values), .sample_out(sample_out),
        .voice_gate(voice_gate), .voice_assigned(voice_assigned),
        .voice_keys(voice_keys), .voice_levels(voice_levels),
        .timbre_blends(timbre_blends),
        .voice_phase_steps(voice_phase_steps)
    );

    task set_velocity(input integer key_number, input [7:0] velocity);
        begin
            velocity_values[key_number*8 +: 8] = velocity;
        end
    endtask

    task pulse_keys_on(input [KEY_COUNT-1:0] keys);
        begin
            @(negedge clk);
            key_on_pulse = keys;
            @(negedge clk);
            key_on_pulse = {KEY_COUNT{1'b0}};
            repeat (6) @(negedge clk); // 同拍四键在四个系统时钟内依次处理。
        end
    endtask

    task pulse_keys_off(input [KEY_COUNT-1:0] keys);
        begin
            @(negedge clk);
            key_off_pulse = keys;
            @(negedge clk);
            key_off_pulse = {KEY_COUNT{1'b0}};
        end
    endtask

    task next_sample;
        begin
            @(negedge clk);
            sample_tick = 1'b1;
            @(negedge clk);
            sample_tick = 1'b0;
        end
    endtask

    initial begin
        set_velocity(0,  8'd160);
        set_velocity(2,  8'd180);
        set_velocity(4,  8'd200);
        set_velocity(5,  8'd190);
        set_velocity(7,  8'd220);
        set_velocity(12, 8'd255);

        repeat (3) @(posedge clk);
        rst_n = 1'b1;

        // C4、E4、G4、C5 同时按下，形成四声部 C 大三和弦加高八度根音。
        pulse_keys_on(13'b1_0000_1001_0001);
        if (voice_gate != 4'b1111 || voice_assigned != 4'b1111)
            $fatal(1, "four simultaneous notes were not allocated");
        if (voice_keys != 16'hc740)
            $fatal(1, "unexpected voice order: %h", voice_keys);
        if (voice_phase_steps[31:0] != 32'd23_012_828 ||
            voice_phase_steps[127:96] != 32'd46_025_656)
            $fatal(1, "C4/C5 phase-step lookup failed");
        if (voice_phase_steps[127:96] != voice_phase_steps[31:0] * 2)
            $fatal(1, "octave phase-step ratio is not exactly 2:1");

        nonzero_samples = 0;
        peak = 0;
        for (sample_index = 0; sample_index < 160; sample_index = sample_index + 1) begin
            next_sample();
            magnitude = (sample_out < 0) ? -sample_out : sample_out;
            if (magnitude != 0)
                nonzero_samples = nonzero_samples + 1;
            if (magnitude > peak)
                peak = magnitude;
            if (magnitude > 32767)
                $fatal(1, "mixed sample overflowed: %0d", sample_out);
        end
        if (nonzero_samples < 100 || peak < 500)
            $fatal(1, "polyphonic mixer did not produce an audible waveform");

        // 切到第二种音色再切回，四个声部必须同步完成交叉淡化。
        timbre = 1'b1;
        repeat (32) next_sample();
        if (timbre_blends != 32'hffff_ffff)
            $fatal(1, "square-wave timbre crossfade did not finish: %h", timbre_blends);
        timbre = 1'b0;
        repeat (32) next_sample();
        if (timbre_blends != 32'h0000_0000)
            $fatal(1, "triangle-wave timbre crossfade did not return: %h", timbre_blends);

        // 第五键 D4 到来时四个声部均忙，轮询策略应替换 voice 0。
        pulse_keys_on(13'b0_0000_0000_0100);
        if (voice_keys[3:0] != 4'd2 || !voice_gate[0])
            $fatal(1, "fifth-note voice stealing failed: keys=%h", voice_keys);

        // 松开 E4，仅它所属的 voice 1 进入释音，其他三个继续发声。
        pulse_keys_off(13'b0_0000_0001_0000);
        if (voice_gate[1] || !voice_gate[0] || !voice_gate[2] || !voice_gate[3])
            $fatal(1, "independent note-off disturbed another voice");
        repeat (260) next_sample();
        repeat (3) @(negedge clk);
        if (voice_assigned[1])
            $fatal(1, "released voice was not reclaimed after envelope reached zero");

        // 新的 F4 应使用刚回收的 voice 1，而不是抢占仍在发声的声部。
        pulse_keys_on(13'b0_0000_0010_0000);
        if (!voice_gate[1] || voice_keys[7:4] != 4'd5)
            $fatal(1, "free voice was not reused for F4");

        // 松开当前四个实际声部，最终必须完全静音。
        pulse_keys_off(13'b1_0000_1010_0100); // C5、G4、F4、D4
        repeat (260) next_sample();
        repeat (3) @(negedge clk);
        if (voice_gate != 4'b0000 || voice_assigned != 4'b0000 || sample_out != 16'sd0)
            $fatal(1, "all-note release did not reach silence");

        $display("PASS tb_poly_synth_4voice peak=%0d", peak);
        $finish;
    end
endmodule

`default_nettype wire
