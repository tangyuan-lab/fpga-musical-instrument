// Address remapping only; generator mathematics and read latency unchanged.
module rimshot_parameter_port(
 input wire clk,rst_n,request,input wire [2:0] bank,input wire [7:0] address,
 output wire ready,output reg response_valid,output wire [287:0] response_data);
 reg [8:0] physical_address;
 assign ready=request&&rst_n;
 always @*begin
  physical_address=9'd0;
  case(bank)
   3'd0:begin
    if(address<8'd49)physical_address={1'b0,address}+9'd1;
    else if(address>=8'd64&&address<8'd192)physical_address={1'b0,address}-9'd14;
    else if(address>=8'd192&&address<8'd216)physical_address={1'b0,address}-9'd14;
   end
   3'd1:begin
    if(address<8'd16)physical_address={1'b0,address}+9'd202;
    else if(address>=8'd64&&address<8'd160)physical_address={1'b0,address}+9'd154;
    else if(address>=8'd192&&address<8'd216)physical_address={1'b0,address}+9'd122;
   end
   3'd2:begin
    if(address<8'd16)physical_address={1'b0,address}+9'd338;
    else if(address>=8'd64&&address<8'd96)physical_address={1'b0,address}+9'd290;
    else if(address>=8'd192&&address<8'd216)physical_address={1'b0,address}+9'd194;
   end
   3'd3:begin
    if(address<8'd8)physical_address={1'b0,address}+9'd410;
    else if(address>=8'd64&&address<8'd80)physical_address={1'b0,address}+9'd354;
    else if(address>=8'd192&&address<8'd204)physical_address={1'b0,address}+9'd242;
   end
   3'd4:begin
    if(address<8'd4)physical_address={1'b0,address}+9'd446;
    else if(address>=8'd64&&address<8'd72)physical_address={1'b0,address}+9'd386;
    else if(address>=8'd192&&address<8'd204)physical_address={1'b0,address}+9'd266;
   end
   3'd5:begin
    if(address<8'd22)physical_address={1'b0,address}+9'd470;
    else if(address>=8'd64&&address<8'd72)physical_address={1'b0,address}+9'd428;
    else if(address>=8'd192&&address<8'd204)physical_address={1'b0,address}+9'd308;
   end
   default:physical_address=0;
  endcase
 end
 rimshot_parameter_storage storage(.clk(clk),.address(physical_address),.data(response_data));
 always @(posedge clk)begin
  if(!rst_n)response_valid<=0;else response_valid<=ready;
 end
endmodule
