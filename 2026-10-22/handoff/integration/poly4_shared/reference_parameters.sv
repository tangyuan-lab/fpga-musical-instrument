module reference_parameters(
 input wire clk,rst_n,input wire [3:0] request,input wire [11:0] bank,input wire [31:0] address,
 output wire [3:0] ready,response_valid,output wire [1151:0] response_data
);
 genvar v;generate for(v=0;v<4;v=v+1)begin:voices
  // Four unmodified accepted single-client banks, independent of the new arbiter.
  rimshot_parameter_port parameters(.clk(clk),.rst_n(rst_n),.request(request[v]),.bank(bank[v*3+:3]),.address(address[v*8+:8]),
   .ready(ready[v]),.response_valid(response_valid[v]),.response_data(response_data[v*288+:288]));
 end endgenerate
endmodule
