`timescale 1ns/1ps
module tb_synth32_tracks;
    reg clk=0;always #10 clk=~clk;
    reg rst_n=0,tick=0,panic=0,cv=0,gv=0,tw=0,pw=0;
    reg [1:0] op=1,source=2;reg [15:0] id=0;reg [6:0] note=60;
    reg [4:0] owner=0,go=0;reg [15:0] gt=32768;reg [10:0] address=0;
    wire cr,gr,gd,ge,done,deadline;wire signed [15:0] pcm;wire [5:0] voices;wire [31:0] mask;
    synth32_tracks dut(.clk(clk),.rst_n(rst_n),.sample_tick(tick),.panic(panic),
        .command_valid(cv),.command_ready(cr),.command_op(op),.command_source(source),.command_id(id),
        .command_note(note),.command_velocity(7'd100),.command_timbre(4'd2),.command_owner(owner),
        .gain_valid(gv),.gain_ready(gr),.gain_owner(go),.gain_target(gt),.gain_done(gd),.gain_error(ge),.sample_done(done),
        .custom_ready(8'd1),.bend(14'sd0),.vibrato_depth(8'd0),.vibrato_rate(8'd0),
        .table_write(tw),.table_address(address),.table_data(16'sd8192),.parameter_write(pw),.parameter_bank(4'd2),
        .attack_step(12'd4095),.decay_step(12'd1),.sustain_level(12'd4095),.release_step(12'd32),
        .pcm(pcm),.voice_count(voices),.active_mask(mask),.deadline_error(deadline));
    task event_on(input [15:0] identifier,input [4:0] who,input [6:0] pitch,input [1:0] src);
        begin wait(cr);@(negedge clk);id=identifier;owner=who;note=pitch;source=src;cv=1;
            @(negedge clk);cv=0;wait(cr);end
    endtask
    task gain(input [4:0] who,input [15:0] target);
        begin wait(gr);@(negedge clk);go=who;gt=target;gv=1;@(negedge clk);gv=0;wait(gd);@(negedge clk);end
    endtask
    integer latency=-1,cycles;
    task frame;
        begin @(negedge clk);tick=1;@(negedge clk);tick=0;cycles=0;
            while(!done) begin @(negedge clk);cycles=cycles+1;if(cycles>400)$fatal(1,"synth frame deadline");end
            if(latency<0) latency=cycles;else if(latency!=cycles)$fatal(1,"audio frame latency changed");
            repeat(1023-cycles) @(negedge clk);
        end
    endtask
    integer i,full,previous,expected,mixed;reg [31:0] phase_before;
    initial begin
        repeat(5) @(negedge clk);rst_n=1;wait(cr);
        for(i=0;i<256;i=i+1) begin @(negedge clk);tw=1;address=i;end
        @(negedge clk);tw=0;pw=1;@(negedge clk);pw=0;
        event_on(1,0,60,2);event_on(2,1,64,2);
        repeat(4) frame();full=pcm;
        if(full<=0 || voices!=2 || mask[3:0]!=0)$fatal(1,"baseline or real-time reserve failed");
        phase_before=dut.phase[4];gain(0,8231);previous=pcm;
        for(i=0;i<128;i=i+1) begin frame();if(pcm>previous)$fatal(1,"gain discontinuity");previous=pcm;end
        mixed=pcm;expected=(full*(32768+8231))>>16;
        if(pcm<expected-2 || pcm>expected+2)$fatal(1,"track -12dB ratio got=%0d expected=%0d",pcm,expected);
        if(dut.phase[4]!==phase_before+dut.pitch(60)*32'd128 || dut.velocity[4]!=100 || dut.stage[4]!=3 || voices!=2)
            $fatal(1,"gain change retriggered phase/envelope or changed velocity");
        gain(0,0);repeat(128) frame();if(pcm<full/2-2 || pcm>full/2+2)$fatal(1,"other track changed");
        gain(1,0);repeat(128) frame();if(pcm!=0 || voices!=2)$fatal(1,"mute killed voices or failed to mute");
        gain(0,32768);repeat(128) frame();if(pcm<full/2-2 || pcm>full/2+2)$fatal(1,"unmute failed");
        panic=1;@(negedge clk);panic=0;repeat(3) @(negedge clk);if(mask!=0 || pcm!=0)$fatal(1,"panic failed");
        // 测试源使用实时源编号，可验证全部32槽独立状态，正常伴奏仍不能占用0..3。
        for(i=0;i<32;i=i+1)event_on(16'h100+i,i%18,40+i,0);
        repeat(4) frame();if(voices!=32 || mask!=32'hffffffff || deadline)$fatal(1,"32 voice track mixing failed");
        $display("PASS synth32_tracks voices=32 sample_cycles=%0d baseline=%0d mixed=%0d exact128 no_retrigger independent_mute",latency,full,mixed);$finish;
    end
    initial begin #20000000;$fatal(1,"track synth timeout");end
endmodule
