`include "src/poly4_shared/resource_ports.vh"
// Current modal arithmetic overlaps the following coefficient/state prefetch.
// One fixed-width datapath serves C and legacy drums; accepted rounding and
// state writeback formats remain distinct. Four physical voice slots remain.
module shared_drum_stream #(parameter integer EXTERNAL_BANKS=0)(
 input wire clk,rst_n,start,first,started,held,drum_C,
 input wire [4:0] note,input wire [16:0] age,input wire [15:0] pitch,
 output reg done,output reg active,output wire signed [63:0] sum,
 output wire param_request,input wire param_ready,param_valid,output wire [10:0] param_address,input wire [287:0] param_data,
 input wire [287:0] retained_parameter,input wire [159:0] retained_row,
 output wire sine_request,input wire sine_ready,sine_valid,output wire [11:0] sine_address,input wire signed [15:0] sine_data,
 `RESOURCE_PORTS
);
 localparam IDLE=0,LOAD=1,PG=2,RUN=3;
 reg [1:0] state;reg is_C,f_first,f_started;
 reg [4:0] f_note;reg [16:0] f_age;reg [15:0] f_pitch;
 reg [6:0] index;wire [6:0] modes=is_C?49:64;
 reg pp_pending,pp_loaded,read_pending,row_loaded,ram_was_write;
 reg [5:0] pp_index,read_index;
  wire [287:0] normalized_parameter=is_C?param_data:
   {56'd0,8'd0,param_data[191:168],8'd0,param_data[191:168],param_data[167:120],param_data[223:192],param_data[255:224],param_data[119:88],param_data[87:64]};
  wire [127:0] normalized_row=is_C?ram_q[127:0]:
   {ram_q[111:80],8'd0,ram_q[79:56],8'd0,ram_q[55:32],ram_q[31:0]};
 wire [287:0] parameter_buffer;
 wire [127:0] row_buffer;
 generate if(EXTERNAL_BANKS)begin:g_external_banks
  assign parameter_buffer=retained_parameter;
  assign row_buffer=is_C?retained_row[127:0]:
   {retained_row[111:80],8'd0,retained_row[79:56],8'd0,retained_row[55:32],retained_row[31:0]};
 end else begin:g_private_banks
  reg [287:0] parameters;reg [127:0] row;
  assign parameter_buffer=parameters;assign row_buffer=row;
  always @(posedge clk)if(rst_n)begin
   if(param_valid)parameters<=normalized_parameter;
   if(ram_valid&&!ram_was_write)row<=normalized_row;
  end
 end endgenerate
 wire [287:0] coefficient=parameter_buffer;
 wire [127:0] old_row=row_buffer;
 reg [31:0] source_main,source_onset;
 reg [31:0] next_main,next_onset,next_phase,next_glide,envelope;
 reg [32:0] increment;reg signed [15:0] sine;
 reg [23:0] gained;
 // At most 64 signed 32x16 amplitudes: a signed 54-bit sum is exact.
 wire signed [53:0] accumulator;
 assign sum={{10{accumulator[53]}},accumulator};
 reg envelope_pending,env_ready,phase_ready,sine_sent,have_sine,gain_sent,gain_ready,amp_sent,amp_ready,state_written;
 // The current coefficient/row is needed through the PG result. Launch the
 // following prefetch only after PG is granted. Its earliest buffer update
 // coincides with that last use, so the old value is read before the NBA.
 assign param_request=pp_pending&&state!=PG;
 assign param_address=is_C?{5'd0,pp_index}:{3'd0,f_note[1:0],pp_index};
 assign sine_request=state==RUN&&phase_ready&&!sine_sent;
 assign sine_address=next_phase[31:20];
 assign ram_write=state==RUN&&env_ready&&phase_ready&&!state_written;
 assign ram_request=ram_write||(read_pending&&state!=PG&&!(state==RUN&&!phase_ready));
 assign ram_address=ram_write?(is_C?{2'd0,index}:9'd320+index):(is_C?{3'd0,read_index}:9'd320+read_index);
 assign ram_data=is_C?{32'd0,next_phase,next_main,next_onset,next_glide}:{48'd0,next_phase,next_main[23:0],next_onset[23:0],next_glide};
 wire [31:0] load_main=f_first?parameter_buffer[231:200]:is_C||f_started?row_buffer[95:64]:0;
 wire [31:0] load_onset=f_first?parameter_buffer[199:168]:is_C||f_started?row_buffer[63:32]:0;
 wire [31:0] glide=f_first?coefficient[55:24]:is_C||f_started?old_row[31:0]:0;
 wire signed [33:0] tom_frequency=$signed({2'b00,coefficient[87:56]})+$signed(glide);
 wire [31:0] C_frequency=tom_frequency[31:0];
 wire signed [35:0] frequency_operand=is_C?{{4{C_frequency[31]}},C_frequency}:tom_frequency[33]?36'd0:(|tom_frequency[32:31]) ? 36'h07fffffff : {4'd0,tom_frequency[31:0]};
 wire [17:0] alias_roll=18'd131072-{1'b0,increment[30:14]}-(|increment[13:0]);
 wire [23:0] alias_factor=(|increment[32:31])?24'd0:(&increment[30:29])?{6'd0,alias_roll}:24'd32768;
 wire fresh_gain=mul_valid&&result_tag==2;
 wire [23:0] current_gain=fresh_gain?product0[38:15]:gained;
 wire signed [15:0] current_sine=have_sine?sine:sine_data;
 reg request,pair;reg [5:0] tag;reg signed [35:0] a0,a1;reg signed [26:0] b0,b1;
 assign mul_request=request;assign mul_pair=pair;assign mul_tag=tag;assign mul_a0=a0;assign mul_a1=a1;assign mul_b0=b0;assign mul_b1=b1;
 always @*begin
  request=0;pair=0;tag=0;a0=0;a1=0;b0=0;b1=0;
  case(state) /* synthesis parallel_case */
   LOAD:if(pp_loaded&&row_loaded)begin
    request=1;pair=1;a0=is_C?{{4{load_main[31]}},load_main}:{4'd0,load_main};a1=is_C?{{4{load_onset[31]}},load_onset}:{4'd0,load_onset};
    b0={3'd0,parameter_buffer[167:144]};b1={3'd0,parameter_buffer[143:120]};
   end
   PG:begin request=1;pair=1;tag=1;a0={{4{glide[31]}},glide};b0={3'd0,coefficient[23:0]};a1=frequency_operand;b1={11'd0,f_pitch};end
   RUN:begin
    if(!is_C&&env_ready&&phase_ready&&!gain_sent)begin request=1;tag=2;a0={12'd0,envelope[23:0]};b0={3'd0,alias_factor};end
    else if(env_ready&&(have_sine||sine_valid)&&(is_C||gain_ready||fresh_gain)&&!amp_sent)begin
     request=1;tag=3;
     if(is_C)begin a0={{4{envelope[31]}},envelope};b0={{11{current_sine[15]}},current_sine};end
     else begin a0={{20{current_sine[15]}},current_sine};b0={3'd0,current_gain};end
    end
   end
  endcase
 end
 function [32:0] rounded_drop;
  input [62:0] p;reg [31:0] upper,rounded;
  begin
   upper=is_C?p[55:24]:{8'd0,p[47:24]};
   rounded=upper+p[23];
   rounded_drop=rounded==0?33'd1:{1'b0,rounded};
  end
 endfunction
 // Fold the rounding bit into the subtraction carry. Preserve the original
 // 32-bit rounding wrap and the minimum decrement of one exactly.
 function [31:0] decayed_product;
  input [31:0] value;input [62:0] p;
  reg [31:0] upper,operand;reg decrement;reg [33:0] difference;
  begin
   upper=is_C?p[55:24]:{8'd0,p[47:24]};
   operand=(&upper)&&p[23]?32'd0:upper;
   decrement=p[23]||upper==0;
   difference={2'b0,value}-{2'b0,operand}-decrement;
   decayed_product=difference[33]?32'd0:difference[31:0];
  end
 endfunction
 function [31:0] decayed;
  input [31:0] value;input [32:0] drop;reg [33:0] difference;
  begin difference={2'b0,value}-{1'b0,drop};decayed=difference[33]?0:difference[31:0];end
 endfunction
 wire signed [33:0] glide_drop=$signed({product0[56],product0[56:24]})+$signed({33'd0,product0[23]});
 wire [31:0] glide_adjust=glide_drop!=0?glide_drop[31:0]:glide==0?32'd0:glide[31]?32'hffffffff:32'd1;
 wire glide_rounds_to_zero=(!( |product0[56:24])&&!product0[23])||((&product0[56:24])&&product0[23]);
 wire [31:0] glide_operand=glide_rounds_to_zero?(glide==0?32'd0:glide[31]?32'hffffffff:32'd1):product0[55:24];
 wire [31:0] glide_next=glide-glide_operand-(!glide_rounds_to_zero&&product0[23]);
 wire [31:0] phase_base=f_first?coefficient[119:88]:(is_C||f_started)?old_row[127:96]:32'd0;
 wire phase_advance=is_C?f_age>coefficient[247:232]:!f_first&&f_started;
 reg [32:0] env_difference;
 wire returned_amplitude=mul_valid&&result_tag==3;
 wire write_accepted=ram_request&&ram_ready&&ram_write;
 wire retire=state==RUN&&(amp_ready||returned_amplitude)&&(state_written||write_accepted);
 // Late prefetch keeps the source banks stable through the ENV return.
 // Their valid window therefore needs no LOAD-only clock enable.

 wire acc_clear=state==IDLE&&start;
 shared_wide_accumulator #(.WIDTH(54)) modal_accumulator(.clk(clk),.rst_n(rst_n),
  .enable(acc_clear||mul_valid&&result_tag==3),.clear(acc_clear),.load(1'b0),
  .subtract(1'b0),.value(product0[53:0]),.sum(accumulator));
 always @(posedge clk)begin source_main<=load_main;source_onset<=load_onset;end
 always @(posedge clk)begin
  if(!rst_n)begin
   state<=IDLE;done<=0;active<=0;pp_pending<=0;pp_loaded<=0;read_pending<=0;row_loaded<=0;ram_was_write<=0;
   envelope_pending<=0;env_ready<=0;phase_ready<=0;sine_sent<=0;have_sine<=0;gain_sent<=0;gain_ready<=0;amp_sent<=0;amp_ready<=0;state_written<=0;
  end else begin
   done<=0;envelope_pending<=0;
   if(param_request&&param_ready)pp_pending<=0;
   if(param_valid)pp_loaded<=1;
   if(ram_request&&ram_ready)begin
    ram_was_write<=ram_write;
    if(ram_write)begin state_written<=1;if(next_main!=0)active<=1;end else read_pending<=0;
   end
   if(ram_valid&&!ram_was_write)row_loaded<=1;
   if(sine_request&&sine_ready)sine_sent<=1;
   if(sine_valid)begin sine<=sine_data;have_sine<=1;end
   if(request&&mul_ready&&state==RUN)begin if(tag==2)gain_sent<=1;else if(tag==3)amp_sent<=1;end
   if(mul_valid)case(result_tag) /* synthesis parallel_case */
    0:begin
     next_main<=f_first&&!is_C||is_C&&f_age<=coefficient[247:232]?source_main:decayed_product(source_main,product0);
     next_onset<=f_first&&!is_C||is_C&&f_age<=coefficient[247:232]?source_onset:decayed_product(source_onset,product1);
     envelope_pending<=1;
    end
    1:begin
     increment<=product1[47:15];
     if(!is_C&&f_first||is_C&&f_age<=coefficient[247:232])next_glide<=glide;
     else next_glide<=glide_next;
     next_phase<=phase_base+(phase_advance?product1[46:15]:32'd0);
     phase_ready<=1;
    end
    2:begin gained<=product0[38:15];gain_ready<=1;end
    3:begin amp_ready<=1;end
   endcase
   if(envelope_pending)begin
    env_difference={1'b0,next_main}-{1'b0,next_onset};
    envelope<=env_difference[32]||is_C&&f_age<coefficient[247:232]?0:env_difference[31:0];env_ready<=1;
   end
   case(state) /* synthesis parallel_case */
    IDLE:if(start)begin
     is_C<=drum_C;f_first<=first;f_started<=started;f_note<=note;f_age<=age;f_pitch<=pitch;
     index<=0;active<=0;pp_index<=0;pp_pending<=1;pp_loaded<=0;read_index<=0;read_pending<=1;row_loaded<=0;state<=LOAD;
    end
    LOAD:if(request&&mul_ready)begin
     env_ready<=0;phase_ready<=0;sine_sent<=0;have_sine<=0;gain_sent<=0;gain_ready<=0;amp_sent<=0;amp_ready<=0;state_written<=0;
     if(index!=modes-1)begin pp_index<=index+1'b1;pp_pending<=1;pp_loaded<=0;read_index<=index+1'b1;read_pending<=1;row_loaded<=0;end
     state<=PG;
    end
    PG:if(mul_ready)state<=RUN;
    RUN:if(retire)begin
     if(index==modes-1)begin done<=1;state<=IDLE;end
     else begin index<=index+1'b1;state<=LOAD;end
    end
   endcase
  end
 end
endmodule
