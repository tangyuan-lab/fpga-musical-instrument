`timescale 1ns/1ps
// Call the production function; compare against the accepted round-then-
// subtract operation across full widths, including 32-bit rounding wrap.
module tb_decay_carry;
 integer i;reg [31:0] value,expected,got;reg [62:0] product;reg [32:0] drop;
 shared_drum_stream dut(.clk(1'b0),.rst_n(1'b0),.product0(product));
 initial begin
  for(i=0;i<200000;i=i+1)begin
   dut.is_C=i%2;value=$random;product={$random,$random};
   case(i%32)
    0:begin product=0;value=0;end
    1:begin product=0;value=1;end
    2:begin product=0;value=32'hffffffff;end
    3:product=63'h00ffffffff800000;
    4:product=63'h00ffffffff000000;
    5:product=63'h0000000000800000;
    6:begin product=63'h007fffffff800000;value=32'h80000000;end
   endcase
   drop=dut.rounded_drop(product);
   expected=value<drop?0:value-drop;
   got=dut.decayed_product(value,product);
   if(got!==expected)$fatal(1,"Decay carry mismatch i=%0d C=%0d value=%h product=%h expected=%h got=%h",i,dut.is_C,value,product,expected,got);
   dut.f_first=1;dut.parameter_buffer=0;dut.parameter_buffer[55:24]=value;
   #1;
   if(dut.glide_next!==value-dut.glide_adjust)$fatal(1,"Glide carry mismatch i=%0d",i);
  end
  $display("PASS actual modal carry subtraction: 200000 full-width random/boundary C/T decay and signed glide cases");$finish;
 end
endmodule
