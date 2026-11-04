// Stable 48 kHz output adapter. The C core has a two-frame scheduling delay
// plus the FIR's twenty-sample delay. Every 48 kHz tick produces one valid sample.
module tom_poly4_voice #(parameter integer ADSR_ENABLE=0)(
 input wire clk,rst_n,sample_tick,note_on,note_off,note_active,input wire [6:0] velocity,input wire [15:0] pitch_ratio_q15,
 output wire cp_request,input wire cp_ready,cp_valid,
 output wire [7:0] cp_address,input wire [287:0] cp_data,
 output reg signed [15:0] sample_out,output reg sample_valid,output wire overrun
);
 reg half,pending;reg [6:0] pending_velocity,core_velocity;
 reg signed [15:0] saved_even,saved_odd,next_odd;
 wire tick24=sample_tick&&!half;
 wire trigger=tick24&&(pending||note_on);
 wire [6:0] trigger_velocity=note_on?velocity:pending_velocity;
 wire signed [15:0] ce,co;wire pair_valid;
 wire [15:0] adsr_gain;
 generate if(ADSR_ENABLE)begin:g_adsr
  adsr envelope(.sys_clk(clk),.sys_rst_n(rst_n),.sample_tick(sample_tick),
   .note_on(note_on),.note_off(note_off),.note_active(note_active),.gain(adsr_gain),.voice_active());
 end else begin:g_bypass
  assign adsr_gain=16'hffff;
 end endgenerate
 wire signed [15:0] selected=pending||note_on?16'sd0:(half?next_odd:saved_even);
 wire signed [32:0] shaped=selected*$signed({1'b0,adsr_gain});
 tom_poly4_core core(.clk(clk),.rst_n(rst_n),.tick24(tick24),.note_on(trigger),
  .velocity(trigger?trigger_velocity:core_velocity),.pitch_ratio_q15(pitch_ratio_q15),
  .cp_request(cp_request),.cp_ready(cp_ready),.cp_valid(cp_valid),.cp_address(cp_address),.cp_data(cp_data),
  .even_q20(),.odd_q20(),.raw_q20(),.even_pcm(ce),.odd_pcm(co),.pair_valid(pair_valid),.raw_valid(),.overrun(overrun));
 always @(posedge clk)begin
  if(!rst_n)begin
   half<=0;pending<=0;pending_velocity<=0;core_velocity<=0;
   saved_even<=0;saved_odd<=0;next_odd<=0;sample_out<=0;sample_valid<=0;
  end else begin
   sample_valid<=0;
   if(pair_valid&&!pending&&!note_on)begin saved_even<=ce;saved_odd<=co;end
   if(note_on)begin pending<=1;pending_velocity<=velocity;saved_even<=0;saved_odd<=0;next_odd<=0;end
   if(trigger)begin pending<=0;core_velocity<=trigger_velocity;end
   if(sample_tick)begin
    half<=!half;sample_valid<=1;
    sample_out<=ADSR_ENABLE?shaped>>>16:selected;
    if(!half)next_odd<=pending||note_on?0:saved_odd;
   end
  end
 end
endmodule
