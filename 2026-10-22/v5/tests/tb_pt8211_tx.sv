`timescale 1ns/1ps
`default_nettype none

module tb_pt8211_tx;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg signed [15:0] sample_left = 16'sh3cc3;
    reg signed [15:0] sample_right = -16'sd23131; // 位模式 A5A5。
    wire sample_tick;
    wire hp_bck;
    wire hp_ws;
    wire hp_din;
    integer i;
    time first_tick_time;

    always #5 clk = ~clk;

    pt8211_tx #(.BCK_HALF_DIV(2)) dut (
        .clk(clk), .rst_n(rst_n),
        .sample_left(sample_left), .sample_right(sample_right),
        .sample_tick(sample_tick), .hp_bck(hp_bck),
        .hp_ws(hp_ws), .hp_din(hp_din)
    );

    initial begin
        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        @(posedge sample_tick);
        first_tick_time = $time;

        for (i = 15; i >= 0; i = i - 1) begin
            @(posedge hp_bck);
            if (hp_ws !== 1'b0 || hp_din !== sample_right[i])
                $fatal(1, "right channel bit %0d mismatch", i);
        end
        for (i = 15; i >= 0; i = i - 1) begin
            @(posedge hp_bck);
            if (hp_ws !== 1'b1 || hp_din !== sample_left[i])
                $fatal(1, "left channel bit %0d mismatch", i);
        end

        @(posedge sample_tick);
        if (($time - first_tick_time) != 1280)
            $fatal(1, "sample period mismatch: %0t ns", $time - first_tick_time);

        $display("PASS tb_pt8211_tx");
        $finish;
    end
endmodule

`default_nettype wire
