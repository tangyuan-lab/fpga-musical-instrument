`timescale 1ns/1ps
module tb_shared_top;
 reg clk=0;always #10 clk=~clk;
 reg k2=1,k3=1;wire bck,ws,din,pa;
 piano_drums_poly4_shared_top #(.KEY_FILTER_MAX(3),.POR_CYCLES(8)) dut(
  .sys_clk(clk),.key2_n(k2),.key3_n(k3),.HP_BCK(bck),.HP_WS(ws),.HP_DIN(din),.PA_EN(pa));
 integer ticks=0,outputs=0,cycles=0,last_tick=0,triggers=0;
 reg [4:0] notes[0:31];reg sounds[0:31];
 always @(posedge clk)begin
  cycles=cycles+1;
  if(dut.rst_output)begin
   if(dut.frame_tick)begin
    if(last_tick!=0&&cycles-last_tick!=1041&&cycles-last_tick!=1042)$fatal(1,"48k fractional period");
    last_tick=cycles;ticks=ticks+1;
   end
   if(dut.sample_valid)outputs=outputs+1;
   if(dut.controls.overflow||dut.overrun)$fatal(1,"Top overflow");
   if(dut.event_valid&&dut.event_ready&&dut.event_on)begin
    notes[triggers]=dut.event_note;sounds[triggers]=dut.event_timbre;triggers=triggers+1;
   end
  end
 end
 reg [15:0] serial_word=0,left_word=0,latched_word=0;integer bitno=0,words=0;
 always @(posedge bck)if(dut.rst_output)begin
  serial_word={serial_word[14:0],din};
  if(!ws&&bitno==0)latched_word=dut.output_tx.sample_hold;
  if(bitno==15)begin
   if(serial_word!==latched_word)$fatal(1,"PT8211 serial PCM mismatch");
   if(!ws)left_word=serial_word;else if(serial_word!==left_word)$fatal(1,"PT8211 stereo mismatch");
   words=words+1;bitno=0;
  end else bitno=bitno+1;
 end
 task frames(input integer n);integer goal;begin goal=ticks+n;wait(ticks>=goal);repeat(12)@(negedge clk);end endtask
 task select_sound;begin k2=0;repeat(12)@(negedge clk);k2=1;repeat(12)@(negedge clk);end endtask
 task hit;begin k3=0;frames(75);k3=1;repeat(12)@(negedge clk);frames(2);end endtask
 wire [3:0] slot_timbres={dut.engine.slots[3].slot.timbre,dut.engine.slots[2].slot.timbre,dut.engine.slots[1].slot.timbre,dut.engine.slots[0].slot.timbre};
 reg [3:0] prior_timbres;
 integer j,prior;
 initial begin
  frames(3);if(dut.audio!=0||dut.active)$fatal(1,"Power-on sound");
  select_sound;frames(2);
  if(triggers!=0||dut.active||!dut.selected)$fatal(1,"K2 triggered/reset sound");
  for(j=0;j<8;j=j+1)hit;
  for(j=0;j<8;j=j+1)if(!sounds[j]||notes[j]!=(j%8))$fatal(1,"K3 tom loop");
  prior=triggers;k3=0;frames(75);prior_timbres=slot_timbres;select_sound;frames(20);
  if(triggers!=prior+1||slot_timbres!==prior_timbres)$fatal(1,"K2 changed held voice or long press retriggered");
  k3=1;repeat(12)@(negedge clk);frames(2);
  for(j=0;j<18;j=j+1)hit;
  for(j=0;j<18;j=j+1)if(sounds[prior+1+j]||notes[prior+1+j]!=(j==0||j==17?16:j-1))$fatal(1,"K3 17-note piano loop");
  // Same-cycle edges select the new timbre before triggering.
  k2=0;k3=0;frames(75);k2=1;k3=1;repeat(12)@(negedge clk);frames(2);
  if(!sounds[triggers-1]||notes[triggers-1]!=1)$fatal(1,"Simultaneous K2/K3 order");
  if(words<100||outputs<100)$fatal(1,"Insufficient serialized samples");
  $display("PASS shared four-voice top: K2 select, K3 low/mid/high/kick/snare/sidestick/clap/rimshot and piano loops, hold/release, simultaneous edges, silent POR, four voices, 48kHz PT8211 exact stereo; frames=%0d",outputs);
  $finish;
 end
 initial begin #120000000;$fatal(1,"Top timeout");end
endmodule
