`timescale 1ns/1ps
module tb_voice_count;
 `include "sim/result.svh"
 reg [31:0] mask=0;wire [5:0] count;
 workstation_voice_count dut(.mask(mask),.count(count));
 integer checks=0,expected=0,seed=32'h612904;
 task automatic check_mask(input [31:0] value);
  begin
   mask=value;expected=0;
   for(integer b=0;b<32;b=b+1)if(value[b])expected=expected+1;
   #1;if((^count)===1'bx||count!==expected[5:0])$fatal(1,"voice count mask=%h got=%0d expected=%0d",mask,count,expected);
   checks=checks+1;
  end
 endtask
 initial begin
  check_mask(0);check_mask(32'hffffffff);
  for(integer i=0;i<32;i=i+1)begin check_mask(32'd1<<i);check_mask(~(32'd1<<i));end
  for(integer i=0;i<1000;i=i+1)check_mask($random(seed));
  complete_test("tb_voice_count",checks);$display("PASS tb_voice_count checks=%0d",checks);$finish;
 end
endmodule
