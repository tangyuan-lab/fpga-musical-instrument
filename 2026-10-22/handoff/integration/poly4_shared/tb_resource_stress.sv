`timescale 1ns/1ps
module tb_resource_stress;
 parameter integer RESPONSE_CYCLES=2,PIANO_SECOND_LANE=0;
 reg clk=0;always #10 clk=~clk;
 reg rst=0;reg [2:0] rr=0,rw=0,mr=0,pair=0;
 reg [26:0] address=0;reg [479:0] wd=0;
 reg [107:0] a0=0,a1=0;reg [80:0] b0=0,b1=0;reg [17:0] tag=0;
 wire [2:0] rg,rv,mg,mv;wire [479:0] rd;wire [188:0] p0,p1;wire [17:0] rt;
 shared_voice_ram ram(.clk(clk),.rst_n(rst),.request(rr),.write_enable(rw),.address(address),.write_data(wd),.ready(rg),.response_valid(rv),.response_data(rd));
 shared_voice_mul #(.RESPONSE_CYCLES(RESPONSE_CYCLES),.PIANO_SECOND_LANE(PIANO_SECOND_LANE)) math(.clk(clk),.rst_n(rst),.request(mr),.pair(pair),.a0(a0),.a1(a1),.b0(b0),.b1(b1),.tag(tag),
  .ready(mg),.response_valid(mv),.product0(p0),.product1(p1),.response_tag(rt));
 reg [159:0] expected_memory[0:511],expected_read;
 reg [2:0] expected_rv=0,expected_mv[0:4103];
 reg signed [62:0] expected_p0[0:4103][0:2],expected_p1[0:4103][0:2];reg [5:0] expected_tag[0:4103][0:2];
 reg [31:0] rng=32'h73a5c619;integer cycle=0,i,n,reads=0,writes=0,products=0,concurrent=0;
 reg [2:0] expected_grant;
 reg signed [35:0] sa;reg signed [26:0] sb;
 function [31:0] next_rng;input [31:0] x;reg [31:0] t;begin t=x^(x<<13);t=t^(t>>17);next_rng=t^(t<<5);end endfunction
 initial begin
  for(n=0;n<512;n=n+1)expected_memory[n]=0;
  for(n=0;n<4104;n=n+1)expected_mv[n]=0;
  repeat(5)@(negedge clk);
  for(cycle=0;cycle<4096;cycle=cycle+1)begin
   rst=(cycle%97!=0)&&(cycle%97!=1);rng=next_rng(rng);rr=rng[2:0];rw=rng[5:3];mr=rng[8:6];pair=rng[11:9];
   if(PIANO_SECOND_LANE)pair[2]=0;
   for(i=0;i<3;i=i+1)begin
    rng=next_rng(rng);address[i*9+:9]=rng[8:0];wd[i*160+:160]={rng,~rng,rng^32'h80000001,rng+32'd1,rng-32'd1};
    rng=next_rng(rng);a0[i*36+:36]={rng[3:0],rng};b0[i*27+:27]=rng[26:0];
    rng=next_rng(rng);a1[i*36+:36]={rng[7:4],rng};b1[i*27+:27]=rng[30:4];tag[i*6+:6]=(cycle+i)%64;
   end
   @(posedge clk);
   if(rst)begin
    expected_grant=0;
    if(mr[0])expected_grant[0]=1;else if(mr[1])expected_grant[1]=1;
    if(PIANO_SECOND_LANE)expected_grant[2]=mr[2]&&!(|(expected_grant[1:0]&pair[1:0]));
    else if(!(|expected_grant))expected_grant[2]=mr[2];
    if(mg!==expected_grant)$fatal(1,"Arbitration mismatch cycle=%0d got=%b want=%b",cycle,mg,expected_grant);
    if(mg[2]&&(|mg[1:0]))concurrent=concurrent+1;
    if(rv!==expected_rv)$fatal(1,"RAM response ownership cycle=%0d",cycle);
    for(i=0;i<3;i=i+1)begin
     if(rv[i]&&rd[i*160+:160]!==expected_read)$fatal(1,"RAM data/write-through cycle=%0d client=%0d",cycle,i);
     if(mv[i]!==expected_mv[cycle][i])$fatal(1,"Multiplier validity cycle=%0d client=%0d",cycle,i);
     if(mv[i])begin
      if(p0[i*63+:63]!==expected_p0[cycle][i]||rt[i*6+:6]!==expected_tag[cycle][i])$fatal(1,"Multiplier data/tag cycle=%0d client=%0d",cycle,i);
      if(expected_p1[cycle][i]!==63'bx&&p1[i*63+:63]!==expected_p1[cycle][i])$fatal(1,"Second multiplier data cycle=%0d client=%0d",cycle,i);
      products=products+1;
     end
    end
    expected_rv=rg;
    for(i=0;i<3;i=i+1)begin
     if(rg[i])begin
      if(rw[i])begin expected_memory[address[i*9+:9]]=wd[i*160+:160];writes=writes+1;end else reads=reads+1;
      expected_read=expected_memory[address[i*9+:9]];
     end
     if(mg[i])begin
      expected_mv[cycle+RESPONSE_CYCLES][i]=1;expected_tag[cycle+RESPONSE_CYCLES][i]=tag[i*6+:6];
      sa=a0[i*36+:36];sb=b0[i*27+:27];expected_p0[cycle+RESPONSE_CYCLES][i]=sa*sb;
      if(pair[i])begin sa=a1[i*36+:36];sb=b1[i*27+:27];expected_p1[cycle+RESPONSE_CYCLES][i]=sa*sb;end
      else expected_p1[cycle+RESPONSE_CYCLES][i]=63'bx;
     end
    end
   end else begin
    expected_rv=0;for(n=cycle;n<=cycle+3;n=n+1)expected_mv[n]=0;
   end
   @(negedge clk);
  end
  if(PIANO_SECOND_LANE&&concurrent<100)$fatal(1,"Missing concurrent coverage");
  $display("PASS resource stress: RAM %0d reads/%0d writes, %0d signed tagged products, %0d concurrent grants, pipeline resets, persistent dirty RAM",reads,writes,products,concurrent);$finish;
 end
endmodule
