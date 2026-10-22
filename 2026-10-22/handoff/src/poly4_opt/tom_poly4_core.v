// 24 kHz C synthesizer: 49 delayed modes + 128 analytic chirplets + 12
// two-section stochastic resonators, followed by a causal 2x halfband FIR.
// Coefficients are shared; only runtime state is private to each voice.
module tom_poly4_core(
 input wire clk,rst_n,tick24,note_on,input wire [15:0] pitch_ratio_q15,input wire [6:0] velocity,
 output reg cp_request,input wire cp_ready,cp_valid,
 output reg [7:0] cp_address,input wire [287:0] cp_data,
 output reg signed [31:0] even_q20,odd_q20,raw_q20,
 output reg signed [15:0] even_pcm,odd_pcm,output reg pair_valid,raw_valid,overrun
);
 localparam IDLE=0,MWAIT=1,MLOAD=2,MEWAIT=3,MENV=4,MPWAIT=5,MPHASE=6,
  MCWAIT=7,MCLOAD=8,MMWAIT=9,MDONE=10,PWAIT=11,PLOAD=12,PPWAIT=13,
  PFIRE=14,PDRAIN=15,NWAIT=16,NLOAD=17,NR1=18,NR2=19,NR3=20,
  NEWAIT=21,NE0=22,NE1WAIT=23,NE1=24,NSQWAIT=25,NSQUARE=26,
  NF0WAIT=27,NF0=28,NF1WAIT=29,NF1=30,NF2WAIT=31,NF2=32,
  NF3WAIT=33,NF3=34,NNWAIT=35,NNORM=36,NOWAIT=37,NOUT=38,
  NW0=39,NW1=40,NW2=41,TOTAL=42,FLOAD=43,FWAIT=44,FMAC=45,FINISH=46,VWAIT=47,VDONE=48,PAWAIT=49,PASCALE=50,PALWAIT=51,
  EDEC=52,EOUT=53,NSQLOAD=54,FSTORE=55,FREAD=56;
 reg [5:0] state /* synthesis syn_encoding="onehot" */;reg [7:0] index,current,rd_addr;
 reg [16:0] age;reg started,pending,first;reg [15:0] pitch;
 reg [6:0] frame_velocity;
 reg [287:0] param_q;reg loaded;
 reg [159:0] ram[0:255] /* synthesis syn_ramstyle="block_ram" */;
 reg [159:0] ram_q;reg wr;reg [7:0] wr_addr;
 wire [159:0] wr_data;reg [4:0] wr_select;
 wire gv;wire [7:0] gt;wire [159:0] gs;wire signed [31:0] gy;
 wire ram_write=gv||wr;
 wire [7:0] ram_address=gv?gt:wr?wr_addr:rd_addr;
 wire [159:0] ram_input=gv?gs:wr_data;
 always @(posedge clk)begin
  if(ram_write)begin ram[ram_address]<=ram_input;ram_q<=ram_input;end
  else ram_q<=ram[ram_address];
 end
 // Two time-multiplexed signed multipliers serve all non-packet arithmetic.
 reg signed [31:0] a0,a1;reg signed [24:0] b0,b1;
 reg signed [56:0] p0,p1;
 always @(posedge clk)begin p0<=a0*b0;p1<=a1*b1;end
 // One shared envelope unit, pipelined between rounding, saturated decay,
 // and main-minus-onset. No duplicated long subtract/compare/DSP feedback.
 reg [31:0] ev0,ev1,ed0,ed1,evn0,evn1;
 reg [1:0] eowner;reg eadvance,eactive;
 wire [31:0] rounded0=p0[55:24]+p0[23],rounded1=p1[55:24]+p1[23];
 wire [32:0] difference0={1'b0,ev0}-{1'b0,ed0};
 wire [32:0] difference1={1'b0,ev1}-{1'b0,ed1};
 wire [32:0] envelope_difference={1'b0,evn0}-{1'b0,evn1};
 wire [31:0] envelope=eactive&&!envelope_difference[32]?envelope_difference[31:0]:0;
 function [31:0] rng_next;
  input [31:0] x;reg [31:0] a;
  begin a=x^(x<<13);a=a^(a>>17);rng_next=a^(a<<5);end
 endfunction
 function signed [15:0] pcm;
  input signed [56:0] value;
  reg signed [56:0] v;
  begin v=value>>>12;pcm=v>32767?16'sd32767:v< -32768?-16'sd32768:v[15:0];end
 endfunction
 task fetch;
  input [7:0] address;
  begin cp_request<=1;cp_address<=address;index<=address;rd_addr<=address;loaded<=0;end
 endtask
 task write_state;
  input [7:0] address;
  begin wr<=1;wr_addr<=address;end
 endtask
 reg [15:0] mstart;reg [31:0] main_v,onset_v,mphase,mstep;
 reg signed [31:0] glide;reg [23:0] gd;
 reg [31:0] main_n,onset_n,phase_n,env;
 reg signed [31:0] glide_n;
 reg signed [63:0] body_sum;
 reg signed [31:0] packet_sum,noise_sum;
 wire [31:0] ms=first?param_q[231:200]:ram_q[95:64];
 wire [31:0] os=first?param_q[199:168]:ram_q[63:32];
 wire signed [31:0] gl=first?$signed(param_q[55:24]):$signed(ram_q[31:0]);
 wire signed [56:0] gdround=p0+57'sd8388608;
 wire signed [31:0] gdrop=gdround>>>24;
 reg [11:0] body_phase;reg [9:0] sqrt_index;
 wire signed [15:0] cos_q;wire [16:0] math_q;
 reg gi;reg [7:0] gtag;reg [31:0] gphase,gstep,gphase_step;
 reg signed [31:0] gdelta;reg signed [47:0] gell,gdiff;
 reg signed [39:0] gacc;reg [23:0] gpeak;
 reg [3:0] drain;
 // Fitted C packets stay below 11.25 kHz. Bending them upward fades the
 // last 750 Hz before the internal Nyquist limit, without changing default C.
 wire signed [32:0] bent_step=p0[47:15];
 reg [32:0] absolute_step;
 wire [15:0] alias_roll=16'd32768-{1'b0,absolute_step[26:12]}-(|absolute_step[11:0]);
 wire [24:0] alias_gain=(|absolute_step[32:31]) ? 25'd0 : (&absolute_step[30:27]) ? {9'd0,alias_roll} : 25'd32768;
 C_packet_math math(.clk(clk),.rst_n(rst_n),.in_valid(gi),.tag(gtag),
  .phase(gphase),.step(gstep),.phase_step(gphase_step),.step_delta(gdelta),
  .log_env(gell),.log_delta(gdiff),.log_accel(gacc),.peak(gpeak),
  .body_phase(body_phase),.sqrt_index(sqrt_index),.cosine_q(cos_q),.math_q(math_q),
  .out_valid(gv),.out_tag(gt),.sample_q20(gy),.next_state(gs));
 // Compact noise runtime storage occupies three rows per band in the same RAM.
 reg [3:0] band;reg [7:0] naddr;
 reg signed [23:0] nb,na1,na2;reg [23:0] ngain;
 reg [31:0] seed,rng,x1,x2,y1,y2,z1,z2;
 reg [127:0] eparam0,eparam1;
 reg [31:0] em0,eo0,em1,eo1,en0,en1;
 reg [31:0] xx,yy,zz,nrng;
 reg signed [63:0] filter_acc;
 reg [63:0] power;
 reg [5:0] exponent;
 reg [31:0] noise_amp;
 reg signed [31:0] normalized;
 reg [31:0] next_em0,next_eo0,next_em1,next_eo1;
 reg [5:0] power_exp;reg [63:0] power_scan;
 integer k;
 always @*begin
  power_exp=31;power_scan=power;
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
 reg signed [63:0] fir_sum;reg signed [31:0] fir_even;
 wire signed [63:0] noise_filter0=$signed(p0)-$signed(p1)+64'sd2097152;
 wire signed [63:0] filter_finish=filter_acc-$signed(p0);
 wire signed [31:0] new_total=(body_sum>>>23)+packet_sum+noise_sum;

 // A RAM write consumes its payload one edge after MDONE/NW0/NW1/NW2/TOTAL.
 // These source registers remain unchanged until that edge. Keep only the
 // write selector and address, rather than a redundant 160-bit payload bank.
 // NW2 changes naddr immediately, so wr_addr must retain the original address.
 assign wr_data=({160{wr_select[0]}} & {32'd0,phase_n,main_n,onset_n,glide_n})
              |({160{wr_select[1]}} & {nrng,xx,x1,yy,y1})
              |({160{wr_select[2]}} & {zz,z1,next_em0,next_eo0,next_em1})
              |({160{wr_select[3]}} & {128'd0,next_eo1})
              |({160{wr_select[4]}} & {128'd0,new_total});
 always @(posedge clk)begin
  if(!rst_n)wr_select<=0;
  else case(state)
   MDONE:wr_select<=5'b00001;
   NW0:wr_select<=5'b00010;
   NW1:wr_select<=5'b00100;
   NW2:wr_select<=5'b01000;
   TOTAL:wr_select<=5'b10000;
   default:wr_select<=0;
  endcase
 end

 // Each consumed product has a fresh launch two edges earlier. Invalid-cycle
 // operands are zero; holding old operands and synchronously resetting these
 // datapath registers adds control routing without affecting valid samples.
 reg signed [31:0] launch_a0,launch_a1;
 reg signed [24:0] launch_b0,launch_b1;
 always @*begin
  launch_a0=0;launch_a1=0;launch_b0=0;launch_b1=0;
  case(state)
   MLOAD:begin launch_a0=ms;launch_b0={1'b0,param_q[167:144]};launch_a1=os;launch_b1={1'b0,param_q[143:120]};end
   EOUT:case(eowner)
    0:begin launch_a0=glide;launch_b0={1'b0,gd};launch_a1=mstep+glide;launch_b1={9'd0,pitch};end
    1:begin launch_a0=em1;launch_b0={1'b0,eparam1[47:24]};launch_a1=eo1;launch_b1={1'b0,eparam1[23:0]};end
    default:begin end
   endcase
   MCLOAD:begin launch_a0=env;launch_b0=cos_q;end
   PLOAD:begin launch_a0=age==param_q[287:272]?param_q[223:192]:ram_q[127:96];launch_b0={9'd0,pitch};end
   PAWAIT:begin launch_a0={8'd0,gpeak};launch_b0=alias_gain;end
   NEWAIT:begin launch_a0=em0;launch_b0={1'b0,eparam0[47:24]};launch_a1=eo0;launch_b1={1'b0,eparam0[23:0]};end
   NSQLOAD:begin launch_a0=en0;launch_b0=en0;launch_a1=en1;launch_b1=en1;end
   NF0WAIT:begin launch_a0=xx-x2;launch_b0=nb;launch_a1=y1;launch_b1=na1;end
   NF1WAIT:begin launch_a0=y2;launch_b0=na2;end
   NF2WAIT:begin launch_a0=(filter_finish>>>22)-y2;launch_b0=nb;launch_a1=z1;launch_b1=na1;end
   NF3WAIT:begin launch_a0=z2;launch_b0=na2;end
   NNWAIT:begin launch_a0=filter_finish>>>22;launch_b0={1'b0,ngain};end
   NOWAIT:begin launch_a0=(p0+57'sd32768)>>>16;launch_b0=noise_amp;end
   FLOAD:begin
    launch_a0=fi<=history_count?ram_q[31:0]:0;launch_b0=fir[fi];
    launch_a1=fi==10&&fi<=history_count?ram_q[31:0]:0;launch_b1=25'sd4196474;
   end
   FINISH:begin launch_a0=fir_even;launch_a1=(fir_sum+64'sd2097152)>>>22;launch_b0={18'd0,frame_velocity};launch_b1={18'd0,frame_velocity};end
   default:begin end
  endcase
 end
 always @(posedge clk)begin a0<=launch_a0;a1<=launch_a1;b0<=launch_b0;b1<=launch_b1;end
 always @(posedge clk)begin
  if(!rst_n)begin
   state<=IDLE;index<=0;current<=0;rd_addr<=0;wr<=0;wr_addr<=0;
   age<=0;started<=0;pending<=0;first<=0;pitch<=32768;
   cp_request<=0;cp_address<=0;loaded<=0;param_q<=0;
   pair_valid<=0;raw_valid<=0;overrun<=0;even_q20<=0;odd_q20<=0;raw_q20<=0;even_pcm<=0;odd_pcm<=0;frame_velocity<=0;
   gi<=0;body_phase<=0;sqrt_index<=0;
   body_sum<=0;packet_sum<=0;noise_sum<=0;hp<=0;history_count<=0;drain<=0;
  end else begin
   wr<=0;gi<=0;pair_valid<=0;raw_valid<=0;
   if(cp_ready)cp_request<=0;
   if(cp_valid)begin param_q<=cp_data;loaded<=1;end
   if(note_on)pending<=1;
   if(tick24&&state!=IDLE)overrun<=1;
   if(gv)packet_sum<=packet_sum+gy;
   case(state)
    IDLE:if(tick24)begin
     if(pending||note_on||started)begin
      first<=pending||note_on;pending<=0;started<=1;
      if(pending||note_on)begin age<=0;hp<=0;history_count<=0;frame_velocity<=velocity;end else age<=age+1'b1;
      pitch<=pitch_ratio_q15;body_sum<=0;packet_sum<=0;noise_sum<=0;
      fetch(0);state<=MWAIT;
     end else begin even_q20<=0;odd_q20<=0;raw_q20<=0;even_pcm<=0;odd_pcm<=0;pair_valid<=1;raw_valid<=1;end
    end
    MWAIT:if(loaded&&!ram_write)state<=MLOAD;
    MLOAD:begin
     current<=index;mstart<=param_q[247:232];main_v<=ms;onset_v<=os;
     mphase<=first?param_q[119:88]:ram_q[127:96];mstep<=param_q[87:56];glide<=gl;gd<=param_q[23:0];
     
     ev0<=ms;ev1<=os;eowner<=0;eadvance<=age>param_q[247:232];eactive<=age>=param_q[247:232];
     fetch(index==48?8'd64:index+1'b1);state<=MEWAIT;
    end
    MEWAIT:state<=MENV;
    MENV:begin
     ed0<=rounded0==0?1:rounded0;ed1<=rounded1==0?1:rounded1;state<=EDEC;
    end
    EDEC:begin
     evn0<=!eadvance?ev0:difference0[32]?0:difference0[31:0];
     evn1<=!eadvance?ev1:difference1[32]?0:difference1[31:0];state<=EOUT;
    end
    EOUT:begin
     case(eowner)
      0:begin
       main_n<=evn0;onset_n<=evn1;env<=envelope;
       state<=MPWAIT;
      end
      1:begin
       next_em0<=evn0;next_eo0<=evn1;en0<=envelope;
       ev0<=em1;ev1<=eo1;eowner<=2;eadvance<=age>eparam1[127:112];eactive<=age>=eparam1[127:112];
       state<=NE1;
      end
      default:begin next_em1<=evn0;next_eo1<=evn1;en1<=envelope;state<=NSQLOAD;end
     endcase
    end
    MPWAIT:state<=MPHASE;
    MPHASE:begin
     phase_n<=age>mstart?mphase+(p1>>>15):mphase;
     body_phase<=age>mstart?(mphase+(p1>>>15))>>20:mphase>>20;
     glide_n<=age<=mstart?glide:(gdrop==0?(glide>0?glide-1:glide<0?glide+1:0):glide-gdrop);
     state<=MCWAIT;
    end
    MCWAIT:state<=MCLOAD;
    MCLOAD:begin state<=MMWAIT;end
    MMWAIT:state<=MDONE;
    MDONE:begin
     body_sum<=body_sum+p0;write_state(current);
     state<=current==48?PWAIT:MWAIT;
    end
    PWAIT:if(loaded&&!ram_write)state<=PLOAD;
    PLOAD:begin
     current<=index;gtag<=index;gdelta<=param_q[191:160];gpeak<=param_q[159:136];gacc<=param_q[39:0];
     gphase<=age==param_q[287:272]?param_q[255:224]:ram_q[159:128];
     gstep<=age==param_q[287:272]?param_q[223:192]:ram_q[127:96];
     gell<=age==param_q[287:272]?param_q[135:88]:ram_q[95:48];
     gdiff<=age==param_q[287:272]?param_q[87:40]:ram_q[47:0];
     
     fetch(index==191?8'd192:index+1'b1);
     if(age>=param_q[287:272]&&age<({1'b0,param_q[287:272]}+param_q[271:256]))state<=PPWAIT;
     else if(index==191)begin drain<=0;state<=PDRAIN;end else state<=PWAIT;
    end
    PPWAIT:state<=PFIRE;
    PFIRE:begin
     gphase_step<=p0>>>15;absolute_step<=bent_step<0?-bent_step:bent_step;state<=PAWAIT;
    end
    PAWAIT:begin state<=PALWAIT;end
    PALWAIT:state<=PASCALE;
    PASCALE:begin
     gi<=1;gpeak<=p0>>>15;
     if(current==191)begin drain<=0;state<=PDRAIN;end else state<=PWAIT;
    end
    PDRAIN:begin
     drain<=drain+1'b1;
     if(drain==6)begin band<=0;naddr<=192;state<=NWAIT;end
    end
    NWAIT:if(loaded)state<=NLOAD;
    NLOAD:begin
     seed<=param_q[255:224];nb<=param_q[223:200];na1<=param_q[199:176];na2<=param_q[175:152];ngain<=param_q[151:128];eparam0<=param_q[127:0];
     rd_addr<=naddr;fetch(8'd193+{band,1'b0});rd_addr<=naddr;state<=NR1;
    end
    NR1:begin rd_addr<=naddr+1'b1;state<=NR2;end
    NR2:begin
     rng<=first?seed:ram_q[159:128];x1<=first?0:ram_q[127:96];x2<=first?0:ram_q[95:64];y1<=first?0:ram_q[63:32];y2<=first?0:ram_q[31:0];
     rd_addr<=naddr+2'd2;state<=NR3;
    end
    NR3:begin
     z1<=first?0:ram_q[159:128];z2<=first?0:ram_q[127:96];
     em0<=first?eparam0[111:80]:ram_q[95:64];eo0<=first?eparam0[79:48]:ram_q[63:32];
     em1<=ram_q[31:0];state<=NEWAIT;
    end
    NEWAIT:if(loaded)begin
     eparam1<=param_q[127:0];if(first)em1<=param_q[111:80];eo1<=first?param_q[79:48]:ram_q[31:0];
     state<=NE0;
     ev0<=em0;ev1<=eo0;eowner<=1;eadvance<=age>eparam0[127:112];eactive<=age>=eparam0[127:112];
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
     
     
     nrng<=rng_next(rng);xx<=$signed(rng_next(rng))>>>16<<8;state<=NSQUARE;
    end
    NSQUARE:state<=NF0WAIT;
    NF0WAIT:begin
     power<=p0+p1;state<=NF0;
    end
    NF0:begin exponent<=power_exp;sqrt_index<=power_scan[63:54];state<=NF1WAIT;end
    NF1WAIT:begin filter_acc<=noise_filter0;state<=NF1;end
    NF1:begin noise_amp<=power==0?0:({47'd0,math_q}<<exponent)>>16;state<=NF2WAIT;end
    NF2WAIT:begin
     yy<=filter_finish>>>22;state<=NF2;
    end
    NF2:state<=NF3WAIT;
    NF3WAIT:begin filter_acc<=noise_filter0;state<=NF3;end
    NF3:state<=NNWAIT;
    NNWAIT:begin zz<=filter_finish>>>22;state<=NNORM;end
    NNORM:state<=NOWAIT;
    NOWAIT:begin normalized<=(p0+57'sd32768)>>>16;state<=NOUT;end
    NOUT:state<=NW0;
    NW0:begin
     noise_sum<=noise_sum+(p0>>>31);write_state(naddr);state<=NW1;
    end
    NW1:begin write_state(naddr+1'b1);state<=NW2;end
    NW2:begin
     write_state(naddr+2'd2);
     if(band==11)state<=TOTAL;
     else begin band<=band+1'b1;naddr<=naddr+3;fetch(8'd194+{band,1'b0});state<=NWAIT;end
    end
    TOTAL:begin
     raw_q20<=new_total;raw_valid<=1;write_state(8'd228+hp);rd_addr<=8'd228+hp;
     fi<=0;fir_sum<=0;fir_even<=0;state<=FSTORE;
    end
    FSTORE:state<=FREAD;
    FREAD:state<=FLOAD;
    FLOAD:begin
     
     state<=FWAIT;
    end
    FWAIT:state<=FMAC;
    FMAC:begin
     fir_sum<=fir_sum+p0;if(fi==10)fir_even<=(p1+57'sd2097152)>>>22;
     if(fi==19)state<=FINISH;else begin fi<=fi+1'b1;rd_addr<=8'd228+next_history_offset;state<=FREAD;end
    end
    FINISH:begin
     even_q20<=fir_even;odd_q20<=(fir_sum+64'sd2097152)>>>22;
     
     hp<=hp==27?0:hp+1'b1;if(history_count<21)history_count<=history_count+1'b1;
     if(age>=100000)started<=0;state<=VWAIT;
    end
    VWAIT:state<=VDONE;
    VDONE:begin even_pcm<=pcm(p0);odd_pcm<=pcm(p1);pair_valid<=1;state<=IDLE;end
    default:state<=IDLE;
   endcase
  end
 end
endmodule
