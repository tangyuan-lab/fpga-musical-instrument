`timescale 1ns/1ps
`include "sim/vendor_ddr_startup_slice.sv"
module Gowin_PLL(output wire lock,clkout0,clkout1,clkout2,input wire clkin,init_clk,reset,enclk0,enclk1,enclk2);
 reg test_lock=0,fast=0,gate=0;integer phase_ps=0;
 initial begin
  if(!$value$plusargs("PHASE_PS=%d",phase_ps))phase_ps=0;
  #(phase_ps/1000.0);forever #1.25 fast=~fast;
 end
 always @(negedge fast or posedge reset)if(reset)gate<=0;else gate<=enclk2;
 assign lock=test_lock&&!reset;assign clkout0=0;assign clkout1=clkin&&!reset;assign clkout2=fast&&gate;
endmodule
module DDR3_Memory_Interface_Top(
 input wire memory_clk,clk,rst_n,pll_lock,output wire pll_stop,
 input wire [2:0] cmd,input wire cmd_en,output wire cmd_ready,input wire [28:0] addr,
 input wire [255:0] wr_data,input wire [31:0] wr_data_mask,input wire wr_data_en,wr_data_end,
 output wire wr_data_rdy,output wire [255:0] rd_data,output wire rd_data_valid,rd_data_end,
 input wire sr_req,ref_req,output wire sr_ack,ref_ack,init_calib_complete,clk_out,ddr_rst,input wire burst,
 output wire [14:0] O_ddr_addr,output wire [2:0] O_ddr_ba,
 output wire O_ddr_cs_n,O_ddr_ras_n,O_ddr_cas_n,O_ddr_we_n,O_ddr_clk,O_ddr_clk_n,O_ddr_cke,O_ddr_odt,O_ddr_reset_n,
 output wire [3:0] O_ddr_dqm,inout wire [31:0] IO_ddr_dq,inout wire [3:0] IO_ddr_dqs,IO_ddr_dqs_n
);
 reg training_feedback=0,recalib_feedback=0;
 ddr_startup_slice startup(.clk(clk),.memory_clk(memory_clk),.rst_n(rst_n),.pll_lock(pll_lock),
   .training_complete_feedback(training_feedback),.recalib_feedback(recalib_feedback),
   .pll_stop(pll_stop),.clk_out(clk_out),.ddr_rst(ddr_rst));
 assign init_calib_complete=training_feedback;assign cmd_ready=0;assign wr_data_rdy=0;
 assign rd_data=0;assign rd_data_valid=0;assign rd_data_end=0;assign sr_ack=0;assign ref_ack=0;
endmodule
module tb_ddr_startup_guard;
 GSR GSR(.GSRI(1'b1));
 `include "sim/result.svh"
 reg clk=0,rst_n=0;always #10 clk=~clk;
 wire user_clk,user_rst_n,calibrated,pll_locked;
 workstation_ddr_phy dut(.clk50(clk),.rst_n(rst_n),.reinit_request(1'b0),.user_clk(user_clk),
  .user_rst_n(user_rst_n),.calibrated(calibrated),.pll_locked(pll_locked),
  .cmd(3'd0),.cmd_en(1'b0),.addr(29'd0),.wr_data(256'd0),.wr_data_mask(32'd0),.wr_data_en(1'b0),.wr_data_end(1'b0),.fabric_clk50(),.cmd_ready(),.wr_data_rdy(),.rd_data(),.rd_data_valid(),.rd_data_end(),.ddr_addr(),.ddr_bank(),.ddr_cs(),.ddr_ras(),.ddr_cas(),.ddr_we(),.ddr_ck(),.ddr_ck_n(),.ddr_cke(),.ddr_odt(),.ddr_reset_n(),.ddr_dm(),.ddr_dq(),.ddr_dqs(),.ddr_dqs_n());
 realtime ip_released=0;integer ip_releases=0;
 always @(posedge dut.ip_rst_n)begin ip_released=$realtime;ip_releases=ip_releases+1;end
 always @(posedge dut.memory_clk)if(dut.ip_rst_n&&ip_released>0&&$realtime-ip_released<80.0)
  $fatal(1,"IP release before reset quiet window %0.3f",$realtime-ip_released);
 realtime released=0;integer releases=0,edges=0,captures=0;reg seen=0;
 always @(posedge dut.ddr_rst)seen=1;
 always @(negedge dut.ddr_rst)if(seen)begin released=$realtime;releases=releases+1;end
 always @(posedge dut.memory_clk)begin
  edges=edges+1;
  if(dut.ddr_rst===0&&released>0&&$realtime-released<80.0)$fatal(1,"fast clock before reset quiet window %0.3f",$realtime-released);
 end
 always @(posedge user_clk)if(dut.u_ddr3.startup.\gw3_top/u_ddr_phy_top/n2474_3 ===1'b1&&!dut.ddr_rst)captures=captures+1;
 task automatic wait_capture(input integer expected);
  integer n;begin n=0;while(captures<expected&&n<30000)begin @(negedge clk);n=n+1;end
   if(n>=30000)$fatal(1,"startup guard deadlock captures=%0d stop=%b guard=%b",captures,dut.pll_stop,dut.clock_guard);
  end
 endtask
 initial begin
  repeat(5)@(negedge clk);rst_n=1;dut.Gowin_PLL_inst.test_lock=1;
  wait_capture(1);
  dut.u_ddr3.training_feedback=1;repeat(50)@(negedge clk);
  dut.u_ddr3.recalib_feedback=1;repeat(8)@(negedge clk);dut.u_ddr3.recalib_feedback=0;
  wait_capture(2);
  @(negedge clk);rst_n=0;repeat(5)@(negedge clk);rst_n=1;
  wait_capture(3);
  // 模拟PLL失锁时真实控制器训练状态被清除，不保留失效的完成反馈。
  dut.u_ddr3.training_feedback=0;dut.Gowin_PLL_inst.test_lock=0;
  repeat(5)@(negedge clk);dut.Gowin_PLL_inst.test_lock=1;wait_capture(4);
  if(ip_releases<3)$fatal(1,"IP release coverage insufficient %0d",ip_releases);
  $display("CHECK IP reset releases=%0d minimum quiet interval=80ns",ip_releases);
  if(releases<7||edges<1000)$fatal(1,"guard coverage insufficient releases=%0d edges=%0d",releases,edges);
  complete_test("tb_ddr_startup_guard",releases);$display("PASS tb_ddr_startup_guard captures=%0d releases=%0d edges=%0d",captures,releases,edges);$finish;
 end
 initial begin #2000000;$fatal(1,"guard test global timeout");end
endmodule
