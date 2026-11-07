`timescale 1ns/1ps
module tb_screen_scope_capture;
    `include "sim/result.svh"
    GSR GSR(.GSRI(1'b1));
    reg clk=0,rst_n=0,clear=0,enable=1,sample_tick=0,right_channel=0,pop=0;always #10 clk=~clk;
    reg signed [15:0] left=0,right=0;wire [23:0] pair_data;wire [2:0] available;wire overflow;
    screen_scope_capture #(.SAMPLES_PER_COLUMN(4),.ADDRESS_WIDTH(2)) dut(.*);
    integer i,checks=0;
    task tick(input integer l,input integer r);
        begin @(negedge clk);left=l;right=r;sample_tick=1;@(negedge clk);sample_tick=0;repeat(2)@(negedge clk);end
    endtask
    task expect_pair(input integer lo,input integer hi);
        integer a,b;
        begin
            repeat(3)@(negedge clk);a=(lo+32768)/16;b=(hi+32768)/16;
            if(pair_data!={12'(b),12'(a)})$fatal(1,"peak/valley mismatch got=%h expected=%h",pair_data,{12'(b),12'(a)});
            pop=1;@(negedge clk);pop=0;checks=checks+1;
        end
    endtask
    initial begin
        repeat(5)@(negedge clk);rst_n=1;
        tick(-32768,0);tick(0,0);tick(32767,0);tick(200,0);
        if(available!=1)$fatal(1,"one column required");expect_pair(-32768,32767);
        for(i=0;i<4;i=i+1)tick(0,0);expect_pair(0,0);
        tick(-16,0);tick(16,0);tick(0,0);tick(0,0);expect_pair(-16,16);
        right_channel=1;
        tick(-32000,3000);tick(32000,-1000);tick(0,0);tick(0,100);expect_pair(-1000,3000);
        enable=0;for(i=0;i<12;i=i+1)tick(2000,2000);
        if(available!=0)$fatal(1,"paused capture enqueued samples");checks=checks+1;enable=1;
        for(i=0;i<20;i=i+1)tick(100,100);
        if(available!=4||!overflow)$fatal(1,"full FIFO must report loss without overwriting history");checks=checks+1;
        expect_pair(100,100);expect_pair(100,100);expect_pair(100,100);expect_pair(100,100);
        clear=1;@(negedge clk);clear=0;repeat(2)@(negedge clk);
        if(available!=0||overflow)$fatal(1,"explicit gap reset failed");checks=checks+1;
        for(i=0;i<4;i=i+1)tick(0,-32768);expect_pair(-32768,-32768);
        complete_test("tb_screen_scope_capture",checks);$display("PASS tb_screen_scope_capture checks=%0d",checks);$finish;
    end
endmodule
