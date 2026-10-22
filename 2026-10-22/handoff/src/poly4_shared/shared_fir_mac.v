// Exact signed 32x25 dot product. low16 is unsigned, high16 signed.
// Twenty unrestricted 25x16 partial products fit each 48-bit accumulator.
// The extra coefficient bit preserves negation of signed 24-bit minima.
module shared_fir_mac(
 input wire clk,rst_n,in_valid,first,last,
 input wire signed [31:0] sample,input wire signed [24:0] coefficient,
 output reg out_valid,out_last,output wire signed [63:0] sum
);
 // synthesis translate_off
 GSR GSR(.GSRI(1'b1));
 // synthesis translate_on
 reg v0,v1,f0,f1,l0,l1,fold_pending;
 wire [26:0] a=in_valid?{{2{coefficient[24]}},coefficient}:27'd0;
 wire [35:0] halves={{{2{sample[31]}},sample[31:16]},{2'd0,sample[15:0]}};
 wire signed [47:0] partial_sum[0:1];
 genvar n;generate for(n=0;n<2;n=n+1)begin:lanes
  MULTALU27X18 #(.AREG_CLK("CLK0"),.BREG_CLK("CLK0"),.PREG_CLK("CLK0"),
   .OREG_CLK("CLK0"),.OREG_CE("CE1"),.DYN_ACC_SEL("TRUE"),.DYN_C_SEL("TRUE"),.C_SEL(1'b0),.PRE_LOAD(48'd0)) mac(
   .A(a),.B(halves[n*18+:18]),.C(n==1?{{16{partial_sum[0][47]}},partial_sum[0][47:16]}:48'd0),.D(26'd0),.SIA(27'd0),.CASI(48'd0),
   .PSEL(1'b0),.ASEL(1'b0),.CSEL(n==1&&fold_pending),.CASISEL(1'b0),.PADDSUB(1'b0),.ACCSEL(!f1),.ADDSUB(2'd0),
   .CLK({1'b0,clk}),.CE({v1||(n==1&&fold_pending),1'b1}),.RESET({1'b0,!rst_n}),.DOUT(partial_sum[n]),.CASO(),.SOA());
 end endgenerate
 always @(posedge clk)begin
  f0<=first&&in_valid;f1<=f0;l0<=last;l1<=l0;
  if(!rst_n)begin v0<=0;v1<=0;fold_pending<=0;out_valid<=0;out_last<=0;end
  else begin v0<=in_valid;v1<=v0;fold_pending<=v1&&l1;out_valid<=fold_pending;out_last<=fold_pending;end
 end
 // One zero-product tail operation folds floor(low_sum/2^16) into the high
 // accumulator via C. Concatenation then reconstructs the exact sum.
 // A group must leave four idle input edges after its last accepted tap.
 assign sum={partial_sum[1],partial_sum[0][15:0]};
 // synthesis translate_off
 always @(posedge clk)if(rst_n&&fold_pending&&in_valid)$fatal(1,"FIR groups overlap their final carry fold");
 // synthesis translate_on
endmodule
