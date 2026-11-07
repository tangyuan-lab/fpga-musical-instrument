`timescale 1ns/1ps
module tb_hw_monitor_reset;
    `include "sim/result.svh"
    reg clk=0,mem_clk=0,clock_enabled=1,rst_n=1,mem_rst_n=1,calibrated=1;
    always #10 clk=~clk;
    always #5 if(clock_enabled)mem_clk=~mem_clk;
    reg command_fire=0,reinit=0;
    wire [399:0] status;
    workstation_hw_status dut(.app_clk(clk),.rst_n(rst_n),.mem_clk(mem_clk),.mem_rst_n(mem_rst_n),
        .pll_locked(1'b1),.calibrated(calibrated),.storage_ready(1'b1),
        .request_fire(1'b0),.response_fire(1'b0),.response_error(1'b0),
        .command_fire(command_fire),.command_write(1'b1),.reinit(reinit),
        .sample_tick(1'b0),.sample_valid(1'b0),.voices(6'd0),.peak_voices(6'd0),
        .deadline_error(1'b0),.parameter_error(1'b0),.timeout_count(32'd0),.status(status));
    integer checks=0,phase;
    initial begin
        #1;rst_n=0;
        for(phase=0;phase<10;phase=phase+1)begin
            #(21+phase);rst_n=1;
            @(negedge mem_clk);
            // 同步释放最少经历目的时钟采样，功能计数尚未接受请求。
            repeat(3)@(negedge mem_clk);
            if(dut.monitor_mem_rst_n!==1||dut.write_count!==0)$fatal(1,"reset release/count phase=%0d",phase);
            command_fire=1;repeat(3)@(negedge mem_clk);command_fire=0;
            if(dut.write_count!==3)$fatal(1,"accepted write count=%0d",dut.write_count);
            reinit=1;repeat(4)@(negedge mem_clk);reinit=0;
            mem_rst_n=0;calibrated=0;repeat(4)@(negedge mem_clk);
            if(dut.write_count!==3||dut.reinit_count!==1)$fatal(1,"DDR reinit erased cumulative counters");
            mem_rst_n=1;calibrated=1;checks=checks+3;
            // 停钟时断言仍必须立即清零；没有时钟不能自行释放。
            clock_enabled=0;#2;rst_n=0;#2;
            if(dut.monitor_mem_rst_n!==0||dut.write_count!==0)$fatal(1,"asynchronous assertion with stopped clock");
            #40;rst_n=1;#20;
            if(dut.monitor_mem_rst_n!==0)$fatal(1,"released without destination clock");
            rst_n=0;clock_enabled=1;checks=checks+2;
        end
        repeat(4)@(negedge clk);
        complete_test("tb_hw_monitor_reset",checks);
        $display("PASS tb_hw_monitor_reset phases=10 checks=%0d",checks);$finish;
    end
    initial begin #100000;$fatal(1,"monitor reset test timeout");end
endmodule
