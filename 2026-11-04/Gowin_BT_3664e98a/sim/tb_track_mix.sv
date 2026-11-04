`timescale 1ns/1ps
module tb_track_mix;
    `include "sim/result.svh"
    reg clk=0;always #10 clk=~clk;
    reg rst_n=0;reg [255:0] gains=0;reg [6:0] piano=80,midi=60;
    wire valid;reg ready=0,done=0;wire [4:0] owner;wire [15:0] gain;wire error;
    integer cycle=0,accepts=0,rounds=0;reg [18:0] seen=0;integer expected;
    workstation_track_mix dut(.clk(clk),.rst_n(rst_n),.song_gains(gains),.piano_volume(piano),.midi_volume(midi),
        .command_valid(valid),.command_ready(ready),.command_done(done),.command_error(1'b0),
        .command_owner(owner),.command_gain(gain),.error(error));
    always @(negedge clk)ready=cycle%7!=0;
    always @(posedge clk)begin
        cycle<=cycle+1;done<=valid&&ready;
        if(rst_n&&valid&&ready)begin
            if((^{owner,gain})===1'bx||owner>18)$fatal(1,"track mix unknown/invalid");
            expected=owner<16 ? (gains[owner*16+:16]*midi+50)/100:owner<18 ? (32768*piano+50)/100:32768;
            if(gain!==16'(expected))$fatal(1,"track mix owner=%0d gain=%0d expected=%0d",owner,gain,expected);
            seen[owner]<=1;accepts<=accepts+1;
        end
    end
    initial begin
        for(integer t=0;t<16;t=t+1)gains[t*16+:16]=t*2048;
        repeat(4)@(negedge clk);rst_n=1;repeat(1000)@(negedge clk);
        if(seen!==19'h7ffff)$fatal(1,"initial19 gain targets missing %h",seen);
        seen=0;piano=100;midi=100;for(integer t=0;t<16;t=t+1)gains[t*16+:16]=32768-t*511;
        repeat(1600)@(negedge clk);
        if((seen&19'h3ffff)!==19'h3ffff||error)$fatal(1,"changed gain target not applied %h",seen);
        complete_test("tb_track_mix",38);$display("PASS tb_track_mix owners=19 accepts=%0d exact_rounding=1",accepts);$finish;
    end
    initial begin #1000000;$fatal(1,"track mix timeout");end
endmodule
