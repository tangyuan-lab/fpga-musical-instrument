`timescale 1ns/1ps
// 真实桥/FIFO：停钟释放、半完成写取消、响应背压和不复位重启；不模拟模拟PHY。
module tb_ddr_bridge_recovery;
 `include "sim/result.svh"
 reg ac=0,mc=0,mem_run=0,ar=0,mr=0,cal=0;
 always #10 ac=~ac;
 always begin #5;if(mem_run)mc=~mc;else mc=0;end
 reg rv=0,rr=1,cr=1,dr=1;
 wire ready,rready,pv,pe,reinit,ce,we,wend;
 wire [2:0] cmd;wire [28:0] addr;wire [255:0] wd,pdata;wire [31:0] mask;
 integer commands=0,words=0,responses=0,checks=0;
 workstation_ddr_bridge #(.TIMEOUT(300)) dut(
  .app_clk(ac),.app_rst_n(ar),.mem_clk(mc),.mem_rst_n(mr),.calibrated(cal),
  .req_valid(rv),.req_ready(rready),.req_write(1'b1),.req_address(32'h100),
  .req_data(256'h12345678),.req_mask(32'h0),.resp_valid(pv),.resp_ready(rr),
  .resp_error(pe),.resp_data(pdata),.ready(ready),.reinit_request(reinit),
  .cmd(cmd),.cmd_en(ce),.cmd_ready(cr),.addr(addr),.wr_data(wd),.wr_data_mask(mask),
  .wr_data_en(we),.wr_data_end(wend),.wr_data_rdy(dr),
  .rd_data(256'd0),.rd_data_valid(1'b0),.rd_data_end(1'b0));
 always @(posedge mc)begin
  if((^{ce,we})===1'bx)$fatal(1,"DDR enables X");
  if(ce&&cr)begin commands=commands+1;if(cmd!==0||addr!==29'h40)$fatal(1,"DDR command mismatch");end
  if(we&&dr)begin words=words+1;if(wd!==256'h12345678||mask!==0||wend!==1)$fatal(1,"DDR data mismatch");end
 end
 always @(posedge ac)if(pv&&rr)begin
  if(pe!==0||pdata!==0)$fatal(1,"response data/X");
  responses=responses+1;
 end
 task automatic wait_online;
  integer n;begin
   n=0;while(ready!==1&&n<100)begin @(negedge ac);n=n+1;end
   if(n>=100)$fatal(1,"bridge online timeout");checks=checks+1;
  end
 endtask
 task automatic issue;
  integer n;begin
   @(negedge ac);rv=1;n=0;
   while(rready!==1&&n<100)begin @(negedge ac);n=n+1;end
   if(n>=100)$fatal(1,"request acceptance timeout");
   @(posedge ac);@(negedge ac);rv=0;checks=checks+1;
  end
 endtask
 task automatic wait_response(input integer expected);
  integer n;begin
   n=0;while(responses<expected&&n<200)begin @(negedge ac);n=n+1;end
   if(responses!=expected)$fatal(1,"response missing/duplicate %0d/%0d",responses,expected);
   checks=checks+1;
  end
 endtask
 initial begin
  repeat(4)@(negedge ac);ar=1;mr=1;cal=1;
  repeat(12)begin @(negedge ac);if(ready!==0||rready!==0)$fatal(1,"ready before remote clock release");end
  checks=checks+1;mem_run=1;wait_online();
  issue();wait_response(1);
  if(commands!=1||words!=1)$fatal(1,"first transaction duplicated");
  // 命令已收、数据暂停；取消后不可提交旧响应。
  dr=0;issue();repeat(12)@(negedge ac);
  if(commands!=2||words!=1||responses!=1)$fatal(1,"half-complete case not reached");
  cal=0;#1;if(ready!==0||pv!==0||ce!==0||we!==0)$fatal(1,"calibration loss did not cancel");
  repeat(8)@(negedge ac);
  if(responses!=1)$fatal(1,"stale response after cancel");
  checks=checks+1;dr=1;cal=1;wait_online();
  rr=0;issue();repeat(15)@(negedge ac);
  if(pv!==1||rready!==0)$fatal(1,"response backpressure not held");
  repeat(10)begin @(negedge ac);if(pv!==1||pe!==0||pdata!==0)$fatal(1,"stalled response changed");end
  rr=1;wait_response(2);
  // 数据已收、命令暂停；另一半完成场景不产生重复数据。
  cr=0;issue();repeat(12)@(negedge ac);
  if(commands!=3||words!=3)$fatal(1,"opposite half-complete case not reached %0d/%0d",commands,words);
  mr=0;#1;if(ready!==0||pv!==0)$fatal(1,"memory reset did not cancel");
  repeat(8)@(negedge ac);mr=1;cr=1;wait_online();issue();wait_response(3);
  repeat(12)@(negedge ac);
  if(commands!=4||words!=4||responses!=3||reinit!==0)$fatal(1,"final counters/stale/reinit %0d/%0d/%0d",commands,words,responses);
  complete_test("tb_ddr_bridge_recovery",checks);$display("PASS tb_ddr_bridge_recovery checks=%0d",checks);$finish;
 end
 initial begin #100000;$fatal(1,"bridge recovery timeout");end
endmodule
