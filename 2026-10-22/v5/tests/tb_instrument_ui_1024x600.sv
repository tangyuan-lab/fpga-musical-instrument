`timescale 1ns/1ps
`default_nettype none

module tb_instrument_ui_1024x600;
    reg clk = 1'b0;
    reg [10:0] x = 11'd0;
    reg [9:0] y = 10'd0;
    reg [116:0] bar_levels = 117'd0;
    reg [12:0] key_down = 13'd0;
    reg [3:0] active_key_count = 4'd0;
    reg scan_ready = 1'b1;
    reg calibrated = 1'b1;
    reg audio_ready = 1'b1;
    reg fault = 1'b0;
    reg midi_mode = 1'b0;
    reg midi_file_ready = 1'b0;
    reg midi_parser_busy = 1'b0;
    reg midi_playing = 1'b0;
    reg [3:0] midi_voice_gate = 4'd0;
    wire [23:0] rgb;

    always #5 clk = ~clk;

    instrument_ui_1024x600 dut (
        .clk(clk), .x(x), .y(y), .bar_levels(bar_levels), .key_down(key_down),
        .active_key_count(active_key_count), .scan_ready(scan_ready),
        .calibrated(calibrated), .audio_ready(audio_ready), .fault(fault),
        .midi_mode(midi_mode), .midi_file_ready(midi_file_ready),
        .midi_parser_busy(midi_parser_busy), .midi_playing(midi_playing),
        .midi_voice_gate(midi_voice_gate), .rgb(rgb)
    );

    task automatic settle;
        begin
            repeat (5) @(posedge clk);
            #1;
        end
    endtask

    initial begin
        // 实时模式就绪时顶栏为绿色。
        x = 11'd100; y = 10'd30;
        settle();
        if (rgb != 24'h20_c8_88)
            $fatal(1, "live header color mismatch: %h", rgb);

        // MIDI 文件就绪后顶栏变为紫色。
        midi_mode = 1'b1;
        midi_file_ready = 1'b1;
        settle();
        if (rgb != 24'h8a_5c_e6)
            $fatal(1, "MIDI header color mismatch: %h", rgb);

        // MIDI 第一个声部打开时，第一列显示紫色声部柱。
        x = 11'd40; y = 10'd300;
        midi_playing = 1'b1;
        midi_voice_gate = 4'b0001;
        settle();
        if (rgb != 24'hb0_72_ff)
            $fatal(1, "MIDI voice bar mismatch: %h", rgb);

        // 第五列不对应 MIDI 声部，应保持背景色。
        x = 11'd344; y = 10'd300;
        settle();
        if (rgb != 24'h18_2a_42)
            $fatal(1, "unused MIDI bar mismatch: %h", rgb);

        $display("PASS tb_instrument_ui_1024x600");
        $finish;
    end
endmodule

`default_nettype wire
