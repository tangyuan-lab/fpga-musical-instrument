`timescale 1ns/1ps
module tb_workstation_v2_serial_router;
    reg clk=0,rst_n=0,changed=0;always #10 clk=~clk;
    reg [2:0] mode=2;reg [255:0] mapping=0;reg [15:0] keys=0,screen=0;reg [127:0] velocity=0;
    wire [15:0] piano,chord,drums,ref_piano,ref_chord,ref_drums;
    wire [127:0] levels,ref_levels,notes,ref_notes;wire [95:0] timbres,ref_timbres;
    workstation_v2_router dut(.clk(clk),.rst_n(rst_n),.mode_changed(changed),.map_changed(1'b0),.mode(mode),.active_map(mapping),
        .physical_keys(keys),.screen_keys(screen),.physical_velocity(velocity),.physical_piano_keys(piano),.physical_notes(notes),
        .physical_timbres(timbres),.chord_keys(chord),.drum_triggers(drums),.drum_velocity(levels));
    instrument_key_router #(.MELODIC_TIMBRES(10),.ALLOW_FOLLOW_TIMBRE(1)) reference(.clk(clk),.rst_n(rst_n),.mode_changed(changed),.map_changed(1'b0),.mode(mode),.active_map(mapping),
        .physical_keys(keys),.screen_keys(screen),.physical_velocity(velocity),.physical_piano_keys(ref_piano),.physical_notes(ref_notes),
        .physical_timbres(ref_timbres),.chord_keys(ref_chord),.drum_triggers(ref_drums),.drum_velocity(ref_levels));
    reg [15:0] seen=0,ref_seen=0;reg [127:0] seen_levels=0,ref_seen_levels=0;integer j,i,trial;
    always @(posedge clk) if(rst_n) begin
        seen=seen|drums;ref_seen=ref_seen|ref_drums;
        for(j=0;j<16;j=j+1) begin
            if(drums[j]) seen_levels[j*8+:8]=levels[j*8+:8];
            if(ref_drums[j]) ref_seen_levels[j*8+:8]=ref_levels[j*8+:8];
        end
    end
    task clear_seen;
        begin @(negedge clk);seen=0;ref_seen=0;seen_levels=0;ref_seen_levels=0;end
    endtask
    task verify;
        begin repeat(40) @(negedge clk);
            if(piano!==ref_piano || chord!==ref_chord || notes!==ref_notes || timbres!==ref_timbres)
                $fatal(1,"serial routing differs piano=%h/%h chord=%h/%h",piano,ref_piano,chord,ref_chord);
            if(seen!==ref_seen || seen_levels!==ref_seen_levels) $fatal(1,"drum routing differs hits=%h/%h levels=%h/%h",seen,ref_seen,seen_levels,ref_seen_levels);
        end
    endtask
    initial begin
        for(i=0;i<16;i=i+1) begin mapping[i*16+:16]=i<8 ? (i==0 ? 16'h3f00:16'((i<<8)|i)):16'h4000|16'((i-8)/2);velocity[i*8+:8]=20+i*7;end
        repeat(3) @(negedge clk);rst_n=1;repeat(40) @(negedge clk);clear_seen();
        keys=16'hffff;screen=8;verify();
        changed=1;@(negedge clk);changed=0;clear_seen();verify();
        if(piano!=0 || drums!=0) $fatal(1,"held keys retrigger after mode/map change");
        keys=0;screen=0;repeat(40) @(negedge clk);clear_seen();mode=1;screen=16'h8001;verify();
        screen=0;repeat(40) @(negedge clk);
        for(trial=0;trial<30;trial=trial+1) begin
            clear_seen();keys=$random;screen=$random;verify();
        end
        $display("PASS tb_workstation_v2_serial_router melody/custom/follow/chord/drum-max/screen/held-key/random");$finish;
    end
endmodule
