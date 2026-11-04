`timescale 1ns/1ps
module tb_drum_synth;
    reg clk=0;always #10 clk=~clk;reg rst_n=0,tick=1,clear=0;reg [15:0] triggers=0;
    wire signed [15:0] sample;integer energies[0:15];integer id,n,energy;
    drum_synth dut(clk,rst_n,tick,clear,triggers,{16{8'd200}},sample);
    initial begin
        repeat(4) @(negedge clk);rst_n=1;
        for(id=0;id<16;id=id+1) begin
            clear=1;@(negedge clk);clear=0;triggers=16'b1<<id;@(negedge clk);triggers=0;energy=0;
            for(n=0;n<1000;n=n+1) begin @(negedge clk);energy=energy+(sample<0 ? -int'(sample) : int'(sample));end
            energies[id]=energy;if(energy<1000) $fatal(1,"silent drum %d",id);
        end
        for(id=1;id<16;id=id+1) if(energies[id]==energies[0]) $fatal(1,"identical drum waveform");
        clear=1;@(negedge clk);clear=0;triggers=16'h00ff;@(negedge clk);triggers=0;repeat(20) @(negedge clk);
        if(dut.idle!==8'h00) $fatal(1,"simultaneous triggers lost voices %h",dut.idle);
        for(id=0;id<8;id=id+1) if(dut.sound[id]!==4'(id)) $fatal(1,"pending fire overwrote drum %d",id);
        triggers=16'hffff;@(negedge clk);triggers=0;repeat(40) @(negedge clk);
        clear=1;repeat(3) @(negedge clk);if(sample!==0) $fatal(1,"clear drum failed");
        $display("PASS tb_drum_synth 16 distinct HDL drums, simultaneous requests and clear");$finish;
    end
endmodule
