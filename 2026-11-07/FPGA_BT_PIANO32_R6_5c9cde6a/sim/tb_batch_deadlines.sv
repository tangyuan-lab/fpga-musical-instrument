`timescale 1ns/1ps
module batch_deadline_case #(parameter integer LEASE_N=1024,SERVICE_N=3,SEED_TERMINAL=0)(output reg finished=0);

reg clk=0;
reg rst_n=0;
reg frame_valid=0;
reg [7:0] frame_type=0;
reg [15:0] frame_seq=0;
reg [15:0] frame_length=0;
reg [255:0] payload=0;
reg usb_idle=0;
reg external_cancel=0;
reg [255:0] status_data=0;
reg response_busy=0;
reg command_ready=0;
reg command_done=0;
reg [7:0] command_result=0;
wire a_lease_active;
wire a_response_valid;
wire [15:0] a_response_seq;
wire [7:0] a_response_length;
wire [511:0] a_response_payload;
wire a_command_valid;
wire [7:0] a_command_op;
wire [31:0] a_command_value;
wire [31:0] a_command_aux;
wire a_command_cancel;
wire a_emergency;
wire [31:0] a_accepted_commands;
wire b_lease_active;
wire b_response_valid;
wire [15:0] b_response_seq;
wire [7:0] b_response_length;
wire [511:0] b_response_payload;
wire b_command_valid;
wire [7:0] b_command_op;
wire [31:0] b_command_value;
wire [31:0] b_command_aux;
wire b_command_cancel;
wire b_emergency;
wire [31:0] b_accepted_commands;
r7_bt_control #(.BUILD_ID(32'h12345678),.LEASE_CYCLES(LEASE_N),.SERVICE_CYCLES(SERVICE_N),.EARLY_FRAME_FIELDS(1)) a(.clk(clk),.rst_n(rst_n),.frame_valid(frame_valid),.frame_type(frame_type),.frame_seq(frame_seq),.frame_length(frame_length),.payload(payload),.usb_idle(usb_idle),.external_cancel(external_cancel),.status_data(status_data),.response_busy(response_busy),.command_ready(command_ready),.command_done(command_done),.command_result(command_result),.lease_active(a_lease_active),.response_valid(a_response_valid),.response_seq(a_response_seq),.response_length(a_response_length),.response_payload(a_response_payload),.command_valid(a_command_valid),.command_op(a_command_op),.command_value(a_command_value),.command_aux(a_command_aux),.command_cancel(a_command_cancel),.emergency(a_emergency),.accepted_commands(a_accepted_commands));
reference_batch_bt_control #(.BUILD_ID(32'h12345678),.LEASE_CYCLES(LEASE_N),.SERVICE_CYCLES(SERVICE_N)) b(.clk(clk),.rst_n(rst_n),.frame_valid(frame_valid),.frame_type(frame_type),.frame_seq(frame_seq),.frame_length(frame_length),.payload(payload),.usb_idle(usb_idle),.external_cancel(external_cancel),.status_data(status_data),.response_busy(response_busy),.command_ready(command_ready),.command_done(command_done),.command_result(command_result),.lease_active(b_lease_active),.response_valid(b_response_valid),.response_seq(b_response_seq),.response_length(b_response_length),.response_payload(b_response_payload),.command_valid(b_command_valid),.command_op(b_command_op),.command_value(b_command_value),.command_aux(b_command_aux),.command_cancel(b_command_cancel),.emergency(b_emergency),.accepted_commands(b_accepted_commands));
wire equivalent={a_lease_active,a_response_valid,a_response_seq,a_response_length,a_response_payload,a_command_valid,a_command_op,a_command_value,a_command_aux,a_command_cancel,a_emergency,a_accepted_commands}==={b_lease_active,b_response_valid,b_response_seq,b_response_length,b_response_payload,b_command_valid,b_command_op,b_command_value,b_command_aux,b_command_cancel,b_emergency,b_accepted_commands};


always #10 clk=~clk;
integer checks=0,timeouts=0,expiries=0;
reg [255:0] data;reg [63:0] token;
always @(negedge clk)begin #1;if(rst_n)begin
 if(!equivalent)$fatal(1,"BATCH_DEADLINE_PUBLIC_MISMATCH lease=%0d service=%0d",LEASE_N,SERVICE_N);
 if((a.lease_active||a.hello_pending)&&a.lease_age>=LEASE_N)$fatal(1,"BATCH_LEASE_RANGE");
 if(a.state!=0&&a.service_age>=SERVICE_N)$fatal(1,"BATCH_SERVICE_RANGE");
 checks=checks+1;
end end
always @(posedge clk)if(rst_n)begin
 if(b.expired)expiries=expiries+1;
 if(b_response_valid&&b_response_payload[15:8]==8)timeouts=timeouts+1;
end
task automatic frame(input [15:0] seq,length,input [255:0] bytes);
 begin
  @(negedge clk);frame_seq=seq;frame_length=length;payload=bytes;frame_type=8'h42;
  @(negedge clk);frame_valid=1;
  @(negedge clk);frame_valid=0;repeat(3)@(negedge clk);
 end
endtask
initial begin
 usb_idle=1;command_ready=0;command_done=0;
 repeat(5)@(negedge clk);rst_n=1;
 data=0;data[79:0]={64'h123456789abcdef0,8'd0,8'd1};frame(1,10,data);
 if(LEASE_N<256)begin
  repeat(LEASE_N+5)@(negedge clk);
  if(b.hello_pending||a.hello_pending||expiries<1)$fatal(1,"BATCH_HELLO_LEASE_EXPIRY_VACUOUS");
 end else begin
  token=b_response_payload[95:32];data=0;data[143:0]={token,64'h123456789abcdef0,8'd1,8'd1};frame(2,18,data);
  if(!b_lease_active||!a_lease_active)$fatal(1,"BATCH_DEADLINE_CLAIM");
  data=0;data[151:0]={32'd0,32'd2,8'd1,token,8'd5,8'd1};frame(3,19,data);
  if(SEED_TERMINAL)begin
   // 默认阈值只种入可达的N-2，下一更新沿释放；不以长跑250M拍代替边界检查。
   @(negedge clk);force a.service_age=SERVICE_N-2;force b.service_age=SERVICE_N-2;
   @(negedge clk);release a.service_age;release b.service_age;
   repeat(7)@(negedge clk);
  end else repeat(SERVICE_N+8)@(negedge clk);
  if(timeouts<1||a_lease_active||b_lease_active)$fatal(1,"BATCH_SERVICE_TIMEOUT_VACUOUS service=%0d",SERVICE_N);
 end
 if(checks<8)$fatal(1,"BATCH_DEADLINE_EMPTY");finished=1;
end
endmodule
module tb_batch_deadlines;
`include "sim/result.svh"
wire [8:0] finished;
batch_deadline_case #(.LEASE_N(1)) l1(finished[0]);
batch_deadline_case #(.LEASE_N(2)) l2(finished[1]);
batch_deadline_case #(.LEASE_N(3)) l3(finished[2]);
batch_deadline_case #(.LEASE_N(128)) l128(finished[3]);
batch_deadline_case #(.SERVICE_N(1)) s1(finished[4]);
batch_deadline_case #(.SERVICE_N(2)) s2(finished[5]);
batch_deadline_case #(.SERVICE_N(3)) s3(finished[6]);
batch_deadline_case #(.SERVICE_N(128)) s128(finished[7]);
batch_deadline_case #(.LEASE_N(250000000),.SERVICE_N(5000000),.SEED_TERMINAL(1)) nominal_boundary(finished[8]);
initial begin
 wait(&finished);#5;
 complete_test("tb_batch_deadlines",9);
 $display("PASS tb_batch_deadlines CASES=9 public-output-equivalence and reachable boundaries");$finish;
end
initial begin #2000000;$fatal(1,"BATCH_DEADLINE_BOUND");end
endmodule
