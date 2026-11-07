`timescale 1ns/1ps
`default_nettype none
module tb_lissajous_pairs;
    `include "sim/result.svh"
    reg clk=0;always #10 clk=~clk;
    reg rst_n=0,clear=0,sample_tick=0;
    reg signed [15:0] left=0,right=0,aligned_dry=0,effect_output=0;
    reg [1:0] graph_kind=2,liss_stride=1;
    reg liss_fx_pair=0,freeze_graph=0,right_channel=0,read_lock=0;
    reg [5:0] read_address=0,host_address=0;
    wire [15:0] read_data,host_data;wire lock_granted,ready,fft_busy;
    wire [31:0] revision;wire [63:0] peak_bins,peak_magnitudes;wire [7:0] graph_config;
    audio_observer dut(.*);
    integer checks=0,stride,n,expected_x,expected_y;reg [31:0] old_revision;
    integer circle_x[0:31],circle_y[0:31];real angle;
    task automatic feed(input integer i);
        begin
            left=16'(i*17-17000);right=-left;aligned_dry=16'(i*9-9000);effect_output=16'(i*7+2000);
            sample_tick=1;@(negedge clk);sample_tick=0;repeat(99)@(negedge clk);
        end
    endtask
    initial begin
        repeat(4)@(negedge clk);rst_n=1;repeat(5)@(negedge clk);
        for(integer c=0;c<4;c=c+1)begin
            clear=1;@(negedge clk);clear=0;liss_stride=c;liss_fx_pair=c[0];
            repeat(5)@(negedge clk);stride=1<<(c*2);old_revision=revision;
            for(integer i=0;i<32*stride;i=i+1)feed(i);
            repeat(100)@(negedge clk);
            if(!ready||revision==old_revision||graph_config!=={2'd0,graph_kind,liss_fx_pair,liss_stride,right_channel})
                $fatal(1,"LISS no coherent config publication c=%0d",c);
            read_lock=1;while(!lock_granted)@(negedge clk);old_revision=revision;
            for(integer i=0;i<32;i=i+1)begin
                n=(i+1)*stride-1;
                expected_x=liss_fx_pair ? n*9-9000:n*17-17000;
                expected_y=liss_fx_pair ? n*7+2000:-(n*17-17000);
                read_address=i*2;repeat(2)@(negedge clk);
                if(read_data!==16'(expected_x))$fatal(1,"LISS X c=%0d i=%0d got=%0d expected=%0d",c,i,$signed(read_data),expected_x);
                read_address=i*2+1;repeat(2)@(negedge clk);
                if(read_data!==16'(expected_y))$fatal(1,"LISS Y c=%0d i=%0d got=%0d expected=%0d",c,i,$signed(read_data),expected_y);
                checks=checks+2;
            end
            read_lock=0;freeze_graph=1;
            for(integer i=0;i<32*stride;i=i+1)feed(i);
            if(revision!=old_revision)$fatal(1,"LISS freeze changed snapshot");freeze_graph=0;
        end
        // 同频正交测试：XY来自同一采样相位，幅值保持12000，不由显示自动归一化。
        clear=1;@(negedge clk);clear=0;liss_stride=0;liss_fx_pair=0;
        repeat(5)@(negedge clk);
        for(integer i=0;i<32;i=i+1)begin
            angle=6.283185307179586*i/32.0;
            circle_x[i]=$rtoi(12000.0*$cos(angle));circle_y[i]=$rtoi(12000.0*$sin(angle));
            left=16'(circle_x[i]);right=16'(circle_y[i]);sample_tick=1;
            @(negedge clk);sample_tick=0;repeat(99)@(negedge clk);
        end
        repeat(100)@(negedge clk);read_lock=1;
        while(!lock_granted)@(negedge clk);
        for(integer i=0;i<32;i=i+1)begin
            read_address=i*2;repeat(2)@(negedge clk);
            if(read_data!==16'(circle_x[i]))$fatal(1,"LISS circle X pairing");
            read_address=i*2+1;repeat(2)@(negedge clk);
            if(read_data!==16'(circle_y[i]))$fatal(1,"LISS circle Y pairing");checks=checks+2;
        end
        complete_test("tb_lissajous_pairs",checks);$display("PASS tb_lissajous_pairs paired_sources_stride_1_4_16_64_freeze checks=%0d",checks);$finish;
    end
    initial begin #20000000;$fatal(1,"LISS timeout");end
endmodule
`default_nettype wire
