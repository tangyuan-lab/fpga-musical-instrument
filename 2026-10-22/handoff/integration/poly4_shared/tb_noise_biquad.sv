`timescale 1ns/1ps
module tb_noise_biquad;
 reg clk=0;always #10 clk=~clk;
 reg rst=0,start=0;reg signed [31:0] x0,x1,x2;reg signed [23:0] b,a1,a2;
 wire ready,busy,valid;wire signed [31:0] got;
 shared_noise_biquad dut(.clk(clk),.rst_n(rst),.start(start),.x0(x0),.x1(x1),.x2(x2),.b(b),.a1(a1),.a2(a2),.ready(ready),.busy(busy),.response_valid(valid),.result(got));
 integer i,cycles,max_cycles=0,resets=0;reg signed [63:0] expected;reg signed [31:0] expected_pcm;
 function [31:0] boundary32(input integer n);
  case(n%6)0:boundary32=0;1:boundary32=1;2:boundary32=-1;3:boundary32=32'h7fffffff;4:boundary32=32'h80000000;default:boundary32=32'hffff0001;endcase
 endfunction
 function [23:0] boundary24(input integer n);
  case(n%6)0:boundary24=0;1:boundary24=1;2:boundary24=-1;3:boundary24=24'h7fffff;4:boundary24=24'h800000;default:boundary24=24'hff0001;endcase
 endfunction
 initial begin
  repeat(4)@(negedge clk);rst=1;
  for(i=0;i<4096;i=i+1)begin
   if(!ready)$fatal(1,"MAC not ready before a job");
   x0=i<216?boundary32(i):$random;x1=i<216?boundary32(i/6):$random;x2=i<216?boundary32(i/36):$random;
   b=i<216?boundary24(i/36):$random;a1=i<216?boundary24(i):$random;a2=i<216?boundary24(i/6):$random;
   expected=$signed(x0)*$signed(b)-$signed(x1)*$signed(a1)-$signed(x2)*$signed(a2)+64'sd2097152;
   expected_pcm=expected>>>22;
   start=1;@(negedge clk);start=0;cycles=0;
   if(i%117==116)begin
    repeat(2)@(negedge clk);rst=0;@(negedge clk);rst=1;resets=resets+1;
    repeat(10)begin @(negedge clk);if(valid)$fatal(1,"Cancelled filter job returned after reset");end
   end else begin
    while(!valid&&cycles<12)begin @(negedge clk);cycles=cycles+1;end
    if(!valid||got!==expected_pcm)$fatal(1,"Split MAC mismatch job=%0d got=%0d expected=%0d clocks=%0d",i,got,expected_pcm,cycles);
    if(cycles>max_cycles)max_cycles=cycles;
    @(negedge clk);
   end
  end
  $display("PASS exact split biquad: 4096 boundary/random jobs, signed coefficient minimum included, %0d cancelled resets, max clocks=%0d",resets,max_cycles);$finish;
 end
 initial begin #10000000;$fatal(1,"Biquad watchdog");end
endmodule
