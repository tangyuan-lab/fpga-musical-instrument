`timescale 1ns/1ps
`include "sim/math_reference.sv"
module tb_modal_local;
    `include "sim/result.svh"
    GSR GSR(.GSRI(1'b1));
    reg clk=0;always #10 clk=~clk;
    reg rst_n=0,iv=0,first=0,held=1;
    reg [43:0] tag=0;reg [1:0] kind=0;reg [16:0] age=0;
    reg [255:0] coefficient=0;reg [127:0] state=0;
    wire rv,cv,rq,cq;wire [43:0] rt,ct;wire [1:0] rk,ck;
    wire signed [63:0] rc,cc;wire [127:0] rs,cs;wire [15:0] rb,cb;
    wire [43:0] candidate_tag=tag^(($test$plusargs("MUTATE_VALID")&&tag==8)?44'd1:44'd0);
    shared_modal_math_reference #(.TAG_WIDTH(44)) ref_dut(
        .clk(clk),.rst_n(rst_n),.in_valid(iv),.in_tag(tag),.kind(kind),.first(first),.held(held),.age(age),
        .piano_pitch(32'h10000000),.drum_pitch(16'h8000),.coefficient(coefficient),.state(state),
        .out_valid(rv),.out_tag(rt),.out_kind(rk),.contribution(rc),.next_state(rs),.quiet(rq),.quiet_bound(rb));
    shared_modal_math #(.TAG_WIDTH(44)) cand_dut(
        .clk(clk),.rst_n(rst_n),.in_valid(iv),.in_tag(candidate_tag),.kind(kind),.first(first),.held(held),.age(age),
        .piano_pitch(32'h10000000),.drum_pitch(16'h8000),.coefficient(coefficient),.state(state),
        .out_valid(cv),.out_tag(ct),.out_kind(ck),.contribution(cc),.next_state(cs),.quiet(cq),.quiet_bound(cb));
    integer checked=0;
    always @(negedge clk)begin
        if((^{rv,cv})===1'bx)$fatal(1,"modal valid X");
        if(rv!==cv)$fatal(1,"modal output mismatch valid");
        if(rv)begin
            if((^{ct,ck,cc,cs,cq,cb})===1'bx)$fatal(1,"modal candidate data X");
            if({rt,rk,rc,rs,rq,rb}!=={ct,ck,cc,cs,cq,cb})$fatal(1,"modal output mismatch tag=%0d/%0d",rt,ct);
            checked=checked+1;
        end
    end
    initial begin
        repeat(4)@(negedge clk);rst_n=1;
        for(integer n=0;n<180;n=n+1)begin
            @(negedge clk);iv=n%3!=0;tag=n;kind=n%2?0:3;first=n%5==0;held=n%7!=0;age=n;
            coefficient={128'd0,32'h01000000,32'h10000000,16'h4000,24'd1234,24'd455};
            state={32'd0,32'h12345678,32'h10000000,32'h08000000};
            // 在有效流水中取消后立即恢复，比较器持续检查，不能跳过边界。
            rst_n=!(n==40||n==41||n==100);
        end
        @(negedge clk);iv=0;rst_n=1;repeat(12)@(negedge clk);
        if(checked<90)$fatal(1,"modal checker vacuous count=%0d",checked);
        complete_test("tb_modal_local",checked);$display("PASS tb_modal_local checked=%0d",checked);$finish;
    end
    initial begin #100000;$fatal(1,"modal test timeout");end
endmodule
