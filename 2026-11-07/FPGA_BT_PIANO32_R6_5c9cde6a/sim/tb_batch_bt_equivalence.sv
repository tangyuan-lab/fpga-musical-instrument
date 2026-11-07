`timescale 1ns/1ps
module tb_batch_bt_equivalence;
`include "sim/result.svh"
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
r7_bt_control #(.BUILD_ID(32'h12345678),.LEASE_CYCLES(2048),.SERVICE_CYCLES(128),.EARLY_FRAME_FIELDS(1)) a(.clk(clk),.rst_n(rst_n),.frame_valid(frame_valid),.frame_type(frame_type),.frame_seq(frame_seq),.frame_length(frame_length),.payload(payload),.usb_idle(usb_idle),.external_cancel(external_cancel),.status_data(status_data),.response_busy(response_busy),.command_ready(command_ready),.command_done(command_done),.command_result(command_result),.lease_active(a_lease_active),.response_valid(a_response_valid),.response_seq(a_response_seq),.response_length(a_response_length),.response_payload(a_response_payload),.command_valid(a_command_valid),.command_op(a_command_op),.command_value(a_command_value),.command_aux(a_command_aux),.command_cancel(a_command_cancel),.emergency(a_emergency),.accepted_commands(a_accepted_commands));
reference_batch_bt_control #(.BUILD_ID(32'h12345678),.LEASE_CYCLES(2048),.SERVICE_CYCLES(128)) b(.clk(clk),.rst_n(rst_n),.frame_valid(frame_valid),.frame_type(frame_type),.frame_seq(frame_seq),.frame_length(frame_length),.payload(payload),.usb_idle(usb_idle),.external_cancel(external_cancel),.status_data(status_data),.response_busy(response_busy),.command_ready(command_ready),.command_done(command_done),.command_result(command_result),.lease_active(b_lease_active),.response_valid(b_response_valid),.response_seq(b_response_seq),.response_length(b_response_length),.response_payload(b_response_payload),.command_valid(b_command_valid),.command_op(b_command_op),.command_value(b_command_value),.command_aux(b_command_aux),.command_cancel(b_command_cancel),.emergency(b_emergency),.accepted_commands(b_accepted_commands));
wire equivalent={a_lease_active,a_response_valid,a_response_seq,a_response_length,a_response_payload,a_command_valid,a_command_op,a_command_value,a_command_aux,a_command_cancel,a_emergency,a_accepted_commands}==={b_lease_active,b_response_valid,b_response_seq,b_response_length,b_response_payload,b_command_valid,b_command_op,b_command_value,b_command_aux,b_command_cancel,b_emergency,b_accepted_commands};

always #10 clk=~clk;
integer cycles=0,checks=0,accepted=0,cancels=0,panics=0,i;
reg auto_complete=1;
reg [63:0] token;reg [255:0] data;
always @(posedge clk)begin
    cycles<=cycles+1;
    if(auto_complete)command_done<=a_command_valid&&command_ready;
    if(rst_n&&a_command_valid&&command_ready)accepted=accepted+1;
    if(rst_n&&a_command_cancel)cancels=cancels+1;
    if(rst_n&&a_emergency)panics=panics+1;
end
always @(posedge clk)begin
    if(rst_n&&!equivalent)$fatal(1,"BT_URGENT_PRE_EDGE_MISMATCH cycle=%0d",cycles);
end
always @(negedge clk)begin
    #1;if(rst_n)begin
        if(!equivalent)$fatal(1,"BT_SEQUENCE_PUBLIC_MISMATCH cycle=%0d",cycles);
        checks=checks+1;
        if(a_command_valid&&((^{a_command_op,a_command_value,a_command_aux})===1'bx))$fatal(1,"BT_SEQUENCE_ACCEPT_X");
    end
end
task automatic frame(input [15:0] seq,length,input [255:0] bytes);
    begin
        @(negedge clk);frame_seq=seq;frame_length=length;payload=bytes;frame_type=8'h42;frame_valid=0;
        @(negedge clk);frame_valid=1;
        @(negedge clk);frame_valid=0;
        repeat(5)@(negedge clk);
    end
endtask
task automatic claim;
    begin
        @(negedge clk);external_cancel=1;
        repeat(2)@(negedge clk);external_cancel=0;
        data=0;data[79:0]={64'h123456789abcdef0,8'd0,8'd1};frame(1,10,data);
        token=b_response_payload[95:32];
        data=0;data[143:0]={token,64'h123456789abcdef0,8'd1,8'd1};frame(2,18,data);
        if(!a_lease_active)$fatal(1,"BT_SEQUENCE_CLAIM");
    end
endtask
initial begin
    usb_idle=1;command_ready=1;status_data=256'h12345678;
    repeat(6)@(negedge clk);rst_n=1;
    claim();
    for(i=3;i<90;i=i+1)begin
        data=0;data[151:0]={32'd0,32'd2,8'd1,token,8'd5,8'd1};frame(i,19,data);
        if(i%9==0)frame(i,19,data); // 重复请求必须沿用原回复归属
    end
    // 覆盖8位分组边界、最高有效序号和禁止的ffff。
    data=0;data[79:0]={token,8'd4,8'd1};frame(255,10,data);frame(256,10,data);
    frame(32767,10,data);frame(32768,10,data);frame(65534,10,data);frame(65535,10,data);frame(0,10,data);
    claim();command_ready=0;
    data=0;data[151:0]={32'd0,32'd2,8'd1,token,8'd5,8'd1};frame(3,19,data);
    data=0;data[79:0]={token,8'd6,8'd1};frame(16'hffff,10,data);
    if(!a_command_valid||a_command_cancel)$fatal(1,"CLOSURE_FFFF_CANCELLED_PENDING");frame(4,10,data);
    command_ready=1;
    claim();
    // 完整帧中的未知序号不得接受或取消；控制器全部公开输出须与原版一致。
    data=0;data[79:0]={token,8'd6,8'd1};frame(16'h00x5,10,data);frame(16'hz005,10,data);
    data[87:80]=8'hxx;frame(5,10,data);
    repeat(2100)@(negedge clk); // 租约超时及恢复
    claim();data=0;data[151:0]={32'd0,32'd2,8'd1,token,8'd5,8'd1};frame(3,19,data);
    repeat(12)@(negedge clk);
    if(accepted<80||cancels<1||panics<1||checks<1000)$fatal(1,"BT_SEQUENCE_VACUOUS accepted=%0d cancels=%0d panics=%0d",accepted,cancels,panics);
    // 排队命令尚未握手，急停有效的同一沿不得误接受旧PLAY/控制。
    claim();auto_complete=0;command_done=0;command_ready=0;
    data=0;data[151:0]={32'd0,32'd2,8'd1,token,8'd5,8'd1};frame(400,19,data);
    data=0;data[79:0]={token,8'd6,8'd1};
    @(negedge clk);payload=data;frame_seq=401;frame_length=10;frame_type=8'h42;
    @(negedge clk);frame_valid=1;command_ready=1;
    #2;if(!a_command_cancel||a_command_valid)$fatal(1,"BT_URGENT_SAME_EDGE_CANCEL");
    @(negedge clk);frame_valid=0;repeat(5)@(negedge clk);
    // 预判沿恰好完成：last_seq更新、回复占用必须与旧控制器逐周期一致。
    claim();command_ready=1;
    data=0;data[151:0]={32'd0,32'd2,8'd1,token,8'd5,8'd1};frame(500,19,data);
    data=0;data[79:0]={token,8'd6,8'd1};
    @(negedge clk);payload=data;frame_seq=499;frame_length=10;command_done=1;
    @(negedge clk);frame_valid=1;command_done=0;
    @(negedge clk);frame_valid=0;repeat(5)@(negedge clk);
    // 撤销后旧pending_seq仍高，新会话低序号急停不得被旧pending误拒绝。
    claim();data=0;data[79:0]={token,8'd6,8'd1};frame(4,10,data);
    // CRC预判沿与外部取消相邻：租约失效必须即时压住旧资格位。
    claim();command_ready=0;
    data=0;data[151:0]={32'd0,32'd2,8'd1,token,8'd5,8'd1};frame(3,19,data);
    data=0;data[79:0]={token,8'd6,8'd1};
    @(negedge clk);payload=data;frame_seq=4;frame_length=10;external_cancel=1;
    @(negedge clk);frame_valid=1;external_cancel=0;
    @(negedge clk);frame_valid=0;repeat(5)@(negedge clk);
    if(!equivalent)$fatal(1,"BT_URGENT_FINAL_MISMATCH");
    complete_test("tb_batch_bt_equivalence",checks);
    $display("PASS tb_batch_bt_equivalence CHECKS=%0d ACCEPTED=%0d CANCELS=%0d PANICS=%0d",checks,accepted,cancels,panics);$finish;
end
initial begin #4000000;$fatal(1,"BT_SEQUENCE_BOUND");end
endmodule
