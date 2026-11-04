// One immutable nine-block accepted parameter bank, four independent clients.
// Library number and address are selected together by the fair arbiter.
module drums_parameter_4(
 input wire clk,rst_n,input wire [3:0] request,input wire [11:0] bank,input wire [31:0] address,
 output reg [3:0] ready,output reg [3:0] response_valid,output wire [1151:0] response_data
);
 reg [1:0] next_client,chosen;reg found;integer offset,candidate;
 always @*begin
  ready=0;chosen=next_client;found=0;
  for(offset=0;offset<4;offset=offset+1)begin
   candidate=(next_client+offset)&3;
   if(!found&&request[candidate]&&rst_n)begin found=1;chosen=candidate;ready[candidate]=1;end
  end
 end
 reg [2:0] accepted_bank;reg [7:0] accepted_address;reg [3:0] accepted;
 wire [287:0] data;
 // Grant metadata is registered together. The mapper and nine-block fanout
 // now start at local registers; response ownership has the same extra stage.
 rimshot_parameter_port storage(.clk(clk),.rst_n(rst_n),.request(|accepted),.bank(accepted_bank),.address(accepted_address),
  .ready(),.response_valid(),.response_data(data));
 assign response_data={4{data}};
 always @(posedge clk)begin
  if(!rst_n)begin next_client<=0;accepted<=0;response_valid<=0;end
  else begin
   accepted<=ready;response_valid<=accepted;
   if(found)begin next_client<=chosen+1'b1;accepted_bank<=bank[chosen*3+:3];accepted_address<=address[chosen*8+:8];end
  end
 end
endmodule
