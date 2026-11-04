`timescale 1ns/1ps
`default_nettype none

module tb_pressure_key_matrix;
    localparam integer KEY_COUNT = 13;
    localparam integer ADC_BITS  = 12;

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg adc_ready = 1'b1;
    reg sample_frame_valid = 1'b0;
    reg [KEY_COUNT*ADC_BITS-1:0] adc_samples;

    wire calibrated;
    wire [KEY_COUNT*ADC_BITS-1:0] baseline_values;
    wire [KEY_COUNT*ADC_BITS-1:0] pressure_values;
    wire [KEY_COUNT*8-1:0] velocity_values;
    wire [KEY_COUNT-1:0] key_down;
    wire [KEY_COUNT-1:0] key_on_pulse;
    wire [KEY_COUNT-1:0] key_off_pulse;
    wire [$clog2(KEY_COUNT+1)-1:0] active_key_count;

    reg saw_key3_off = 1'b0;
    integer index;

    always #5 clk = ~clk;
    always @(posedge clk) begin
        if (key_off_pulse[3])
            saw_key3_off <= 1'b1;
    end

    pressure_key_matrix #(
        .KEY_COUNT(KEY_COUNT),
        .ADC_BITS(ADC_BITS),
        .CALIBRATION_SAMPLES(4),
        .FILTER_SHIFT(2),
        .PRESS_ON(12'd16),
        .PRESS_OFF(12'd8),
        .PRESS_FULL(12'd512),
        .ACTIVE_LOW_MASK({KEY_COUNT{1'b1}})
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .adc_ready(adc_ready),
        .sample_frame_valid(sample_frame_valid),
        .adc_samples(adc_samples),
        .calibrated(calibrated),
        .baseline_values(baseline_values),
        .pressure_values(pressure_values),
        .velocity_values(velocity_values),
        .key_down(key_down),
        .key_on_pulse(key_on_pulse),
        .key_off_pulse(key_off_pulse),
        .active_key_count(active_key_count)
    );

    task set_all_samples(input [ADC_BITS-1:0] value);
        begin
            for (index = 0; index < KEY_COUNT; index = index + 1)
                adc_samples[index*ADC_BITS +: ADC_BITS] = value;
        end
    endtask

    task set_key_sample(input integer key_number, input [ADC_BITS-1:0] value);
        begin
            adc_samples[key_number*ADC_BITS +: ADC_BITS] = value;
        end
    endtask

    task sample_frame;
        begin
            @(negedge clk);
            sample_frame_valid = 1'b1;
            @(negedge clk);
            sample_frame_valid = 1'b0;
        end
    endtask

    initial begin
        set_all_samples(12'd3000);
        repeat (3) @(posedge clk);
        rst_n = 1'b1;

        // 每个键独立完成松开基线校准。
        repeat (4) sample_frame();
        if (!calibrated)
            $fatal(1, "13-key calibration did not finish");
        for (index = 0; index < KEY_COUNT; index = index + 1) begin
            if (baseline_values[index*ADC_BITS +: ADC_BITS] != 12'd3000)
                $fatal(1, "key %0d baseline mismatch", index);
        end

        sample_frame();
        if (key_down != {KEY_COUNT{1'b0}} || active_key_count != 0)
            $fatal(1, "idle inputs produced a false key");

        // 同一帧按下四个键，验证真正的四声部输入事件不会互相覆盖。
        set_key_sample(0,  12'd2850); // 压力差 150
        set_key_sample(3,  12'd2750); // 压力差 250
        set_key_sample(7,  12'd2650); // 压力差 350
        set_key_sample(12, 12'd2550); // 压力差 450
        sample_frame();
        if ((key_down & 13'b1_0000_1000_1001) != 13'b1_0000_1000_1001)
            $fatal(1, "four simultaneous keys were not captured: %b", key_down);
        if ((key_on_pulse & 13'b1_0000_1000_1001) != 13'b1_0000_1000_1001)
            $fatal(1, "four simultaneous key-on pulses were not generated");
        if (active_key_count != 4)
            $fatal(1, "active key count should be 4, got %0d", active_key_count);

        repeat (12) sample_frame();
        if (!(velocity_values[12*8 +: 8] > velocity_values[7*8 +: 8] &&
              velocity_values[7*8 +: 8] > velocity_values[3*8 +: 8] &&
              velocity_values[3*8 +: 8] > velocity_values[0*8 +: 8]))
            $fatal(1, "velocity ordering does not follow pressure");

        // 只松开第 3 键，其余三个键必须继续保持。
        set_key_sample(3, 12'd3000);
        repeat (20) sample_frame();
        if (key_down[3] || !saw_key3_off)
            $fatal(1, "independent key release failed");
        if (!key_down[0] || !key_down[7] || !key_down[12] || active_key_count != 3)
            $fatal(1, "releasing one key disturbed the other voices");

        // 第 3 键在触发阈值下方抖动时不能误触发。
        set_key_sample(3, 12'd2985); // 原始压力差 15
        repeat (20) sample_frame();
        if (key_down[3])
            $fatal(1, "noise below PRESS_ON retriggered key 3");

        // 超过触发阈值后，再回到迟滞区，按键应继续保持。
        set_key_sample(3, 12'd2976); // 原始压力差 24
        repeat (8) sample_frame();
        if (!key_down[3])
            $fatal(1, "key 3 did not trigger above PRESS_ON");
        set_key_sample(3, 12'd2988); // 原始压力差 12，位于 8～16
        repeat (12) sample_frame();
        if (!key_down[3])
            $fatal(1, "hysteresis did not hold key 3");

        // ADC 掉线时所有键必须立即释放，避免持续卡音。
        @(negedge clk);
        adc_ready = 1'b0;
        @(negedge clk);
        if (key_down != {KEY_COUNT{1'b0}} || active_key_count != 0)
            $fatal(1, "ADC fault did not release all keys");
        if (velocity_values != {(KEY_COUNT*8){1'b0}})
            $fatal(1, "ADC fault did not clear velocities");

        $display("PASS tb_pressure_key_matrix");
        $finish;
    end
endmodule

`default_nettype wire
