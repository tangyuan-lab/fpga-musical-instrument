`timescale 1ns/1ps
module tb_engine;
 parameter integer CASE=0,FRAMES=512,ADSR_MODE=0;
 integer case_code=CASE,frame_count=FRAMES,drum_index=0,switch_phase=0;
 initial begin
  if($value$plusargs("case=%d",case_code))begin end
  if($value$plusargs("frames=%d",frame_count))begin end
  if($value$plusargs("drum=%d",drum_index))begin end
  if($value$plusargs("switch_phase=%d",switch_phase))begin end
 end
 reg clk=0;always #10 clk=~clk;
 reg rst=0,tick=0,event_valid=0,event_on=0,event_timbre=0;
 reg [4:0] event_key=0,event_note=0;reg [6:0] velocity=112;reg [15:0] pitch=32768;
 wire ready_g,ready_w,valid_g,valid_w,overrun_g,overrun_w;
 wire signed [15:0] sample_g,sample_w;wire [3:0] active_g,active_w;
 instrument_shared4_engine #(.PIANO_ADSR_ENABLE(ADSR_MODE),.TOM_ADSR_ENABLE(ADSR_MODE)) dut(
  .clk(clk),.rst_n(rst),.sample_tick(tick),.event_valid(event_valid),.event_ready(ready_g),.event_on(event_on),.event_key(event_key),
  .event_timbre(event_timbre),.event_note(event_note),.event_velocity(velocity),.pitch_ratio_q15(pitch),
  .sample_out(sample_g),.sample_valid(valid_g),.active_voices(active_g),.overrun(overrun_g));
 instrument_reference4_engine #(.PIANO_ADSR_ENABLE(ADSR_MODE),.TOM_ADSR_ENABLE(ADSR_MODE)) reference(
  .clk(clk),.rst_n(rst),.sample_tick(tick),.event_valid(event_valid),.event_ready(ready_w),.event_on(event_on),.event_key(event_key),
  .event_timbre(event_timbre),.event_note(event_note),.event_velocity(velocity),.pitch_ratio_q15(pitch),
  .sample_out(sample_w),.sample_valid(valid_w),.active_voices(active_w),.overrun(overrun_w));
 integer clock_count=0,frame_start=0,f=-1,max_frame=0,max_piano=0,max_C=0;
 always @(posedge clk)clock_count<=clock_count+1;
 reg seen_g=0,seen_w=0;reg signed [15:0] capture_g,capture_w;
 reg [3:0] piano_g=0,piano_w=0;
 reg signed [15:0] piano_capture_g[0:3],piano_capture_w[0:3];
 integer C_start[0:3];
 reg [2:0] reset_history=0;
 always @(posedge clk)reset_history<={reset_history[1:0],rst};
 integer reference_piano_latency[0:3],reference_tom_latency[0:3];
 genvar v;generate for(v=0;v<4;v=v+1)begin:voices
  always @(posedge clk)begin
   if(!rst)C_start[v]<=0;
   else if(dut.slots[v].slot.C_voice.core.tick24)C_start[v]<=clock_count;
  end
  always @(negedge clk)if(rst&&f>=0)begin
   if(reference.slots[v].slot.piano_valid&&clock_count-frame_start!=901+v)
    $fatal(1,"Accepted piano valid schedule changed voice=%0d frame=%0d clocks=%0d",v,f,clock_count-frame_start);
   if(reference.slots[v].slot.tom_valid&&clock_count-frame_start!=747+v)
    $fatal(1,"Accepted tom valid schedule changed voice=%0d frame=%0d clocks=%0d",v,f,clock_count-frame_start);
   if(&reset_history)begin
    if(ADSR_MODE&&(dut.slots[v].slot.post_adsr_gain!==reference.slots[v].slot.tom.adsr_gain||
       dut.slots[v].slot.piano.adsr_gain!==reference.slots[v].slot.piano.adsr_gain||
       dut.slots[v].slot.C_voice.adsr_gain!==reference.slots[v].slot.C_voice.adsr_gain))
     $fatal(1,"Per-clock ADSR history mismatch voice=%0d frame=%0d clock=%0d tom=%0d/%0d",v,f,clock_count-frame_start,dut.slots[v].slot.post_adsr_gain,reference.slots[v].slot.tom.adsr_gain);
    if(dut.slots[v].slot.busy!==reference.slots[v].slot.busy||dut.slots[v].slot.held!==reference.slots[v].slot.held||
       dut.slots[v].slot.level!==reference.slots[v].slot.level||dut.slots[v].slot.quiet_frames!==reference.slots[v].slot.quiet_frames)
     $fatal(1,"Per-clock allocator metadata mismatch voice=%0d frame=%0d clock=%0d level=%0d/%0d quiet=%0d/%0d",v,f,clock_count-frame_start,dut.slots[v].slot.level,reference.slots[v].slot.level,dut.slots[v].slot.quiet_frames,reference.slots[v].slot.quiet_frames);
   end
   if((case_code==8||case_code==9)&&reference.slots[v].slot.piano_valid)begin
    if(f<3)$display("REFERENCE PIANO frame=%0d voice=%0d cycles=%0d",f,v,clock_count-frame_start);
    reference_piano_latency[v]=clock_count-frame_start;
   end
   if((case_code==8||case_code==9)&&reference.slots[v].slot.tom_valid)begin
    if(f<3)$display("REFERENCE TOM frame=%0d voice=%0d cycles=%0d",f,v,clock_count-frame_start);
    reference_tom_latency[v]=clock_count-frame_start;
   end
   if(dut.slots[v].slot.piano_valid)begin
    piano_g[v]=1;piano_capture_g[v]=dut.slots[v].slot.piano_sample;
    if(clock_count-frame_start>max_piano)max_piano=clock_count-frame_start;
   end
   if(reference.slots[v].slot.piano_valid)begin piano_w[v]=1;piano_capture_w[v]=reference.slots[v].slot.piano_sample;end
   if(dut.slots[v].slot.C_voice.core.pair_valid)begin
    if(clock_count-C_start[v]>max_C)max_C=clock_count-C_start[v];
    if(clock_count-C_start[v]>1770)$fatal(1,"C missed planned deadline voice=%0d frame=%0d clocks=%0d",v,f,clock_count-C_start[v]);
   end
  end
 end endgenerate
 always @(negedge clk)if(rst&&f>=0)begin
  if(valid_g)begin seen_g=1;capture_g=sample_g;if(clock_count-frame_start>max_frame)max_frame=clock_count-frame_start;end
  if(valid_w)begin seen_w=1;capture_w=sample_w;end
 end
 task send_event;
  input is_on,timbre;input [4:0] key,note;input [6:0] vel;
  begin
   while(!ready_g||!ready_w)@(negedge clk);
   event_valid=1;event_on=is_on;event_timbre=timbre;event_key=key;event_note=note;velocity=vel;
   @(negedge clk);event_valid=0;@(negedge clk);
  end
 endtask
 integer stress_events=0,max_event_wait=0;
 task queued_event;
  input is_on,timbre;input [4:0] key,note;input [6:0] vel;
  integer waited;
  begin
   @(negedge clk);event_valid=1;event_on=is_on;event_timbre=timbre;event_key=key;event_note=note;velocity=vel;waited=0;
   while(!ready_g||!ready_w)begin
    if(ready_g!==ready_w)$fatal(1,"Ready diverged under queued stealing");
    @(negedge clk);waited=waited+1;
    if(waited>70*1042)$fatal(1,"Stealing starved a queued event");
   end
   @(negedge clk);event_valid=0;stress_events=stress_events+1;
   if(waited>max_event_wait)max_event_wait=waited;
   @(negedge clk);
  end
 endtask
 integer sequence_index;
 initial begin
  wait(case_code==5&&rst);wait(f>=3);
  for(sequence_index=0;sequence_index<24;sequence_index=sequence_index+1)begin
   queued_event(1,sequence_index%3!=0,8+sequence_index%24,sequence_index%3==0?sequence_index%17:sequence_index%8,1+(sequence_index*37)%127);
   queued_event(0,0,sequence_index%4,0,112);
  end
 end
 integer period,i;
 initial begin
  repeat(8)@(negedge clk);rst=1;repeat(5)@(negedge clk);
  if(case_code==8||case_code==10||case_code==11)for(i=0;i<4;i=i+1)send_event(1,1,i,case_code==10?0:1+(i%2),0);
  for(f=0;f<frame_count;f=f+1)begin
   seen_g=0;seen_w=0;piano_g=0;piano_w=0;frame_start=clock_count;
   // Reuse a silent, free tom slot exactly on the sample edge. Its old
   // zero-volume frame still has an outstanding modal job to complete.
   if((case_code==8||case_code==9)&&(f==1030||f==1100))begin
    if(!ready_g||!ready_w)$fatal(1,"Silent-slot reuse was unexpectedly blocked");
    event_valid=1;event_on=1;event_timbre=1;event_key=f==1030?8:9;event_note=f==1030?1:2;velocity=112;
   end
   tick=1;@(negedge clk);tick=0;
   if((case_code==8||case_code==9)&&(f==1030||f==1100))event_valid=0;
   if((case_code==10||case_code==11)&&(f==1030||f==1100||f==1170||f==1240))event_valid=0;
   if(f==0&&case_code!=8&&case_code!=10&&case_code!=11)begin
    for(i=0;i<4;i=i+1)begin
     if(case_code==0||case_code==3||case_code==4||case_code==5||case_code==12)send_event(1,0,i,(i*5)%17,case_code==12?0:112-i*11);
     else if(case_code==1||case_code==6||case_code==7)send_event(1,1,i,case_code==6?drum_index:0,112-i*7);
     else if(case_code==9)send_event(1,1,i,1+(i%2),0);
     else send_event(1,1,i,i==0?0:i==1?3:i==2?4:7,112-i*9);
    end
   end
   // Leave four nonzero piano histories running, free their silent slots,
   // then start four identical drums. All eight modal workloads now compete
   // at real sample periods, including the worst packet-overlap ages.
   if(case_code==12&&f==2)for(i=0;i<4;i=i+1)send_event(0,0,i,0,0);
   if(case_code==12&&f==1030)begin
    if(active_w!=0)$fatal(1,"Piano-history stress slots did not become free");
    for(i=0;i<4;i=i+1)send_event(1,1,8+i,drum_index,112-i*7);
   end
   if(case_code==3)begin
    if(f==30)begin send_event(0,0,0,0,112);send_event(0,0,1,0,112);end
    if(f>=60&&f<780&&(f-60)%90==0)send_event(1,1,8+(f-60)/90,(f-60)/90,112);
    if(f==820||f==910)send_event(1,0,20+(f/70)%8,(f/70)%17,73);
   end
   if(case_code==4)begin
    if(f==60||f==150)send_event(1,1,8+(f/50),0,127);
    if(f==203)begin repeat(200)@(negedge clk);rst=0;repeat(6)@(negedge clk);rst=1;end
    if(f==204)for(i=0;i<4;i=i+1)send_event(1,i!=3,20+i,i==0?0:i==1?1:i==2?7:16,91);
   end
   // Steal four already-running C voices into mid/high toms, then back to
   // C drums. Exercise both parities of the core's 24kHz scheduling phase;
   // the last old job can overlap the new voice's first 48kHz frame.
   if(case_code==7&&f>=100+switch_phase&&f<=590+switch_phase&&(f-100-switch_phase)%70==0)begin
    sequence_index=(f-100-switch_phase)/70;
    send_event(1,1,8+sequence_index,sequence_index<4?(sequence_index[0]?2:1):(sequence_index==4?0:sequence_index==5?4:sequence_index==6?7:3),127);
   end
   if(f==180&&case_code<3)send_event(1,case_code!=0,16,case_code==0?16:6,127);
   if(f==270&&case_code<3)send_event(0,0,1,0,112);
   if(f==300)pitch=30000;
   if(f==400)pitch=37000;
   period=f%3==0?1041:1042;
   if((case_code==10||case_code==11)&&(f==1029||f==1099||f==1169||f==1239))begin
    while(clock_count-frame_start<period-1)@(negedge clk);
    if(!ready_g||!ready_w)$fatal(1,"Late free-slot event blocked");
    event_valid=1;event_on=1;event_key=12+(f-1029)/70;
    event_timbre=f!=1099;event_note=f==1099?16:f==1169?0:f==1239?7:1;velocity=112;
   end
   while(clock_count-frame_start<period)@(negedge clk);
   if(!(case_code==4&&f==203))begin
   if(!seen_g||!seen_w||overrun_g||overrun_w)$fatal(1,"Engine deadline case=%0d frame=%0d seen=%b%b overrun=%b%b",case_code,f,seen_g,seen_w,overrun_g,overrun_w);
   if(capture_g!==capture_w)$fatal(1,"Engine mismatch case=%0d frame=%0d got=%0d want=%0d",case_code,f,capture_g,capture_w);
   if(piano_g!=15||piano_w!=15)$fatal(1,"Background piano missed frame=%0d new=%b reference=%b",f,piano_g,piano_w);
   for(i=0;i<4;i=i+1)if(piano_capture_g[i]!==piano_capture_w[i])$fatal(1,"Hidden piano changed voice=%0d frame=%0d got=%0d want=%0d",i,f,piano_capture_g[i],piano_capture_w[i]);
   if(ready_g!==ready_w||active_g!==active_w)begin
    $display("ALLOCATOR got=%b want=%b quiet0=%0d/%0d",active_g,active_w,dut.slots[0].slot.quiet_frames,reference.slots[0].slot.quiet_frames);
    $fatal(1,"Allocator status mismatch frame=%0d",f);
   end
   end
  end
  if(max_frame>884||max_piano>884)$fatal(1,"48k work exceeded planned 884 clocks: output=%0d background=%0d",max_frame,max_piano);
  if(case_code==5)begin
   if(stress_events!=48||max_event_wait<64*1000)$fatal(1,"Queued stealing stress incomplete: accepted=%0d max_wait=%0d",stress_events,max_event_wait);
   $display("Queued stealing: 48 accepted events, max backpressure=%0d clocks",max_event_wait);
  end
  $display("PASS four-voice case %0d ADSR=%0d: %0d exact frames, max output=%0d piano=%0d C=%0d",case_code,ADSR_MODE,frame_count,max_frame,max_piano,max_C);$finish;
 end
 initial begin #50000000000.0;$fatal(1,"Engine watchdog");end
endmodule
