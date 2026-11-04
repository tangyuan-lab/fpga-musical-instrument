`timescale 1ns/1ps
module tb_bend_pipeline;
 `include "sim/result.svh"
 GSR GSR(.GSRI(1'b1));
 reg clk=0;always #10 clk=~clk;
 reg rst_n=0,panic=0;reg signed [13:0] bend=0;
 integer cycles=0,checks=0;reg pending=0,due;
 reg [31:0] expected;
 wire [31:0] original_word;
 wire sample_tick=(cycles%1041)==1040;
 unified_models8_32 dut(.clk(clk),.rst_n(rst_n),.sample_tick(sample_tick),.panic(panic),
  .command_valid(1'b0),.command_op(2'd0),.command_source(2'd0),.command_id(32'd0),
  .command_track(5'd16),.command_note(7'd60),.command_velocity(7'd96),.command_timbre(5'd10),
  .custom_ready(8'd0),.bend(bend),.vibrato_depth(8'd23),.vibrato_rate(8'd5),
  .table_write(1'b0),.table_address(11'd0),.table_data(16'd0),.parameter_write(1'b0),.parameter_bank(5'd10),
  .attack_step(12'd64),.decay_step(12'd8),.sustain_level(12'd3072),.release_step(12'd32),
  .mix_valid(1'b0),.mix_track(5'd16),.mix_gain(16'd32768));
 // 原地址直接进同一系数ROM，独立记录旧实现start_frame沿应取的确切值。
 bend_factor_rom reference_rom(.clk(clk),.address(dut.factor_address),.data(original_word));
 always @(posedge clk)begin
  if(!rst_n||panic)pending=0;
  else begin
   due=dut.factor_capture_q;
   if(dut.start_frame)begin
    if(pending)$fatal(1,"bend overlapping capture");
    expected=original_word;pending=1;
   end
   #1;
   if(due)begin
    if(!pending||(^dut.frame_factor)===1'bx||dut.frame_factor!==expected)
     $fatal(1,"bend sample-time changed got=%h expected=%h",dut.frame_factor,expected);
    pending=0;checks=checks+1;
   end
  end
 end
 // 在帧边界附近也逐拍改变输入，不能用稳定零弯音掩盖一拍错位。
 always @(negedge clk)if(rst_n)begin
  cycles=cycles+1;bend=(cycles*3079+997)%16384-8192;
 end
 initial begin
  repeat(4)@(negedge clk);rst_n=1;
  wait(checks==20);@(negedge clk);panic=1;repeat(3)@(negedge clk);panic=0;
  wait(checks==40);
  complete_test("tb_bend_pipeline",checks);$display("PASS tb_bend_pipeline captures=%0d original_sample_time",checks);$finish;
 end
 initial begin #1200000;$fatal(1,"bend bounded wait timeout checks=%0d",checks);end
endmodule
