module tb_key16_instrument_map;
 reg [3:0] key_index;reg [1:0] timbre;reg low_c3_mode;
 wire [4:0] note_index;wire valid;
 key16_instrument_map dut(.*);
 integer k,t,m;
 initial begin
  for(t=0;t<4;t=t+1)for(m=0;m<2;m=m+1)for(k=0;k<16;k=k+1)begin
   key_index=k;timbre=t;low_c3_mode=m;#1;
   if(valid!==((t==0)||(t==2)||((t==1)&&(k<8))))$fatal(1,"valid");
   if(note_index!==((t==0&&m==1&&k==0)?5'd16:{1'b0,key_index}))$fatal(1,"mapping");
  end
  $display("PASS 16-key instrument map: 128 combinations");$finish;
 end
endmodule
