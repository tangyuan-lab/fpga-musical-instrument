`timescale 1ns/1ps
`include "src/poly4_shared/resource_ports.vh"
module tb_C;
 parameter integer BANK=0,FRAMES=256,BEND=0,TRACE=0;
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
 `RESOURCE_WIRES(p_)
 shared_C_core dut(.clk(clk),.rst_n(rst),.tick24(tick),.note_on(on),.velocity(velocity),.pitch_ratio_q15(pitch),
  .cp_request(req[1]),.cp_ready(rdy[1]),.cp_valid(pv[1]),.cp_address(addr[8+:8]),.cp_data(pd[288+:288]),
  .raw_q20(raw[1]),.even_q20(even_q[1]),.odd_q20(odd_q[1]),.even_pcm(ep[1]),.odd_pcm(op[1]),.pair_valid(valid[1]),.raw_valid(raw_valid[1]),.overrun(ov[1]),`RESOURCE_LINK(p_));
 resource_fixture resources(.clk(clk),.rst_n(rst),`RESOURCE_LINK(p_));
 always @(posedge clk)if(TRACE&&rst&&f<2)begin
  if(dut.state==dut.TOTAL)$display("RAW frame=%0d value=%0d hp=%0d",f,dut.new_total,dut.hp);
  if(dut.state==dut.FSTREAM&&p_ram_request&&p_ram_ready)$display("FIR read tag=%0d addr=%0d",dut.fir_issue,p_ram_address);
  if(dut.state==dut.FSTREAM&&p_mul_request&&p_mul_ready)$display("FIR issue tag=%0d a=%0d b=%0d q=%0d history=%0d",p_mul_tag,p_mul_a0,p_mul_b0,$signed(p_ram_q[31:0]),dut.history_count);
  if(p_ram_request&&p_ram_ready&&p_ram_write&&dut.state!=dut.BODY)$display("WRITE addr=%0d value=%0d sel=%b",p_ram_address,$signed(p_ram_data[31:0]),dut.wr_select);
  if(dut.state==dut.FSTREAM&&p_mul_valid)$display("FIR result tag=%0d p=%0d",p_result_tag,p_product0);
  if(dut.state==dut.FINISH)$display("FIR sum=%0d",dut.fir_sum);
 end
 integer f,c,max_clocks=0;reg [1:0] seen,seen_raw;
 reg signed [31:0] raw_capture[0:1],even_capture[0:1],odd_capture[0:1];reg signed [15:0] ep_capture[0:1],op_capture[0:1];
 initial begin
  repeat(8)@(negedge clk);rst=1;repeat(4)@(negedge clk);
  for(f=0;f<FRAMES;f=f+1)begin
   on=f==0||f==173;velocity=f<173?112:73;
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
   if(seen!=3||seen_raw!=3||ov!=0)$fatal(1,"C deadline bank=%0d frame=%0d state=%0d clocks=%0d seen=%b raw=%b",BANK,f,dut.state,c,seen,seen_raw);
   if(raw_capture[0]!==raw_capture[1])begin
    $display("optimized total=%0d accepted body=%0d packet=%0d noise=%0d",dut.total,reference.body_sum,reference.packet_sum,reference.noise_sum);
    $fatal(1,"C raw mismatch bank=%0d frame=%0d got=%0d want=%0d",BANK,f,raw_capture[1],raw_capture[0]);
   end
   if(even_capture[0]!==even_capture[1]||odd_capture[0]!==odd_capture[1]||ep_capture[0]!==ep_capture[1]||op_capture[0]!==op_capture[1])
    $fatal(1,"C FIR mismatch bank=%0d frame=%0d got=%0d,%0d want=%0d,%0d",BANK,f,even_capture[1],odd_capture[1],even_capture[0],odd_capture[0]);
   repeat(2083-c)@(negedge clk);
  end
  $display("PASS shared C bank %0d: %0d raw/FIR/PCM pairs exact, max clocks %0d",BANK,FRAMES,max_clocks);$finish;
 end
 initial begin #2000000000;$fatal(1,"C watchdog state=%0d loaded=%b read=%b",dut.state,dut.loaded,dut.read_loaded);end
endmodule
