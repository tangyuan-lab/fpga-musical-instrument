`timescale 1ns/1ps
module tb_workstation_v2_integration;
    reg clk=0,rst_n=0;always #10 clk=~clk;
    reg frame_valid=0;reg [7:0] frame_type=0;reg [15:0] seq=0,len=0;reg [1055:0] payload=0;reg emergency_stop=0;
    wire response_valid,response_busy;wire [15:0] response_seq;wire [7:0] response_length;wire [767:0] response_payload;
    wire command_valid,command_done,parameter_done,player_done;wire [7:0] command_op,command_result,parameter_result,player_result;wire [31:0] command_value,command_aux;
    assign command_done=command_op==34 ? parameter_done:player_done;
    assign command_result=command_op==34 ? parameter_result:player_result;
    wire [1:0] song;wire [15:0] read_address;wire [7:0] read_data;wire [16:0] size;wire ready;wire [31:0] duration,mask,revision;
    wire [7:0] patches;wire tw,pw;wire [10:0] ta;wire signed [15:0] td;wire [3:0] bank;wire [47:0] adsr;
    wire [6:0] section_address;wire [191:0] section_data;wire [5:0] sections;
    wire playing,paused,parsing,error,panic;wire [31:0] tick,la,lb;wire [4:0] section;wire loop_en;
    wire [3:0] live_patch,screen_patch;wire signed [13:0] bend;wire [7:0] vib,rate;wire [6:0] dm,rm,fb;wire [11:0] dt;
    wire ev,er;wire [1:0] eo,es;wire [15:0] ei;wire [6:0] en,velocity;wire [3:0] et;
    wire [15:0] drums,guide;wire [127:0] dv;
    wire validation_start,validation_release,validation_done;wire [31:0] validation_duration;wire [175:0] runtime_data;
    reg sample_tick=0;integer sample_counter=0;wire signed [15:0] pcm;wire [5:0] voices;wire [31:0] voices_mask;wire deadline;
    always @(negedge clk) begin sample_tick=sample_counter==1023;sample_counter=(sample_counter+1)%1024;end
    workstation_v2_resources resources(.clk(clk),.rst_n(rst_n),.frame_valid(frame_valid),.frame_type(frame_type),.frame_seq(seq),.frame_length(len),.payload(payload),
        .response_valid(response_valid),.response_seq(response_seq),.response_length(response_length),.response_payload(response_payload),.response_busy(response_busy),
        .control_valid(command_valid),.control_op(command_op),.control_value(command_value),.control_aux(command_aux),.control_done(command_done),.control_result(command_result),.status_data(224'd0),
        .runtime_data(runtime_data),.command_feedback(112'd0),.validation_start(validation_start),.validation_release(validation_release),
        .validation_done(validation_done),.validation_busy(parsing),.validation_error(error),.validation_duration(validation_duration),
        .selected_song(song),.song_read_address(read_address),.song_read_data(read_data),.selected_size(size),.selected_ready(ready),.selected_duration(duration),
        .song_ready_mask(mask),.patch_ready_mask(patches),.table_write(tw),.table_address(ta),.table_data(td),.parameter_write(pw),.parameter_bank(bank),.envelope_parameters(adsr),
        .envelope_read_bank(live_patch),.envelope_read_data(),
        .external_adsr_valid(command_valid && command_op==34),.external_adsr_value(command_value),.external_adsr_aux(command_aux),.external_adsr_done(parameter_done),.external_adsr_result(parameter_result),
        .section_read_address(section_address),.section_data(section_data),.selected_sections(sections),.catalog_index(4'd0),.catalog_name(),.catalog_ready(),.catalog_duration(),.catalog_sections(),.directory_revision(revision));
    workstation_v2_player player(.clk(clk),.rst_n(rst_n),.emergency_stop(emergency_stop),.emergency_abort(emergency_stop),.command_valid(command_valid && command_op!=34),.command_op(command_op),.command_value(command_value),.command_aux(command_aux),
        .validation_start(validation_start),.validation_release(validation_release),.validation_done(validation_done),.validation_duration(validation_duration),.runtime_data(runtime_data),
        .command_done(player_done),.command_result(player_result),.song_ready_mask(mask),.patch_ready_mask(patches),.selected_song(song),.selected_ready(ready),.selected_size(size),.duration(duration),
        .file_read_address(read_address),.file_read_data(read_data),.section_count(sections),.section_address(section_address),.section_data(section_data),
        .playing(playing),.paused(paused),.parser_busy(parsing),.parser_error(error),.tick(tick),.section(section),.loop_enabled(loop_en),.loop_a(la),.loop_b(lb),
        .live_timbre(live_patch),.screen_timbre(screen_patch),.bend(bend),.vibrato_depth(vib),.vibrato_rate(rate),.delay_mix(dm),.reverb_mix(rm),.feedback(fb),.delay_time(dt),.panic(panic),
        .event_valid(ev),.event_ready(er),.event_op(eo),.event_source(es),.event_id(ei),.event_note(en),.event_velocity(velocity),.event_timbre(et),.drum_triggers(drums),.drum_velocities(dv),.guide_keys(guide));
    synth32 synth(.clk(clk),.rst_n(rst_n),.sample_tick(sample_tick),.panic(panic),.command_valid(ev),.command_ready(er),.command_op(eo),.command_source(es),.command_id(ei),
        .command_note(en),.command_velocity(velocity),.command_timbre(et),.custom_ready(patches),.bend(bend),.vibrato_depth(vib),.vibrato_rate(rate),.table_write(tw),.table_address(ta),.table_data(td),
        .parameter_write(pw),.parameter_bank(bank),.attack_step(adsr[11:0]),.decay_step(adsr[23:12]),.sustain_level(adsr[35:24]),.release_step(adsr[47:36]),
        .pcm(pcm),.voice_count(voices),.active_mask(voices_mask),.deadline_error(deadline));
    wire tx;uart_frame_tx_v2 #(.CLKS_PER_BIT(4)) transmitter(.clk(clk),.rst_n(rst_n),.response_valid(response_valid),.response_type(8'h81),.response_seq(response_seq),.response_length(response_length),.response_payload(response_payload),.tx(tx),.busy(response_busy));
    wire [7:0] rxdata;wire rxvalid;uart_rx #(.CLKS_PER_BIT(4)) receiver(.clk(clk),.rst_n(rst_n),.rx(tx),.data(rxdata),.valid(rxvalid),.framing_error());
    wire ack_valid;wire [7:0] ack_type;wire [15:0] ack_seq,ack_len;wire [1055:0] ack_payload;
    uart_frame_protocol monitor(.clk(clk),.rst_n(rst_n),.rx_data(rxdata),.rx_valid(rxvalid),.frame_valid(ack_valid),.bad_frame(),.frame_type(ack_type),.frame_seq(ack_seq),.frame_length(ack_len),.frame_payload(ack_payload));
    reg [1055:0] received_payload;reg [15:0] received_length;
    task send(input [7:0] typ,input [15:0] number,input integer length,input [1055:0] data,input integer status);
        begin
            wait(!response_busy && resources.state==0);@(negedge clk);frame_type=typ;seq=number;len=length;payload=data;frame_valid=1;
            @(negedge clk);frame_valid=0;
            wait(ack_valid);received_payload=ack_payload;received_length=ack_len;
            if(ack_seq!=number || ack_payload[7:0]!=typ || ack_payload[15:8]!=status) $fatal(1,"bad ACK seq=%d/%d type=%h code=%d expected=%d",ack_seq,number,typ,ack_payload[15:8],status);
            repeat(5) @(negedge clk);
        end
    endtask
    integer audio_nonzero=0;
    always @(posedge sample_tick) if(pcm!=0) audio_nonzero=audio_nonzero+1;
    initial begin
        repeat(8) @(negedge clk);rst_n=1;
`include "v2_fixture.inc"
        repeat(100000) @(negedge clk);
        if(error || !playing || voices<2 || audio_nonzero==0 || deadline) $fatal(1,"playback failed error=%b playing=%b voices=%d audio=%d tick=%d events=%d",error,playing,voices,audio_nonzero,tick,player.event_count);
        send(8'h37,999,0,0,0);
        if(received_length!=80 || received_payload[23:16]!=1 || received_payload[319:304]!=16'h0102 || received_payload[399:384]!=100)
            $fatal(1,"runtime details schema/actual timbres/speed mismatch");
        send(8'h35,1000,9,{64'd0,8'd4},0);
        repeat(1000) @(negedge clk);if(!paused || voices_mask!=0) $fatal(1,"pause fails to silence");
        send(8'h35,1001,9,{32'd0,32'd240,8'd6},0);
        repeat(1000) @(negedge clk);if(tick!=240 || !paused) $fatal(1,"seek while paused");
        send(8'h35,1002,9,{64'd0,8'd4},0);
        repeat(50000) @(negedge clk);if(voices<2) $fatal(1,"seek sustained notes not restored");
        send(8'h35,1010,9,{32'd0,32'd1,8'd24},0);
        send(8'h35,1011,9,{32'd1,32'd37,8'd25},0);
        send(8'h35,1012,9,{32'd0,32'd2,8'd26},0);
        send(8'h35,1013,9,{32'd0,32'd1,8'd27},0);
        send(8'h35,1014,9,{32'd0,32'd2,8'd12},0);
        send(8'h35,1015,9,{32'd0,32'd0,8'd6},0);
        repeat(5000) @(negedge clk);
        if(player.part_timbres[7:0]!=1 || player.part_volumes[15:8]!=37 || player.mute_mask!=2 || player.solo_mask!=1 || live_patch!=2)
            $fatal(1,"BRAM arrangement override lost after scan restart");
        send(8'h35,1016,9,{32'd0,32'd1,8'd23},0);repeat(5000) @(negedge clk);
        if(section!=1 || player.part_timbres[7:0]!=0 || player.part_volumes[15:8]!=72 || player.mute_mask!=0 || player.solo_mask!=0 || live_patch!=0)
            $fatal(1,"BRAM override leaked section=%d timbres=%h volumes=%h mute=%d solo=%d live=%d",section,player.part_timbres,player.part_volumes,player.mute_mask,player.solo_mask,live_patch);
        send(8'h35,1017,9,{32'd0,32'd0,8'd23},0);repeat(5000) @(negedge clk);
        if(section!=0 || player.part_timbres[7:0]!=1 || player.part_volumes[15:8]!=37 || player.mute_mask!=2 || player.solo_mask!=1 || live_patch!=2)
            $fatal(1,"BRAM override failed section roundtrip");
        send(8'h35,1018,9,{32'd0,32'd1,8'd2},0);send(8'h35,1019,9,{32'd0,32'd0,8'd3},0);
        wait(player.parsed && !player.parser_busy);send(8'h35,1020,9,{32'd0,32'd7600,8'd6},0);repeat(5000) @(negedge clk);
        if(player.tempo_count!=64 || player.tempo!=563000) $fatal(1,"64-entry tempo BRAM read failed count=%d tempo=%d",player.tempo_count,player.tempo);
        send(8'h35,1003,9,{32'd0,32'd1,8'd29},0);
        repeat(20000) @(negedge clk);if(voices!=32) $fatal(1,"32-frequency device test failed voices=%d",voices);
        emergency_stop=1;@(negedge clk);emergency_stop=0;
        repeat(1000) @(negedge clk);
        if(voices_mask!=0 || playing || paused || player.test_running || player.auto_start) $fatal(1,"independent emergency did not stop 32 voices");
        send(8'h35,1005,9,{32'd0,32'd1,8'd29},0);
        repeat(20000) @(negedge clk);if(voices!=32) $fatal(1,"test did not restart after independent emergency");
        send(8'h35,1004,9,{64'd0,8'd15},0);
        repeat(1000) @(negedge clk);if(voices_mask!=0) $fatal(1,"panic failed");
        $display("PASS tb_workstation_v2_integration CRC/retry/catalog/GBK/multisong/multitimbre/FPGA-parser/pause/seek/32voices");$finish;
    end
    initial begin #100_000_000;$fatal(1,"integration timeout state=%d player=%d",resources.state,player.state);end
endmodule
