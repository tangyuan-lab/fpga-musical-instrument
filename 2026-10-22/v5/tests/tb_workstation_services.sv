`timescale 1ns/1ps
module tb_workstation_services;
    reg clk=0;always #10 clk=~clk;
    reg rst_n=0,valid=0;reg [7:0] op=0,val=0;wire [2:0] mode,bank;wire changed,map_changed,error;
    wire [255:0] map;wire [3:0] edit_key;wire [15:0] desc;wire [6:0] v0,v1,v2;wire ms,mt;
    reg [15:0] physical=0,screen=0;reg [127:0] velocities={16{8'd200}};
    wire [15:0] piano,screen_piano,chord,drum;wire [95:0] timbres;wire [127:0] notes,drum_vel;
    instrument_mode_control modes(.clk(clk),.rst_n(rst_n),.cmd_valid(valid),.mode_pressed(1'b0),.cmd_op(op),.cmd_value(val),
        .mode(mode),.mode_changed(changed),.map_changed(map_changed),.command_error(error),.active_map(map),
        .edit_bank(bank),.edit_key(edit_key),.edit_descriptor(desc),.piano_volume(v0),.drum_volume(v1),.midi_volume(v2),.midi_start(ms),.midi_stop(mt),.boot_pending());
    instrument_key_router router(clk,rst_n,changed,map_changed,mode,map,physical,screen,velocities,piano,notes,timbres,screen_piano,chord,drum,drum_vel);
    task command(input [7:0] o,v);
        begin @(negedge clk);valid=1;op=o;val=v;@(negedge clk);valid=0;repeat(2) @(negedge clk);end
    endtask
    reg tick=0;wire running;wire [7:0] bpm;wire [3:0] step;wire [15:0] hits;wire [63:0] patterns;wire [15:0] sounds;
    drum_sequencer #(.TEMPO_THRESHOLD(3_000_000)) seq(clk,rst_n,tick,changed,mode==1||mode==3,valid,op,val,running,bpm,step,hits,patterns,sounds);
    reg [47:0] samples=0;reg [20:0] volumes={3{7'd100}};reg [2:0] enables=7;wire signed [15:0] mixed;
    pcm_source_mixer mix(clk,rst_n,tick,samples,volumes,enables,mixed);
    initial begin
        repeat(4) @(negedge clk);rst_n=1;repeat(3) @(negedge clk);
        command(5,2);screen=16'h0010;physical=1;#1;
        if(screen_piano!==16'h0010 || piano!==1 || chord!==16'h0011) $fatal(1,"default keys");
        command('h20,2);command('h21,0);command('h22,1);command('h23,0);command('h24,5);
        if(desc!==0) $fatal(1,"staging changed active map");
        command('h25,1);
        if(desc!==16'h4005 || piano!==0 || screen_piano!==16'h10) $fatal(1,"mapped drum changed screen");
        physical=0;repeat(5) @(negedge clk);physical=1;repeat(4) @(negedge clk);#1;
        if(drum!==16'h20 || drum_vel[5*8+:8]!==200 || chord!==16'h10) $fatal(1,"per key drum mapping");
        repeat(3) @(negedge clk);if(drum!==0) $fatal(1,"held drum retriggered");
        physical=0;command(5,1);if(map[15:0]!==16'h4000) $fatal(1,"drum bank default");
        command(5,2);if(map[15:0]!==16'h4005) $fatal(1,"bank not retained");
        command('h23,63);command('h25,1);if(desc!==16'h4005) $fatal(1,"unimplemented timbre accepted");
        command('h26,2);if(map[15:0]!==0) $fatal(1,"restore default");
        command(5,1);command('h12,0);command('h0c,1);command('h0c,1);
        if(patterns[15:0]!==2) $fatal(1,"step set must be idempotent");
        command('h0e,3);command('h0f,1);tick=1;
        repeat(7) @(negedge clk);#1;
        if(step!==1 || hits!==8) $fatal(1,"tempo or track mapping: %d %h",step,hits);
        command(5,0);if(running || piano || drum) $fatal(1,"home must stop sources");
        samples={3{16'sd20000}};repeat(300) @(negedge clk);#1;
        if(mixed!==32767) $fatal(1,"positive saturation %d",mixed);
        samples={3{-16'sd20000}};repeat(4) @(negedge clk);#1;
        if(mixed!==-32768) $fatal(1,"negative saturation %d",mixed);
        enables=0;repeat(300) @(negedge clk);#1;if(mixed!==0) $fatal(1,"mute failed %d",mixed);
        $display("PASS tb_workstation_services mapping banks, screen isolation, sequencer, 3-source mixer");$finish;
    end
endmodule
