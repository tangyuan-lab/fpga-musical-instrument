`include "src/poly4_shared/resource_ports.vh"
// 24 kHz C synthesizer: 49 delayed modes + 128 analytic chirplets + 12
// two-section stochastic resonators, followed by a causal 2x halfband FIR.
// Coefficients are shared; only runtime state is private to each voice.
module shared_C_core #(parameter integer EXTERNAL_BANKS=0)(
 input wire clk,rst_n,tick24,note_on,cancel_C,input wire [15:0] pitch_ratio_q15,input wire [6:0] velocity,
 output wire cp_request,input wire cp_ready,cp_valid,
 output wire [7:0] cp_address,input wire [287:0] cp_data,
 output reg signed [31:0] even_q20,odd_q20,raw_q20,
 output reg signed [15:0] even_pcm,odd_pcm,output reg pair_valid,raw_valid,overrun,
 `TOM_POST_PORTS,
 input wire [287:0] retained_parameter,input wire [159:0] retained_row,
 `RESOURCE_PORTS,
 `DRUM_JOB_PORTS,
 input wire [11:0] modal_phase,output wire signed [15:0] modal_cosine
);
 localparam IDLE=0,MWAIT=1,MLOAD=2,MEWAIT=3,MENV=4,MPWAIT=5,MPHASE=6,
  MCWAIT=7,MCLOAD=8,MMWAIT=9,MDONE=10,PWAIT=11,PLOAD=12,PPWAIT=13,
  PFIRE=14,PDRAIN=15,NWAIT=16,NLOAD=17,NR1=18,NR2=19,NR3=20,
  NEWAIT=21,NE0=22,NE1WAIT=23,NE1=24,NSQWAIT=25,NSQUARE=26,
  NF0WAIT=27,NF0=28,NF1WAIT=29,NF1=30,NF2WAIT=31,NF2=32,
  NF3WAIT=33,NF3=34,NNWAIT=35,NNORM=36,NOWAIT=37,NOUT=38,
  NW0=39,NW1=40,NW2=41,TOTAL=42,FLOAD=43,FWAIT=44,FMAC=45,FINISH=46,VWAIT=47,VDONE=48,PAWAIT=49,PASCALE=50,PALWAIT=51,
  EDEC=52,EOUT=53,NSQLOAD=54,FSTORE=55,FREAD=56,BODY=57,FSTREAM=58,NZWAIT=59;
 localparam TFETCH=60,TLOAD=61,TENV=62,TEWAIT=63,THI=64,THWAIT=65,TLO=66,TLWAIT=67,
  TMAC=68,TMWAIT=69,TSTORE=70,TVEL=71,TVWAIT=72,TADSR=73,TAWAIT=74,CFLUSH=75;
 reg [2:0] flush_left;
 reg [6:0] state ;reg [7:0] index,current,rd_addr;
 reg tom_post,tparam_pending;
 reg [3:0] band;reg [7:0] naddr;
 reg read_pending,read_loaded,ram_was_write;reg [8:0] read_address;
 reg [24:0] em0,eo0,em1,eo1,en0,en1;
 reg [5:0] power_exp;reg [63:0] power_scan;
 wire execute;
 reg signed [31:0] packet_a;reg signed [16:0] packet_b;
 reg signed [48:0] packet_multiply_q;reg [1:0] packet_valid;reg packet_loaded;
 assign post_ready=state==IDLE&&!tick24;
 assign tn_request=tom_post&&tparam_pending;
 assign tn_address={post_bank,band[1:0]};
 reg [16:0] age;reg started,pending,first;reg [15:0] pitch;
 reg [6:0] frame_velocity;
 wire [287:0] param_q;reg loaded;
 wire [159:0] state_row;
 generate if(EXTERNAL_BANKS)begin:g_external_banks
  assign param_q=retained_parameter;assign state_row=retained_row;
 end else begin:g_private_banks
  reg [287:0] parameters;reg [159:0] row;
  assign param_q=parameters;assign state_row=row;
  always @(posedge clk)if(rst_n)begin
   if(cp_valid&&state!=BODY)parameters<=cp_data;
   if(tom_post&&tn_valid)parameters[127:0]<=tn_data;
   if(ram_valid&&state!=BODY&&!ram_was_write)row<=ram_q;
  end
 end endgenerate
 reg wr;reg [7:0] wr_addr;wire [159:0] wr_data;reg [4:0] wr_select;
 wire gv;wire signed [31:0] gy;
 wire ctl_write=wr;
 // This controller is client 0 of the fixed-priority pool. Each general
 // result is consumed on its valid edge; any dependent launch is granted
 // on that edge. Keeping a second 114-bit product bank is unnecessary.
 wire signed [56:0] p0=product0[56:0],p1=product1[56:0];
 reg ctl_cp_request;reg [7:0] ctl_cp_address;
 task read_state;
  input [8:0] address;
  begin read_pending<=1;read_address<=address;read_loaded<=0;end
 endtask
 // One shared envelope unit, pipelined between rounding, saturated decay,
 // and main-minus-onset. No duplicated long subtract/compare/DSP feedback.
 reg [24:0] ed0,ed1,evn0,evn1;
 reg [1:0] eowner;reg eadvance,eactive;
 wire [31:0] rounded0=p0[55:24]+p0[23],rounded1=p1[55:24]+p1[23];
 wire [25:0] difference0={1'b0,em0}-{1'b0,ed0};
 wire [25:0] difference1={1'b0,eo0}-{1'b0,ed1};
 wire [25:0] envelope_difference={1'b0,evn0}-{1'b0,evn1};
 wire [31:0] envelope=eactive&&!envelope_difference[25]?envelope_difference[24:0]:0;
 function [31:0] rng_next;
  input [31:0] x;reg [31:0] a;
  begin a=x^(x<<13);a=a^(a>>17);rng_next=a^(a<<5);end
 endfunction
 function signed [15:0] pcm;
  input signed [56:0] value;
  reg signed [56:0] v;
  begin
   v=value>>>12;
   pcm=v[56]?((&v[55:15])?v[15:0]:16'h8000):((|v[55:15])?16'h7fff:v[15:0]);
  end
 endfunction
 task fetch;
  input [7:0] address;
  begin ctl_cp_request<=1;ctl_cp_address<=address;index<=address;rd_addr<=address;loaded<=0;read_state(address);end
 endtask
 task write_state;
  input [7:0] address;
  begin wr<=1;wr_addr<=address;end
 endtask
 // Every contribution is ultimately added modulo 2^32. Shifting the modal
 // result once, then adding the packet/noise terms in order is exactly the
 // original final 32-bit truncation, without three separate accumulators.
 // The tom sum needs 56 bits; C contributions still wrap at 32 bits on
 // every update, matching the accepted C integer model exactly.
 reg total_narrow;wire [55:0] total_full;
 wire signed [55:0] total=total_narrow?{24'd0,total_full[31:0]}:total_full;
 wire [55:0] accumulation_term=tom_post?p0[55:0]:state==NW0?{{30{p0[56]}},p0[56:31]}:{{24{gy[31]}},gy};
 wire [55:0] accumulated=total+accumulation_term;
 wire signed [31:0] tom_raw_pcm=$signed(total)>>>26;
 wire signed [56:0] tom_velocity=$signed(p0)>>>7;
 wire signed [56:0] tom_shaped=$signed(p0)>>>16;
 wire signed [31:0] tom_old_hi=first||!post_started?32'sd0:$signed(state_row[63:32]);
 wire signed [31:0] tom_old_lo=first||!post_started?32'sd0:$signed(state_row[31:0]);
 wire [31:0] tom_filter_next=(state==TLWAIT?tom_old_lo:tom_old_hi)+p0[47:16];
 function signed [15:0] clip32(input signed [31:0] v);
  begin clip32=v[31]?((&v[30:15])?v[15:0]:16'h8000):((|v[30:15])?16'h7fff:v[15:0]);end
 endfunction
 function signed [15:0] clip57(input signed [56:0] v);
  begin clip57=v[56]?((&v[55:15])?v[15:0]:16'h8000):((|v[55:15])?16'h7fff:v[15:0]);end
 endfunction
 wire [9:0] sqrt_index=power_scan[63:54];
 wire signed [15:0] cos_q;wire [16:0] math_q;
 reg gi;reg [23:0] gpeak;
 // Prefetch is issued after the pitch result, rather than before it. This
 // leaves the current coefficient/state row available for its early write.
 // Rendering needs only a cosine address and the exponent-table address.
 reg [11:0] render_phase;reg [17:0] render_env;
 wire packet_first=age==param_q[287:272];
 wire [31:0] packet_phase=packet_first?param_q[255:224]:state_row[159:128];
 wire [31:0] packet_step=packet_first?param_q[223:192]:state_row[127:96];
 wire signed [47:0] packet_log=packet_first?param_q[135:88]:state_row[95:48];
 wire signed [47:0] packet_delta=packet_first?param_q[87:40]:state_row[47:0];
 wire [31:0] next_packet_phase=packet_phase+packet_multiply_q[46:15];
 wire [31:0] next_packet_step=packet_step+param_q[191:160];
 wire [47:0] next_packet_log=packet_log+packet_delta;
 wire [47:0] next_packet_delta=packet_delta+$signed(param_q[39:0]);
 wire [159:0] next_packet_state={next_packet_phase,next_packet_step,next_packet_log,next_packet_delta};
 reg [3:0] drain;
 // Fitted C packets stay below 11.25 kHz. Bending them upward fades the
 // last 750 Hz before the internal Nyquist limit, without changing default C.
 wire signed [32:0] bent_step=packet_multiply_q[47:15];
 reg [32:0] absolute_step;
 wire [15:0] alias_roll=16'd32768-{1'b0,absolute_step[26:12]}-(|absolute_step[11:0]);
 wire [24:0] alias_gain=(|absolute_step[32:31]) ? 25'd0 : (&absolute_step[30:27]) ? {9'd0,alias_roll} : 25'd32768;
 shared_packet_math math(.clk(clk),.rst_n(rst_n),.in_valid(gi),.tag(8'd0),
  .phase({render_phase,20'd0}),.step(32'd0),.phase_step(32'd0),.step_delta(32'sd0),
  .log_env({render_env,30'd0}),.log_delta(48'sd0),.log_accel(40'sd0),.peak(gpeak),
  .body_phase(modal_phase),.sqrt_index(sqrt_index),.cosine_q(cos_q),.math_q(math_q),
  .out_valid(gv),.out_tag(),.sample_q20(gy),.next_state());
 // Compact noise runtime storage occupies three rows per band in the same RAM.

 reg signed [23:0] saved_nb,saved_na1,saved_na2;reg [23:0] saved_ngain;reg [31:0] saved_seed;
 wire signed [23:0] nb=EXTERNAL_BANKS?param_q[223:200]:saved_nb;
 wire signed [23:0] na1=EXTERNAL_BANKS?param_q[199:176]:saved_na1;
 wire signed [23:0] na2=EXTERNAL_BANKS?param_q[175:152]:saved_na2;
 wire [23:0] ngain=EXTERNAL_BANKS?param_q[151:128]:saved_ngain;
 wire [31:0] seed=EXTERNAL_BANKS?param_q[255:224]:saved_seed;
 always @(posedge clk)if(rst_n&&execute&&state==NLOAD)begin
  saved_seed<=param_q[255:224];saved_nb<=param_q[223:200];saved_na1<=param_q[199:176];saved_na2<=param_q[175:152];saved_ngain<=param_q[151:128];
 end
 // Read each filter row when it is used. state_row already retains all its
 // fields, so copying seven old filter values into separate banks is wasteful.
 wire [31:0] rng=first?seed:state_row[159:128];
 wire [31:0] old_x1=first?0:state_row[127:96],old_x2=first?0:state_row[95:64];
 wire [31:0] old_y1=first?0:state_row[63:32],old_y2=first?0:state_row[31:0];
 wire [31:0] old_z1=first?0:state_row[159:128],old_z2=first?0:state_row[127:96];
 wire [31:0] nrng=rng_next(rng);
 wire signed [31:0] white_sample=$signed(nrng)>>>16<<8;
 reg [63:0] eparam0;
 // The second parameter word stays in param_q until this band retires.
 wire [127:0] eparam1=param_q[127:0];
 reg [31:0] xx,yy,zz;
 reg [50:0] power;
 wire [5:0] exponent=power_exp;
 reg [31:0] noise_amp;
 reg signed [31:0] normalized;
 integer k;
 always @*begin
  power_exp=31;power_scan={13'd0,power};
  if(!(|power_scan[63:32]))begin power_scan=power_scan<<32;power_exp=power_exp-16;end
  if(!(|power_scan[63:48]))begin power_scan=power_scan<<16;power_exp=power_exp-8;end
  if(!(|power_scan[63:56]))begin power_scan=power_scan<<8;power_exp=power_exp-4;end
  if(!(|power_scan[63:60]))begin power_scan=power_scan<<4;power_exp=power_exp-2;end
  if(!(|power_scan[63:62]))begin power_scan=power_scan<<2;power_exp=power_exp-1;end
 end
 // FIR history shares otherwise unused rows 228..255 of the state RAM.
 // A synchronous read avoids four banks of 1024 flip-flops and read muxes.
 reg signed [23:0] fir[0:31];
 initial $readmemh("src/excitation_v3/fir_odd_32x24.mem",fir);
 reg [4:0] hp,fi,history_count;
 wire [5:0] next_history_offset=hp>fi?{1'b0,hp}-{1'b0,fi}-1:{1'b0,hp}+27-{1'b0,fi};
 wire signed [63:0] fir_sum;reg signed [31:0] fir_even;
 wire fir_dot_valid,fir_dot_last;
 wire signed [31:0] filter_result=(fir_sum+64'sd2097152)>>>22;
 // Replace the 64-bit variable shift with an exact power-of-two multiply
 // in an otherwise unused pool slot. Splitting the exponent at bit 4 keeps
 // both operands positive within the existing signed 36x27 widths.
 wire normalize_launch=state==NF1;
 wire [35:0] normalize_a=power==0?36'd0:exponent[4]?{3'd0,math_q,16'd0}:{19'd0,math_q};
 wire [24:0] normalize_b=25'd1<<exponent[3:0];
 wire signed [31:0] new_total=total;

 // A RAM write consumes its payload one edge after MDONE/NW0/NW1/NW2/TOTAL.
 // These source registers remain unchanged until that edge. Keep only the
 // write selector and address, rather than a redundant 160-bit payload bank.
 // NW2 changes naddr immediately, so wr_addr must retain the original address.
 assign wr_data=({160{wr_select[0]}} & next_packet_state)
              |({160{wr_select[1]}} & {nrng,white_sample,old_x1,yy,old_y1})
              |({160{wr_select[2]}} & {zz,old_z1,7'd0,em1,7'd0,eo1,7'd0,em0})
              |({160{wr_select[3]}} & {135'd0,eo0})
              |({160{wr_select[4]}} & {128'd0,new_total});
 always @(posedge clk)begin
  if(!rst_n)wr_select<=0;
  else case(state) /* synthesis parallel_case */
   PFIRE:if(execute)wr_select<=5'b00001;
   NF2WAIT:if(execute)wr_select<=5'b00010;
   NW1:wr_select<=5'b00100;
   NW2:wr_select<=5'b01000;
   TOTAL:wr_select<=5'b10000;
   default:wr_select<=0;
  endcase
 end

 // Each consumed product has a fresh launch two edges earlier. Invalid-cycle
 // operands are zero; holding old operands and synchronously resetting these
 // datapath registers adds control routing without affecting valid samples.
 reg signed [31:0] launch_a0,launch_a1;reg launch_valid,launch_pair;
 reg signed [24:0] launch_b0,launch_b1;
 always @*begin
  launch_a0=0;launch_a1=0;launch_b0=0;launch_b1=0;launch_valid=0;launch_pair=0;
  case(state) /* synthesis parallel_case */
   EOUT:if(!tom_post&&eowner==1)begin launch_valid=1;launch_pair=1;launch_a0=em1;launch_b0={1'b0,eparam1[47:24]};launch_a1=eo1;launch_b1={1'b0,eparam1[23:0]};end
   NEWAIT:begin launch_valid=1;launch_pair=1; launch_a0=em0;launch_b0={1'b0,eparam0[47:24]};launch_a1=eo0;launch_b1={1'b0,eparam0[23:0]};end
   NSQUARE:if(read_loaded)begin launch_valid=1;launch_pair=1; launch_a0=en0;launch_b0=en0;launch_a1=en1;launch_b1=en1;end
   NF1:begin launch_valid=1;launch_b0=normalize_b;end
   NNWAIT:begin launch_valid=1; launch_a0=filter_result;launch_b0={1'b0,ngain};end
   NOWAIT:begin launch_valid=1; launch_a0=(p0+57'sd32768)>>>16;launch_b0=noise_amp;end
   FINISH:begin launch_valid=1;launch_pair=1; launch_a0=fir_even;launch_a1=odd_q20;launch_b0={18'd0,frame_velocity};launch_b1={18'd0,frame_velocity};end
   TENV:begin launch_valid=1;launch_pair=1;launch_a0=em0;launch_a1=eo0;launch_b0={1'b0,param_q[103:80]};launch_b1={1'b0,param_q[79:56]};end
   THI:begin launch_valid=1;launch_a0=$signed(post_white)-tom_old_hi;launch_b0={9'd0,param_q[47:32]};end
   TLO:begin launch_valid=1;launch_a0=yy-tom_old_lo;launch_b0={9'd0,param_q[23:8]};end
   TMAC:begin launch_valid=1;launch_a0=yy-zz;launch_b0={1'b0,en0[23:0]};end
   TVEL:begin launch_valid=1;launch_a0=tom_raw_pcm;launch_b0={18'd0,post_velocity};end
   TADSR:begin launch_valid=1;launch_a0=normalized;launch_b0={9'd0,post_adsr_gain};end
   default:begin end
  endcase
 end

 wire packet_active=age>=param_q[287:272]&&age<({1'b0,param_q[287:272]}+param_q[271:256]);
 reg needs_product;
 always @*begin
  needs_product=0;
  case(state) /* synthesis parallel_case */
   NE1WAIT,NSQWAIT,NF0WAIT,NOWAIT,NW0,PFIRE,PASCALE,VDONE,TEWAIT,THWAIT,TLWAIT,TMWAIT,TVWAIT,TAWAIT:needs_product=1;
  endcase
 end
 wire data_ready=(state==PFIRE||state==PASCALE)?(packet_loaded||packet_valid[1]):
  (state==NF2WAIT||state==NNWAIT)?(fir_dot_valid&&fir_dot_last):(!needs_product||mul_valid);
 wire launch_eligible=launch_valid&&data_ready&&(state!=NEWAIT||loaded);
 assign execute=data_ready&&(!launch_eligible||mul_ready);
 // Two-clock exact signed 32x17 packet operation, independent of the pool.
 wire packet_launch=execute&&((state==PLOAD&&packet_active)||state==PAWAIT);
 // These temporaries are consumed only at the original valid edges. Their
 // sources remain stable through those edges, so local enables are redundant.
 always @(posedge clk)begin
  absolute_step<=bent_step<0?-bent_step:bent_step;
  gpeak<=packet_multiply_q>>>15;
 end
 always @(posedge clk)begin
  if(packet_launch)begin
   packet_a<=state==PLOAD?packet_step:{8'd0,param_q[159:136]};
   packet_b<=state==PLOAD?{1'b0,pitch}:{1'b0,alias_gain[15:0]};
  end
  packet_multiply_q<=packet_a*packet_b;
  if(!rst_n)begin packet_valid<=0;packet_loaded<=0;end
  else begin
   packet_valid<={packet_valid[0],packet_launch};
   if(packet_valid[1])packet_loaded<=1;
   if(packet_launch)packet_loaded<=0;
  end
 end
 reg body_start;
 wire body_done=modal_done;wire signed [63:0] body_result=modal_sum;
 assign modal_request=body_start;assign modal_first=first;assign modal_started=started;
 assign modal_note=5'd0;assign modal_age=age;assign modal_pitch=pitch;assign modal_cosine=cos_q;
 assign cp_request=state==BODY?1'b0:ctl_cp_request;
 assign cp_address=ctl_cp_address;
 reg [4:0] fir_issue,fir_retired,fir_read_tag;
 wire [5:0] fir_offset=hp>=fir_issue?hp-fir_issue:hp+28-fir_issue;
 wire fir_read=state==FSTREAM&&fir_issue<20;
 wire ctl_ram_request=wr||read_pending||fir_read;
 wire [8:0] ctl_ram_address=wr?{1'b0,wr_addr}:fir_read?9'd228+fir_offset:read_address;
 assign ram_request=state==TSTORE||state!=BODY&&ctl_ram_request;
 assign ram_write=state==TSTORE||ctl_write;
 assign ram_address=state==TSTORE?9'd384+band[1:0]:ctl_ram_address;
 assign ram_data=state==TSTORE?{48'd0,em0[23:0],eo0[23:0],yy,zz}:wr_data;
 wire fir_sample_valid=state==FSTREAM&&ram_valid&&!ram_was_write;
 wire signed [31:0] fir_sample=fir_read_tag<=history_count?$signed(ram_q[31:0]):32'sd0;
 // The two DSP MACs serve each three-term noise biquad, then the FIR.
 // Sources remain in the current state row until this dot product retires.
 wire noise_first=execute&&(state==NF0WAIT||state==NZWAIT&&read_loaded);
 wire noise_middle=execute&&(state==NF0||state==NF2);
 wire noise_last=execute&&(state==NF1WAIT||state==NF3WAIT);
 wire noise_second=state==NZWAIT||state==NF2||state==NF3WAIT;
 wire signed [31:0] noise_input=noise_first?(noise_second?xx:white_sample-old_x2):
  noise_middle?(noise_second?old_z1:old_y1):(noise_second?old_z2:old_y2);
 wire signed [24:0] noise_coefficient=noise_first?$signed(nb):noise_middle?-$signed({na1[23],na1}):-$signed({na2[23],na2});
 // Read the complete word before selecting its sign bit. The installed
 // Gowin V1.9.12.03 synthesizer miscompiles the nested fir[index][23]
 // expression; the isolated 32-address mapped-netlist check reproduces it.
 wire signed [23:0] fir_coefficient_word /* synthesis syn_keep=1 */=fir[fir_read_tag];
 shared_fir_mac fir_dot(.clk(clk),.rst_n(rst_n),.in_valid(fir_sample_valid||noise_first||noise_middle||noise_last),
  .first(fir_sample_valid?fir_read_tag==0:noise_first),.last(fir_sample_valid?fir_read_tag==19:noise_last),
  .sample(fir_sample_valid?fir_sample:noise_input),.coefficient(fir_sample_valid?{fir_coefficient_word[23],fir_coefficient_word}:noise_coefficient),
  .out_valid(fir_dot_valid),.out_last(fir_dot_last),.sum(fir_sum));
 // Only the even halfband center product still uses the general pool.
 wire fir_product=fir_sample_valid&&fir_read_tag==10;
 assign mul_request=state!=BODY&&(fir_product||launch_eligible);
 assign mul_pair=fir_product?1'b0:launch_pair;
 assign mul_a0=fir_product?(fir_read_tag<=history_count?{{4{ram_q[31]}},ram_q[31:0]}:36'd0):normalize_launch?normalize_a:{{4{launch_a0[31]}},launch_a0};
 assign mul_a1={{4{launch_a1[31]}},launch_a1};
 assign mul_b0=fir_product?27'sd4196474:{{2{launch_b0[24]}},launch_b0};
 assign mul_b1={{2{launch_b1[24]}},launch_b1};
 assign mul_tag=fir_product?{1'b1,fir_read_tag}:normalize_launch?6'd16:6'd0;

 reg sum_enable,sum_clear,sum_load,sum_narrow;
 reg [55:0] sum_value;
 always @*begin
  sum_enable=gv&&state!=CFLUSH;sum_clear=0;sum_load=0;sum_narrow=1;sum_value=accumulation_term;
  if(execute)case(state)
   IDLE:if(tick24)begin
    if(pending||note_on||started)begin sum_enable=1;sum_clear=1;sum_narrow=0;end
   end else if(post_request&&post_ready)begin sum_enable=1;sum_load=1;sum_value=post_sum;sum_narrow=0;end
   BODY:if(body_done)begin sum_enable=1;sum_load=1;sum_value=body_result>>>23;sum_narrow=0;end
   NW0:sum_enable=1;
   TMWAIT:begin sum_enable=1;sum_narrow=0;end
  endcase
 end
 shared_wide_accumulator #(.WIDTH(56)) total_accumulator(.clk(clk),.rst_n(rst_n),
  .enable(sum_enable),.clear(sum_clear),.load(sum_load),.subtract(1'b0),.value(sum_value),.sum(total_full));
 always @(posedge clk)begin
  if(!rst_n)total_narrow<=0;else if(sum_enable)total_narrow<=sum_narrow;
 end
 always @(posedge clk)begin
  if(!rst_n)begin
   read_pending<=0;read_loaded<=0;ram_was_write<=0;
   fir_issue<=0;fir_retired<=0;fir_read_tag<=0;
   body_start<=0;state<=IDLE;index<=0;current<=0;rd_addr<=0;wr<=0;wr_addr<=0;
   age<=0;started<=0;pending<=0;first<=0;pitch<=32768;
   ctl_cp_request<=0;ctl_cp_address<=0;loaded<=0;
   pair_valid<=0;raw_valid<=0;overrun<=0;even_q20<=0;odd_q20<=0;raw_q20<=0;even_pcm<=0;odd_pcm<=0;frame_velocity<=0;
   gi<=0;
   tom_post<=0;tparam_pending<=0;post_valid<=0;post_active<=0;post_sample<=0;flush_left<=0;
   hp<=0;history_count<=0;drain<=0;
  end else begin
   if(body_start&&modal_ready)body_start<=0;wr<=0;gi<=0;pair_valid<=0;raw_valid<=0;post_valid<=0;
   if(ram_request&&ram_ready&&state!=BODY)begin
    ram_was_write<=ram_write;
    if(!ram_write)begin read_pending<=0;if(state==FSTREAM)begin fir_read_tag<=fir_issue;fir_issue<=fir_issue+1'b1;end end
   end
   if(ram_valid&&state!=BODY&&!ram_was_write)read_loaded<=1;
   if(state==TOTAL&&execute)begin fir_issue<=0;fir_retired<=0;end
   if(state==FSTREAM&&mul_valid)fir_retired<=fir_retired+1'b1;

   if(cp_ready&&state!=BODY)ctl_cp_request<=0;
   if(cp_valid&&state!=BODY)loaded<=1;
   if(tn_request&&tn_ready)tparam_pending<=0;
   if(tom_post&&tn_valid)loaded<=1;
   if(note_on)pending<=1;
   if(tick24&&state!=IDLE)overrun<=1;
   if(mul_valid&&result_tag==16)noise_amp<=product0[47:16];
   if(execute)case(state) /* synthesis parallel_case */
    IDLE:if(tick24)begin
     if(pending||note_on||started)begin
      tom_post<=0;first<=pending||note_on;pending<=0;started<=1;
      if(pending||note_on)begin age<=0;hp<=0;history_count<=0;frame_velocity<=velocity;end else age<=age+1'b1;
      pitch<=pitch_ratio_q15;
      body_start<=1;state<=BODY;
     end else begin even_q20<=0;odd_q20<=0;raw_q20<=0;even_pcm<=0;odd_pcm<=0;pair_valid<=1;raw_valid<=1;end
    end else if(post_request&&post_ready)begin
     tom_post<=1;first<=post_first;band<=0;post_active<=post_modal_active;
     loaded<=0;tparam_pending<=1;read_state(9'd384);state<=TFETCH;
    end
    BODY:if(body_done)begin fetch(64);state<=PWAIT;end
    EDEC:begin
     evn0<=!eadvance?em0:difference0[25]?0:difference0[24:0];
     evn1<=!eadvance?eo0:difference1[25]?0:difference1[24:0];state<=EOUT;
    end
    EOUT:begin
     if(tom_post)begin em0<=evn0;eo0<=evn1;en0<=envelope;state<=THI;end
     else if(eowner==1)begin
      // ENV1's operands are accepted on this edge, so its old source bank
      // can hold ENV0's result. Move the old ENV1 source to the current bank
      // for rounding/subtraction; neither old ENV0 source is needed again.
      em1<=evn0;eo1<=evn1;en0<=envelope;
      em0<=em1;eo0<=eo1;eowner<=2;eadvance<=age>eparam1[127:112];eactive<=age>=eparam1[127:112];state<=NE1;
     end else begin em0<=evn0;eo0<=evn1;en1<=envelope;state<=NSQLOAD;end
    end
    PWAIT:if((loaded||cp_valid)&&(read_loaded||(ram_valid&&!ram_was_write))&&!ctl_write)state<=PLOAD;
    PLOAD:begin
     current<=index;
     if(packet_active)state<=PPWAIT;
     else begin
      fetch(index==191?8'd192:index+1'b1);
      if(index==191)begin drain<=0;state<=PDRAIN;end else state<=PWAIT;
     end
    end
    PPWAIT:state<=PFIRE;
    PFIRE:begin
     render_phase<=packet_phase[31:20];render_env<=packet_log[47:30];
     write_state(index);fetch(index==191?8'd192:index+1'b1);
     state<=PAWAIT;
    end
    PAWAIT:begin state<=PALWAIT;end
    PALWAIT:state<=PASCALE;
    PASCALE:begin
     gi<=1;
     if(current==191)begin drain<=0;state<=PDRAIN;end else state<=PWAIT;
    end
    PDRAIN:begin
     drain<=drain+1'b1;
     if(drain==6)begin band<=0;naddr<=192;state<=NWAIT;end
    end
    NWAIT:if(loaded||cp_valid)state<=NLOAD;
    NLOAD:begin
     eparam0<={param_q[127:112],param_q[47:0]};
     if(first)begin em0<=param_q[111:80];eo0<=param_q[79:48];end
     fetch(8'd193+{band,1'b0});read_state(naddr+1'b1);state<=NR1;
    end
    NR1:if(read_loaded)begin
     em1<=state_row[31:0];
     if(!first)begin em0<=state_row[95:64];eo0<=state_row[63:32];end
     read_state(naddr+2'd2);state<=NR2;
    end
    NR2:if(read_loaded&&loaded)begin
     if(first)em1<=param_q[111:80];eo1<=first?param_q[79:48]:state_row[31:0];state<=NEWAIT;
    end
    NEWAIT:begin
     eowner<=1;eadvance<=age>eparam0[63:48];eactive<=age>=eparam0[63:48];state<=NE0;
    end
    NE0:state<=NE1WAIT;
    NE1WAIT:begin
     ed0<=rounded0==0?1:rounded0;ed1<=rounded1==0?1:rounded1;state<=EDEC;
    end
    NE1:state<=NSQWAIT;
    NSQWAIT:begin
     ed0<=rounded0==0?1:rounded0;ed1<=rounded1==0?1:rounded1;state<=EDEC;
    end
    NSQLOAD:begin
     read_state(naddr);state<=NSQUARE;
    end
    NSQUARE:if(read_loaded)state<=NF0WAIT;
    NF0WAIT:begin
     power<={1'b0,p0[49:0]}+{1'b0,p1[49:0]};state<=NF0;
    end
    NF0:state<=NF1WAIT;
    NF1WAIT:state<=NF1;
    NF1:state<=NF2WAIT;
    NF2WAIT:begin
     yy<=filter_result;xx<=filter_result-old_y2;
     write_state(naddr);read_state(naddr+1'b1);state<=NZWAIT;
    end
    NZWAIT:if(read_loaded)state<=NF2;
    NF2:state<=NF3WAIT;
    NF3WAIT:state<=NF3;
    NF3:state<=NNWAIT;
    NNWAIT:begin zz<=filter_result;state<=NNORM;end
    NNORM:state<=NOWAIT;
    NOWAIT:begin normalized<=(p0+57'sd32768)>>>16;state<=NOUT;end
    NOUT:state<=NW0;
    NW0:begin
     state<=NW1;
    end
    NW1:begin write_state(naddr+1'b1);state<=NW2;end
    NW2:begin
     write_state(naddr+2'd2);
     if(band==11)state<=TOTAL;
     else begin band<=band+1'b1;naddr<=naddr+3;fetch(8'd194+{band,1'b0});state<=NWAIT;end
    end
    TOTAL:begin
     raw_q20<=new_total;raw_valid<=1;write_state(8'd228+hp);rd_addr<=8'd228+hp;
     fi<=0;fir_even<=0;state<=FSTORE;
    end
    FSTORE:if(!wr)begin read_pending<=0;state<=FSTREAM;end
    FSTREAM:begin
     if(mul_valid&&result_tag[5])fir_even<=($signed(product0[56:0])+57'sd2097152)>>>22;
     if(fir_dot_valid&&fir_dot_last)begin odd_q20<=(fir_sum+64'sd2097152)>>>22;state<=FINISH;end
    end
    FINISH:begin
     even_q20<=fir_even;
     
     hp<=hp==27?0:hp+1'b1;if(history_count<21)history_count<=history_count+1'b1;
     if(age>=100000)started<=0;state<=VWAIT;
    end
    VWAIT:state<=VDONE;
    VDONE:begin even_pcm<=pcm(p0);odd_pcm<=pcm(p1);pair_valid<=1;state<=IDLE;end
    TFETCH:if(loaded&&read_loaded)state<=TLOAD;
    TLOAD:begin
     em0<=first?{8'd0,param_q[127:104]}:post_started?{8'd0,state_row[111:88]}:32'd0;
     eo0<=first?{8'd0,param_q[127:104]}:post_started?{8'd0,state_row[87:64]}:32'd0;
     eadvance<=!first;eactive<=1;state<=TENV;
    end
    TENV:state<=TEWAIT;
    TEWAIT:begin ed0<=rounded0==0?1:rounded0;ed1<=rounded1==0?1:rounded1;state<=EDEC;end
    THI:state<=THWAIT;
    THWAIT:begin yy<=tom_filter_next;state<=TLO;end
    TLO:state<=TLWAIT;
    TLWAIT:begin zz<=tom_filter_next;state<=TMAC;end
    TMAC:state<=TMWAIT;
    TMWAIT:begin state<=TSTORE;end
    TSTORE:if(ram_ready)begin
     if(em0[23:0]!=0)post_active<=1;
     if(band==3)state<=TVEL;
     else begin band<=band+1'b1;loaded<=0;tparam_pending<=1;read_state(9'd385+band[1:0]);state<=TFETCH;end
    end
    TVEL:state<=TVWAIT;
    TVWAIT:begin
     normalized<=tom_velocity[31:0];
     if(post_adsr_enable)state<=TADSR;
     else begin post_sample<=clip32(tom_velocity[31:0]);post_valid<=1;state<=IDLE;tom_post<=0;end
    end
    TADSR:state<=TAWAIT;
    TAWAIT:begin post_sample<=clip57(tom_shaped);post_valid<=1;state<=IDLE;tom_post<=0;end
    CFLUSH:begin
     if(flush_left==0)state<=IDLE;else flush_left<=flush_left-1'b1;
    end
    default:state<=IDLE;
   endcase
   // A C adapter has already emitted this tick's delayed sample when a
   // steal commits. Its still-running calculation belongs to a future C
   // sample that will no longer be selected. Drain all old RAM/math/packet
   // returns before granting the retained banks to a new tom task.
   // Never cancel a tom job: its current 48kHz frame still needs its result.
   if(cancel_C&&!tom_post)begin
    state<=CFLUSH;flush_left<=5;body_start<=0;ctl_cp_request<=0;
    read_pending<=0;read_loaded<=0;wr<=0;gi<=0;pending<=0;
    pair_valid<=0;raw_valid<=0;post_valid<=0;
   end
  end
 end
 // The closed voice architecture assigns this controller highest priority.
 // Fail loudly if a future arbiter change invalidates the result lifetime.
 // synthesis translate_off
 always @(posedge clk)if(rst_n)begin
  if((state==NE1WAIT||state==NSQWAIT||state==TEWAIT)&&mul_valid&&
      (|rounded0[31:25]|| |rounded1[31:25]))$fatal(1,"Envelope drop exceeds proven25bit bound");
  if(state==NR1&&read_loaded&&!first&&( |state_row[95:89]|| |state_row[63:57]|| |state_row[31:25]))
   $fatal(1,"Stored envelope exceeds proven25bit bound");
  if(state==NLOAD&&( |param_q[111:105]|| |param_q[79:73]))$fatal(1,"Envelope INIT exceeds proven25bit bound");
  if(state==NR2&&first&&loaded&&( |param_q[111:105]|| |param_q[79:73]))$fatal(1,"Envelope INIT1 exceeds proven25bit bound");
  if(state==NF0WAIT&&mul_valid&&( |p0[56:50]|| |p1[56:50]))
   $fatal(1,"Noise-square input violated the proven25bit bound");
  if(mul_request&&!mul_ready)$fatal(1,"C client 0 lost its guaranteed math grant");
  if(normalize_launch&&exponent[5])$fatal(1,"Noise normalization exponent exceeds the proven 0..31 range");
  if(gv&&state==NW0&&execute)$fatal(1,"Packet drain overlapped noise accumulation");
  if(EXTERNAL_BANKS&&((state>=NR1&&state<=NW2)||state==NSQLOAD||state==NZWAIT))begin
   if({seed,nb,na1,na2,ngain}!=={saved_seed,saved_nb,saved_na1,saved_na2,saved_ngain})
    $fatal(1,"Retained noise header differs from the original NLOAD snapshot");
  end
 end
 // synthesis translate_on
endmodule
