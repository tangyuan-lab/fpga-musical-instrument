`timescale 1ns/1ps
module tb_workstation_v2_router;
    reg clk=0,rst_n=0,changed=0;always #10 clk=~clk;
    reg [255:0] mapping=0;reg [15:0] keys=0;
    wire [15:0] routed,legacy,chords;wire [95:0] timbres;
    instrument_key_router #(.MELODIC_TIMBRES(10),.ALLOW_FOLLOW_TIMBRE(1)) dut(
        .clk(clk),.rst_n(rst_n),.mode_changed(changed),.map_changed(1'b0),.mode(3'd2),
        .active_map(mapping),.physical_keys(keys),.screen_keys(16'd0),.physical_velocity(128'd0),
        .physical_piano_keys(routed),.physical_timbres(timbres),.chord_keys(chords));
    instrument_key_router old_rules(.clk(clk),.rst_n(rst_n),.mode_changed(changed),.map_changed(1'b0),.mode(3'd2),
        .active_map(mapping),.physical_keys(keys),.screen_keys(16'd0),.physical_velocity(128'd0),.physical_piano_keys(legacy));
    integer i;
    initial begin
        // 覆盖内置0/1、自定义2..9、跟随63及无效10；第15键同时覆盖最高实体键位。
        for(i=0;i<10;i=i+1) mapping[i*16+:16]=(i<<8)|i;
        mapping[10*16+:16]=16'h0a0a;mapping[15*16+:16]=16'h3f0f;
        repeat(3) @(negedge clk);rst_n=1;repeat(3) @(negedge clk);
        keys=16'h87ff;#1;
        if(routed!==16'h83ff || legacy!==16'h0003 || timbres[15*6+:6]!=63 || chords!==16'h83ff)
            $fatal(1,"timbre routing V2=%h old=%h chords=%h",routed,legacy,chords);
        changed=1;@(negedge clk);changed=0;#1;
        if(routed!=0) $fatal(1,"mode change retriggered held keys");
        keys=0;repeat(2) @(negedge clk);keys=16'h8000;#1;
        if(routed!=16'h8000) $fatal(1,"release did not unblock follow timbre");
        $display("PASS tb_workstation_v2_router presets/custom/follow/legacy/held-key/chord");$finish;
    end
endmodule
