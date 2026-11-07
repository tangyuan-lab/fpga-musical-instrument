`timescale 1ns/1ps
module tb_player_controls;
    GSR GSR(.GSRI(1'b1));
    `include "sim/result.svh"
    reg clk=0;always #10 clk=~clk;
    reg rst_n=0,cv=0,validation_start=0,validation_release=0;
    reg [7:0] op=0;reg [31:0] value=0,aux=0;
    wire cd;wire [7:0] cr;wire playing,paused,pbusy,perror,parsed,panic;
    wire [31:0] tick;wire [4:0] section;
    wire [15:0] address,guide;wire [6:0] secaddr;wire [1:0] song;
    reg [7:0] bytes[0:32767];reg [7:0] q0=0,q1=0;
    wire ev;reg ready=1;wire [1:0] eop,source;wire [31:0] id;
    wire [6:0] note,velocity;wire [4:0] timbre;wire [3:0] track;wire [255:0] gains;
    wire [127:0] timbres,volumes;wire [15:0] mutes,solos;wire [63:0] channel_map;
    wire [191:0] unused_secdata={32'd0,8'd0,8'd10,8'd0,8'd0,{4{8'd100}},{4{8'd10}},32'd5000,32'd0};
    wire [191:0] secdata=secaddr[4:0]==0 ? {32'd0,8'd0,8'd10,8'd0,8'd0,{4{8'd100}},{4{8'd10}},32'd480,32'd0}:
        {32'd0,8'd0,8'd19,8'd0,8'd0,{8'd40,8'd50,8'd60,8'd70},{4{8'd19}},32'd5000,32'd480};
    integer extra_on=0,extra_off=0,extra_mode=0,wraps=0,start_cycle=0,limit=0;
    reg [31:0] last_tick=0;
    reg countin_guide=0;
    reg [31:0] extra_ids[0:511];reg [511:0] extra_held=0;integer extra_slot=0,found_slot;
    always @(posedge clk)if(rst_n&&extra_mode==2&&dut.epoch==10&&((!dut.flushing&&tick>=480)||(dut.flushing&&dut.state==14)))
        $display("TRACE epoch=%0d tick=%0d state=%0d flushing=%b index=%0d held=%b flags=%h",dut.epoch,tick,dut.state,dut.flushing,dut.index,dut.held,dut.flags_read);
    always @(posedge clk)if(rst_n&&extra_mode!=0&&ev&&ready)begin
        if(eop==1)begin
            if(extra_slot>=512)$fatal(1,"test scoreboard overflow");
            for(integer q=0;q<extra_slot;q=q+1)if(extra_held[q]&&extra_ids[q]===id)$fatal(1,"duplicate held ID %h",id);
            extra_ids[extra_slot]=id;extra_held[extra_slot]=1;extra_slot=extra_slot+1;
        end else begin
            found_slot=-1;
            for(integer q=0;q<extra_slot;q=q+1)if(extra_held[q]&&extra_ids[q]===id)found_slot=q;
            if(found_slot<0)$fatal(1,"unmatched off ID %h",id);
            extra_held[found_slot]=0;
        end
    end
    always @(posedge clk)if(rst_n)begin
        last_tick<=tick;
        if(extra_mode==2&&playing&&tick<last_tick)wraps<=wraps+1;
        if(extra_mode!=0&&playing&&dut.precount_remaining!=0&&guide!=0)countin_guide<=1;
        if(extra_mode!=0&&ev&&ready)begin
            if(track!==4'(15-id[3:0]))$fatal(1,"reverse channel map failed id=%h track=%d",id,track);
            if(eop==1)begin
                if(dut.precount_remaining!=0)$fatal(1,"note during count-in");
                extra_on<=extra_on+1;
            end else extra_off<=extra_off+1;
        end
    end
    integer cycle=0,on_count=0,off_count=0;reg [15:0] held=0,on_seen=0;reg count_events=0;
    always @(posedge clk)begin cycle<=cycle+1;q0<=bytes[address];q1<=q0;end
    workstation_cut123_player dut(.lesson_begin(1'b0),.lesson_prepare(1'b0),.lesson_hold(1'b0),.lesson_reader_enable(1'b0),.lesson_reader_index(11'd0),.clk(clk),.rst_n(rst_n),.command_valid(cv),.command_op(op),.command_value(value),.command_aux(aux),
        .validation_start(validation_start),.validation_release(validation_release),.validation_done(parsed),.validation_duration(),.runtime_data(),.command_done(cd),.command_result(cr),
        .song_ready_mask(32'd1),.patch_ready_mask(8'd0),.selected_song(song),.selected_ready(1'b1),.selected_size(17'd162),.duration(32'd5000),
        .file_read_address(address),.file_read_data(q1),.section_count(6'd2),.section_address(secaddr),.section_data(secdata),
        .playing(playing),.paused(paused),.parser_busy(pbusy),.parser_error(perror),.tick(tick),.section(section),.loop_enabled(),.loop_a(),.loop_b(),
        .live_timbre(),.screen_timbre(),.live_transpose(),.bend(),.vibrato_depth(),.vibrato_rate(),.delay_mix(),.reverb_mix(),.feedback(),.delay_time(),.panic(panic),
        .event_valid(ev),.event_ready(ready),.event_op(eop),.event_source(source),.event_id(id),.event_note(note),.event_velocity(velocity),.event_timbre(timbre),
        .drum_triggers(),.drum_velocities(),.guide_keys(guide),.event_track(track),.track_gains(gains),.channel_map(channel_map),
        .track_timbres(timbres),.track_volumes(volumes),.track_mutes(mutes),.track_solos(solos),.emergency_stop(1'b0),.emergency_abort(1'b0));
    always @(negedge clk)ready=cycle%9<5;
    always @(posedge clk)if(rst_n)begin
        if((^{ev,panic,pbusy,perror})===1'bx)$fatal(1,"player control X");
        if(panic)$fatal(1,"player operation issued global panic");
        if(perror)$fatal(1,"parser error code=%0d",dut.parser_code);
        if(ev&&ready&&count_events)begin
            if((^{eop,source,id,note,velocity,timbre,track})===1'bx)$fatal(1,"event X");
            if(source!==2||id[11:0]>=16||track!==id[3:0])$fatal(1,"source/track identity id=%0d track=%0d source=%0d",id,track,source);
            if(eop==1)begin
                if(held[id[11:0]])$fatal(1,"duplicate note on %0d",id);
                if(timbre!==(id[11:0]%3==0 ? 5'd10:id[11:0]%3==1 ? 5'd19:5'd20))$fatal(1,"five-bit timbre %0d id=%0d",timbre,id);
                held[id[11:0]]=1;on_seen[id[11:0]]=1;on_count=on_count+1;
            end else begin
                if(!held[id[11:0]])$fatal(1,"duplicate/stale note off %0d",id);
                held[id[11:0]]=0;off_count=off_count+1;
            end
        end
    end
    task automatic control(input [7:0] operation,input [31:0] v,a);
        integer n;
        begin @(negedge clk);op=operation;value=v;aux=a;cv=1;@(negedge clk);cv=0;n=0;
            while(cd!==1&&n<1000)begin @(negedge clk);n=n+1;end
            if(cd!==1||cr!==0)$fatal(1,"control failed op=%0d result=%0d",operation,cr);
            repeat(20)@(negedge clk);
        end
    endtask
    task automatic until_on(input integer target);
        integer n;
        begin n=0;while(on_count<target&&n<200000)begin @(negedge clk);n=n+1;end
            if(on_count!=target)$fatal(1,"note count timeout expected=%0d actual=%0d",target,on_count);end
    endtask
    task automatic until_flush;
        integer n;
        begin n=0;while(dut.flushing&&n<40000)begin @(negedge clk);n=n+1;end
            if(dut.flushing||held!=0)$fatal(1,"song-scoped flush incomplete held=%h",held);end
    endtask
    initial begin
        for(integer i=0;i<32768;i=i+1)bytes[i]=0;
        $readmemh("sim/song16.mem",bytes,0,161);
        repeat(5)@(negedge clk);rst_n=1;repeat(2100)@(negedge clk);
        validation_start=1;@(negedge clk);validation_start=0;
        repeat(5000)@(negedge clk);
        if(parsed!==1||dut.event_count!==16)$fatal(1,"sixteen channel parse incomplete count=%0d",dut.event_count);
        for(integer t=0;t<16;t=t+1)control(24,t%3==0 ? 10:t%3==1 ? 19:20,t);
        control(25,50,15);repeat(100)@(negedge clk);
        if(gains[15*16+:16]<16383||gains[15*16+:16]>16385)$fatal(1,"track15 gain truncated %0d",gains[15*16+:16]);
        count_events=1;control(3,0,0);until_on(16);
        control(26,32'h8000,0);if(gains[15*16+:16]!==0||held!==16'hffff)$fatal(1,"mute retriggered/released held notes");
        control(26,0,0);control(27,1,0);if(gains[31:16]!==0||held!==16'hffff)$fatal(1,"solo did not preserve ownership");control(27,0,0);
        control(4,0,0);until_flush();if(!paused||on_seen!==16'hffff)$fatal(1,"pause failed");
        control(4,0,0);until_on(32);control(5,0,0);until_flush();
        control(6,100,0);control(10,150,0);control(11,1,0);until_flush();control(11,0,0);until_flush();
        control(3,0,0);until_on(48);control(5,0,0);until_flush();
        if(on_count!==48||off_count!==48)$fatal(1,"event conservation on=%0d off=%0d",on_count,off_count);
        count_events=0;
        control(39,32'h89abcdef,32'h01234567);
        if(channel_map!==64'h0123456789abcdef)$fatal(1,"channel map command");
        control(10,100,0);control(40,1,0);extra_mode=1;start_cycle=cycle;
        control(3,0,0);limit=0;
        while(dut.precount_remaining!=0&&limit<100000)begin @(negedge clk);limit=limit+1;end
        if(limit>=100000||!countin_guide||extra_on!=0||cycle-start_cycle<49000)$fatal(1,"count-in incorrect limit=%0d guide=%b notes=%0d duration=%0d",limit,countin_guide,extra_on,cycle-start_cycle);
        limit=0;while(extra_on<16&&limit<10000)begin @(negedge clk);limit=limit+1;end
        if(extra_on!=16)$fatal(1,"count-in did not resume all16");
        control(5,0,0);until_flush();
        if(extra_off!=16)$fatal(1,"count-in stop lost note-offs %0d",extra_off);
        control(40,0,0);control(7,240,0);control(8,480,0);control(9,1,0);control(6,400,0);until_flush();
        extra_mode=2;control(10,200,0);control(3,0,0);repeat(100000)@(negedge clk);
        if(wraps<2||!playing||tick<240||tick>480)$fatal(1,"loop did not wrap deterministically wraps=%0d tick=%0d",wraps,tick);
        control(9,0,0);control(23,1,0);until_flush();repeat(500)@(negedge clk);
        if(section!=1||tick<480||timbres[31:0]!=={4{8'd19}})$fatal(1,"section arrangement not selected section=%0d tick=%0d timbres=%h",section,tick,timbres);
        if(volumes[31:0]!=={8'd40,8'd50,8'd60,8'd70})$fatal(1,"SECTION_VOLUME_NOT_COMMITTED actual=%h",volumes[31:0]);
        control(25,77,15);repeat(50)@(negedge clk);
        if(volumes[15*8+:8]!==8'd77)$fatal(1,"later track-volume command overwritten by section commit");
        control(5,0,0);until_flush();repeat(2)@(negedge clk);
        if(extra_held!==0)begin
            for(integer q=0;q<extra_slot;q=q+1)if(extra_held[q])$display("LOST_RELEASE slot=%0d id=%h",q,extra_ids[q]);
            $fatal(1,"controls left held notes on=%0d off=%0d",extra_on,extra_off);
        end
        extra_mode=0;
        $display("CHECK countin=1 map16=reverse loop_wraps=%0d section1=19 extra_on=%0d extra_off=%0d",wraps,extra_on,extra_off);
        complete_test("tb_player_controls",20);$display("PASS tb_player_controls tracks=16 timbres=10/19/20 on=%0d off=%0d",on_count,off_count);$finish;
    end
    initial begin #20000000;$fatal(1,"player16 timeout");end
endmodule
