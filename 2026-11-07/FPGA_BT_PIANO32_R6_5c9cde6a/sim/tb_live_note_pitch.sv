`timescale 1ns/1ps
`default_nettype none
module tb_live_note_pitch;
    `include "sim/result.svh"
    reg clk=0;always #10 clk=~clk;
    reg rst_n=0,clear=0,request=0,event_valid=0;
    reg signed [31:0] requested_offset=0;
    reg [31:0] pressed=0,event_id=0;reg [1:0] event_op=0,event_source=0;
    reg [4:0] event_key=0;reg [6:0] event_note=0;reg [2:0] event_result=0;
    reg [4:0] event_slot=16;reg [31:0] active_slots=32'hffffffff;
    wire offset_write,done;wire [4:0] offset_key;wire [31:0] offset_id;
    wire signed [6:0] offset_value;wire [7:0] result;wire [127:0] status;
    live_note_pitch dut(.*);
    task automatic event_send(input [1:0] op,src,input [4:0] key,input [31:0] id,input [6:0] note);
        begin event_op=op;event_source=src;event_key=key;event_id=id;event_note=note;event_valid=1;
            @(negedge clk);event_valid=0;end
    endtask
    initial begin
        repeat(4)@(negedge clk);rst_n=1;
        requested_offset=1;request=1;@(negedge clk);request=0;
        if(!done||result!=2)$fatal(1,"PITCH no-target not rejected");
        pressed[2]=1;event_send(1,0,2,100,60);
        request=1;@(negedge clk);request=0;
        if(!offset_write||offset_key!=2||offset_id!=100||offset_value!=1||done)$fatal(1,"PITCH did not wait for same identity commit");
        event_send(3,2,2,100,61);if(done)$fatal(1,"PITCH song completed live request");
        event_send(3,0,2,99,61);if(done)$fatal(1,"PITCH stale identity completed request");
        event_send(3,0,2,100,60);if(done)$fatal(1,"PITCH old pressure pitch completed request");
        event_send(3,0,2,100,61);if(!done||result!=0||status[39:32]!=61||status[47:40]!=1)$fatal(1,"PITCH commit missing");
        requested_offset=13;request=1;@(negedge clk);request=0;if(!done||result!=1)$fatal(1,"PITCH limit");
        pressed[19]=1;event_send(1,1,19,200,67);
        requested_offset=-1;request=1;@(negedge clk);request=0;
        if(offset_key!=19||offset_id!=200)$fatal(1,"PITCH screen last-note priority");
        pressed[19]=0;@(negedge clk);if(!done||result!=4||status[0])$fatal(1,"PITCH release while pending");
        pressed[2]=1;event_send(1,0,2,300,60);
        event_send(1,2,0,400,67);if(status[0])$fatal(1,"PITCH stolen slot still selected");
        event_send(1,0,2,301,60);active_slots[16]=0;@(negedge clk);
        if(status[0])$fatal(1,"PITCH finished voice still selected");
        active_slots[16]=1;pressed[2]=1;event_send(1,0,2,500,60);
        requested_offset=1;request=1;@(negedge clk);request=0;
        pressed[2]=0;event_send(3,0,2,500,61);
        if(!done||result!=4||status[0])$fatal(1,"PITCH_CANCEL_PRIORITY release and update commit same clock");
        pressed[2]=1;event_send(1,0,2,501,60);
        pressed[19]=1;requested_offset=2;request=1;event_send(1,1,19,600,67);request=0;
        if(!done||result!=4||offset_write||status[79:48]!=600)
            $fatal(1,"PITCH_REQUEST_SELECTION_RACE changed last-note must reject old-target write");
        request=1;event_send(0,1,19,600,67);request=0;
        if(!done||result!=4||offset_write||status[0])$fatal(1,"PITCH_REQUEST_OFF_RACE");
        pressed[2]=1;event_send(1,0,2,700,60);
        requested_offset=1;request=1;@(negedge clk);request=0;event_send(3,0,2,700,61);
        event_send(3,0,2,700,63);
        if(status[31:24]!=62||status[39:32]!=63)$fatal(1,"PITCH global transpose did not update held-note base");
        requested_offset=2;request=1;@(negedge clk);request=0;event_send(3,0,2,700,64);
        if(!done||result!=0||status[39:32]!=64||status[47:40]!=2)$fatal(1,"PITCH offset after global transpose did not commit");
        complete_test("tb_live_note_pitch",16);$display("PASS tb_live_note_pitch ownership_commit_pressure_scope_limits_release_steal_same_clock_cancel_global_transpose");$finish;
    end
    initial begin #100000;$fatal(1,"pitch timeout");end
endmodule
`default_nettype wire
