`include "src/poly4_shared/resource_ports.vh"
module shared_piano_voice #(parameter integer ADSR_ENABLE=0)(
 output wire pp_request,input wire pp_ready,pp_valid,output wire [10:0] pp_address,input wire [127:0] pp_data,
 output wire ps_request,input wire ps_ready,ps_valid,output wire [9:0] ps_address,input wire [15:0] ps_data,
 input wire clk,rst_n,sample_tick,note_on,note_off,note_active,
 input wire [4:0] note_index,input wire [6:0] velocity,input wire [15:0] pitch_ratio_q15,
 output reg signed [15:0] sample_out,output reg sample_valid,output reg overrun,
 `RESOURCE_PORTS
);
 localparam IDLE=0,MODAL=1,VELOCITY=2,VWAIT=3,VMIDDLE=4,VMWAIT=5,VHIGH=6,VHWAIT=7,
  ADSR=8,AWAIT=9,CLIP=10,BLEND=11,BWAIT=12,BTAIL=13,BTWAIT=14;
 reg [3:0] state;
 reg pending,released,started,trigger_frame,held_frame;
 reg [4:0] pending_note,active_note;reg [6:0] pending_velocity,frame_velocity;
 reg [15:0] frame_pitch;reg [6:0] transition_age;reg signed [15:0] transition_tail,clipped;
 reg kernel_start;
 wire kernel_done;wire signed [63:0] kernel_sum;
 reg signed [55:0] mix;reg signed [42:0] enveloped;
 reg signed [25:0] raw_pcm;
 wire [15:0] adsr_gain;
 generate if(ADSR_ENABLE)begin:g_adsr
  adsr #(.ATTACK_STEP(16'd8192),.DECAY_STEP(16'd64),.SUSTAIN_LEVEL(16'd62259),.RELEASE_STEP(16'd32)) envelope(
   .sys_clk(clk),.sys_rst_n(rst_n),.sample_tick(sample_tick),.note_on(note_on),.note_off(note_off),.note_active(note_active),.gain(adsr_gain),.voice_active());
 end else begin:g_bypass
  assign adsr_gain=16'hffff;
 end endgenerate
 `RESOURCE_WIRES(k_)
 wire [11:0] kernel_sine_address;
 shared_piano_modes modes(.clk(clk),.rst_n(rst_n),.start(kernel_start),.drum_C(1'b0),
  .first(trigger_frame),.started(started),.held(held_frame),.note(active_note),.age(17'd0),.pitch(frame_pitch),
  .done(kernel_done),.active(),.sum(kernel_sum),
  .param_request(pp_request),.param_ready(pp_ready),.param_valid(pp_valid),.param_address(pp_address),.param_data({160'd0,pp_data}),
  .sine_request(ps_request),.sine_ready(ps_ready),.sine_valid(ps_valid),.sine_address(kernel_sine_address),.sine_data(ps_data),`RESOURCE_LINK(k_));
 assign ps_address=kernel_sine_address[9:0];
 assign ram_request=k_ram_request;assign ram_write=k_ram_write;assign ram_address=k_ram_address;assign ram_data=k_ram_data;
 assign k_ram_ready=ram_ready;assign k_ram_valid=ram_valid;assign k_ram_q=ram_q;
 // A local narrow pipeline removes the background piano from the voice's
 // broad drum operand selector. Three exact partial products implement the
 // 56x7 velocity product; only carries that reach bit 38 need retaining.
 reg post_request;reg signed [26:0] operand_a;reg signed [17:0] operand_b;
 
 wire signed [44:0] post_product=product0[44:0];
 wire [1:0] post_valid={mul_valid&&state!=MODAL,1'b0};
 reg [6:0] low_carry;reg [7:0] middle_carry;reg [23:0] blend_first;
 always @*begin
  post_request=0;operand_a=0;operand_b=0;
  case(state) /* synthesis parallel_case */
   VELOCITY:begin post_request=1;operand_a={8'd0,mix[18:0]};operand_b={11'd0,frame_velocity};end
   VMIDDLE:begin post_request=1;operand_a={8'd0,mix[37:19]};operand_b={11'd0,frame_velocity};end
   VHIGH:begin post_request=1;operand_a={{9{mix[55]}},mix[55:38]};operand_b={11'd0,frame_velocity};end
   ADSR:begin post_request=1;operand_a={raw_pcm[25],raw_pcm};operand_b={2'd0,adsr_gain};end
   BLEND:begin post_request=1;operand_a={{11{clipped[15]}},clipped};operand_b={11'd0,transition_age};end
   BTAIL:begin post_request=1;operand_a={{11{transition_tail[15]}},transition_tail};operand_b=18'd64-{11'd0,transition_age};end
  endcase
 end
 assign mul_request=state==MODAL?k_mul_request:post_request;assign mul_pair=0;
 assign mul_a0=state==MODAL?k_mul_a0:{{9{operand_a[26]}},operand_a};
 assign mul_b0=state==MODAL?k_mul_b0:{{9{operand_b[17]}},operand_b};
 assign mul_a1=0;assign mul_b1=0;assign mul_tag=0;
 assign k_mul_ready=mul_ready;assign k_mul_valid=mul_valid&&state==MODAL;assign k_result_tag=result_tag;assign k_product0=product0;assign k_product1=product1;
 wire [26:0] middle_sum={1'b0,post_product[25:0]}+{20'd0,low_carry};
 wire [23:0] blend_product=blend_first+post_product[23:0];

 always @(posedge clk)begin
  if(!rst_n)begin
   state<=IDLE;pending<=0;released<=1;started<=0;kernel_start<=0;
   sample_out<=0;sample_valid<=0;overrun<=0;transition_age<=64;transition_tail<=0;
   pending_note<=0;active_note<=0;pending_velocity<=0;frame_velocity<=0;frame_pitch<=32768;trigger_frame<=0;held_frame<=0;
  end else begin
   kernel_start<=0;sample_valid<=0;
   if(note_off)released<=1;
   if(note_on)begin pending<=1;pending_note<=note_index;pending_velocity<=velocity;released<=0;end
   if(sample_tick&&state!=IDLE)overrun<=1;
   case(state) /* synthesis parallel_case */
    IDLE:if(sample_tick)begin
     trigger_frame<=pending||note_on;held_frame<=note_active&&(!released||note_on)&&!note_off;frame_pitch<=pitch_ratio_q15;
     if(pending||note_on)begin
      pending<=0;active_note<=note_on?note_index:pending_note;frame_velocity<=note_on?velocity:pending_velocity;
      transition_tail<=sample_out;transition_age<=started&&sample_out!=0?0:64;started<=1;
     end else if(transition_age<64)transition_age<=transition_age+1'b1;
     if(started||pending||note_on)begin kernel_start<=1;state<=MODAL;end
     else begin sample_out<=0;sample_valid<=1;end
    end
    MODAL:if(kernel_done)begin mix<=kernel_sum[55:0];state<=VELOCITY;end
    VELOCITY:if(mul_ready)state<=VWAIT;
    VWAIT:if(post_valid[1])begin low_carry<=post_product[25:19];state<=VMIDDLE;end
    VMIDDLE:if(mul_ready)state<=VMWAIT;
    VMWAIT:if(post_valid[1])begin middle_carry<=middle_sum[26:19];state<=VHIGH;end
    VHIGH:if(mul_ready)state<=VHWAIT;
    VHWAIT:if(post_valid[1])begin raw_pcm<=$signed(post_product[25:0])+$signed({18'd0,middle_carry});state<=ADSR_ENABLE?ADSR:CLIP;end
    ADSR:if(mul_ready)state<=AWAIT;
    AWAIT:if(post_valid[1])begin enveloped<=$signed(post_product[42:0])>>>16;state<=CLIP;end
    CLIP:begin
     if(ADSR_ENABLE)clipped<=enveloped[42]?((&enveloped[41:15])?enveloped[15:0]:16'h8000):((|enveloped[41:15])?16'h7fff:enveloped[15:0]);
     else clipped<=raw_pcm[25]?((&raw_pcm[24:15])?raw_pcm[15:0]:16'h8000):((|raw_pcm[24:15])?16'h7fff:raw_pcm[15:0]);
     state<=BLEND;
    end
    BLEND:if(mul_ready)state<=BWAIT;
    BWAIT:if(post_valid[1])begin blend_first<=post_product[23:0];state<=BTAIL;end
    BTAIL:if(mul_ready)state<=BTWAIT;
    BTWAIT:if(post_valid[1])begin sample_out<=blend_product[21:6];sample_valid<=1;state<=IDLE;end
    default:state<=IDLE;
   endcase
  end
 end
endmodule
