`timescale 1ns/1ps
`default_nettype none
module tb_pressure_lesson;
    `include "sim/result.svh"
    reg clk=0;always #10 clk=~clk;
    reg rst_n=0,clear=0,request=0;reg [2:0] action=0;reg [3:0] selected_track=0;
    reg source_available=1,source_quiet=1,parser_ready=1,parser_busy=0,parser_error=0;
    reg [11:0] event_count=2;reg [31:0] event_start=0,event_end=10;
    reg [6:0] event_note=60;reg [3:0] event_track=0;
    reg [111:0] physical_pitch_map=0;reg [15:0] enabled_keys=16'hffff,physical_down=0;reg [15:0] screen_down=0;
    reg signed [6:0] transpose=0;
    reg accepted_valid=0;reg [1:0] accepted_op=0,accepted_source=0;
    reg [4:0] accepted_key=0;reg [31:0] accepted_id=0;reg [6:0] accepted_note=0;reg [2:0] accepted_result=0;
    wire prepare_parser,reader_enable,done,active;wire [10:0] reader_index;
    wire [7:0] result;wire [15:0] guide_keys;wire [255:0] status;
    pressure_lesson dut(.*);
    always @(negedge clk)if(rst_n&&(^status)===1'bx)$fatal(1,"LESSON_STATUS_X idle/loading/finished status");
    task automatic command(input [2:0] a);
        begin action=a;request=1;@(negedge clk);request=0;if(!done||result!=0)$fatal(1,"LESSON command %0d rejected",a);end
    endtask
    task automatic key_event(input [1:0] op,src,input [4:0] key,input [6:0] note,input [31:0] id);
        begin accepted_op=op;accepted_source=src;accepted_key=key;accepted_note=note;accepted_id=id;accepted_valid=1;
            @(negedge clk);accepted_valid=0;end
    endtask
    initial begin
        for(integer i=0;i<16;i=i+1)physical_pitch_map[i*7+:7]=60+i;
        repeat(4)@(negedge clk);rst_n=1;@(negedge clk);
        if(status[87:64]!==24'hffffff)$fatal(1,"LESSON idle target sentinel");
        command(1);action=3;request=1;@(negedge clk);request=0;
        if(!done||result!=4||status[1:0]!=2||status[8])$fatal(1,"LESSON pause during unfinished load accepted");
        repeat(160)@(negedge clk);
        if(guide_keys!=1||status[63:48]!=42)$fatal(1,"LESSON Twinkle not preloaded");
        physical_down=2;key_event(1,0,1,61,100);
        if(status[47:32]!=0||status[79:72]!=60||status[111:96]!=2)$fatal(1,"LESSON wrong key advanced");
        physical_down=0;key_event(1,1,0,60,101);key_event(1,2,0,60,102);
        if(status[2:0]!=4)$fatal(1,"LESSON nonphysical source accepted");
        physical_down=1;key_event(1,0,0,60,103);
        if(status[2:0]!=5||status[47:32]!=0)$fatal(1,"LESSON correct press missing");
        repeat(3)key_event(3,0,0,60,103);
        if(status[47:32]!=0)$fatal(1,"LESSON held pressure advanced");
        physical_down=0;key_event(0,0,0,60,99);
        if(status[47:32]!=0)$fatal(1,"LESSON old release advanced");
        key_event(0,0,0,60,103);repeat(6)@(negedge clk);
        if(status[47:32]!=1||guide_keys!=1)$fatal(1,"LESSON repeated C requires new press");
        command(3);physical_down=1;key_event(1,0,0,60,104);
        if(status[47:32]!=1||guide_keys!=0)$fatal(1,"LESSON pause failed");
        physical_down=0;command(4);repeat(6)@(negedge clk);
        // 屏幕键16对应实体键0。保活与另一来源的释音都不能推进。
        screen_down=1;key_event(1,1,16,60,200);
        if(status[2:0]!=5||status[144]!=1)$fatal(1,"LESSON screen new press not accepted state=%0d source=%b key=%d target=%d note=%d valid=%b single=%b physical=%h screen=%h",status[2:0],status[144],accepted_key,status[71:64],status[79:72],dut.source_key_valid,dut.one_live_key,physical_down,screen_down);
        repeat(3)key_event(3,1,16,60,200);
        if(status[47:32]!=1)$fatal(1,"LESSON screen keepalive advanced");
        screen_down=0;key_event(0,0,0,60,200);
        if(status[47:32]!=1)$fatal(1,"LESSON other-source release advanced");
        key_event(0,1,16,60,200);repeat(6)@(negedge clk);
        if(status[47:32]!=2)$fatal(1,"LESSON screen release did not advance");
        command(5);repeat(6)@(negedge clk);
        physical_down=1;key_event(1,0,0,60,201);physical_down=0;key_event(0,0,0,60,201);repeat(6)@(negedge clk);
        physical_down=1;key_event(1,0,0,60,105);physical_down=0;key_event(0,0,0,60,105);repeat(6)@(negedge clk);
        if(status[47:32]!=2||guide_keys!=16'h0080)$fatal(1,"LESSON next G key8 mapping failed");
        physical_down=16'h0080;key_event(1,0,7,67,106);
        physical_down=0;action=3;request=1;key_event(0,0,7,67,106);request=0;
        if(status[47:32]!=2||!status[8])$fatal(1,"LESSON pause/release same clock advanced");
        command(4);repeat(6)@(negedge clk);
        for(integer i=2;i<42;i=i+1)begin
            physical_down=16'd1<<status[71:64];
            key_event(1,0,5'(status[71:64]),7'(status[79:72]),1000+i);
            if(status[2:0]!=5)$fatal(1,"LESSON complete course missing press i=%0d",i);
            physical_down=0;key_event(0,0,5'(status[71:64]),7'(status[79:72]),1000+i);repeat(6)@(negedge clk);
            if(status[47:32]!=i+1)$fatal(1,"LESSON complete course wrong position i=%0d",i);
        end
        if(status[2:0]!=6||status[87:64]!==24'hffffff||guide_keys!=0)$fatal(1,"LESSON finished status/target");
        command(0);physical_pitch_map=0;command(1);repeat(30)@(negedge clk);
        if(status[2:0]!=7||status[23:16]!=5)$fatal(1,"LESSON unmapped course accepted");
        complete_test("tb_pressure_lesson",97);$display("PASS tb_pressure_lesson Twinkle42_wrong_source_hold_repeat_release_pause_mapping_no_status_X_control_priority");$finish;
    end
    initial begin #100000;$fatal(1,"lesson timeout");end
endmodule
`default_nettype wire
