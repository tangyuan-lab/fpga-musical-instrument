`timescale 1ns/1ps
`default_nettype none
module tb_fx_ram;
    `include "sim/result.svh"
    GSR GSR(.GSRI(1'b1));
    reg clk=0;always #10 clk=~clk;
    reg write_enable=0;
    reg [10:0] write_address=0,read_address=0;
    reg signed [15:0] write_data=0;
    wire signed [15:0] read_data;
    sample_ram #(.ADDRESS_WIDTH(11)) dut(.*);
    integer checks=0;
    function automatic [15:0] expected(input integer a);
        expected=16'((a*7919)^16'ha55a);
    endfunction
    initial begin
        repeat(5)@(negedge clk);
        for(integer i=0;i<2048;i=i+1)begin
            write_enable=1;write_address=i;write_data=expected(i);
            @(negedge clk);
        end
        write_enable=0;
        for(integer i=0;i<2048;i=i+1)begin
            read_address=i;repeat(4)@(negedge clk);
            if((^read_data)===1'bx || read_data!==expected(i))
                $fatal(1,"FX_RAM_WRITE_MISSING addr=%0d expected=%h actual=%h",i,expected(i),read_data);
            checks=checks+1;
        end
        complete_test("tb_fx_ram",checks);
        $display("PASS tb_fx_ram two_banks_signed_bytes checks=%0d",checks);$finish;
    end
    initial begin #1000000;$fatal(1,"FX_RAM timeout");end
endmodule
`default_nettype wire
