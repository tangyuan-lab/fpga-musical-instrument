`timescale 1ns/1ps
`include "src/poly4_shared/resource_ports.vh"
module tb_C_modes;
 parameter integer TRACE=0;
 integer BANK=0,FRAMES=256,BEND=0,RETRIGGER=1;
 initial begin
  if($value$plusargs("bank=%d",BANK))begin end
  if($value$plusargs("frames=%d",FRAMES))begin end
  if($value$plusargs("bend=%d",BEND))begin end
  if($value$plusargs("retrigger=%d",RETRIGGER))begin end
 end
 reg clk=0;always #10 clk=~clk;
 reg rst=0,tick=0,on=0;reg [15:0] pitch=32768;reg [6:0] velocity=112;
 wire [1:0] req,rdy,pv,valid,raw_valid,ov;
 wire [15:0] addr;wire [575:0] pd;
 wire signed [31:0] raw[0:1],even_q[0:1],odd_q[0:1];wire signed [15:0] ep[0:1],op[0:1];
 genvar i;generate for(i=0;i<2;i=i+1)begin:rom
 if(i==0)begin:accepted
  rimshot_parameter_port p(.clk(clk),.rst_n(rst),.request(req[i]),.bank(BANK[2:0]),.address(addr[i*8+:8]),
   .ready(rdy[i]),.response_valid(pv[i]),.response_data(pd[i*288+:288]));
 end else begin:shared
  wire [3:0] grant,response_valid;wire [1151:0] response_data;
  drums_parameter_4 p(.clk(clk),.rst_n(rst),.request({3'd0,req[i]}),.bank({9'd0,BANK[2:0]}),.address({24'd0,addr[i*8+:8]}),
   .ready(grant),.response_valid(response_valid),.response_data(response_data));
  assign rdy[i]=grant[0];assign pv[i]=response_valid[0];assign pd[i*288+:288]=response_data[0+:288];
 end
 end endgenerate
 tom_C_core reference(.clk(clk),.rst_n(rst),.tick24(tick),.note_on(on),.velocity(velocity),.pitch_ratio_q15(pitch),
  .cp_request(req[0]),.cp_ready(rdy[0]),.cp_valid(pv[0]),.cp_address(addr[0+:8]),.cp_data(pd[0+:288]),
  .raw_q20(raw[0]),.even_q20(even_q[0]),.odd_q20(odd_q[0]),.even_pcm(ep[0]),.odd_pcm(op[0]),.pair_valid(valid[0]),.raw_valid(raw_valid[0]),.overrun(ov[0]));
 C_test_fixture dut(.clk(clk),.rst_n(rst),.tick24(tick),.note_on(on),.velocity(velocity),.pitch_ratio_q15(pitch),
  .cp_request(req[1]),.cp_ready(rdy[1]),.cp_valid(pv[1]),.cp_address(addr[8+:8]),.cp_data(pd[288+:288]),
  .raw_q20(raw[1]),.even_q20(even_q[1]),.odd_q20(odd_q[1]),.even_pcm(ep[1]),.odd_pcm(op[1]),.pair_valid(valid[1]),.raw_valid(raw_valid[1]),.overrun(ov[1]));
 always @(posedge clk)if(TRACE&&rst&&f<2)begin
  if(dut.core.state==dut.core.TOTAL)$display("RAW frame=%0d value=%0d hp=%0d",f,dut.core.new_total,dut.core.hp);
  if(dut.core.state==dut.core.FSTREAM&&dut.c_ram_request&&dut.c_ram_ready)$display("FIR read tag=%0d addr=%0d",dut.core.fir_issue,dut.c_ram_address);
  if(dut.core.state==dut.core.FSTREAM&&dut.c_mul_request&&dut.c_mul_ready)$display("FIR issue tag=%0d a=%0d b=%0d q=%0d history=%0d",dut.c_mul_tag,dut.c_mul_a0,dut.c_mul_b0,$signed(dut.c_ram_q[31:0]),dut.core.history_count);
  if(dut.c_ram_request&&dut.c_ram_ready&&dut.c_ram_write&&dut.core.state!=dut.core.BODY)$display("WRITE addr=%0d value=%0d sel=%b",dut.c_ram_address,$signed(dut.c_ram_data[31:0]),dut.core.wr_select);
  if(dut.core.state==dut.core.FSTREAM&&dut.c_mul_valid)$display("FIR result tag=%0d p=%0d",dut.c_result_tag,dut.c_product0);
  if(dut.core.state==dut.core.FINISH)$display("FIR sum=%0d",dut.core.fir_sum);
 end
 integer f,c,max_clocks=0;reg [1:0] seen,seen_raw;
 reg signed [31:0] raw_capture[0:1],even_capture[0:1],odd_capture[0:1];reg signed [15:0] ep_capture[0:1],op_capture[0:1];
 initial begin
  repeat(8)@(negedge clk);rst=1;repeat(4)@(negedge clk);
  for(f=0;f<FRAMES;f=f+1)begin
   on=f==0||(RETRIGGER&&f==173);velocity=!RETRIGGER||f<173?112:73;
   pitch=BEND?(f<64?32768:f<128?30000:37000):32768;
   seen=0;seen_raw=0;tick=1;@(negedge clk);tick=0;on=0;c=1;
   while(seen!=3&&c<2300)begin
    for(integer v=0;v<2;v=v+1)begin
     if(raw_valid[v])begin seen_raw[v]=1;raw_capture[v]=raw[v];end
     if(valid[v])begin
      seen[v]=1;even_capture[v]=even_q[v];odd_capture[v]=odd_q[v];ep_capture[v]=ep[v];op_capture[v]=op[v];
      if(v==1&&c>max_clocks)max_clocks=c;
     end
    end
    @(negedge clk);c=c+1;
   end
   if(seen!=3||seen_raw!=3||ov!=0)$fatal(1,"C deadline bank=%0d frame=%0d state=%0d clocks=%0d seen=%b raw=%b",BANK,f,dut.core.state,c,seen,seen_raw);
   if(raw_capture[0]!==raw_capture[1])begin
    $display("optimized total=%0d accepted body=%0d packet=%0d noise=%0d",dut.core.total,reference.body_sum,reference.packet_sum,reference.noise_sum);
    $fatal(1,"C raw mismatch bank=%0d frame=%0d got=%0d want=%0d",BANK,f,raw_capture[1],raw_capture[0]);
   end
   if(even_capture[0]!==even_capture[1]||odd_capture[0]!==odd_capture[1]||ep_capture[0]!==ep_capture[1]||op_capture[0]!==op_capture[1])
    $fatal(1,"C FIR mismatch bank=%0d frame=%0d got=%0d,%0d want=%0d,%0d",BANK,f,even_capture[1],odd_capture[1],even_capture[0],odd_capture[0]);
   if(c>=2083||max_clocks>1770)$fatal(1,"Shared C exceeded deadline bank=%0d frame=%0d new=%0d old=%0d",BANK,f,max_clocks,c);
   repeat(4)@(negedge clk);
  end
  $display("PASS shared C bank %0d: %0d raw/FIR/PCM pairs exact, max clocks %0d",BANK,FRAMES,max_clocks);$finish;
 end
 initial begin #100000000000.0;$fatal(1,"C watchdog state=%0d loaded=%b read=%b",dut.core.state,dut.core.loaded,dut.core.read_loaded);end
endmodule
