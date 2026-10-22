`timescale 1ns/1ps
module tb_piano_post;
 parameter integer ADSR_MODE=0;
 reg clk=0;always #10 clk=~clk;
 reg rst=0;wire valid;wire signed [15:0] got;
 shared_piano_voice #(.ADSR_ENABLE(ADSR_MODE)) dut(.clk(clk),.rst_n(rst),.sample_tick(1'b0),.note_on(1'b0),.note_off(1'b0),.note_active(1'b0),
  .note_index(5'd0),.velocity(7'd0),.pitch_ratio_q15(16'd32768),.sample_out(got),.sample_valid(valid),.overrun(),
  .pp_ready(1'b0),.pp_valid(1'b0),.pp_data(128'd0),.ps_ready(1'b0),.ps_valid(1'b0),.ps_data(16'd0),
  .ram_ready(1'b0),.ram_valid(1'b0),.ram_q(160'd0),.mul_ready(1'b0),.mul_valid(1'b0),.product0(63'd0),.product1(63'd0),.result_tag(6'd0));
 reg signed [55:0] mix_value;reg [6:0] velocity_value,blend_age;reg signed [15:0] tail;reg [15:0] gain_value;
 reg signed [63:0] velocity_product,shaped,blend_product;
 reg signed [25:0] raw;reg signed [15:0] clipped,expected;reg [23:0] blend_word;
 integer i,cycles,max_cycles=0;
 initial begin
  repeat(4)@(negedge clk);rst=1;repeat(3)@(negedge clk);
  for(i=0;i<8192;i=i+1)begin
   mix_value={$random,$random};velocity_value=i%128;blend_age=i%65;tail=$random;gain_value=$random;
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
   while(!valid&&cycles<32)begin @(negedge clk);cycles=cycles+1;end
   if(!valid||got!==expected)$fatal(1,"Piano post mismatch mode=%0d job=%0d mix=%0d vel=%0d age=%0d gain=%0d got=%0d expected=%0d",ADSR_MODE,i,mix_value,velocity_value,blend_age,gain_value,got,expected);
   if(cycles>max_cycles)max_cycles=cycles;
   if(ADSR_MODE)release dut.adsr_gain;
   @(negedge clk);
  end
  $display("PASS actual piano post ADSR=%0d: 8192 signed56 velocity, clip and blend boundary/random jobs, all velocities and 65 blend ages, max clocks=%0d",ADSR_MODE,max_cycles);$finish;
 end
 initial begin #100000000;$fatal(1,"Piano post watchdog");end
endmodule
