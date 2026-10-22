`timescale 1ns/1ps
module tb_poly_synth_adsr;
    reg clk=0,rst_n=0,tick=0,gate=0,trigger=0;
    reg [12:0] target=128;
    wire [12:0] level;
    wire idle;
    wire signed [15:0] sample_out;
    always #10 clk=~clk;
    poly_synth_voice #(.ADSR_ENABLE(1),.ATTACK_STEP(32),.DECAY_STEP(8),.RELEASE_STEP(16)) dut(
        .clk(clk),.rst_n(rst_n),.sample_tick(tick),.gate(gate),.retrigger(trigger),.timbre(1'b0),
        .phase_step(32'd23012828),.target_level(target),.sample_out(sample_out),.current_level(level),.idle(idle));
    task step(input integer expected);
        begin
            @(negedge clk); tick=1;
            @(negedge clk); tick=0;
            if(level!==expected) $fatal(1,"ADSR level got=%0d expected=%0d",level,expected);
        end
    endtask
    initial begin
        repeat(3) @(negedge clk); rst_n=1; gate=1; trigger=1;
        @(negedge clk); trigger=0;
        step(32);step(64);step(96);step(128);
        step(120);step(112);step(104);step(96);step(96);
        target=256; step(128);step(160);step(192);step(192);
        gate=0; step(176);step(160);step(144);step(128);step(112);step(96);
        step(80);step(64);step(48);step(32);step(16);step(0);
        if(!idle) $fatal(1,"release did not idle");
        gate=1;trigger=1; @(negedge clk);trigger=0;
        step(32); gate=0;step(16);step(0);
        $display("PASS tb_poly_synth_adsr attack=PASS decay=PASS sustain_pressure=PASS release=PASS short_note=PASS");
        $finish;
    end
    initial begin #100000; $fatal(1,"timeout"); end
endmodule
