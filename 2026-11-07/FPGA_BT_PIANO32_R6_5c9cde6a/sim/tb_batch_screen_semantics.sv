`timescale 1ns/1ps
module tb_batch_screen_semantics;
`include "sim/result.svh"
reg clk=0;
reg rst_n=0;
reg command_valid=0;
reg [1:0] command_source=0;
reg [7:0] command_op=0;
reg [7:0] command_value=0;
reg external_stop=0;
reg [31:0] session=0;
reg [31:0] build_id=0;
reg [2:0] test_kind=0;
reg [5:0] completed_count=0;
reg [5:0] voices=0;
reg failed=0;
reg [7:0] result=0;
wire a_forward_valid;
wire [7:0] a_forward_op;
wire [7:0] a_forward_value;
wire [479:0] a_telemetry;
wire b_forward_valid;
wire [7:0] b_forward_op;
wire [7:0] b_forward_value;
wire [479:0] b_telemetry;
wire cancel_semantic;
wire [4:0] hints=(^{command_op,command_value})===1'bx ? 5'd0:{command_op==8'h6f,(command_op==8'h67&&command_value!=0),(command_op==8'h60&&command_value<=3),(command_op==8'h62&&command_value==0),(command_op==8'h61&&command_value>=1&&command_value<=7)};
r7_piano32_screen_status #(.PREDECODED_CANCEL(1)) a_dut(.command_cancel_flags(hints),.clk(clk),.rst_n(rst_n),.command_valid(command_valid),.command_source(command_source),.command_op(command_op),.command_value(command_value),.external_stop(external_stop),.session(session),.build_id(build_id),.test_kind(test_kind),.completed_count(completed_count),.voices(voices),.failed(failed),.result(result),.forward_valid(a_forward_valid),.forward_op(a_forward_op),.forward_value(a_forward_value),.telemetry(a_telemetry),.forward_restart_or_stop(cancel_semantic));
reference_batch_screen_status b_dut(.clk(clk),.rst_n(rst_n),.command_valid(command_valid),.command_source(command_source),.command_op(command_op),.command_value(command_value),.external_stop(external_stop),.session(session),.build_id(build_id),.test_kind(test_kind),.completed_count(completed_count),.voices(voices),.failed(failed),.result(result),.forward_valid(b_forward_valid),.forward_op(b_forward_op),.forward_value(b_forward_value),.telemetry(b_telemetry));

always #10 clk=~clk;
integer checks=0,cancels=0,op,value,source;
wire old_cancel=b_forward_valid===1'b1 &&
 ((b_forward_op===8'h61&&b_forward_value>=1&&b_forward_value<=7)||
 (b_forward_op===8'h62&&b_forward_value===0)||(b_forward_op===8'h60&&b_forward_value<=3));
always @(negedge clk)begin #1;if(rst_n)begin
 if({a_forward_valid,a_forward_op,a_forward_value,a_telemetry}!=={b_forward_valid,b_forward_op,b_forward_value,b_telemetry})
  $fatal(1,"BATCH_SCREEN_PUBLIC_MISMATCH");
 if(cancel_semantic!==old_cancel)$fatal(1,"BATCH_SCREEN_CANCEL_MISMATCH op=%h",command_op);
 checks=checks+1;if(cancel_semantic)cancels=cancels+1;
end end
always @(posedge clk)if(rst_n)begin
 if(a_forward_valid&&a_forward_op==8'h61&&a_forward_value>=1&&a_forward_value<=7)begin
  session<=session+1'b1;test_kind<=a_forward_value[2:0];completed_count<=0;
 end else if(a_forward_valid&&a_forward_op==8'h62&&a_forward_value==0)test_kind<=0;
 else if(completed_count<32)completed_count<=completed_count+1'b1;
end
initial begin
 build_id=32'h12345678;repeat(5)@(negedge clk);rst_n=1;
 for(source=1;source<=2;source=source+1)
 for(op=96;op<112;op=op+1)for(value=0;value<256;value=value+1)begin
  @(negedge clk);command_source=source;command_op=op;command_value=value;command_valid=1;
  @(negedge clk);command_valid=0;
 end
 @(negedge clk);command_valid=1;command_source=2;command_op=8'hxx;command_value=0;
 @(negedge clk);command_op=8'h67;command_value=8'hxx;
 @(negedge clk);command_op=8'h6f;command_value=1;command_source=2'bxx;
 @(negedge clk);command_valid=0;repeat(5)@(negedge clk);
 if(checks<16000||cancels<100)$fatal(1,"BATCH_SCREEN_VACUOUS");
 complete_test("tb_batch_screen_semantics",checks);
 $display("PASS tb_batch_screen_semantics CHECKS=%0d CANCELS=%0d",checks,cancels);$finish;
end
initial begin #2000000;$fatal(1,"BATCH_SCREEN_BOUND");end
endmodule

