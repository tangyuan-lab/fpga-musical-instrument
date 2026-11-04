`timescale 1ns/1ps
module tb_fir_mac;
 reg clk=0;always #10 clk=~clk;
 reg rst_n=0,in_valid=0,first=0,last=0;
 reg signed [31:0] sample=0;reg signed [24:0] coefficient=0;
 wire out_valid,out_last;wire signed [63:0] sum;
 shared_fir_mac dut(.*);
 reg signed [63:0] expected[0:25000],running,term;
 reg expected_valid[0:25000],expected_last[0:25000];
 integer cycle,n,tap=0,groups=0,checked=0,gap=0,group_length=3;
 initial begin
  for(n=0;n<25001;n=n+1)begin expected_valid[n]=0;expected_last[n]=0;end
  for(cycle=0;cycle<24000;cycle=cycle+1)begin
   @(negedge clk);
   rst_n=cycle%97>3;in_valid=rst_n&&gap==0&&($random%4!=0);first=tap==0;last=tap==group_length-1;
   if(gap!=0)gap=gap-1;
   sample=$random;coefficient=$random;
   if(cycle%11==0)begin sample=32'h80000000;coefficient=25'h1000000;end
   if(cycle%13==0)begin sample=32'h7fffffff;coefficient=25'h0ffffff;end
   if(!rst_n)begin tap=0;running=0;gap=0;group_length=3;for(n=cycle;n<cycle+4;n=n+1)expected_valid[n]=0;end
   else if(in_valid)begin
    term=sample*coefficient;running=first?term:running+term;
    if(last)begin expected[cycle+3]=running;expected_valid[cycle+3]=1;expected_last[cycle+3]=1;tap=0;gap=4;group_length=group_length==3?20:3;groups=groups+1;end else tap=tap+1;
   end
   @(posedge clk);#1;
   if(rst_n)begin
    if(out_valid!==expected_valid[cycle])$fatal(1,"FIR validity cycle=%0d",cycle);
    if(out_valid)begin
     if(sum!==expected[cycle]||out_last!==expected_last[cycle])$fatal(1,"FIR exact sum cycle=%0d want=%0d got=%0d",cycle,expected[cycle],sum);
     checked=checked+1;
    end
   end
  end
  $display("PASS vendor DSP FIR MAC: %0d full-width exact dot products, %0d launched groups, input gaps and pipeline resets",checked,groups);$finish;
 end
endmodule
