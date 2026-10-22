// Exact (x0*b - x1*a1 - x2*a2 + 2^21) >>> 22, truncated to 32 bits.
// Two 27x18 MACs sum signed high halves and unsigned low halves separately.
// Job inputs must remain stable until response_valid. No datapath reset is
// needed: the first accepted term overwrites both complete accumulators.
module shared_noise_biquad(
 input wire clk,rst_n,start,
 input wire signed [31:0] x0,x1,x2,
 input wire signed [23:0] b,a1,a2,
 output wire ready,output reg busy,response_valid,
 output reg signed [31:0] result
);
 reg [1:0] issue;
 reg valid,first,last,finish;
 reg signed [42:0] product_hi,product_lo;
 reg signed [47:0] sum_hi,sum_lo;
 wire signed [31:0] source=issue==0?x0:issue==1?x1:x2;
 wire signed [24:0] coefficient=issue==0?{b[23],b}:issue==1?-$signed({a1[23],a1}):-$signed({a2[23],a2});
 wire signed [17:0] high_half={{2{source[31]}},source[31:16]};
 wire signed [17:0] low_half={2'b00,source[15:0]};
 wire signed [63:0] high_extended={{16{sum_hi[47]}},sum_hi};
 wire signed [63:0] low_extended={{16{sum_lo[47]}},sum_lo};
 wire signed [63:0] combined=(high_extended<<<16)+low_extended+64'sd2097152;
 assign ready=!busy;
 always @(posedge clk)begin
  product_hi<=coefficient*high_half;product_lo<=coefficient*low_half;
  if(valid)begin
   sum_hi<=first?product_hi:sum_hi+product_hi;
   sum_lo<=first?product_lo:sum_lo+product_lo;
  end
  if(!rst_n)begin busy<=0;response_valid<=0;issue<=3;valid<=0;first<=0;last<=0;finish<=0;end
  else begin
   response_valid<=0;
   valid<=busy&&issue<3;first<=issue==0;last<=issue==2;
   finish<=valid&&last;
   if(start&&ready)begin busy<=1;issue<=0;end
   else if(busy&&issue<3)issue<=issue+1'b1;
   if(finish)begin result<=combined>>>22;response_valid<=1;busy<=0;end
  end
 end
endmodule
