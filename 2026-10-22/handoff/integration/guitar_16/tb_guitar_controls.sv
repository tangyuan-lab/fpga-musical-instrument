`timescale 1ns/1ps
module tb_guitar_controls;
 reg clk=0;always #10 clk=~clk;
 reg rst_n=0,k2=1,k3=1,ready=1;
 wire valid,on,overflow;wire [4:0] key,note;wire [1:0] timbre,selected;wire [6:0] velocity;
 guitar_audition_controller #(.KEY_FILTER_MAX(2)) dut(.clk(clk),.rst_n(rst_n),.key2_n(k2),.key3_n(k3),
  .event_valid(valid),.event_ready(ready),.event_on(on),.event_key(key),.event_timbre(timbre),
  .event_note(note),.event_velocity(velocity),.selected_timbre(selected),.overflow(overflow));
 reg [19:0] events[0:511];integer count=0;
 always @(posedge clk)if(rst_n&&valid&&ready)begin events[count]<={on,key,timbre,note,velocity};count<=count+1;end
 task clocks(input integer n);repeat(n)@(negedge clk);endtask
 task select_next;begin k2=0;clocks(12);k2=1;clocks(12);end endtask
 task trigger;begin k3=0;clocks(12);k3=1;clocks(12);end endtask
 task expect_event(input integer i,input bit down,input integer bank,input integer number);
  reg [19:0] expected;
  begin expected={down,5'd31,bank[1:0],number[4:0],7'd112};
   if(events[i]!==expected)$fatal(1,"event %0d got %h expected %h",i,events[i],expected);
  end
 endtask
 integer i,start_count;
 initial begin
  clocks(4);rst_n=1;clocks(10);
  if(count!=0||selected!=0)$fatal(1,"startup");
  // Complete piano cycle and note 16, not a truncated four-bit bank.
  for(i=0;i<18;i=i+1)begin trigger();expect_event(2*i,1,0,i==0||i==17?16:i-1);expect_event(2*i+1,0,0,i==0||i==17?16:i-1);end
  select_next();if(count!=36||selected!=1)$fatal(1,"silent selection");
  for(i=0;i<9;i=i+1)begin trigger();expect_event(36+2*i,1,1,i%8);end
  select_next();if(selected!=2)$fatal(1,"guitar selection");
  for(i=0;i<17;i=i+1)begin trigger();expect_event(54+2*i,1,2,i%16);expect_event(55+2*i,0,2,i%16);end
  // Hold produces exactly one down. Switching while held must retain the off owner.
  k3=0;clocks(60);start_count=count;if(start_count!=89)$fatal(1,"hold repeat");
  select_next();if(count!=start_count||selected!=0)$fatal(1,"selection triggered audio");
  k3=1;clocks(15);expect_event(89,0,2,1);
  // Backpressure must preserve payload and FIFO order.
  ready=0;trigger();trigger();clocks(10);
  if(count!=90)$fatal(1,"backpressure");
  ready=1;clocks(15);expect_event(90,1,0,0);expect_event(92,1,0,1);
  // Simultaneous K2 and K3: select before trigger, then retain the selected off event.
  k2=0;k3=0;clocks(12);k2=1;k3=1;clocks(15);
  expect_event(94,1,1,1);expect_event(95,0,1,1);
  if(overflow)$fatal(1,"unexpected overflow");
  // An intentionally stalled consumer must expose overflow, never silently hide it.
  ready=0;repeat(5)trigger();if(!overflow)$fatal(1,"missing overflow indication");
  $display("PASS guitar controller: three timbres, full note cycles, owner, simultaneous keys, FIFO, overflow");$finish;
 end
 initial begin #2000000;$fatal(1,"timeout");end
endmodule
