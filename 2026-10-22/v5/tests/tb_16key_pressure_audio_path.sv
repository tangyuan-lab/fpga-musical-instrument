`timescale 1ns/1ps
`default_nettype none

// 从 16 路 ADC 数字采样一直验证到四声部混音输出，不依赖真实 MCP3208。
module tb_16key_pressure_audio_path #(
    parameter [15:0] ACTIVE_LOW_MASK = 16'hffff
);
    localparam integer KEY_COUNT = 16;
    localparam integer ADC_BITS  = 12;

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg sample_frame_valid = 1'b0;
    reg sample_tick = 1'b0;
    reg [KEY_COUNT*ADC_BITS-1:0] adc_samples;
    wire calibrated;
    wire [KEY_COUNT*ADC_BITS-1:0] baseline_values;
    wire [KEY_COUNT*ADC_BITS-1:0] pressure_values;
    wire [KEY_COUNT*8-1:0] velocity_values;
    wire [KEY_COUNT-1:0] key_down;
    wire [KEY_COUNT-1:0] key_on_pulse;
    wire [KEY_COUNT-1:0] key_off_pulse;
    wire [4:0] active_key_count;
    wire signed [15:0] sample_out;
    wire [3:0] voice_gate;
    wire [3:0] voice_assigned;
    wire [15:0] voice_keys;
    wire [51:0] voice_levels;
    wire [31:0] timbre_blends;
    wire [127:0] voice_phase_steps;

    integer index;
    integer nonzero_count;

    always #5 clk = ~clk;

    pressure_key_matrix #(
        .KEY_COUNT(KEY_COUNT), .CALIBRATION_SAMPLES(4),
        .FILTER_SHIFT(2),
        .ACTIVE_LOW_MASK(ACTIVE_LOW_MASK)
    ) key_matrix (
        .clk(clk), .rst_n(rst_n), .adc_ready(1'b1),
        .sample_frame_valid(sample_frame_valid), .adc_samples(adc_samples),
        .calibrated(calibrated), .baseline_values(baseline_values),
        .pressure_values(pressure_values), .velocity_values(velocity_values),
        .key_down(key_down), .key_on_pulse(key_on_pulse),
        .key_off_pulse(key_off_pulse), .active_key_count(active_key_count)
    );

    poly_synth_4voice #(.KEY_COUNT(KEY_COUNT)) synth (
        .clk(clk), .rst_n(rst_n), .sample_tick(sample_tick), .timbre(1'b0),
        .key_on_pulse(key_on_pulse), .key_off_pulse(key_off_pulse),
        .velocity_values(velocity_values), .sample_out(sample_out),
        .voice_gate(voice_gate), .voice_assigned(voice_assigned),
        .voice_keys(voice_keys), .voice_levels(voice_levels),
        .timbre_blends(timbre_blends),
        .voice_phase_steps(voice_phase_steps)
    );

    task set_all_samples(input [ADC_BITS-1:0] value);
        begin
            for (index = 0; index < KEY_COUNT; index = index + 1)
                // 镜像原降压用例：升压接法松开1095、按压后增加，保持相同压力差。
                adc_samples[index*ADC_BITS +: ADC_BITS] = ACTIVE_LOW_MASK[index] ? value : 12'd4095-value;
        end
    endtask

    task set_key_sample(input integer key_number, input [ADC_BITS-1:0] value);
        begin
            adc_samples[key_number*ADC_BITS +: ADC_BITS] = ACTIVE_LOW_MASK[key_number] ? value : 12'd4095-value;
        end
    endtask

    task adc_frame;
        begin
            @(negedge clk);
            sample_frame_valid = 1'b1;
            @(negedge clk);
            sample_frame_valid = 1'b0;
            repeat (2) @(negedge clk);
        end
    endtask

    task next_audio_sample;
        begin
            @(negedge clk);
            sample_tick = 1'b1;
            @(negedge clk);
            sample_tick = 1'b0;
        end
    endtask

    initial begin
        set_all_samples(12'd3000);
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        repeat (4) adc_frame();
        if (!calibrated)
            $fatal(1, "end-to-end path did not calibrate");

        // 用四个不同的模拟压力差同时按下 C4、C#5、D5、D#5，覆盖升压和降压接法。
        set_key_sample(0,  12'd2800);
        set_key_sample(13, 12'd2750);
        set_key_sample(14, 12'd2700);
        set_key_sample(15, 12'd2600);
        repeat (12) adc_frame();
        if (active_key_count != 4 || voice_gate != 4'b1111)
            $fatal(1, "ADC-to-voice four-note allocation failed");
        if (voice_keys != 16'hfed0)
            $fatal(1, "ADC-to-voice note mapping failed: %h", voice_keys);

        if (voice_phase_steps !== {32'd54734038,32'd51662052,32'd48762484,32'd23012828})
            $fatal(1, "added sensor keys did not map to C#5/D5/D#5");
        nonzero_count = 0;
        repeat (160) begin
            next_audio_sample();
            if (sample_out != 16'sd0)
                nonzero_count = nonzero_count + 1;
        end
        if (nonzero_count < 100)
            $fatal(1, "ADC pressure did not reach polyphonic audio output");
        if (!(voice_levels[51:39] > voice_levels[38:26] &&
              voice_levels[38:26] > voice_levels[25:13] &&
              voice_levels[25:13] > voice_levels[12:0]))
            $fatal(1, "independent pressure did not control voice levels");

        // 四个传感器全部松开，滤波、迟滞和包络共同完成无卡音静音。
        set_all_samples(12'd3000);
        repeat (24) adc_frame();
        if (key_down != 16'd0 || voice_gate != 4'b0000)
            $fatal(1, "released sensors left a voice gate active");
        repeat (260) next_audio_sample();
        repeat (3) @(negedge clk);
        if (voice_assigned != 4'b0000 || sample_out != 16'sd0)
            $fatal(1, "release envelope did not return to silence");

        set_all_samples(12'd2600);
        repeat (24) adc_frame();
        if (active_key_count !== 5'd16) $fatal(1, "pressure active count overflow");
        $display("PASS tb_16key_pressure_audio_path nonzero=%0d", nonzero_count);
        $finish;
    end
endmodule

`default_nettype wire
