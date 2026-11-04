`timescale 1ns/1ps
module tb_key_sound_mapping;
    reg clk=0;always #10 clk=~clk;reg rst_n=0;reg [1:0] div=0;wire tick=div==3;
    always @(posedge clk) div<=div+1'b1;
    reg [15:0] on_pulse=0,off_pulse=0;reg [127:0] notes=0;reg [95:0] timbres=0;
    wire [3:0] gate;wire [15:0] keys;wire [127:0] phase_steps;wire [31:0] blends;
    wire signed [15:0] sample;
    poly_synth_4voice #(.KEY_COUNT(16),.ADSR_ENABLE(1),.OCTAVE_CONTROL(1),.PER_KEY_SOUND(1)) dut(
        .clk(clk),.rst_n(rst_n),.sample_tick(tick),.timbre(1'b0),.octave_shift(2'd0),
        .key_on_pulse(on_pulse),.key_off_pulse(off_pulse),.velocity_values({16{8'd160}}),
        .key_notes(notes),.key_timbres(timbres),.sample_out(sample),.voice_gate(gate),.voice_assigned(),
        .voice_keys(keys),.voice_levels(),.timbre_blends(blends),.voice_phase_steps(phase_steps));
    integer v,found;
    initial begin
        notes[7:0]=9;notes[15:8]=4;timbres[5:0]=1;
        repeat(4) @(negedge clk);rst_n=1;on_pulse=3;@(negedge clk);on_pulse=0;
        repeat(200) @(negedge clk);found=0;
        for(v=0;v<4;v=v+1) if(gate[v]) begin
            if(keys[v*4+:4]==0) begin
                if(phase_steps[v*32+:32]!==32'd38702809 || blends[v*8+:8]!==255) $fatal(1,"mapped pitch/timbre 0 failed");found=found+1;
            end
            if(keys[v*4+:4]==1) begin
                if(phase_steps[v*32+:32]!==32'd28994347 || blends[v*8+:8]!==0) $fatal(1,"mapped pitch/timbre 1 failed");found=found+1;
            end
        end
        if(found!=2) $fatal(1,"simultaneous mapped keys lost");
        notes[7:0]=7;repeat(10) @(negedge clk);
        for(v=0;v<4;v=v+1) if(gate[v] && keys[v*4+:4]==0 && phase_steps[v*32+:32]!==32'd34480283) $fatal(1,"note descriptor update failed");
        $display("PASS tb_key_sound_mapping independent pitch and timbre IDs");$finish;
    end
endmodule
