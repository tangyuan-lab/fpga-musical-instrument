`timescale 1ns/1ps
`default_nettype none
module tb_lesson_import;
    `include "sim/result.svh"
    reg clk=0;always #10 clk=~clk;
    reg rst_n=0,clear=0,request=0;reg [2:0] action=2;reg [3:0] selected_track=3;
    reg source_available=1,source_quiet=1,parser_ready=1,parser_busy=0,parser_error=0;
    reg [11:0] event_count=4;reg [31:0] event_start=0,event_end=0;
    reg [6:0] event_note=0;reg [3:0] event_track=0;
    reg [111:0] physical_pitch_map=0;reg [15:0] enabled_keys=16'hffff,physical_down=0;reg [15:0] screen_down=0;
    reg signed [6:0] transpose=0;
    reg accepted_valid=0;reg [1:0] accepted_op=0,accepted_source=0;
    reg [4:0] accepted_key=0;reg [31:0] accepted_id=0;reg [6:0] accepted_note=0;reg [2:0] accepted_result=0;
    wire prepare_parser,reader_enable,done,active;wire [10:0] reader_index;
    wire [7:0] result;wire [15:0] guide_keys;wire [255:0] status;
    integer scenario=0;
    pressure_lesson dut(.*);
    always @(negedge clk)if(rst_n&&(^status)===1'bx)$fatal(1,"IMPORT_STATUS_X");
    // 同步读模型：第1/3事件为其他轨，同轨3的第2/4事件参与教学。
    always @(posedge clk)begin
        event_start<=reader_index*20;
        event_end<=scenario==1&&reader_index==1 ? 90:reader_index*20+10;
        event_track<=reader_index[0] ? 3:0;
        event_note<=scenario==2 ? 100:60+reader_index;
    end
    task automatic begin_import;
        begin
            request=1;@(negedge clk);request=0;
            if(!prepare_parser||!done||result!=0)$fatal(1,"IMPORT preparation request missing");
            repeat(12)@(negedge clk);
            if(reader_enable)$fatal(1,"IMPORT consumed stale previous parser ready");
            action=3;request=1;@(negedge clk);request=0;action=2;
            if(!done||result!=4||status[2:0]!=1||status[8])$fatal(1,"IMPORT early pause exposed incomplete course");
            parser_ready=0;parser_busy=1;repeat(5)@(negedge clk);
            source_quiet=0;parser_ready=1;parser_busy=0;repeat(4)@(negedge clk);
            if(reader_enable)$fatal(1,"IMPORT stole parser port before song flush");
            source_quiet=1;repeat(30)@(negedge clk);
        end
    endtask
    initial begin
        for(integer i=0;i<16;i=i+1)physical_pitch_map[i*7+:7]=60+i;
        repeat(4)@(negedge clk);rst_n=1;
        begin_import();
        if(status[63:48]!=2||status[79:72]!=61||status[87:80]!=63||guide_keys!=2)
            $fatal(1,"IMPORT track selection/order incorrect %h",status);
        scenario=1;begin_import();
        if(status[2:0]!=7||status[23:16]!=6)$fatal(1,"IMPORT overlapping chord accepted");
        action=5;request=1;@(negedge clk);request=0;
        if(!done||result!=2||status[2:0]!=7)$fatal(1,"IMPORT partial rejected course restarted");action=2;
        scenario=2;begin_import();
        if(status[2:0]!=7||status[23:16]!=5)$fatal(1,"IMPORT out of key range accepted");
        scenario=0;event_count=0;begin_import();
        if(status[2:0]!=7||status[23:16]!=2)$fatal(1,"IMPORT empty track accepted");
        complete_test("tb_lesson_import",12);$display("PASS tb_lesson_import stale_ready_flush_track_overlap_range_empty_partial_reject_early_pause_rejected");$finish;
    end
    initial begin #100000;$fatal(1,"import timeout");end
endmodule
`default_nettype wire
