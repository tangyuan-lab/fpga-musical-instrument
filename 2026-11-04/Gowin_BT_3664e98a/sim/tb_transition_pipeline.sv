`timescale 1ns/1ps
`include "sim/transition_reference.sv"
module tb_transition_pipeline;
 `include "sim/result.svh"
 reg clk=0;always #10 clk=~clk;
 reg rst_n=0,panic=0,start=0;
 reg [31:0] active=0;reg [511:0] generation=0,pcm=0;reg [159:0] timbres=0;
 wire bo,bc,vo,vc,eo,ec;wire [511:0] po,pc;
 voice_transition32_reference original(.clk(clk),.rst_n(rst_n),.panic(panic),.start(start),
  .active32(active),.generation512(generation),.timbres160(timbres),.voice_pcm512(pcm),
  .busy(bo),.valid(vo),.deadline_error(eo),.pcm_out512(po));
 voice_transition32 candidate(.clk(clk),.rst_n(rst_n),.panic(panic),.start(start),
  .active32(active),.generation512(generation),.timbres160(timbres),.voice_pcm512(pcm),
  .busy(bc),.valid(vc),.deadline_error(ec),.pcm_out512(pc));
 integer cycle=0,ref_cycle=0,commits=0,seed=32'h2061029;reg pending=0;
 reg [511:0] saved;reg [31:0] nonzero=0;
 always @(negedge clk)begin
  cycle=cycle+1;
  if(rst_n)begin
   if((^{vo,vc,eo,ec,bo,bc})===1'bx||eo||ec)$fatal(1,"transition invalid control");
   if(panic)begin
    pending=0;
    if(vo||vc||bo||bc||po!==0||pc!==0)$fatal(1,"transition cancelled output");
   end else begin
    if(vo)begin
     if(pending||(^po)===1'bx)$fatal(1,"transition reference duplicate/X");
     saved=po;pending=1;ref_cycle=cycle;
    end
    if(vc)begin
     if(!pending||cycle-ref_cycle!=1)$fatal(1,"transition latency");
     if((^pc)===1'bx||pc!==saved)$fatal(1,"transition payload mismatch frame=%0d",commits);
     for(integer i=0;i<32;i=i+1)if(pc[i*16+:16]!=0)nonzero[i]=1;
     commits=commits+1;pending=0;
    end
   end
  end
 end
 task automatic launch;
  begin @(negedge clk);#1;
   if(bo||bc)$fatal(1,"transition start busy");start=1;
   @(negedge clk);#1;start=0;
  end
 endtask
 task automatic finish_frame;
  integer w;
  begin w=0;while((bo||bc)&&w<45)begin @(negedge clk);#1;w=w+1;end
   if(bo||bc)$fatal(1,"transition frame timeout");repeat(2)@(negedge clk);#1;
  end
 endtask
 initial begin
  repeat(4)@(negedge clk);#1;rst_n=1;active=32'hffffffff;
  for(integer f=0;f<90;f=f+1)begin
   for(integer i=0;i<32;i=i+1)begin
    pcm[i*16+:16]=f==0?0:f%4==0?16'h8000:f%4==1?16'h7fff:$random(seed);
    if(f%17==0)begin generation[i*16+:16]=f+i;timbres[i*5+:5]=i%3==0?10:i%3==1?19:20;end
   end
   active=f%9==8?32'h55aa55aa:32'hffffffff;
   launch();finish_frame();
  end
  // 扫描、乘法在途及末槽写回附近取消；取消后不复位，直接新帧。
  for(integer off=0;off<4;off=off+1)begin
   launch();repeat(off==0?1:off==1?16:off==2?32:33)@(negedge clk);#1;panic=1;
   repeat(2)@(negedge clk);#1;panic=0;launch();finish_frame();
  end
  if(commits!=94||pending||nonzero!==32'hffffffff)$fatal(1,"transition coverage commits=%0d nonzero=%h",commits,nonzero);
  complete_test("tb_transition_pipeline",commits);$display("PASS tb_transition_pipeline commits=%0d exact_data latency=+1",commits);$finish;
 end
 initial begin #200000;$fatal(1,"transition test timeout");end
endmodule
