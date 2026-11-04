`timescale 1ns/1ps
// 音频子系统的持续满负载：真实50MHz/1024采样周期、115200屏幕发送，
// 覆盖延迟线和两路混响暖机。仅为RTL证据，不包含板卡模拟输出或视频IP。
module tb_workstation_v2_load;
    reg clk=0,rst_n=0;always #10 clk=~clk;
    reg [9:0] divider=0;wire tick=divider==1023;
    always @(posedge clk) if(!rst_n) divider<=0;else divider<=divider+1'b1;
    reg valid=0;reg [15:0] identity=0;reg [6:0] note=48;wire ready;
    wire signed [15:0] dry,wet;wire [5:0] voices;wire [31:0] mask;wire error;
    synth32 engine(.clk(clk),.rst_n(rst_n),.sample_tick(tick),.panic(1'b0),.command_valid(valid),.command_ready(ready),
        .command_op(2'd1),.command_source(2'd0),.command_id(identity),.command_note(note),.command_velocity(7'd40),
        .command_timbre(4'd1),.custom_ready(8'd0),.bend(14'sd0),.vibrato_depth(8'd8),.vibrato_rate(8'd5),
        .table_write(1'b0),.table_address(11'd0),.table_data(16'sd0),.parameter_write(1'b0),.parameter_bank(4'd0),
        .attack_step(12'd64),.decay_step(12'd8),.sustain_level(12'd3000),.release_step(12'd64),
        .pcm(dry),.voice_count(voices),.active_mask(mask),.deadline_error(error));
    audio_effects effects(.clk(clk),.rst_n(rst_n),.sample_tick(tick),.clear(1'b0),.dry(dry),
        .delay_mix(7'd64),.reverb_mix(7'd64),.feedback(7'd48),.delay_samples(12'd512),.wet(wet));
    wire bck,ws,din; i2s_tx output_i2s(.clk(clk),.rst_n(rst_n),.sample_left(wet),.sample_right(wet),.hp_bck(bck),.hp_ws(ws),.hp_din(din),.sample_tick());
    wire screen_tx;wire [3:0] catalog;wire [7:0] byte_data;wire byte_valid;
    workstation_v2_screen screen(.clk(clk),.rst_n(rst_n),.status_data({224{1'b0}}),.directory_revision(32'd1),
        .envelope_data(48'd0),.runtime_data(176'd0),.command_feedback(112'd0),.catalog_index(catalog),
        .catalog_name(256'h74736574),.catalog_ready(1'b1),.catalog_duration(32'd480),.catalog_sections(6'd1),.tx(screen_tx));
    uart_rx #(.CLKS_PER_BIT(434)) monitor(.clk(clk),.rst_n(rst_n),.rx(screen_tx),.data(byte_data),.valid(byte_valid));
    integer samples=0,commands=0,terminators=0,busy_cycles=0,max_busy=0,nonzero=0,i;
    reg loaded=0;reg [31:0] previous_phase;
    always @(negedge clk) if(rst_n) begin
        if(engine.busy) begin busy_cycles=busy_cycles+1;if(busy_cycles>max_busy) max_busy=busy_cycles;end
        else busy_cycles=0;
        if(tick && loaded) begin
            samples=samples+1;
            if(error || engine.busy || effects.state!=0) $fatal(1,"audio frame missed compute deadline");
            if(voices!=32 || mask!==32'hffffffff) $fatal(1,"full polyphony lost count=%d",voices);
            if((^wet)===1'bx) $fatal(1,"unknown audio sample");
            if(wet!=0) nonzero=nonzero+1;
        end
        if(byte_valid) begin
            if(byte_data==255) terminators=terminators+1;else terminators=0;
            if(terminators==3) begin commands=commands+1;terminators=0;end
        end
    end
    initial begin
        repeat(8) @(negedge clk);rst_n=1;
        for(i=0;i<32;i=i+1) begin
            @(negedge clk);while(!ready) @(negedge clk);
            identity=i;note=48+i;valid=1;@(negedge clk);valid=0;while(!ready) @(negedge clk);
        end
        repeat(4) @(posedge tick);@(negedge clk);loaded=1;
        wait(samples>=12000 && commands>=65);
        if(nonzero<10000 || effects.valid_samples!=4095) $fatal(1,"effects did not reach steady operation");
        for(i=1;i<32;i=i+1) if(engine.phase[i]===engine.phase[i-1]) $fatal(1,"oscillators share phase");
        if(max_busy>=1024) $fatal(1,"pipeline exceeds sampling period");
        $display("PASS tb_workstation_v2_load voices=32 samples=%0d screen_commands=%0d max_compute_cycles=%0d effects_warm=PASS",samples,commands,max_busy);
        $finish;
    end
    initial begin #500_000_000;$fatal(1,"load simulation timeout");end
endmodule
