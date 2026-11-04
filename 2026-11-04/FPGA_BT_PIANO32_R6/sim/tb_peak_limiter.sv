`timescale 1ns/1ps
module tb_peak_limiter;
    `include "sim/result.svh"
    reg clk=0;always #10 clk=~clk;
    reg rst_n=0,clear=0,valid_in=0,enabled=0;reg signed [18:0] sample_in=0;reg [1:0] release_preset=1;
    wire signed [15:0] out;wire valid,clip,limited;wire [15:0] gain;wire [18:0] pre,post;
    pcm_peak_limiter dut(.clk(clk),.rst_n(rst_n),.clear(clear),.valid_in(valid_in),.enabled(enabled),.sample_in(sample_in),
        .release_preset(release_preset),.sample_out(out),.valid_out(valid),.clipped(clip),.limited(limited),.gain_q15(gain),.peak_in(pre),.peak_out(post));
    integer checks=0,previous_gain,expected_gain,expected_out,cycles;
    task automatic sample(input integer value);
        begin
            previous_gain=gain;
            @(negedge clk);sample_in=value;valid_in=1;@(negedge clk);valid_in=0;cycles=0;
            while(!valid&&cycles<40)begin @(negedge clk);cycles=cycles+1;end
            if(!valid)$fatal(1,"limiter deadline");
            if(!enabled)begin
                expected_out=value>32767?32767:value< -32768?-32768:value;
                if(out!==16'(expected_out)||gain!=32768||clip!=(value>32767||value< -32768)||limited)$fatal(1,"bypass mismatch");
            end else begin
                expected_gain=previous_gain+(release_preset==0?14:release_preset==1?7:release_preset==2?3:1);
                if(expected_gain>32768)expected_gain=32768;
                if(value>30000||value< -30000)begin
                    if(983040000/(value<0?-value:value)<expected_gain)expected_gain=983040000/(value<0?-value:value);
                end
                expected_out=(64'(value)*64'(expected_gain))>>>15;
                if(out!==16'(expected_out)||gain!=expected_gain||clip||limited!=(gain<32768)||out>30000||out< -30000)
                    $fatal(1,"limiter mismatch input=%0d output=%0d expected=%0d gain=%0d expected_gain=%0d",value,out,expected_out,gain,expected_gain);
            end
            if(pre!=(value<0?-value:value)||post!=(out<0?-32'(out):32'(out)))$fatal(1,"peak metadata mismatch");
            checks=checks+1;repeat(3)@(negedge clk);
        end
    endtask
    initial begin
        repeat(4)@(negedge clk);rst_n=1;
        for(integer i=-262144;i<=262140;i=i+4093)sample(i);
        enabled=1;
        for(integer p=0;p<4;p=p+1)begin
            release_preset=p;
            sample(262143);sample(-262144);sample(30001);sample(-30001);sample(0);sample(29999);
            for(integer i=0;i<300;i=i+1)sample(((i*17131)%524288)-262144);
            for(integer i=0;i<300;i=i+1)sample(i%2?100:-100);
        end
        // In-flight reset must cancel the old high-level sample.
        @(negedge clk);sample_in=262143;valid_in=1;@(negedge clk);valid_in=0;
        repeat(8)@(negedge clk);clear=1;@(negedge clk);clear=0;
        repeat(40)begin @(negedge clk);if(valid||out!=0||gain!=32768)$fatal(1,"clear leaked result");end
        enabled=0;sample(12345);enabled=1;sample(12345);
        complete_test("tb_peak_limiter",checks);$display("PASS tb_peak_limiter checks=%0d same_sample_ceiling=30000",checks);$finish;
    end
    initial begin #20000000;$fatal(1,"timeout");end
endmodule
