`timescale 1ns/1ps
module tb_observer;
 `include "sim/result.svh"
 reg clk=0,rst_n=0,clear=0,sample_tick=0;always #10 clk=~clk;
 reg signed [15:0] left=0,right=0;reg [1:0] graph_kind=1;
 reg freeze_graph=0,right_channel=0,read_lock=0;reg [5:0] read_address=0,host_address=0;
 reg liss_fx_pair=0;reg [1:0] liss_stride=0;
 wire signed [15:0] aligned_dry=left,effect_output=right;wire [7:0] graph_config;
 wire [15:0] read_data,host_data;wire lock_granted,ready,fft_busy;
 wire [31:0] revision;wire [63:0] peak_bins,peak_magnitudes;
 audio_observer dut(.*);
 integer i,w,mode,checks=0,peak1,peak2;reg [31:0] rev;reg [15:0] words[0:63];
 real x;
 task automatic feed(input integer dual);
  begin
   for(i=0;i<512;i=i+1)begin
    @(negedge clk);x=10000.0*$sin(6.283185307179586*8*i/512.0);
    if(dual)x=x+7000.0*$sin(6.283185307179586*16*i/512.0);
    left=$rtoi(x);right=-left;sample_tick=1;
    @(negedge clk);sample_tick=0;
   end
  end
 endtask
 initial begin
  repeat(4)@(negedge clk);rst_n=1;
  for(mode=0;mode<2;mode=mode+1)begin
   rev=revision;feed(mode);w=0;
   while(revision==rev&&w<20000)begin @(negedge clk);w=w+1;end
   if(w>=20000||!ready)$fatal(1,"FFT publication timeout");
   if(peak_bins[15:0]!=8)$fatal(1,"FFT expected 750Hz bin8 got %0d",peak_bins[15:0]);
   if(mode&&peak_bins[31:16]!=16)$fatal(1,"FFT expected 1500Hz bin16");
   if((^peak_magnitudes)===1'bx||peak_magnitudes[15:0]<4000)$fatal(1,"FFT magnitude/X");
   checks=checks+1;
  end
  @(negedge clk);read_lock=1;
  while(!lock_granted)@(negedge clk);
  rev=revision;
  for(i=0;i<64;i=i+1)begin
   read_address=i;host_address=i;repeat(2)@(negedge clk);
   if((^read_data)===1'bx||read_data!==host_data)$fatal(1,"observer snapshot X/mismatch");words[i]=read_data;
  end
  if(revision!=rev||words[8]<4000||words[16]<2500)$fatal(1,"observer snapshot incoherent");
  read_lock=0;freeze_graph=1;feed(0);repeat(17000)@(negedge clk);
  if(revision!=rev)$fatal(1,"observer freeze changed revision");checks=checks+1;
  freeze_graph=0;graph_kind=0;rev=revision;feed(0);
  w=0;while(revision==rev&&w<20000)begin @(negedge clk);w=w+1;end
  if(w>=20000)$fatal(1,"waveform publication timeout");checks=checks+1;
  graph_kind=2;rev=revision;feed(0);w=0;
  while(revision==rev&&w<20000)begin @(negedge clk);w=w+1;end
  if(w>=20000)$fatal(1,"lissajous publication timeout");checks=checks+1;
  complete_test("tb_observer",checks);$display("PASS tb_observer checks=%0d",checks);$finish;
 end
 initial begin #5000000;$fatal(1,"observer global timeout");end
endmodule
