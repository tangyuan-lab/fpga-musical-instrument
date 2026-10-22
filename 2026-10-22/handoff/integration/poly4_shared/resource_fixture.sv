// Unit-test adapter. Integrated tests use all three real clients in each voice.
module resource_fixture(
 input wire clk,rst_n,ram_request,ram_write,output wire ram_ready,ram_valid,
 input wire [8:0] ram_address,input wire [159:0] ram_data,output wire [159:0] ram_q,
 input wire mul_request,mul_pair,output wire mul_ready,mul_valid,
 input wire signed [35:0] mul_a0,mul_a1,input wire signed [26:0] mul_b0,mul_b1,
 input wire [5:0] mul_tag,output wire [5:0] result_tag,
 output wire signed [62:0] product0,product1
);
 wire [2:0] rr,rv,mr,mv;wire [479:0] rd;wire [188:0] mp0,mp1;wire [17:0] mt;
 shared_voice_ram memory(.clk(clk),.rst_n(rst_n),.request({2'b0,ram_request}),.write_enable({2'b0,ram_write}),
  .address({18'd0,ram_address}),.write_data({320'd0,ram_data}),.ready(rr),.response_valid(rv),.response_data(rd));
 assign ram_ready=rr[0];assign ram_valid=rv[0];assign ram_q=rd[0+:160];
 shared_voice_mul arithmetic(.clk(clk),.rst_n(rst_n),.request({2'b0,mul_request}),.pair({2'b0,mul_pair}),
  .a0({72'd0,mul_a0}),.a1({72'd0,mul_a1}),.b0({54'd0,mul_b0}),.b1({54'd0,mul_b1}),.tag({12'd0,mul_tag}),
  .ready(mr),.response_valid(mv),.product0(mp0),.product1(mp1),.response_tag(mt));
 assign mul_ready=mr[0];assign mul_valid=mv[0];assign product0=mp0[0+:63];assign product1=mp1[0+:63];assign result_tag=mt[0+:6];
endmodule
