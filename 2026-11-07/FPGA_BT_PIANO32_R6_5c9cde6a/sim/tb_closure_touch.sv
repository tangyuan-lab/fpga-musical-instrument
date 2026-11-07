`timescale 1ns/1ps
module tb_closure_touch;
`include "sim/result.svh"
reg clk=0;always #10 clk=~clk;reg rst_n=0,frame_valid=0;
reg [7:0] frame_op=0,frame_value=0;
wire [15:0] ah,bh;wire [1:0] ao,bo;wire atest,btest,av,bv,au,bu;wire [7:0] aop,bop,aval,bval;wire [4:0] flags;
screen_touch_service #(.KEY_COUNT(16),.POLYPHONIC(1),.PERFORMANCE_CONTROLS(1),.WORKSTATION_CONTROLS(1),.WATCHDOG_CYCLES(64)) a(
 .clk(clk),.rst_n(rst_n),.frame_valid(frame_valid),.frame_op(frame_op),.frame_value(frame_value),.held_keys(ah),.octave_shift(ao),.test_mode(atest),.command_valid(av),.command_op(aop),.command_value(aval),.unsupported_frame(au),.command_cancel_flags(flags));
reference_closure_touch_service #(.KEY_COUNT(16),.POLYPHONIC(1),.PERFORMANCE_CONTROLS(1),.WORKSTATION_CONTROLS(1),.WATCHDOG_CYCLES(64)) b(
 .clk(clk),.rst_n(rst_n),.frame_valid(frame_valid),.frame_op(frame_op),.frame_value(frame_value),.held_keys(bh),.octave_shift(bo),.test_mode(btest),.command_valid(bv),.command_op(bop),.command_value(bval),.unsupported_frame(bu));
function automatic [4:0] classify(input [7:0] op,value);begin
 if((^{op,value})===1'bx)classify=0;
 else classify={op==8'h6f,(op==8'h67&&value!=0),(op==8'h60&&value<=3),(op==8'h62&&value==0),(op==8'h61&&value>=1&&value<=7)};
end endfunction
integer checks=0,op,value;
always @(negedge clk)begin #1;if(rst_n)begin
 if({ah,ao,atest,av,aop,aval,au}!=={bh,bo,btest,bv,bop,bval,bu})$fatal(1,"CLOSURE_TOUCH_PUBLIC_MISMATCH");
 if(flags!==classify(aop,aval))$fatal(1,"CLOSURE_TOUCH_HINT_CAPTURE");checks=checks+1;
end end
initial begin
 repeat(4)@(negedge clk);rst_n=1;
 for(op=0;op<256;op=op+1)for(value=0;value<256;value=value+1)begin
  @(negedge clk);frame_valid=1;frame_op=op;frame_value=value;
  @(negedge clk);frame_valid=0;
 end
 @(negedge clk);frame_valid=1;frame_op=8'hxx;frame_value=0;
 @(negedge clk);frame_op=8'h67;frame_value=8'hzz;
 @(negedge clk);frame_valid=0;repeat(80)@(negedge clk);
 if(checks<131000)$fatal(1,"CLOSURE_TOUCH_VACUOUS");
 complete_test("tb_closure_touch",checks);$display("PASS tb_closure_touch CHECKS=%0d",checks);$finish;
end
initial begin #4000000;$fatal(1,"CLOSURE_TOUCH_BOUND");end
endmodule
