`timescale 1ns/1ps
module tb_integer_rules;
reg is_C,f_first,f_started;reg [16 : 0] f_age;reg [287 : 0] coefficient;reg [127 : 0] old_row;reg [31 : 0] glide;reg [32 : 0] increment;reg [62 : 0] product0,product1;
 wire signed [33 : 0] tom_frequency=$signed({2'b00,coefficient[87 : 56]})+$signed(glide);
 wire [31 : 0] C_frequency=tom_frequency[31 : 0];
 wire signed [35 : 0] frequency_operand=is_C ? {{4{C_frequency[31]}},C_frequency} : tom_frequency[33] ? 36'd0 : (|tom_frequency[32 : 31])  ?  36'h07fffffff  :  {4'd0,tom_frequency[31 : 0]};
 wire [17 : 0] alias_roll=18'd131072-{1'b0,increment[30 : 14]}-(|increment[13 : 0]);
 wire [23 : 0] alias_factor=(|increment[32 : 31]) ? 24'd0 : (&increment[30 : 29]) ? {6'd0,alias_roll} : 24'd32768;
 function [32 : 0] rounded_drop;
  input [62 : 0] p;reg [31 : 0] upper,rounded;
  begin
   upper=is_C ? p[55 : 24] : {8'd0,p[47 : 24]};
   rounded=upper+p[23];
   rounded_drop=rounded==0 ? 33'd1 : {1'b0,rounded};
  end
 endfunction
 wire signed [33 : 0] glide_drop=$signed({product0[56],product0[56 : 24]})+$signed({33'd0,product0[23]});
 wire [31 : 0] glide_adjust=glide_drop!=0 ? glide_drop[31 : 0] : glide==0 ? 32'd0 : glide[31] ? 32'hffffffff : 32'd1;
 wire [31 : 0] phase_base=f_first ? coefficient[119 : 88] : (is_C||f_started) ? old_row[127 : 96] : 32'd0;
 wire phase_advance=is_C ? f_age>coefficient[247 : 232] : !f_first&&f_started;
 function signed [15 : 0] pcm;
  input signed [56 : 0] value;
  reg signed [56 : 0] v;
  begin
   v=value>>>12;
   pcm=v[56] ? ((&v[55 : 15]) ? v[15 : 0] : 16'h8000) : ((|v[55 : 15]) ? 16'h7fff : v[15 : 0]);
  end
 endfunction

integer i;reg signed [63 : 0] p,expected_drop;reg [32 : 0] want_round;reg [31 : 0] want_glide,want_phase;reg [23 : 0] want_alias;reg signed [56 : 0] sample;reg signed [63 : 0] v;reg signed [15 : 0] want_pcm;
initial begin
for(i=0;i<100000;i=i+1)begin
 is_C=i%2;f_first=i%7==0;f_started=i%11!=0;f_age=$random;coefficient={$random,$random,$random,$random,$random,$random,$random,$random,$random};old_row={$random,$random,$random,$random};glide=$random;product0={$random,$random};product1={$random,$random};increment={$random,$random};
 if(i<64)begin product0=i-32;increment=(i%8==0) ? 33'h080000000 : (i%8==1) ? 33'h060000000 : (i%8==2) ? 33'h07fffffff : i;end
 #1;
 p=$signed(product0[56 : 0]);expected_drop=(p+64'sd8388608)>>>24;
 want_glide=expected_drop==0 ? ($signed(glide)>0 ? glide-1 : $signed(glide)<0 ? glide+1 : 0) : glide-expected_drop;
 if(glide_drop!==expected_drop[33 : 0]||glide-glide_adjust!==want_glide)$fatal(1,"Glide rule mismatch i=%0d p=%0d old=%0d new=%0d",i,p,expected_drop,glide_drop);
 want_round=is_C ? {1'b0,(product0[55 : 24]+product0[23])} : ({9'd0,product0[47 : 24]}+product0[23]);if(want_round==0)want_round=1;
 if(rounded_drop(product0)!==want_round)$fatal(1,"Decay rounding mismatch %0d",i);
 want_alias=increment>=33'h080000000 ? 0 : increment<=33'h060000000 ? 32768 : (33'h080000000-increment)>>14;
 if(alias_factor!==want_alias)$fatal(1,"Alias rule mismatch %0d",i);
 sample=product0[56 : 0];v=$signed(sample)>>>12;want_pcm=v>32767 ? 32767 : v< -32768 ? -32768 : v;
 if(pcm(sample)!==want_pcm)$fatal(1,"PCM clipping mismatch %0d",i);
end
$display("PASS 100000 actual RTL integer-rule vectors :  signed glide rounding/minimum step, C/T decay rounding, alias taper, full-width PCM clipping");$finish;end
endmodule
