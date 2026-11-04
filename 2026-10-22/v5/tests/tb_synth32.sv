`timescale 1ns/1ps
module tb_synth32;
    reg clk=0,rst_n=0,tick=0,panic=0,valid=0;wire ready;
    reg [1:0] op=0,source=0;reg [15:0] id=0;reg [6:0] note=60,vel=100;reg [3:0] timbre=0;
    reg signed [13:0] bend=0;
    wire signed [15:0] pcm;wire [5:0] count;wire [31:0] mask;wire error;
    integer cycle=0,i,nonzero=0;reg [31:0] phase_before;
    always #10 clk=~clk;
    always @(negedge clk) begin tick=(cycle==1023);cycle=(cycle+1)%1024;if(pcm!=0) nonzero=nonzero+1;end
    synth32 dut(.clk(clk),.rst_n(rst_n),.sample_tick(tick),.panic(panic),.command_valid(valid),.command_ready(ready),
        .command_op(op),.command_source(source),.command_id(id),.command_note(note),.command_velocity(vel),.command_timbre(timbre),.custom_ready(8'hff),
        .bend(bend),.vibrato_depth(8'd0),.vibrato_rate(8'd5),.table_write(1'b0),.table_address(11'd0),.table_data(16'sd0),
        .parameter_write(1'b0),.parameter_bank(4'd0),.attack_step(12'd64),.decay_step(12'd8),.sustain_level(12'd3000),.release_step(12'd64),
        .pcm(pcm),.voice_count(count),.active_mask(mask),.deadline_error(error));
    task command(input integer n,input integer action,input integer origin);
        begin @(negedge clk);while(!ready) @(negedge clk);op=action;source=origin;id=n;note=48+n;valid=1;
            @(negedge clk);valid=0;while(!ready) @(negedge clk);end
    endtask
    initial begin
        repeat(5) @(negedge clk);rst_n=1;
        for(i=0;i<32;i=i+1) command(i,1,i<4 ? 0:2);
        repeat(6) @(posedge tick);repeat(250) @(negedge clk);
        if(count!=32 || mask!==32'hffffffff) $fatal(1,"32 independent states not allocated count=%d mask=%h",count,mask);
        for(i=1;i<32;i=i+1) if(dut.phase[i]==dut.phase[i-1]) $fatal(1,"oscillators share phase %d",i);
        if(nonzero==0 || error) $fatal(1,"silent or deadline missed");
        phase_before=dut.phase[0];vel=40;command(0,2,0);
        if(dut.velocity[0]!=40 || dut.phase[0]==0) $fatal(1,"pressure update retriggers phase");
        command(0,0,0);repeat(200) @(posedge tick);repeat(250) @(negedge clk);
        if(dut.active[0]) $fatal(1,"release not reclaimed");
        panic=1;@(negedge clk);panic=0;repeat(5) @(negedge clk);
        if(mask!=0 || pcm!=0) $fatal(1,"panic does not clear");
        command(0,1,0);bend=4096;repeat(2) @(posedge tick);repeat(250) @(negedge clk);
        phase_before=dut.phase[0];@(posedge tick);repeat(250) @(negedge clk);
        if((dut.phase[0]-phase_before)!=dut.pitch(49)) $fatal(1,"positive bend endpoint wraps sign");
        bend=-4096;@(posedge tick);repeat(250) @(negedge clk);phase_before=dut.phase[0];
        @(posedge tick);repeat(250) @(negedge clk);
        if((dut.phase[0]-phase_before)!=dut.pitch(47)) $fatal(1,"negative bend endpoint mismatch");
        force dut.lfo=32'h40000000;#1;if($signed(dut.lfo_triangle)!=255) $fatal(1,"vibrato positive peak");
        force dut.lfo=32'h80000000;#1;if($signed(dut.lfo_triangle)!=0) $fatal(1,"vibrato midpoint discontinuity");
        force dut.lfo=32'hc0000000;#1;if($signed(dut.lfo_triangle)!=-255) $fatal(1,"vibrato negative peak");
        release dut.lfo;
        @(negedge clk);panic=1;@(negedge clk);panic=0;
        for(i=0;i<32;i=i+1) command(i,1,2);
        repeat(2) @(posedge tick);repeat(250) @(negedge clk);
        if(mask!==32'hfffffff0 || count!=28) $fatal(1,"accompaniment occupied reserved slots");
        for(i=0;i<4;i=i+1) command(i,1,0);
        command(50,1,2);
        for(i=0;i<4;i=i+1) if(dut.source[i]!=0 || dut.identity[i]!=i) $fatal(1,"reserved live voice stolen");
        @(negedge clk);while(!ready) @(negedge clk);op=1;source=2;id=51;valid=1;
        @(negedge clk);valid=0;panic=1;@(negedge clk);panic=0;
        repeat(100) @(negedge clk);
        if(mask!=0 || dut.allocation_state!=0) $fatal(1,"panic allowed deferred allocation");
        $display("PASS tb_synth32 voices=32 independent_phase=PASS pressure=PASS release=PASS deadline=PASS");$finish;
    end
    initial begin #30_000_000;$fatal(1,"timeout");end
endmodule
