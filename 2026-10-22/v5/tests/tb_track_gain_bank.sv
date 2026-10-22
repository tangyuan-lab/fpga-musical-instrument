`timescale 1ns/1ps
module tb_track_gain_bank;
    reg clk=0;always #10 clk=~clk;
    reg rst_n=0,tick=0,cv=0;reg [4:0] owner=0,read_owner=0;reg [15:0] target=0;
    wire cr,cd,ce,ready,done,deadline;wire [15:0] gain;
    track_gain_bank #(.OWNERS(18)) dut(.clk(clk),.rst_n(rst_n),.sample_tick(tick),
        .command_valid(cv),.command_ready(cr),.command_owner(owner),.command_gain(target),.command_done(cd),.command_error(ce),
        .read_owner(read_owner),.read_gain(gain),.initialized(ready),.frame_done(done),.deadline_error(deadline));
    task command(input [4:0] who,input [15:0] value);
        begin wait(cr);@(negedge clk);owner=who;target=value;cv=1;@(negedge clk);cv=0;wait(cd);@(negedge clk);end
    endtask
    integer frame_cycles=-1,cycles;
    task frame;
        begin
            @(negedge clk);tick=1;@(negedge clk);tick=0;cycles=0;
            while(!done) begin @(negedge clk);cycles=cycles+1;if(cycles>50)$fatal(1,"gain frame deadline");end
            if(frame_cycles<0) frame_cycles=cycles;
            else if(cycles!=frame_cycles)$fatal(1,"gain frame latency changed");
            repeat(3) @(negedge clk);
        end
    endtask
    integer i,previous;
    initial begin
        repeat(5) @(negedge clk);rst_n=1;wait(ready);repeat(3) @(negedge clk);
        if(gain!=32768)$fatal(1,"unity init");
        command(0,8231);previous=32768;
        for(i=0;i<128;i=i+1) begin frame();if(gain>previous || gain<8231)$fatal(1,"nonmonotone down ramp");previous=gain;end
        if(gain!=8231)$fatal(1,"-12dB target not exact");
        command(0,65381);
        for(i=0;i<64;i=i+1)frame();previous=gain;
        command(0,32768);
        for(i=0;i<128;i=i+1)begin frame();if(gain>previous)$fatal(1,"midramp retarget discontinuity");previous=gain;end
        if(gain!=32768)$fatal(1,"retarget not exact");
        command(0,0);for(i=0;i<128;i=i+1)frame();if(gain!=0)$fatal(1,"mute not exact");
        read_owner=1;repeat(3) @(negedge clk);if(gain!=32768)$fatal(1,"other owner changed");
        read_owner=31;repeat(3) @(negedge clk);if(gain!=32768)$fatal(1,"reserved read owner");
        command(31,1);if(!ce)$fatal(1,"invalid owner accepted");
        if(deadline)$fatal(1,"false deadline error");
        @(negedge clk);tick=1;@(negedge clk);tick=0;repeat(3) @(negedge clk);tick=1;@(negedge clk);tick=0;
        repeat(3) @(negedge clk);if(!deadline)$fatal(1,"overrun not reported");
        $display("PASS track_gain_bank exact128 monotone retarget independent mute fixed_latency=%0d",frame_cycles);$finish;
    end
    initial begin #10000000;$fatal(1,"gain bank timeout");end
endmodule
