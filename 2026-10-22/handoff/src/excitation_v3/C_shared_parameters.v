// Exactly one copy of the scalar coefficients. Explicit read-only SP32 banks
// avoid the device mapper's two-block expansion of inferred pROM32 cells.
module C_shared_parameters(
 input wire clk,rst_n,input wire [3:0] request,input wire [31:0] address,
 output reg [3:0] ready,response_valid,output wire [1151:0] response_data
);
 reg [1:0] next_client,chosen;reg found;
 integer i,candidate;
 always @*begin
  found=0;chosen=next_client;ready=0;
  for(i=0;i<4;i=i+1)begin
   candidate=(next_client+i)&3;
   if(!found&&request[candidate]&&rst_n)begin chosen=candidate;found=1;ready[candidate]=1;end
  end
 end
 wire [7:0] selected=address[chosen*8+:8];wire [287:0] data;
 C_parameter_storage storage(.clk(clk),.address(selected),.data(data));
 assign response_data={4{data}};
 always @(posedge clk)begin
  if(!rst_n)begin next_client<=0;response_valid<=0;end
  else begin response_valid<=ready;if(found)next_client<=chosen+1'b1;end
 end
endmodule
