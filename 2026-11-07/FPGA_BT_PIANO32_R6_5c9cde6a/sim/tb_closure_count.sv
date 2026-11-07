`timescale 1ns/1ps
module tb_closure_count;
`include "sim/result.svh"
reg [31:0] mask=0;wire [5:0] value,reference_count;
workstation_voice_count a(.mask(mask),.count(value));
reference_closure_voice_count b(.mask(mask),.count(reference_count));
integer checks=0,i,j,seed=32'h713902;reg [31:0] pattern;
task automatic check(input [31:0] m);begin
 mask=m;#1;if(value!==reference_count)$fatal(1,"CLOSURE_COUNT_MISMATCH mask=%h new=%b parent=%b",mask,value,reference_count);checks=checks+1;
end endtask
initial begin
 check(0);check(32'hffffffff);
 for(i=0;i<65536;i=i+1)begin check({i[15:0],i[15:0]});check({16'd0,i[15:0]});check({i[15:0],16'd0});end
 for(i=0;i<2048;i=i+1)check($random(seed));
 for(i=0;i<32;i=i+1)begin
  pattern=0;pattern[i]=1'bx;check(pattern);pattern=32'hffffffff;pattern[i]=1'bz;check(pattern);
  pattern=$random(seed);pattern[i]=1'bx;check(pattern);
 end
 check(32'hxxxxxxxx);check(32'hzzzzzzzz);
 complete_test("tb_closure_count",checks);$display("PASS tb_closure_count CHECKS=%0d",checks);$finish;
end
initial begin #1000000;$fatal(1,"CLOSURE_COUNT_BOUND");end
endmodule
