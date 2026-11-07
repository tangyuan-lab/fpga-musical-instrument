`timescale 1ns/1ps
// 仅验证真实封装的复位契约；两个厂商IP替身不模拟PHY校准或DDR物理时序。
module Gowin_PLL(output wire lock,clkout0,clkout1,clkout2,input wire clkin,init_clk,reset,enclk0,enclk1,enclk2);
 reg test_lock=0;
 reg shifted=0;initial begin #3;forever #10 shifted=~shifted;end
 assign lock=test_lock;assign clkout0=clkin;
 assign clkout1=(enclk1&&!reset)?shifted:1'b0;assign clkout2=clkin;
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
 assign pll_stop=1;assign clk_out=clk;assign init_calib_complete=0;assign ddr_rst=~rst_n;
 assign cmd_ready=0;assign wr_data_rdy=0;assign rd_data=0;assign rd_data_valid=0;assign rd_data_end=0;
 assign sr_ack=0;assign ref_ack=0;
endmodule
module tb_ddr_control_clock;
 `include "sim/result.svh"
 reg clk50=0,rst_n=0,reinit_request=0;always #10 clk50=~clk50;
 wire user_clk,user_rst_n,calibrated,pll_locked;
 workstation_ddr_phy dut(.clk50(clk50),.rst_n(rst_n),.reinit_request(reinit_request),
  .user_clk(user_clk),.user_rst_n(user_rst_n),.calibrated(calibrated),.pll_locked(pll_locked),
  .cmd(3'd0),.cmd_en(1'b0),.addr(29'd0),.wr_data(256'd0),.wr_data_mask(32'd0),.wr_data_en(1'b0),.wr_data_end(1'b0),
  .fabric_clk50(),.cmd_ready(),.wr_data_rdy(),.rd_data(),.rd_data_valid(),.rd_data_end(),
  .ddr_addr(),.ddr_bank(),.ddr_cs(),.ddr_ras(),.ddr_cas(),.ddr_we(),.ddr_ck(),.ddr_ck_n(),
  .ddr_cke(),.ddr_odt(),.ddr_reset_n(),.ddr_dm(),.ddr_dq(),.ddr_dqs(),.ddr_dqs_n());
 time last_edge;integer edges=0,releases=0;
 always @(posedge dut.u_ddr3.clk)begin
  last_edge=$time;
  if(rst_n&&dut.pll_lock&&dut.recovery==0)edges=edges+1;else edges=0;
 end
 always @(posedge dut.ip_rst_n)begin
  if($time!=last_edge||edges<3)$fatal(1,"DDR reset released outside IP control clock or before three edges");
  if(dut.u_ddr3.clk!==dut.fabric_clk50)$fatal(1,"DDR control clock is still raw reference");
  releases=releases+1;
 end
 task automatic wait_ready;
  integer w;
  begin w=0;while(!user_rst_n&&w<300)begin @(negedge clk50);w=w+1;end
   if(w>=300)$fatal(1,"DDR reset release timeout");end
 endtask
 initial begin
  repeat(4)@(negedge clk50);rst_n=1;repeat(260)@(negedge clk50);
  #7;dut.Gowin_PLL_inst.test_lock=1;wait_ready();
  #3;dut.Gowin_PLL_inst.test_lock=0;#1;
  if(dut.ip_rst_n!==0||user_rst_n!==0)$fatal(1,"PLL loss did not assert reset");
  #7;dut.Gowin_PLL_inst.test_lock=1;wait_ready();
  @(negedge clk50);reinit_request=1;repeat(4)@(negedge clk50);reinit_request=0;
  if(dut.ip_rst_n!==0)$fatal(1,"reinit did not hold IP reset");wait_ready();
  #3;rst_n=0;#1;if(user_rst_n!==0)$fatal(1,"external reset assertion");
  #7;rst_n=1;wait_ready();
  if(releases!=4)$fatal(1,"reset recovery count %0d",releases);
  complete_test("tb_ddr_control_clock",releases);$display("PASS tb_ddr_control_clock releases=%0d",releases);$finish;
 end
 initial begin #50000;$fatal(1,"DDR reset test timeout");end
endmodule
