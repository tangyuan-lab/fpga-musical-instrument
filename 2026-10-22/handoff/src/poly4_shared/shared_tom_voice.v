`include "src/poly4_shared/resource_ports.vh"
// Accepted mid/high tom, with two-context modal work and tagged noise work.
module shared_tom_voice #(parameter integer ADSR_ENABLE=0)(
 output wire tn_request,input wire tn_ready,tn_valid,output wire [3:0] tn_address,input wire [127:0] tn_data,
 input wire clk,rst_n,sample_tick,note_on,note_off,note_active,
 input wire [4:0] note_index,input wire [6:0] velocity,input wire [15:0] pitch_ratio_q15,
 output reg signed [15:0] sample_out,output reg sample_valid,output reg active,overrun,
 `RESOURCE_PORTS,
 `DRUM_JOB_PORTS
);
 localparam IDLE=0,MODAL=1,FETCH=2,LOAD=3,ENV=4,HI=5,WAIT_ENV_HI=6,LO=7,LWAIT=8,MAC=9,MWAIT=10,STORE=11,VELOCITY=12,VWAIT=13,ADSR=14,AWAIT=15;
 reg [3:0] state;reg kernel_start,pending,started,frame_first,frame_active;
 reg [1:0] pending_bank,bank,band;reg [6:0] pending_velocity,frame_velocity;reg [15:0] frame_pitch;
 reg [31:0] rng;reg signed [15:0] white;
 reg signed [55:0] mix;reg [127:0] noise_param;
 reg have_param,have_row,param_sent,row_sent,ram_was_write;
 reg [23:0] main_source,onset_source,main_next,onset_next,env;
 reg signed [31:0] old_hi,old_lo,hi_next,lo_next;
 reg env_done,hi_done;reg signed [31:0] pcm;
 wire [15:0] adsr_gain;
 generate if(ADSR_ENABLE)begin:g_adsr
  adsr envelope(.sys_clk(clk),.sys_rst_n(rst_n),.sample_tick(sample_tick),.note_on(note_on),.note_off(note_off),.note_active(note_active),.gain(adsr_gain),.voice_active());
 end else begin:g_bypass
  assign adsr_gain=16'hffff;
 end endgenerate
 function [31:0] rng_next;
  input [31:0] x;reg [31:0] a;
  begin a=x^(x<<13);a=a^(a>>17);rng_next=a^(a<<5);end
 endfunction
 function [23:0] decayed;
  input [23:0] value;input [47:0] product;
  reg [24:0] drop;reg [25:0] difference;
  begin drop={1'b0,product[47:24]}+product[23];if(drop==0)drop=1;
   difference={2'b0,value}-{1'b0,drop};decayed=difference[25]?24'd0:difference[23:0];end
 endfunction
 wire kernel_done=modal_done,kernel_active=modal_active;wire signed [63:0] kernel_sum=modal_sum;
 assign modal_request=kernel_start;assign modal_first=frame_first;assign modal_started=started;
 assign modal_note={3'd0,bank};assign modal_age=17'd0;assign modal_pitch=frame_pitch;
 assign tn_request=state==FETCH&&!param_sent;assign tn_address={bank,band};
 wire noise_read=state==FETCH&&!row_sent;
 assign ram_request=noise_read||state==STORE;
 assign ram_write=state==STORE;
 assign ram_address=9'd384+band;
 assign ram_data={48'd0,main_next,onset_next,hi_next,lo_next};
 reg post_request,post_pair;reg signed [35:0] pa0,pa1;reg signed [26:0] pb0,pb1;reg [5:0] ptag;
 wire signed [31:0] hi_difference=$signed(white)-old_hi;
 wire signed [31:0] lo_difference=hi_next-old_lo;
 wire signed [31:0] noise_difference=hi_next-lo_next;
 wire signed [31:0] raw_pcm=$signed(mix)>>>26;
 always @*begin
  post_request=0;post_pair=0;pa0=0;pa1=0;pb0=0;pb1=0;ptag=6'b100000;
  case(state) /* synthesis parallel_case */
   ENV:begin post_request=1;post_pair=1;pa0={12'd0,main_source};pa1={12'd0,onset_source};pb0={3'd0,noise_param[103:80]};pb1={3'd0,noise_param[79:56]};end
   HI:begin post_request=1;ptag=6'b100001;pa0={{4{hi_difference[31]}},hi_difference};pb0={11'd0,noise_param[47:32]};end
   LO:begin post_request=1;ptag=6'b100010;pa0={{4{lo_difference[31]}},lo_difference};pb0={11'd0,noise_param[23:8]};end
   MAC:begin post_request=1;ptag=6'b100011;pa0={{4{noise_difference[31]}},noise_difference};pb0={3'd0,env};end
   VELOCITY:begin post_request=1;ptag=6'b100100;pa0={{4{raw_pcm[31]}},raw_pcm};pb0={20'd0,frame_velocity};end
   ADSR:begin post_request=1;ptag=6'b100101;pa0={{4{pcm[31]}},pcm};pb0={11'd0,adsr_gain};end
  endcase
 end
 assign mul_request=post_request;
 assign mul_pair=post_pair;
 assign mul_a0=pa0;assign mul_a1=pa1;
 assign mul_b0=pb0;assign mul_b1=pb1;
 assign mul_tag=ptag;
 wire [24:0] difference_env={1'b0,main_next}-{1'b0,onset_next};
 reg signed [56:0] shifted;
 function signed [15:0] clip32(input signed [31:0] v);
  begin clip32=v[31]?((&v[30:15])?v[15:0]:16'h8000):((|v[30:15])?16'h7fff:v[15:0]);end
 endfunction
 function signed [15:0] clip57(input signed [56:0] v);
  begin clip57=v[56]?((&v[55:15])?v[15:0]:16'h8000):((|v[55:15])?16'h7fff:v[15:0]);end
 endfunction
 always @(posedge clk)begin
  if(!rst_n)begin
   state<=IDLE;kernel_start<=0;pending<=0;started<=0;frame_first<=0;frame_active<=0;active<=0;
   pending_bank<=0;bank<=0;band<=0;pending_velocity<=0;frame_velocity<=0;frame_pitch<=32768;
   rng<=32'h12345678;white<=0;sample_out<=0;sample_valid<=0;overrun<=0;
   have_param<=0;have_row<=0;param_sent<=0;row_sent<=0;ram_was_write<=0;env_done<=0;hi_done<=0;
  end else begin
   if(kernel_start&&modal_ready)kernel_start<=0;sample_valid<=0;
   if(note_on)begin pending<=1;pending_bank<=note_index<3?note_index[1:0]:2'd3;pending_velocity<=velocity;end
   if(sample_tick&&state!=IDLE)overrun<=1;
   if(tn_request&&tn_ready)param_sent<=1;
   if(tn_valid)begin noise_param<=tn_data;have_param<=1;end
   if(ram_request&&ram_ready&&state!=MODAL)begin ram_was_write<=ram_write;if(!ram_write)row_sent<=1;end
   if(ram_valid&&state!=MODAL&&!ram_was_write)begin
    main_source<=frame_first?noise_param[127:104]:started?ram_q[111:88]:24'd0;
    onset_source<=frame_first?noise_param[127:104]:started?ram_q[87:64]:24'd0;
    old_hi<=frame_first||!started?32'sd0:ram_q[63:32];old_lo<=frame_first||!started?32'sd0:ram_q[31:0];have_row<=1;
   end
   if(mul_valid&&state!=MODAL)begin
    case(result_tag) /* synthesis parallel_case */
     6'b100000:begin main_next<=frame_first?main_source:decayed(main_source,product0[47:0]);onset_next<=frame_first?onset_source:decayed(onset_source,product1[47:0]);env_done<=1;end
     6'b100001:begin hi_next<=old_hi+($signed(product0[56:0])>>>16);hi_done<=1;end
    endcase
   end
   case(state) /* synthesis parallel_case */
    IDLE:if(sample_tick)begin
     frame_first<=pending||note_on;frame_pitch<=pitch_ratio_q15;frame_active<=0;
     if(pending||note_on)begin
      pending<=0;bank<=note_on?(note_index<3?note_index[1:0]:2'd3):pending_bank;frame_velocity<=note_on?velocity:pending_velocity;
      rng<=rng_next(32'h12345678);white<=rng_next(32'h12345678)>>16;
     end else begin rng<=rng_next(rng);white<=rng_next(rng)>>16;end
     if(started||pending||note_on)begin kernel_start<=1;state<=MODAL;end
     else begin sample_out<=0;sample_valid<=1;active<=0;end
    end
    MODAL:if(kernel_done)begin
     mix<=kernel_sum[55:0];frame_active<=kernel_active;band<=0;have_param<=0;have_row<=0;param_sent<=0;row_sent<=0;state<=FETCH;
    end
    FETCH:if(have_param&&have_row)state<=LOAD;
    LOAD:begin
     // Coefficients can arrive after the state row; trigger sources are read
     // here, after both independent transactions have completed.
     if(frame_first)begin main_source<=noise_param[127:104];onset_source<=noise_param[127:104];end
     env_done<=0;hi_done<=0;state<=ENV;
    end
    ENV:if(mul_ready)state<=HI;
    HI:if(mul_ready)state<=WAIT_ENV_HI;
    WAIT_ENV_HI:if(env_done&&hi_done)begin env<=difference_env[24]?0:difference_env[23:0];if(main_next!=0)frame_active<=1;state<=LO;end
    LO:if(mul_ready)state<=LWAIT;
    LWAIT:if(mul_valid&&result_tag==6'b100010)begin lo_next<=old_lo+($signed(product0[56:0])>>>16);state<=MAC;end
    MAC:if(mul_ready)state<=MWAIT;
    MWAIT:if(mul_valid&&result_tag==6'b100011)begin mix<=mix+$signed(product0[56:0]);state<=STORE;end
    STORE:if(ram_ready)begin
     if(band==3)state<=VELOCITY;
     else begin band<=band+1'b1;have_param<=0;have_row<=0;param_sent<=0;row_sent<=0;state<=FETCH;end
    end
    VELOCITY:if(mul_ready)state<=VWAIT;
    VWAIT:if(mul_valid&&result_tag==6'b100100)begin
     shifted=$signed(product0[56:0])>>>7;pcm<=shifted;
     if(ADSR_ENABLE)state<=ADSR;
     else begin sample_out<=clip32(shifted[31:0]);sample_valid<=1;started<=started||frame_first;active<=frame_active;state<=IDLE;end
    end
    ADSR:if(mul_ready)state<=AWAIT;
    AWAIT:if(mul_valid&&result_tag==6'b100101)begin
     shifted=$signed(product0[56:0])>>>16;sample_out<=clip57(shifted);
     sample_valid<=1;started<=started||frame_first;active<=frame_active;state<=IDLE;
    end
    default:state<=IDLE;
   endcase
  end
 end
endmodule
