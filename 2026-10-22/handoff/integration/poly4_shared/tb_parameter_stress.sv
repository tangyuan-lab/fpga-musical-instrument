`timescale 1ns/1ps
module tb_parameter_stress;
 reg clk=0;always #10 clk=~clk;
 reg rst=0;reg [3:0] request=0;reg [11:0] bank=12'hfff;reg [31:0] address=32'hffffffff;
 wire [3:0] ready,valid,ref_valid;wire [1151:0] data,ref_data;
 reg [3:0] reference_grant=0;reg [11:0] reference_bank;reg [31:0] reference_address;
 always @(posedge clk)begin
  if(!rst)reference_grant<=0;else reference_grant<=ready;
  reference_bank<=bank;reference_address<=address;
 end
 drums_parameter_4 dut(.clk(clk),.rst_n(rst),.request(request),.bank(bank),.address(address),.ready(ready),.response_valid(valid),.response_data(data));
 genvar c;generate for(c=0;c<4;c=c+1)begin:references
  rimshot_parameter_port reference(.clk(clk),.rst_n(rst),.request(reference_grant[c]),.bank(reference_bank[c*3+:3]),.address(reference_address[c*8+:8]),
   .ready(),.response_valid(ref_valid[c]),.response_data(ref_data[c*288+:288]));
 end endgenerate
 integer grants[0:3],waited[0:3];integer checks=0,cycle,i;reg [3:0] accepted,granted,last_grant=0;
 initial begin
  for(i=0;i<4;i=i+1)begin grants[i]=0;waited[i]=0;end
  repeat(5)@(negedge clk);bank=0;address=0;
  repeat(2)@(negedge clk);rst=1;request=15;
  // Each client independently walks every address in all six libraries.
  // Metadata changes immediately after acceptance, before response checking.
  for(cycle=0;cycle<6*256*4+8;cycle=cycle+1)begin
   @(posedge clk);accepted=last_grant;granted=ready;last_grant=ready;
   if(ready!=1&&ready!=2&&ready!=4&&ready!=8)$fatal(1,"Arbiter did not grant exactly one waiting client");
   @(negedge clk);
   if(valid!==accepted||ref_valid!==accepted)$fatal(1,"Response ownership changed");
   for(i=0;i<4;i=i+1)begin
    if(valid[i])begin
     if(data[i*288+:288]!==ref_data[i*288+:288])$fatal(1,"Parameter mismatch client=%0d grant=%0d got=%h expected=%h address=%d bank=%d",i,grants[i],data[i*288+:288],ref_data[i*288+:288],address[i*8+:8],bank[i*3+:3]);
     checks=checks+1;
    end
    if(granted[i])begin
     grants[i]=grants[i]+1;waited[i]=0;
     bank[i*3+:3]=(grants[i]/256)%6;
     address[i*8+:8]=grants[i]%256;
    end else begin waited[i]=waited[i]+1;if(waited[i]>3)$fatal(1,"Parameter starvation client=%0d",i);end
   end
  end
  // Reset cancels return ownership, then arbitration restarts cleanly.
  rst=0;repeat(2)@(negedge clk);if(valid!==0)$fatal(1,"Reset retained stale response");
  rst=1;repeat(8)@(negedge clk);
  $display("PASS parameter stress: %0d tagged returns, all six libraries/all addresses/four clients, wait <=3 clocks",checks);$finish;
 end
endmodule
