`timescale 1ns/1ps
// 验证同鼓映射并发、力度快照、流水线停止清除，防止时序优化丢事件。
module tb_key_router_events;
    reg clk=0;always #10 clk=~clk;
    reg rst_n=0,mode_changed=0,map_changed=0;reg [2:0] mode=1;
    reg [255:0] mapping={16{16'h4005}};
    reg [15:0] physical=0,screen=0;reg [127:0] velocity=0;
    wire [15:0] piano,screen_piano,chord,hits;wire [127:0] notes,hit_velocity;wire [95:0] tones;
    instrument_key_router dut(clk,rst_n,mode_changed,map_changed,mode,mapping,physical,screen,velocity,
        piano,notes,tones,screen_piano,chord,hits,hit_velocity);
    task release_all;
        begin physical=0;screen=0;repeat(6) @(negedge clk);end
    endtask
    integer k,stage;
    initial begin
        repeat(3) @(negedge clk);rst_n=1;release_all;
        for(k=0;k<16;k=k+1) velocity[k*8+:8]=8'(k*9+4);
        velocity[3*8+:8]=231;physical=16'hffff;screen=16'h20;
        repeat(3) @(negedge clk);#1;if(hits) $fatal(1,"drum event arrived early");
        @(negedge clk);#1;
        if(hits!==16'h20 || hit_velocity[5*8+:8]!==231) $fatal(1,"16-key max reduction %h %d",hits,hit_velocity[5*8+:8]);
        repeat(5) @(negedge clk);#1;if(hits) $fatal(1,"held input retriggered");
        release_all;velocity[15*8+:8]=17;physical=16'h8000;screen=16'h20;
        repeat(4) @(negedge clk);#1;
        if(hits!==16'h20 || hit_velocity[5*8+:8]!==160) $fatal(1,"screen/physical max failed");
        release_all;physical=16'h8000;@(negedge clk);velocity[15*8+:8]=250;
        repeat(3) @(negedge clk);#1;
        if(hits!==16'h20 || hit_velocity[5*8+:8]!==17) $fatal(1,"velocity not captured at event");
        // 在各流水级中停止，之后不得补发已经取消的事件。
        for(stage=1;stage<=3;stage=stage+1) begin
            release_all;physical=1;repeat(stage) @(negedge clk);mode_changed=1;
            @(negedge clk);mode_changed=0;repeat(6) begin @(negedge clk);#1;if(hits) $fatal(1,"stale event after mode switch");end
        end
        release_all;mode=2;mapping[15:0]=16'h0009;physical=1;screen=16'h10;#1;
        if(piano!==1 || screen_piano!==16'h10 || chord!==16'h210) $fatal(1,"actual mapped pitch bitmap");
        $display("PASS tb_key_router_events 16-key collision/max, screen isolation, velocity snapshot, canceled pipeline");$finish;
    end
endmodule
