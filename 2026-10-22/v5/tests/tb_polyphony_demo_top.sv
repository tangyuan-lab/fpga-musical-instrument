`timescale 1ns/1ps
`default_nettype none

module tb_polyphony_demo_top;
    reg sys_clk = 1'b0;
    reg sys_rst_n = 1'b0;
    wire [7:0] led_n;
    wire hp_bck;
    wire hp_ws;
    wire hp_din;
    wire pa_en;
    integer timeout_count;

    always #5 sys_clk = ~sys_clk;

    polyphony_demo_top #(
        .STARTUP_CYCLES(2),
        .CHORD_CYCLES(20)
    ) dut (
        .sys_clk(sys_clk), .sys_rst_n(sys_rst_n), .led_n(led_n),
        .hp_bck(hp_bck), .hp_ws(hp_ws), .hp_din(hp_din), .pa_en(pa_en)
    );

    task wait_for_chord(input [12:0] expected_mask);
        begin : wait_block
            for (timeout_count = 0; timeout_count < 40; timeout_count = timeout_count + 1) begin
                @(posedge sys_clk);
                #1;
                if (dut.held_keys == expected_mask)
                    disable wait_block;
            end
            $fatal(1, "automatic chord sequence missed mask %h, got %h",
                   expected_mask, dut.held_keys);
        end
    endtask

    initial begin
        repeat (3) @(posedge sys_clk);
        sys_rst_n = 1'b1;

        wait_for_chord(13'b0_1000_1001_0001); // Cmaj7
        wait_for_chord(13'b0_0010_0011_0001); // Fmaj7
        wait_for_chord(13'b0_1000_1010_0100); // G7
        wait_for_chord(13'b1_0010_1001_0000); // Am7
        wait_for_chord(13'b0_1000_1001_0001); // 回到 Cmaj7

        if (pa_en)
            $fatal(1, "audio amplifier was not enabled after startup");
        if (dut.voice_assigned != 4'b1111)
            $fatal(1, "automatic demo did not allocate four voices");

        $display("PASS tb_polyphony_demo_top");
        $finish;
    end
endmodule

`default_nettype wire
