`timescale 1ns/1ps
`include "sim/shared_modal_backend32_94f0_reference.sv"
`include "sim/shared_models8_render32_94f0_reference.sv"
module tb_render_hardening;
 `include "sim/result.svh"
 GSR GSR(.GSRI(1'b1));
 reg clk=0;always #10 clk=~clk;
 reg rst_n=0,panic=0,tick=0;reg [31:0] active=32'hffffffff,held=32'hffffffff;
 reg [511:0] generation=0;reg [159:0] timbres=0,banks=0;reg [223:0] pressures=0;
 reg [767:0] damping={32{24'h603460}};reg [63:0] profiles=0;reg [223:0] velocities=0;
 wire [4:0] pa_o,pa_c;reg [31:0] pitch_o,pitch_c;
 always @(posedge clk)begin pitch_o<=32'h10000000+{11'd0,pa_o,16'd0};pitch_c<=32'h10000000+{11'd0,pa_c,16'd0};end
 wire bo,bc,so,sc,po,pc,to_,tc,eo,ec,lo,lc,beo,bec,ao,ac,fo,fc;
 wire [511:0] pp_o,pp_c,tp_o,tp_c,ep_o,ep_c,pg_o,pg_c,tg_o,tg_c,eg_o,eg_c;
 wire [31:0] pf_o,pf_c,tf_o,tf_c,ef_o,ef_c;
 shared_models8_render32_94f0_reference #(.DAMPING_ENABLE(1),.VELOCITY_TONE_ENABLE(1)) dut_o(.clk(clk),.rst_n(rst_n),.sample_tick(tick),.panic(panic),.active(active),.held(held),.damping_settings(damping),.velocity_tone_profiles(profiles),.velocities(velocities),
 .generation(generation),.timbres(timbres),.piano_banks(banks),.pressures(pressures),.piano_pitch_word(pitch_o),.piano_pitch_addr(pa_o),.drum_pitch_ratios(512'd0),
 .busy(bo),.sample_valid(so),.deadline_error(lo),.parameter_error(beo),.alignment_error(ao),.frame_failed(fo),
 .piano_valid(po),.tom_valid(to_),.exc_valid(eo),.piano_pcm(pp_o),.tom_pcm(tp_o),.exc_pcm(ep_o),
 .piano_finished(pf_o),.tom_finished(tf_o),.exc_finished(ef_o),.piano_finished_generation(pg_o),.tom_finished_generation(tg_o),.exc_finished_generation(eg_o),.frame_cycles(),.max_frame_cycles());
 shared_models8_render32 #(.DAMPING_ENABLE(1),.VELOCITY_TONE_ENABLE(1)) dut_c(.clk(clk),.rst_n(rst_n),.sample_tick(tick),.panic(panic),.active(active),.held(held),.damping_settings(damping),.velocity_tone_profiles(profiles),.velocities(velocities),
 .generation(generation),.timbres(timbres),.piano_banks(banks),.pressures(pressures),.piano_pitch_word(pitch_c),.piano_pitch_addr(pa_c),.drum_pitch_ratios(512'd0),
 .busy(bc),.sample_valid(sc),.deadline_error(lc),.parameter_error(bec),.alignment_error(ac),.frame_failed(fc),
 .piano_valid(pc),.tom_valid(tc),.exc_valid(ec),.piano_pcm(pp_c),.tom_pcm(tp_c),.exc_pcm(ep_c),
 .piano_finished(pf_c),.tom_finished(tf_c),.exc_finished(ef_c),.piano_finished_generation(pg_c),.tom_finished_generation(tg_c),.exc_finished_generation(eg_c),.frame_cycles(),.max_frame_cycles());
 integer cycle=0,ref_cycle=-9,ref_count=0,cand_count=0;reg have_ref=0;
 reg [3167:0] reference;reg [31:0] nonzero=0;
 wire [3167:0] bundle_o={pp_o,tp_o,ep_o,pf_o,tf_o,ef_o,pg_o,tg_o,eg_o};
 wire [3167:0] bundle_c={pp_c,tp_c,ep_c,pf_c,tf_c,ef_c,pg_c,tg_c,eg_c};
 always @(negedge clk)begin
  cycle=cycle+1;
  if(rst_n)begin
   if((^{po,pc,to_,tc,eo,ec,lo,lc,beo,bec,ao,ac,fo,fc})===1'bx)$fatal(1,"render control X");
   if(lo||lc||beo||bec||ao||ac||fo||fc)$fatal(1,"render error flag");
   if(po!==to_||po!==eo||pc!==tc||pc!==ec)$fatal(1,"render channel valid mismatch");
   if(po)begin
    if(have_ref)$fatal(1,"render duplicate reference");
    if((^bundle_o)===1'bx)$fatal(1,"render reference X");
    reference=bundle_o;ref_cycle=cycle;ref_count=ref_count+1;have_ref=1;
   end
   if(pc)begin
    if(!have_ref||cycle-ref_cycle!=0)$fatal(1,"render latency mismatch ref_cycle=%0d candidate=%0d",ref_cycle,cycle);
    if((^bundle_c)===1'bx)$fatal(1,"render candidate X");
    if(bundle_c!==reference)$fatal(1,"render PCM/finished/generation mismatch frame=%0d",cand_count);
    cand_count=cand_count+1;have_ref=0;
    for(integer i=0;i<32;i=i+1)if(pp_c[i*16+:16]!=0)nonzero[i]=1;
   end
   if(panic&&(po||pc||so||sc))$fatal(1,"render cancelled commit");
  end
 end
 task automatic launch;
  begin @(negedge clk);if(bo||bc)$fatal(1,"render busy launch");tick=1;@(negedge clk);tick=0;end
 endtask
 task automatic frame;
  integer n;
  begin launch();n=0;
   while((bo||bc)&&n<700)begin @(negedge clk);n=n+1;end
   if(bo||bc)$fatal(1,"render completion timeout");
   repeat(2)@(negedge clk);
  end
 endtask
 initial begin
  for(integer i=0;i<32;i=i+1)begin
   timbres[i*5+:5]=i%3==0?10:i%3==1?19:20;banks[i*5+:5]=i%17;
   generation[i*16+:16]=16'h1000+i;pressures[i*7+:7]=32+i*3;velocities[i*7+:7]=32+i*3;profiles[i*2+:2]=i%4;
  end
  repeat(4)@(negedge clk);rst_n=1;repeat(12)frame();held=32'h55aa55aa;repeat(4)frame();
  for(integer k=0;k<3;k=k+1)begin
   launch();repeat(k==0?20:k==1?100:500)@(negedge clk);
   if(!bo||!bc)$fatal(1,"render cancel not inflight");panic=1;
   repeat(2)@(negedge clk);panic=0;repeat(4)frame();
  end
  if(ref_count!=28||cand_count!=28||nonzero!==32'hffffffff)$fatal(1,"render coverage ref=%0d cand=%0d nonzero=%h",ref_count,cand_count,nonzero);
  complete_test("tb_render_hardening",cand_count);$display("PASS tb_render_hardening commits=%0d exact_data latency=0",cand_count);$finish;
 end
 initial begin #3000000;$fatal(1,"render timeout");end
endmodule
