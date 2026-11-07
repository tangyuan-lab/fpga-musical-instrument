`timescale 1ns/1ps
module tb_snapshot_contract;
  `include "sim/result.svh"
  reg src_clk=0,dst_clk=0,rst_n=0;
  always #5 src_clk=~src_clk;
  initial begin #3;forever #10 dst_clk=~dst_clk;end
  reg [31:0] seq=0;wire [99:0] in_data={seq,~seq,seq,4'ha};
  wire [99:0] out_data;wire valid;
  snapshot_cdc #(.WIDTH(100)) dut(.src_clk(src_clk),.src_rst_n(rst_n),.src_data(in_data),
    .dst_clk(dst_clk),.dst_rst_n(rst_n),.dst_data(out_data),.dst_valid(valid));
  always @(posedge src_clk)if(!rst_n)seq<=0;else seq<=seq+1;
  integer captures=0,holds=0;reg pending;reg [99:0] held_before,captured;
  always @(posedge src_clk)if(rst_n)begin
    pending=dut.ack_sync[1]!=dut.request;held_before=dut.held_data;
    #1;if(pending)begin
      if(dut.held_data!==held_before)$fatal(1,"snapshot changed before acknowledge");holds=holds+1;
    end
  end
  always @(posedge dst_clk)if(rst_n)begin
    captured=dut.held_data;
    #1;if(valid)begin
      if((^out_data)===1'bx)$fatal(1,"snapshot X");
      if(out_data!==captured)$fatal(1,"snapshot captured wrong bundle");
      if(out_data[99:68]!==out_data[35:4]||out_data[67:36]!==~out_data[99:68]||out_data[3:0]!==4'ha)$fatal(1,"snapshot incoherent");
      captures=captures+1;
    end
  end
  initial begin
    #42;rst_n=1;repeat(300)@(negedge src_clk);
    #2;rst_n=0;#31;rst_n=1;repeat(300)@(negedge src_clk);
    if(captures<50||holds<300)$fatal(1,"snapshot vacuous");
    complete_test("tb_snapshot_contract",captures+holds);$display("PASS tb_snapshot_contract captures=%0d holds=%0d",captures,holds);$finish;
  end
  initial begin #20000;$fatal(1,"snapshot timeout");end
endmodule
