`timescale 1ns/1ps
module adsr_waveform_tb;
    reg clk=0; always #10 clk=~clk;
    reg rst_n=0, sample_tick=0, note_on=0, note_off=0, note_active=0;
    wire [15:0] gain; wire voice_active;
    adsr dut(.sys_clk(clk),.sys_rst_n(rst_n),.sample_tick(sample_tick),
        .note_on(note_on),.note_off(note_off),.note_active(note_active),
        .gain(gain),.voice_active(voice_active));
    integer n;
    initial begin
        repeat(3) @(negedge clk); rst_n=1; note_active=1; note_on=1;
        @(negedge clk); note_on=0;
        for(n=0;n<220;n=n+1) begin
            @(negedge clk); sample_tick=1;
            @(negedge clk); sample_tick=0;
            if(n==150) begin note_active=0; note_off=1; end
            if(n==151) note_off=0;
        end
        forever #1000;
    end
endmodule
