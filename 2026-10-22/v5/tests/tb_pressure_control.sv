`timescale 1ns/1ps
`default_nettype none

module tb_pressure_control;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg sample_valid = 1'b0;
    reg adc_ready = 1'b1;
    reg audio_ready = 1'b1;
    reg [12:0] adc_sample = 13'd1000;
    wire calibrated;
    wire [12:0] baseline;
    wire [12:0] pressure_drop;
    wire [11:0] pressure_value;
    wire note_gate;
    wire [12:0] volume_target;

    always #5 clk = ~clk;

    pressure_control #(.CALIBRATION_SAMPLES(4)) dut (
        .clk(clk), .rst_n(rst_n), .sample_valid(sample_valid),
        .adc_ready(adc_ready), .audio_ready(audio_ready),
        .adc_sample(adc_sample), .calibrated(calibrated),
        .baseline(baseline), .pressure_drop(pressure_drop),
        .pressure_value(pressure_value), .note_gate(note_gate),
        .volume_target(volume_target)
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

    initial begin
        repeat (3) @(posedge clk);
        rst_n = 1'b1;

        repeat (4) adc_event(13'd1000);
        if (!calibrated || baseline != 13'd1000)
            $fatal(1, "baseline calibration failed: calibrated=%0b baseline=%0d", calibrated, baseline);

        adc_event(13'd985); // 压力差 15，尚未达到触发阈值。
        if (note_gate || volume_target != 13'd0)
            $fatal(1, "gate asserted below PRESS_ON");

        adc_event(13'd984); // 压力差 16，进入发声状态但映射音量从 0 起步。
        if (!note_gate || pressure_drop != 13'd16)
            $fatal(1, "gate did not assert at PRESS_ON");

        adc_event(13'd976); // 压力差 24，(24-16)*315/16=157。
        if (!note_gate || volume_target != 13'd157)
            $fatal(1, "light pressure mapping mismatch: %0d", volume_target);

        adc_event(13'd800); // 压力差 200。
        if (volume_target != 13'd3622)
            $fatal(1, "medium pressure mapping mismatch: %0d", volume_target);

        adc_event(13'd776); // 压力差 224，达到安全音量上限。
        if (volume_target != 13'd4096)
            $fatal(1, "full pressure did not clamp to 4096: %0d", volume_target);

        adc_event(13'd987); // 压力差 13，位于迟滞区，门控应保持。
        if (!note_gate)
            $fatal(1, "hysteresis did not hold gate");

        adc_event(13'd992); // 压力差 8，释放。
        if (note_gate || volume_target != 13'd0)
            $fatal(1, "gate did not release at PRESS_OFF");

        $display("PASS tb_pressure_control");
        $finish;
    end
endmodule

`default_nettype wire
