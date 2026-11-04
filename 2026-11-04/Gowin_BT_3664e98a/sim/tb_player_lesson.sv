`timescale 1ns/1ps
`default_nettype none
module tb_player_lesson;
    `include "sim/result.svh"
    GSR GSR(.GSRI(1'b1));
    reg clk=0;always #10 clk=~clk;
    reg rst_n=0,cv=0,begin_lesson=0,request=0;
    reg [7:0] op=0;reg [31:0] value=0,aux=0;
    reg [7:0] bytes[0:161],q0=0,q1=0;wire [15:0] address;
    wire playing,paused,pbusy,perror,cd,parsed,quiet,prep,reader,active;
    wire [7:0] cr,lr;wire ld;
    wire [10:0] ri;wire [11:0] count;
    wire [31:0] start_tick,end_tick;wire [6:0] note;wire [3:0] track;
    wire [15:0] guide;wire [255:0] status;
    reg [111:0] map=0;
    always @(posedge clk)begin q0<=bytes[address];q1<=q0;end
    workstation_cut123_player player(.clk(clk),.rst_n(rst_n),.command_valid(cv),.command_op(op),.command_value(value),.command_aux(aux),
        .command_done(cd),.command_result(cr),.validation_start(1'b0),.validation_release(1'b0),.validation_done(),.validation_duration(),.runtime_data(),
        .song_ready_mask(32'd1),.patch_ready_mask(8'd0),.selected_song(),.selected_ready(1'b1),.selected_size(17'd162),.duration(32'd5000),
        .file_read_address(address),.file_read_data(q1),.section_count(6'd0),.section_address(),.section_data(192'd0),
        .playing(playing),.paused(paused),.parser_busy(pbusy),.parser_error(perror),.tick(),.section(),.loop_enabled(),.loop_a(),.loop_b(),
        .live_timbre(),.screen_timbre(),.live_transpose(),.bend(),.vibrato_depth(),.vibrato_rate(),.delay_mix(),.reverb_mix(),.feedback(),.delay_time(),.panic(),
        .event_valid(),.event_ready(1'b1),.event_op(),.event_source(),.event_id(),.event_note(),.event_velocity(),.event_timbre(),
        .drum_triggers(),.drum_velocities(),.guide_keys(),.event_track(),.track_gains(),.channel_map(),.track_timbres(),.track_volumes(),.track_mutes(),.track_solos(),
        .emergency_stop(1'b0),.emergency_abort(1'b0),.lesson_begin(begin_lesson),.lesson_prepare(prep),.lesson_hold(active),
        .lesson_reader_enable(reader),.lesson_reader_index(ri),.lesson_quiet(quiet),.lesson_parsed(parsed),
        .lesson_event_count(count),.lesson_event_start(start_tick),.lesson_event_end(end_tick),.lesson_event_note(note),.lesson_event_track(track));
    pressure_lesson lesson(.clk(clk),.rst_n(rst_n),.clear(1'b0),.request(request),.action(3'd2),.selected_track(4'd3),
        .source_available(1'b1),.source_quiet(quiet),.parser_ready(parsed),.parser_busy(pbusy),.parser_error(perror),
        .event_count(count),.event_start(start_tick),.event_end(end_tick),.event_note(note),.event_track(track),
        .physical_pitch_map(map),.enabled_keys(16'hffff),.transpose(7'sd0),.physical_down(16'd0),.screen_down(16'd0),
        .accepted_valid(1'b0),.accepted_op(2'd0),.accepted_source(2'd0),.accepted_key(5'd0),.accepted_id(32'd0),.accepted_note(7'd0),.accepted_result(3'd0),
        .prepare_parser(prep),.reader_enable(reader),.reader_index(ri),.done(ld),.result(lr),.active(active),.guide_keys(guide),.status(status));
    task automatic wait_cycles(input integer n);
        begin repeat(n)@(negedge clk);end
    endtask
    initial begin
        $readmemh("sim/song16.mem",bytes);
        for(integer i=0;i<16;i=i+1)map[i*7+:7]=60+i;
        wait_cycles(5);rst_n=1;wait_cycles(2200);
        cv=1;op=3;@(negedge clk);cv=0;wait_cycles(4000);
        if(!parsed||perror||!playing)$fatal(1,"PLAYER_LESSON original playback not prepared");
        begin_lesson=1;request=1;@(negedge clk);begin_lesson=0;request=0;wait_cycles(5000);
        if(playing||pbusy||perror||!quiet||status[2:0]!=4||status[63:48]!=1||status[79:72]!=63||guide!=8)
            $fatal(1,"PLAYER_LESSON actual parser/flush not closed state=%0d player=%0d flush=%b count=%0d guide=%h",status[2:0],player.state,player.flushing,status[63:48],guide);
        cv=1;op=3;@(negedge clk);cv=0;@(negedge clk);
        if(cr!=4||playing)$fatal(1,"PLAYER_LESSON playback not blocked during lesson");
        complete_test("tb_player_lesson",6);$display("PASS tb_player_lesson actual_parser_reparse_flush_track_ownership");$finish;
    end
    initial begin #500000;$fatal(1,"player lesson bounded timeout");end
endmodule
`default_nettype wire
