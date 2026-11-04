`include "src/poly4_shared/resource_ports.vh"
// Keep note/RNG history private; delegate mutually exclusive drum post work
// to the C controller's existing state and arithmetic resources.
module shared_tom_adapter #(parameter integer ADSR_ENABLE=0)(
 input wire clk,rst_n,sample_tick,adsr_tick,note_on,note_off,note_active,
 input wire [4:0] note_index,input wire [6:0] velocity,input wire [15:0] pitch_ratio_q15,
 output reg signed [15:0] sample_out,output reg sample_valid,active,overrun,
 `DRUM_JOB_PORTS,
 output wire post_request,input wire post_ready,post_valid,post_active,
 input wire signed [15:0] post_sample,
 output wire post_first,post_started,post_modal_active,post_adsr_enable,
 output wire [1:0] post_bank,output wire [6:0] post_velocity,
 output wire signed [15:0] post_white,output wire signed [55:0] post_sum,
 output wire [15:0] post_adsr_gain
);
 localparam IDLE=0,MODAL=1,POST=2,WAIT_POST=3;
 reg [1:0] state,bank,pending_bank;
 reg kernel_start,pending,started,frame_first,frame_active;
 reg [6:0] pending_velocity,frame_velocity;reg [15:0] frame_pitch;
 reg [31:0] rng;reg signed [15:0] white;reg signed [55:0] mix;
 function [31:0] rng_next(input [31:0] x);
  reg [31:0] a;begin a=x^(x<<13);a=a^(a>>17);rng_next=a^(a<<5);end
 endfunction
 generate if(ADSR_ENABLE)begin:g_adsr
  // The accepted envelope keeps evolving while this timbre is unselected.
  // Only the modal/post job is gated; retriggers preserve envelope history.
  adsr envelope(.sys_clk(clk),.sys_rst_n(rst_n),.sample_tick(adsr_tick),
   .note_on(note_on),.note_off(note_off),.note_active(note_active),.gain(post_adsr_gain),.voice_active());
 end else begin:g_bypass
  assign post_adsr_gain=16'hffff;
 end endgenerate
 assign modal_request=kernel_start;assign modal_first=frame_first;assign modal_started=started;
 assign modal_note={3'd0,bank};assign modal_age=0;assign modal_pitch=frame_pitch;
 assign post_request=state==POST;assign post_first=frame_first;assign post_started=started;
 assign post_modal_active=frame_active;assign post_adsr_enable=ADSR_ENABLE!=0;
 assign post_bank=bank;assign post_velocity=frame_velocity;assign post_white=white;assign post_sum=mix;
 always @(posedge clk)begin
  if(!rst_n)begin
   state<=IDLE;kernel_start<=0;pending<=0;started<=0;frame_first<=0;frame_active<=0;
   bank<=0;pending_bank<=0;pending_velocity<=0;frame_velocity<=0;frame_pitch<=32768;
   rng<=32'h12345678;white<=0;sample_out<=0;sample_valid<=0;active<=0;overrun<=0;
  end else begin
   sample_valid<=0;
   if(kernel_start&&modal_ready)kernel_start<=0;
   if(note_on)begin pending<=1;pending_bank<=note_index<3?note_index[1:0]:2'd3;pending_velocity<=velocity;end
   if(sample_tick&&state!=IDLE)overrun<=1;
   case(state)
    IDLE:if(sample_tick)begin
     frame_first<=pending||note_on;frame_pitch<=pitch_ratio_q15;frame_active<=0;
     if(pending||note_on)begin
      pending<=0;bank<=note_on?(note_index<3?note_index[1:0]:2'd3):pending_bank;
      frame_velocity<=note_on?velocity:pending_velocity;
      rng<=rng_next(32'h12345678);white<=rng_next(32'h12345678)>>16;
     end else begin rng<=rng_next(rng);white<=rng_next(rng)>>16;end
     if(started||pending||note_on)begin kernel_start<=1;state<=MODAL;end
     else begin sample_out<=0;sample_valid<=1;active<=0;end
    end
    MODAL:if(modal_done)begin mix<=modal_sum[55:0];frame_active<=modal_active;state<=POST;end
    POST:if(post_ready)state<=WAIT_POST;
    WAIT_POST:if(post_valid)begin
     sample_out<=post_sample;sample_valid<=1;active<=post_active;
     started<=started||frame_first;state<=IDLE;
    end
   endcase
  end
 end
endmodule
