`timescale 1ns/1ps
`include "src/poly4_shared/resource_ports.vh"
module tb_piano_post;
 parameter integer ADSR_MODE=0;
 reg clk=0;always #10 clk=~clk;
 `RESOURCE_WIRES(p_)
 reg rst=0;wire valid;wire signed [15:0] got;
 shared_piano_voice #(.ADSR_ENABLE(ADSR_MODE)) dut(.clk(clk),.rst_n(rst),.sample_tick(1'b0),.note_on(1'b0),.note_off(1'b0),.note_active(1'b0),
  .note_index(5'd0),.velocity(7'd0),.pitch_ratio_q15(16'd32768),.sample_out(got),.sample_valid(valid),.overrun(),
  .pp_ready(1'b0),.pp_valid(1'b0),.pp_data(128'd0),.ps_ready(1'b0),.ps_valid(1'b0),.ps_data(16'd0),
  .ram_ready(1'b0),.ram_valid(1'b0),.ram_q(160'd0),
  .mul_request(p_mul_request),.mul_pair(p_mul_pair),.mul_a0(p_mul_a0),.mul_a1(p_mul_a1),.mul_b0(p_mul_b0),.mul_b1(p_mul_b1),.mul_tag(p_mul_tag),
  .mul_ready(p_mul_ready),.mul_valid(p_mul_valid),.product0(p_product0),.product1(p_product1),.result_tag(p_result_tag));
 // Other clients keep launching signed full-width work while piano uses
 // lane1 when the granted drum job is scalar. Returning drum products may
 // overwrite the shared output on any other cycle.
 reg [31:0] contention=32'h519a4e27;
 function [31:0] next_rng(input [31:0] x);reg [31:0] t;begin t=x^(x<<13);t=t^(t>>17);next_rng=t^(t<<5);end endfunction
 always @(posedge clk)contention<=next_rng(contention);
 wire [2:0] grants,returned;wire [188:0] result0,result1;wire [17:0] result_tags;
 shared_voice_mul #(.RESPONSE_CYCLES(2),.PIANO_SECOND_LANE(1)) pool(.clk(clk),.rst_n(rst),
  .request({p_mul_request,contention[1:0]}),.pair({1'b0,contention[3:2]}),
  .a0({p_mul_a0,{contention[3:0],contention},{contention[7:4],~contention}}),
  .a1({36'd0,{contention[11:8],contention},{contention[15:12],~contention}}),
  .b0({p_mul_b0,contention[26:0],contention[31:5]}),.b1({27'd0,~contention[26:0],~contention[31:5]}),
  .tag({p_mul_tag,contention[5:0],contention[11:6]}),.ready(grants),.response_valid(returned),
  .product0(result0),.product1(result1),.response_tag(result_tags));
 assign p_mul_ready=grants[2];assign p_mul_valid=returned[2];assign p_product0=result0[126+:63];assign p_product1=result1[126+:63];assign p_result_tag=result_tags[12+:6];
 reg signed [55:0] mix_value;reg [6:0] velocity_value,blend_age;reg signed [15:0] tail;reg [15:0] gain_value;
 reg signed [63:0] velocity_product,shaped,blend_product;
 reg signed [25:0] raw;reg signed [15:0] clipped,expected;reg [23:0] blend_word;
 integer i,cycles,max_cycles=0;
 initial begin
  repeat(4)@(negedge clk);rst=1;repeat(3)@(negedge clk);
  for(i=0;i<16640;i=i+1)begin
   mix_value={$random,$random};velocity_value=i%128;blend_age=(i/128)%65;tail=$random;gain_value=$random;
   if(i%16==0)mix_value=56'h80000000000000;
   if(i%16==1)mix_value=56'h7fffffffffffff;
   if(i%16==2)mix_value=-1;
   if(i%16==3)mix_value=0;
   if(i%16==4)mix_value=1;
   if(i%16==5)gain_value=0;
   if(i%16==6)gain_value=65535;
   velocity_product=$signed(mix_value)*$signed({1'b0,velocity_value});raw=velocity_product[63:38];
   shaped=ADSR_MODE?($signed(raw)*$signed({1'b0,gain_value}))>>>16:raw;
   clipped=shaped>32767?32767:shaped< -32768?-32768:shaped;
   blend_product=$signed(clipped)*$signed({1'b0,blend_age})+$signed(tail)*$signed(8'd64-{1'b0,blend_age});
   blend_word=blend_product;expected=blend_word[21:6];
   dut.mix=mix_value;dut.frame_velocity=velocity_value;dut.transition_age=blend_age;dut.transition_tail=tail;
   if(ADSR_MODE)force dut.adsr_gain=gain_value;
   dut.state=dut.VELOCITY;cycles=0;
   @(negedge clk);
   while(!valid&&cycles<256)begin @(negedge clk);cycles=cycles+1;end
   if(!valid||got!==expected)$fatal(1,"Piano post mismatch mode=%0d job=%0d mix=%0d vel=%0d age=%0d gain=%0d got=%0d expected=%0d",ADSR_MODE,i,mix_value,velocity_value,blend_age,gain_value,got,expected);
   if(cycles>max_cycles)max_cycles=cycles;
   if(ADSR_MODE)release dut.adsr_gain;
   @(negedge clk);
  end
  $display("PASS actual piano post ADSR=%0d: 16640 signed56 velocity, clip and blend boundary/random jobs, all velocities and 65 blend ages, max clocks=%0d",ADSR_MODE,max_cycles);$finish;
 end
 initial begin #100000000;$fatal(1,"Piano post watchdog");end
endmodule
