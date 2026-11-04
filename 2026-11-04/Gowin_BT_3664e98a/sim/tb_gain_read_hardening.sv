`timescale 1ns/1ps
`include "sim/track_gain_bank_94f0_reference.sv"
module gain_read_hardening_case #(parameter integer OWNERS=19)(
    input wire clk,rst_n,input wire [15:0] cycle,
    output reg [31:0] checks=0,commands=0,frames=0
);
    reg tick=0,command_valid=0;
    reg [4:0] owner=0,read_owner=0;reg [15:0] gain=0;
    reg [15:0] target[0:OWNERS-1];
    wire ro,rc,dno,dnc,eo,ec,io,ic,fo,fc,lo,lc;
    wire [15:0] go,gc,po,pc;
    track_gain_bank_94f0_reference #(.OWNERS(OWNERS)) original(
        .clk(clk),.rst_n(rst_n),.sample_tick(tick),.command_valid(command_valid),
        .command_ready(ro),.command_owner(owner),.command_gain(gain),.command_done(dno),.command_error(eo),
        .read_owner(read_owner),.read_gain(go),.initialized(io),.frame_done(fo),.deadline_error(lo),.percussion_gain(po));
    track_gain_bank_packed #(.OWNERS(OWNERS)) candidate(
        .clk(clk),.rst_n(rst_n),.sample_tick(tick),.command_valid(command_valid),
        .command_ready(rc),.command_owner(owner),.command_gain(gain),.command_done(dnc),.command_error(ec),
        .read_owner(read_owner),.read_gain(gc),.initialized(ic),.frame_done(fc),.deadline_error(lc),.percussion_gain(pc));
    always @(posedge clk)begin
        if(!rst_n)for(integer i=0;i<OWNERS;i=i+1)target[i]<=32768;
        else if(command_valid&&rc&&owner<OWNERS)target[owner]<=gain;
    end
    always @(negedge clk)if(cycle>2)begin
        if({ro,dno,eo,io,fo,lo,go,po}!=={rc,dnc,ec,ic,fc,lc,gc,pc})
            $fatal(1,"gain read differs OWNERS=%0d cycle=%0d owner=%0d",OWNERS,cycle,read_owner);
        if((^{ro,dno,eo,io,fo,lo,go,po})===1'bx)$fatal(1,"gain read X OWNERS=%0d",OWNERS);
        checks=checks+1;
        if(dnc)commands=commands+1;if(fc)frames=frames+1;
        if(lo||lc)$fatal(1,"gain deadline OWNERS=%0d",OWNERS);
        if(cycle>37500&&read_owner<OWNERS&&gc!==target[read_owner])
            $fatal(1,"gain ramp endpoint OWNERS=%0d owner=%0d actual=%0d target=%0d",OWNERS,read_owner,gc,target[read_owner]);
        // Read all 32 addresses while commands, initialization and ramp writes run.
        read_owner=cycle[4:0];
        tick=rst_n&&cycle[6:0]==100;
        // The final 17528 cycles leave >128 complete sample frames without
        // retargeting, so every owner must reach its exact commanded endpoint.
        command_valid=rst_n&&rc&&cycle%13==0&&cycle<20480;
        owner=cycle/13;gain=16'(cycle*1937+OWNERS*977);
    end
endmodule
module tb_gain_read_hardening;
    `include "sim/result.svh"
    reg clk=0;always #10 clk=~clk;
    reg rst_n=0;reg [15:0] cycle=0;
    always @(posedge clk)cycle<=cycle+1'b1;
    wire [31:0] checks[0:3],commands[0:3],frames[0:3];
    gain_read_hardening_case #(.OWNERS(1)) c1(clk,rst_n,cycle,checks[0],commands[0],frames[0]);
    gain_read_hardening_case #(.OWNERS(4)) c4(clk,rst_n,cycle,checks[1],commands[1],frames[1]);
    gain_read_hardening_case #(.OWNERS(19)) c19(clk,rst_n,cycle,checks[2],commands[2],frames[2]);
    gain_read_hardening_case #(.OWNERS(32)) c32(clk,rst_n,cycle,checks[3],commands[3],frames[3]);
    integer total=0;
    initial begin
        repeat(4)@(posedge clk);#1;rst_n=1;
        repeat(19000)@(posedge clk);#1;rst_n=0;
        repeat(4)@(posedge clk);#1;rst_n=1;
        repeat(19000)@(posedge clk);#1;
        for(integer i=0;i<4;i=i+1)begin
            if(checks[i]<38000||commands[i]<500||frames[i]<280)$fatal(1,"gain vacuous case=%0d",i);
            total=total+checks[i];
        end
        complete_test("tb_gain_read_hardening",total);
        $display("PASS tb_gain_read_hardening checks=%0d owners=1/4/19/32 latency=0 ramp128_exact=1",total);$finish;
    end
    initial begin #1000000;$fatal(1,"gain hardening timeout");end
endmodule
