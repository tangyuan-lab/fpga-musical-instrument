`timescale 1ns/1ps
`default_nettype none

module tb_pressure_audio_path;
    localparam [31:0] PHASE_STEP_A4 = 32'd38_702_809;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg sample_valid = 1'b0;
    reg sample_tick = 1'b0;
    reg [12:0] adc_sample = 13'd1000;
    wire calibrated;
    wire [12:0] baseline;
    wire [12:0] pressure_drop;
    wire [11:0] pressure_value;
    wire note_gate;
    wire [12:0] volume_target;
    wire signed [15:0] sample_out;
    wire [12:0] current_level;
    integer i;
    integer magnitude;
    integer light_peak;
    integer hard_peak;

    always #5 clk = ~clk;

    pressure_control #(.CALIBRATION_SAMPLES(4)) u_control (
        .clk(clk), .rst_n(rst_n), .sample_valid(sample_valid),
        .adc_ready(1'b1), .audio_ready(1'b1), .adc_sample(adc_sample),
        .calibrated(calibrated), .baseline(baseline),
        .pressure_drop(pressure_drop), .pressure_value(pressure_value),
        .note_gate(note_gate), .volume_target(volume_target)
    );

    pressure_tone u_tone (
        .clk(clk), .rst_n(rst_n), .sample_tick(sample_tick),
        .gate(note_gate), .phase_step(PHASE_STEP_A4),
        .target_level(volume_target), .sample_out(sample_out),
        .current_level(current_level)
    );

    task adc_event(input [12:0] value);
        begin
            @(negedge clk);
            adc_sample = value;
            sample_valid = 1'b1;
            @(negedge clk);
            sample_valid = 1'b0;
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
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        repeat (4) adc_event(13'd1000);

        adc_event(13'd960); // 压力差 40，轻按。
        repeat (32) next_sample();
        light_peak = 0;
        for (i = 0; i < 128; i = i + 1) begin
            next_sample();
            magnitude = (sample_out < 0) ? -sample_out : sample_out;
            if (magnitude > light_peak)
                light_peak = magnitude;
        end

        adc_event(13'd776); // 压力差 224，重按。
        repeat (128) next_sample();
        hard_peak = 0;
        for (i = 0; i < 128; i = i + 1) begin
            next_sample();
            magnitude = (sample_out < 0) ? -sample_out : sample_out;
            if (magnitude > hard_peak)
                hard_peak = magnitude;
        end

        if (!note_gate || light_peak <= 0 || hard_peak <= light_peak * 2)
            $fatal(1, "pressure did not increase audio peak: light=%0d hard=%0d", light_peak, hard_peak);

        adc_event(13'd992); // 压力差 8，松开。
        repeat (256) next_sample();
        if (note_gate || current_level != 13'd0 || sample_out != 16'sd0)
            $fatal(1, "release path did not become silent");

        $display("PASS tb_pressure_audio_path light=%0d hard=%0d", light_peak, hard_peak);
        $finish;
    end
endmodule

`default_nettype wire
