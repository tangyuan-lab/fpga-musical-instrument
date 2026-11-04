`timescale 1ns/1ps
`include "src/poly4_shared/resource_ports.vh"
module tb_tom_tail;
 parameter integer FRAMES=500000,ADSR_MODE=0;
 integer NOTE=1,BEND=0,RETRIGGER=0,zeros=0,mode;reg all_zero,complete=0;
 initial begin
  if($value$plusargs("note=%d",NOTE))begin end
  if($value$plusargs("bend=%d",BEND))begin end
  if($value$plusargs("retrigger=%d",RETRIGGER))begin end
 end
 reg clk=0;always #10 clk=~clk;
 reg rst=0,tick=0,on=0,off=0,held=0;
 reg [4:0] note=1;reg [6:0] velocity=112;reg [15:0] pitch=32768;
 wire [1:0] pr,pg,pv,sr,sg,sv,nr,ng,nv;wire [15:0] pa;wire [511:0] pd;wire [23:0] sa;wire [31:0] sd;wire [7:0] na;wire [255:0] nd;
 wire signed [15:0] got,want;wire gv,wv,overrun,old_overrun;
 genvar i;generate for(i=0;i<2;i=i+1)begin:rom
  rimshot_shared_parameter_port #(.ADDR_WIDTH(8),.DATA_WIDTH(256),.INIT_FILE("src/refit_v2/tom_modal_coefficients.mem")) p(
   .clk(clk),.rst_n(rst),.request(pr[i]),.ready(pg[i]),.response_valid(pv[i]),.address(pa[i*8+:8]),.response_data(pd[i*256+:256]));
  rimshot_shared_parameter_port #(.ADDR_WIDTH(12),.DATA_WIDTH(16),.INIT_FILE("src/mem/tom_sine_4096x16.mem")) s(
   .clk(clk),.rst_n(rst),.request(sr[i]),.ready(sg[i]),.response_valid(sv[i]),.address(sa[i*12+:12]),.response_data(sd[i*16+:16]));
  rimshot_shared_parameter_port #(.ADDR_WIDTH(4),.DATA_WIDTH(128),.INIT_FILE("src/refit_v2/tom_noise_coefficients.mem")) n(
   .clk(clk),.rst_n(rst),.request(nr[i]),.ready(ng[i]),.response_valid(nv[i]),.address(na[i*4+:4]),.response_data(nd[i*128+:128]));
 end endgenerate
 tom_shared_voice #(.ADSR_ENABLE(ADSR_MODE)) reference(.clk(clk),.rst_n(rst),.sample_tick(tick),.note_on(on),.note_off(off),.note_active(held),
  .note_index(note),.velocity(velocity),.pitch_ratio_q15(pitch),.sample_out(want),.sample_valid(wv),.active(),.overrun(old_overrun),
  .tp_request(pr[0]),.tp_ready(pg[0]),.tp_valid(pv[0]),.tp_address(pa[0+:8]),.tp_data(pd[0+:256]),
  .ts_request(sr[0]),.ts_ready(sg[0]),.ts_valid(sv[0]),.ts_address(sa[0+:12]),.ts_data(sd[0+:16]),
  .tn_request(nr[0]),.tn_ready(ng[0]),.tn_valid(nv[0]),.tn_address(na[0+:4]),.tn_data(nd[0+:128]));
 T_test_fixture #(.ADSR_ENABLE(ADSR_MODE)) dut(.clk(clk),.rst_n(rst),.sample_tick(tick),.note_on(on),.note_off(off),.note_active(held),
  .note_index(note),.velocity(velocity),.pitch_ratio_q15(pitch),.sample_out(got),.sample_valid(gv),.active(),.overrun(overrun),
  .tp_request(pr[1]),.tp_ready(pg[1]),.tp_valid(pv[1]),.tp_address(pa[8+:8]),.tp_data(pd[256+:256]),
  .ts_request(sr[1]),.ts_ready(sg[1]),.ts_valid(sv[1]),.ts_address(sa[12+:12]),.ts_data(sd[16+:16]),
  .tn_request(nr[1]),.tn_ready(ng[1]),.tn_valid(nv[1]),.tn_address(na[4+:4]),.tn_data(nd[128+:128]));
 integer f,cycles,max_cycles=0;reg seen_g,seen_w;reg signed [15:0] capture_g,capture_w;
 initial begin
  repeat(8)@(negedge clk);rst=1;repeat(4)@(negedge clk);
  for(f=0;f<FRAMES&&!complete;f=f+1)begin
   on=f==0||(RETRIGGER&&f==173);held=1;note=NOTE;velocity=f<173||!RETRIGGER?112:73;
   off=0;pitch=BEND?(f<128?32768:f<192?30000:37000):32768;
   tick=1;seen_g=0;seen_w=0;cycles=0;
   @(negedge clk);tick=0;on=0;off=0;
   while(!(seen_g&&seen_w)&&cycles<1041)begin
    if(gv)begin capture_g=got;seen_g=1;if(cycles>max_cycles)max_cycles=cycles;end
    if(wv)begin capture_w=want;seen_w=1;end
    @(negedge clk);cycles=cycles+1;
   end
   if(!seen_g||!seen_w||overrun||old_overrun)$fatal(1,"Tom deadline frame=%0d state=%0d cycles=%0d",f,dut.core.state,cycles);
   if(capture_g!==capture_w)$fatal(1,"Tom mismatch frame=%0d got=%0d want=%0d sum=%0d oldsum=%0d",f,capture_g,capture_w,dut.core.mix,reference.mix);
   all_zero=1;
   for(mode=0;mode<64;mode=mode+1)if(reference.state_ram[mode][79:32]!==48'd0)all_zero=0;
   for(mode=0;mode<4;mode=mode+1)if(reference.noise_main[mode]!==24'd0||reference.noise_onset[mode]!==24'd0)all_zero=0;
   if(all_zero&&capture_g==0)zeros=zeros+1;else zeros=0;
   if(zeros==32)complete=1;
   if(f<512)repeat(1041-cycles)@(negedge clk);else repeat(4)@(negedge clk);
  end
  if(!complete)$fatal(1,"Tom tail did not become exactly silent, note=%0d",NOTE);
  if(max_cycles>884)$fatal(1,"Tom cycle budget exceeded: %0d",max_cycles);
  $display("PASS shared tom note=%0d bend=%0d retrigger=%0d ADSR=%0d: %0d exact frames, 64 modal and 4 noise envelope pairs zero, max clocks %0d",NOTE,BEND,RETRIGGER,ADSR_MODE,f,max_cycles);$finish;
 end
 initial begin #100000000000.0;$fatal(1,"Tom watchdog");end
endmodule
