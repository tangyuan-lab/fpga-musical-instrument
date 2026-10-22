`timescale 1ns/1ps
`include "src/poly4_shared/resource_ports.vh"
module tb_piano_tail;
 parameter integer FRAMES=100000;
 integer NOTE=0,RELEASE=24000;integer zeros=0,mode;reg all_zero,complete=0;
 initial begin
  if($value$plusargs("note=%d",NOTE))begin end
  if($value$plusargs("release=%d",RELEASE))begin end
 end
 reg clk=0;always #10 clk=~clk;
 reg rst=0,tick=0,on=0,off=0,held=0;
 reg [4:0] note=16;reg [6:0] velocity=112;reg [15:0] pitch=32768;
 wire [1:0] pr,pg,pv,sr,sg,sv;wire [21:0] pa;wire [255:0] pd;wire [19:0] sa;wire [31:0] sd;
 wire signed [15:0] got,want;wire gv,wv,overrun;
 genvar i;generate for(i=0;i<2;i=i+1)begin:rom
  rimshot_shared_parameter_port #(.ADDR_WIDTH(11),.DATA_WIDTH(128),.INIT_FILE("src/mem/piano_accepted_coefficients.mem")) p(
   .clk(clk),.rst_n(rst),.request(pr[i]),.ready(pg[i]),.response_valid(pv[i]),.address(pa[i*11+:11]),.response_data(pd[i*128+:128]));
  rimshot_shared_parameter_port #(.ADDR_WIDTH(10),.DATA_WIDTH(16),.INIT_FILE("src/mem/modal_sine_1024x16.mem")) s(
   .clk(clk),.rst_n(rst),.request(sr[i]),.ready(sg[i]),.response_valid(sv[i]),.address(sa[i*10+:10]),.response_data(sd[i*16+:16]));
 end endgenerate
 piano_C_pipelined_voice reference(.clk(clk),.rst_n(rst),.sample_tick(tick),.note_on(on),.note_off(off),.note_active(held),
  .note_index(note),.velocity(velocity),.pitch_ratio_q15(pitch),.sample_out(want),.sample_valid(wv),
  .pp_request(pr[0]),.pp_ready(pg[0]),.pp_valid(pv[0]),.pp_address(pa[0+:11]),.pp_data(pd[0+:128]),
  .ps_request(sr[0]),.ps_ready(sg[0]),.ps_valid(sv[0]),.ps_address(sa[0+:10]),.ps_data(sd[0+:16]));
 `RESOURCE_WIRES(p_)
 shared_piano_voice dut(.clk(clk),.rst_n(rst),.sample_tick(tick),.note_on(on),.note_off(off),.note_active(held),
  .note_index(note),.velocity(velocity),.pitch_ratio_q15(pitch),.sample_out(got),.sample_valid(gv),.overrun(overrun),
  .pp_request(pr[1]),.pp_ready(pg[1]),.pp_valid(pv[1]),.pp_address(pa[11+:11]),.pp_data(pd[128+:128]),
  .ps_request(sr[1]),.ps_ready(sg[1]),.ps_valid(sv[1]),.ps_address(sa[10+:10]),.ps_data(sd[16+:16]),`RESOURCE_LINK(p_));
 wire [2:0] rr,mr;wire [479:0] rd;wire [188:0] mp0,mp1;wire [17:0] mt;wire [2:0] rv,mv;
 shared_voice_ram memory(.clk(clk),.rst_n(rst),.request({p_ram_request,2'b0}),.write_enable({p_ram_write,2'b0}),
  .address({p_ram_address,18'd0}),.write_data({p_ram_data,320'd0}),.ready(rr),.response_valid(rv),.response_data(rd));
 assign p_ram_ready=rr[2];assign p_ram_valid=rv[2];assign p_ram_q=rd[320+:160];
 shared_voice_mul #(.RESPONSE_CYCLES(2)) arithmetic(.clk(clk),.rst_n(rst),.request({p_mul_request,2'b0}),.pair({p_mul_pair,2'b0}),
  .a0({p_mul_a0,72'd0}),.a1({p_mul_a1,72'd0}),.b0({p_mul_b0,54'd0}),.b1({p_mul_b1,54'd0}),.tag({p_mul_tag,12'd0}),
  .ready(mr),.response_valid(mv),.product0(mp0),.product1(mp1),.response_tag(mt));
 assign p_mul_ready=mr[2];assign p_mul_valid=mv[2];assign p_product0=mp0[126+:63];assign p_product1=mp1[126+:63];assign p_result_tag=mt[12+:6];
 integer f,cycles,max_cycles=0;reg seen_g,seen_w;reg signed [15:0] capture_g,capture_w;
 initial begin
  repeat(8)@(negedge clk);rst=1;repeat(4)@(negedge clk);
  for(f=0;f<FRAMES&&!complete;f=f+1)begin
   if(f==0)begin on=1;held=1;note=NOTE;velocity=112;end
   off=f==RELEASE;if(off)held=0;
   pitch=32768;
   tick=1;seen_g=0;seen_w=0;cycles=0;
   @(negedge clk);tick=0;on=0;off=0;
   while(!(seen_g&&seen_w)&&cycles<1041)begin
    if(gv)begin capture_g=got;seen_g=1;if(cycles>max_cycles)max_cycles=cycles;end
    if(wv)begin capture_w=want;seen_w=1;end
    @(negedge clk);cycles=cycles+1;
   end
   if(!seen_g||!seen_w||overrun)$fatal(1,"Piano deadline frame=%0d state=%0d cycles=%0d",f,dut.state,cycles);
   if(capture_g!==capture_w)$fatal(1,"Piano mismatch frame=%0d got=%0d want=%0d sum=%0d oldsum=%0d",f,capture_g,capture_w,dut.mix,reference.mix);
   if(f>RELEASE)begin
    all_zero=1;
    for(mode=0;mode<64;mode=mode+1)if(reference.state_ram[mode][63:0]!==64'd0)all_zero=0;
    if(all_zero&&capture_g==0)zeros=zeros+1;else zeros=0;
    if(zeros==32)complete=1;
   end
   if(f<512)repeat(1041-cycles)@(negedge clk);else repeat(4)@(negedge clk);
  end
  if(!complete)$fatal(1,"Piano release tail did not become exactly silent, note=%0d",NOTE);
  $display("PASS piano note %0d: %0d exact sustain/release frames, all 64 envelope pairs zero, max clocks %0d",NOTE,f,max_cycles);$finish;
 end
 initial begin #100000000000.0;$fatal(1,"Piano watchdog");end
endmodule
