`timescale 1ns/1ps
// 配置写入只允许增加一拍：锁存上下文、整组原子恢复和实际提交通知必须一致。
module tb_workstation_v2_mapping_commit;
    reg clk=0,rst_n=0,valid=0,direct=0,button=0;always #10 clk=~clk;
    reg [7:0] op=0,value=0;reg [15:0] descriptor=0;
    wire [2:0] mode,bank;wire [3:0] key;wire [255:0] mapping;wire [15:0] edit;
    wire changed,error,mode_changed;
    instrument_mode_control_v2 #(.MODE_SLOTS(4)) dut(.clk(clk),.rst_n(rst_n),.cmd_valid(valid),.mode_pressed(button),
        .cmd_op(op),.cmd_value(value),.direct_valid(direct),.direct_descriptor(descriptor),.mode(mode),
        .map_changed(changed),.mode_changed(mode_changed),.command_error(error),.active_map(mapping),.edit_bank(bank),.edit_key(key),.edit_descriptor(edit));
    task command(input [7:0] code,input [7:0] data);
        begin @(negedge clk);valid=1;op=code;value=data;@(negedge clk);valid=0;end
    endtask
    integer i;
    initial begin
        repeat(3) @(negedge clk);rst_n=1;
        command(5,2);command(8'h20,2);command(8'h21,3);
        @(negedge clk);descriptor=16'h0207;direct=1;
        @(posedge clk);#1;
        if(changed || mapping[48+:16]!=16'h3f03) $fatal(1,"map changed before commit");
        // 接收后立即改变编辑选择，待提交事务仍须写入原第3键。
        @(negedge clk);direct=0;valid=1;op=8'h21;value=4;
        @(posedge clk);#1;
        if(!changed || mapping[48+:16]!=16'h0207 || mapping[64+:16]!=16'h3f04 || key!=4) $fatal(1,"context/commit pulse mismatch");
        @(negedge clk);valid=0;
        @(posedge clk);#1;if(changed) $fatal(1,"stale map notification");
        @(negedge clk);direct=1;descriptor=16'hff00;
        @(posedge clk);#1;if(!error) $fatal(1,"invalid descriptor accepted");
        @(negedge clk);direct=0;
        @(posedge clk);#1;if(changed || mapping[64+:16]!=16'h3f04) $fatal(1,"invalid request committed");
        command(8'h22,1);command(8'h23,0);command(8'h24,9);command(8'h25,1);
        @(posedge clk);#1;
        if(!changed || mapping[64+:16]!=16'h4009) $fatal(1,"staged descriptor commit failed");
        @(negedge clk);valid=1;op=8'h26;value=2;
        @(posedge clk);#1;
        if(changed || mapping[48+:16]!=16'h0207 || mapping[64+:16]!=16'h4009) $fatal(1,"restore was not staged");
        @(negedge clk);valid=0;
        @(posedge clk);#1;
        if(!changed) $fatal(1,"restore notification absent");
        for(i=0;i<16;i=i+1) if(mapping[i*16+:16]!=(16'h3f00|16'(i))) $fatal(1,"restore not atomic at key %d",i);
        command(5,1);
        for(i=0;i<16;i=i+1) if(mapping[i*16+:16]!=(16'h4000|16'(i))) $fatal(1,"restore leaked into another bank");
        // 模式按钮优先级高于同拍直接写入。
        @(negedge clk);button=1;direct=1;descriptor=16'h000f;
        @(negedge clk);button=0;direct=0;
        repeat(2) @(negedge clk);
        if(mode!=2 || mapping[64+:16]!=16'h3f04 || changed) $fatal(1,"mode-button priority lost");
        @(negedge clk);direct=1;descriptor=16'h000f;
        @(negedge clk);direct=0;rst_n=0;
        #1;if(changed || mode!=0) $fatal(1,"reset did not clear pending transaction");
        @(negedge clk);rst_n=1;command(5,2);
        if(mapping[64+:16]!=16'h3f04) $fatal(1,"pending write survived reset");
        $display("PASS tb_workstation_v2_mapping_commit context/atomic-restore/notification/priority/reset");$finish;
    end
    initial begin #100000;$fatal(1,"mapping commit timeout");end
endmodule
