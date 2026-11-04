`timescale 1ns/1ps
`include "sim/mcp3208_dynamic_model.sv"
module tb_adc_rate_contract;
    `include "sim/result.svh"
    reg clk=0;always #10 clk=~clk;reg rst_n=0;
    wire [95:0] v2,v4;wire s2,m2,c20,c21,s4,m4,c40,c41,mi2,mi4,f2,f4;
    reg [95:0] values={8{12'd300}};
    mcp3208_dynamic_model a2(.cs_n(c20),.sclk(s2),.mosi(m2),.values(values),.miso(mi2));
    mcp3208_dynamic_model a4(.cs_n(c40),.sclk(s4),.mosi(m4),.values(values),.miso(mi4));
    mcp3208_dual_scan #(.HALF_PERIOD(2),.ADC_PRESENT_MASK(1)) d2(.clk(clk),.rst_n(rst_n),.mcp0_miso(mi2),.mcp1_miso(1'b0),
        .mcp_sclk(s2),.mcp_mosi(m2),.mcp0_cs_n(c20),.mcp1_cs_n(c21),.samples0(v2),.samples1(),.frame_valid(f2),.ready(),.fault());
    mcp3208_dual_scan #(.HALF_PERIOD(4),.ADC_PRESENT_MASK(1)) d4(.clk(clk),.rst_n(rst_n),.mcp0_miso(mi4),.mcp1_miso(1'b0),
        .mcp_sclk(s4),.mcp_mosi(m4),.mcp0_cs_n(c40),.mcp1_cs_n(c41),.samples0(v4),.samples1(),.frame_valid(f4),.ready(),.fault());
    initial begin
        repeat(4)@(negedge clk);rst_n=1;repeat(10000)@(negedge clk);
        if(v4!=={8{12'd300}})$fatal(1,"ADC four-clock digital contract mismatch %h",v4);
        if(v2==={8{12'd300}})$fatal(1,"ADC test did not reproduce invalid two-clock configuration");
        complete_test("tb_adc_rate_contract",16);
        $display("PASS tb_adc_rate_contract half2_actual=%0d expected300 half4_actual=%0d; half2 rejected as invalid accelerated stimulus",v2[11:0],v4[11:0]);$finish;
    end
    initial begin #500000;$fatal(1,"ADC rate check timeout");end
endmodule
