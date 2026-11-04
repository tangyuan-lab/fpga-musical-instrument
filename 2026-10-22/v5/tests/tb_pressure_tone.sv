`timescale 1ns/1ps
`default_nettype none

module tb_pressure_tone;
    localparam [31:0] PHASE_STEP_A4 = 32'd38_702_809;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg sample_tick = 1'b0;
    reg gate = 1'b0;
    reg [12:0] target_level = 13'd0;
    wire signed [15:0] sample_out;
    wire [12:0] current_level;
    integer i;

    always #5 clk = ~clk;

    pressure_tone dut (
        .clk(clk), .rst_n(rst_n), .sample_tick(sample_tick),
        .gate(gate), .phase_step(PHASE_STEP_A4),
        .target_level(target_level), .sample_out(sample_out),
        .current_level(current_level)
    );

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
        gate = 1'b1;
        target_level = 13'd512;

        repeat (16) next_sample();
        if (current_level != 13'd512)
            $fatal(1, "attack ramp mismatch: %0d", current_level);

        target_level = 13'd128;
        repeat (24) next_sample();
        if (current_level != 13'd128)
            $fatal(1, "downward slew mismatch: %0d", current_level);

        target_level = 13'd4096;
        repeat (124) next_sample();
        if (current_level != 13'd4096)
            $fatal(1, "maximum level mismatch: %0d", current_level);

        for (i = 0; i < 32; i = i + 1) begin
            next_sample();
            if (sample_out > 16'sd4096 || sample_out < -16'sd4096)
                $fatal(1, "sample exceeded safe range: %0d", sample_out);
        end

        gate = 1'b0;
        repeat (256) next_sample();
        if (current_level != 13'd0 || sample_out != 16'sd0)
            $fatal(1, "release did not reach silence");

        $display("PASS tb_pressure_tone");
        $finish;
    end
endmodule

`default_nettype wire
