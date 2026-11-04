`timescale 1ns/1ps
`default_nettype none

module tb_polyphony_timbre_demo_top;
    reg sys_clk = 1'b0;
    reg sys_rst_n = 1'b0;
    reg timbre_key_n = 1'b1;
    reg timbre_key_alt_n = 1'b1;
    wire [7:0] led_n;
    wire hp_bck;
    wire hp_ws;
    wire hp_din;
    wire pa_en;

    always #5 sys_clk = ~sys_clk;

    polyphony_timbre_demo_top #(
        .STARTUP_CYCLES(2), .CHORD_CYCLES(100), .BUTTON_CYCLES(3)
    ) dut (
        .sys_clk(sys_clk), .sys_rst_n(sys_rst_n), .timbre_key_n(timbre_key_n),
        .timbre_key_alt_n(timbre_key_alt_n),
        .led_n(led_n), .hp_bck(hp_bck), .hp_ws(hp_ws),
        .hp_din(hp_din), .pa_en(pa_en)
    );

    task press_and_release_timbre;
        begin
            @(negedge sys_clk);
            timbre_key_n = 1'b0;
            repeat (7) @(negedge sys_clk);
            timbre_key_n = 1'b1;
            repeat (7) @(negedge sys_clk);
        end
    endtask

    task press_and_release_alt;
        begin
            @(negedge sys_clk);
            timbre_key_alt_n = 1'b0;
            repeat (7) @(negedge sys_clk);
            timbre_key_alt_n = 1'b1;
            repeat (7) @(negedge sys_clk);
        end
    endtask

    initial begin
        repeat (3) @(posedge sys_clk);
        sys_rst_n = 1'b1;
        repeat (10) @(negedge sys_clk);
        if (dut.timbre != 1'b0)
            $fatal(1, "default timbre should be triangle");

        press_and_release_alt();
        if (dut.timbre != 1'b1 || led_n[2] != 1'b0)
            $fatal(1, "first button press did not select square timbre");

        press_and_release_timbre();
        if (dut.timbre != 1'b0 || led_n[2] != 1'b1)
            $fatal(1, "second button press did not return to triangle timbre");

        $display("PASS tb_polyphony_timbre_demo_top");
        $finish;
    end
endmodule

`default_nettype wire
