`timescale 1ns/1ps
`include "src/poly4_shared/resource_ports.vh"
module tb_tom;
 parameter integer FRAMES=256,ADSR_MODE=0;
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
 `RESOURCE_WIRES(p_)
 shared_tom_voice #(.ADSR_ENABLE(ADSR_MODE)) dut(.clk(clk),.rst_n(rst),.sample_tick(tick),.note_on(on),.note_off(off),.note_active(held),
  .note_index(note),.velocity(velocity),.pitch_ratio_q15(pitch),.sample_out(got),.sample_valid(gv),.active(),.overrun(overrun),
  .tp_request(pr[1]),.tp_ready(pg[1]),.tp_valid(pv[1]),.tp_address(pa[8+:8]),.tp_data(pd[256+:256]),
  .ts_request(sr[1]),.ts_ready(sg[1]),.ts_valid(sv[1]),.ts_address(sa[12+:12]),.ts_data(sd[16+:16]),
  .tn_request(nr[1]),.tn_ready(ng[1]),.tn_valid(nv[1]),.tn_address(na[4+:4]),.tn_data(nd[128+:128]),`RESOURCE_LINK(p_));
 resource_fixture resources(.clk(clk),.rst_n(rst),`RESOURCE_LINK(p_));
 integer f,cycles,max_cycles=0;reg seen_g,seen_w;reg signed [15:0] capture_g,capture_w;
 initial begin
  repeat(8)@(negedge clk);rst=1;repeat(4)@(negedge clk);
  for(f=0;f<FRAMES;f=f+1)begin
   if(f%23==0)begin on=1;held=1;note=1+(f/23)%2;velocity=1+(f*17)%127;end
   off=f%23==18;if(off)held=0;
   pitch=f<128?32768:f<192?30000:37000;
   tick=1;seen_g=0;seen_w=0;cycles=0;
   @(negedge clk);tick=0;on=0;off=0;
   while(!(seen_g&&seen_w)&&cycles<1041)begin
    if(gv)begin capture_g=got;seen_g=1;if(cycles>max_cycles)max_cycles=cycles;end
    if(wv)begin capture_w=want;seen_w=1;end
    @(negedge clk);cycles=cycles+1;
   end
   if(!seen_g||!seen_w||overrun||old_overrun)$fatal(1,"Tom deadline frame=%0d state=%0d cycles=%0d",f,dut.state,cycles);
   if(capture_g!==capture_w)$fatal(1,"Tom mismatch frame=%0d got=%0d want=%0d sum=%0d oldsum=%0d",f,capture_g,capture_w,dut.mix,reference.mix);
   repeat(1041-cycles)@(negedge clk);
  end
  $display("PASS shared tom ADSR=%0d: %0d exact frames, max clocks %0d",ADSR_MODE,FRAMES,max_cycles);$finish;
 end
 initial begin #1000000000;$fatal(1,"Tom watchdog");end
endmodule
