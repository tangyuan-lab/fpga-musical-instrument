`timescale 1ns/1ps
module tb_audio_effects;
    reg clk=0,rst_n=0,tick=0,clear=0;always #10 clk=~clk;
    reg signed [15:0] dry=0;reg [6:0] dm=64,rm=0,fb=0;reg [11:0] delay=4;wire signed [15:0] wet;
    audio_effects dut(.clk(clk),.rst_n(rst_n),.sample_tick(tick),.clear(clear),.dry(dry),.delay_mix(dm),.reverb_mix(rm),.feedback(fb),.delay_samples(delay),.wet(wet));
    task sample(input integer value);
        begin @(negedge clk);dry=value;tick=1;@(negedge clk);tick=0;repeat(14) @(negedge clk);end
    endtask
    integer i;
    initial begin
        repeat(5) @(negedge clk);rst_n=1;
        sample(12000);if(wet!=12000) $fatal(1,"dry impulse %d",wet);
        for(i=1;i<9;i=i+1) begin sample(0);if(wet!=(i==4 ? 6000:0)) $fatal(1,"delay sample %d value=%d",i,wet);end
        clear=1;sample(0);clear=0;dm=0;rm=64;
        sample(12000);
        for(i=1;i<=3100;i=i+1) begin
            sample(0);
            if(i==2048 || i==3072) begin if(wet!=3000) $fatal(1,"reverb impulse %d value=%d",i,wet);end
            else if(wet!=0) $fatal(1,"unexpected/stale RAM tail %d %d",i,wet);
        end
        clear=1;sample(0);clear=0;
        for(i=0;i<3100;i=i+1) begin sample(0);if(wet!=0) $fatal(1,"clear leaked tail");end
        $display("PASS tb_audio_effects dry/delay/reverb/clear/SDPB16");$finish;
    end
    initial begin #10_000_000;$fatal(1,"effects timeout");end
endmodule
