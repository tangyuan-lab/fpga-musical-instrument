`timescale 1ns/1ps
module tb_workstation_v2_commands;
    reg clk=0,rst_n=0;always #10 clk=~clk;
    reg hv=0,sv=0,safety=0,emergency=0;reg [7:0] ho=0,so=0,sx=0;reg [31:0] hx=0,ha=0;integer snapshot_apps;
    wire hd,av,lv,mv,pv;wire [7:0] hr,ao,lo,lx,sr;wire [31:0] ax,aa,px,pa;wire [15:0] md;
    reg ad=0,pd=0;reg [7:0] ar=0,pr=0;integer countdown=0,host_completions=0,apps=0;
    wire error;wire [2:0] mode;wire [255:0] mapping;
    workstation_v2_commands dut(.clk(clk),.rst_n(rst_n),.host_valid(hv),.host_op(ho),.host_value(hx),.host_aux(ha),.host_done(hd),.host_result(hr),
        .screen_valid(sv),.screen_op(so),.screen_value(sx),.safety_stop(safety),.timbre_pressed(1'b0),.live_patch(4'd0),
        .app_valid(av),.app_op(ao),.app_value(ax),.app_aux(aa),.app_done(ad),.app_result(ar),
        .legacy_valid(lv),.legacy_op(lo),.legacy_value(lx),.legacy_error(error),.map_valid(mv),.map_descriptor(md),
        .adsr_valid(pv),.adsr_value(px),.adsr_aux(pa),.adsr_done(pd),.adsr_result(pr),.screen_result(sr),.emergency_stop(emergency));
    instrument_mode_control_v2 #(.MODE_SLOTS(4)) modes(.clk(clk),.rst_n(rst_n),.cmd_valid(lv),.mode_pressed(1'b0),.cmd_op(lo),.cmd_value(lx),
        .direct_valid(mv),.direct_descriptor(md),.mode(mode),.command_error(error),.active_map(mapping));
    always @(posedge clk) begin
        ad<=0;pd<=pv;
        if(av) begin countdown<=12;apps<=apps+1;ar<=ao==99 ? 8'd7:8'd0;end
        else if(countdown>0) begin countdown<=countdown-1;if(countdown==1) ad<=1;end
        if(hd) host_completions<=host_completions+1;
    end
    task screen(input [7:0] op,input [7:0] value);
        begin @(negedge clk);so=op;sx=value;sv=1;@(negedge clk);sv=0;end
    endtask
    task host(input [7:0] op,input [31:0] value,input integer result);
        begin @(negedge clk);ho=op;hx=value;hv=1;@(negedge clk);hv=0;wait(hd);if(hr!=result) $fatal(1,"wrong host result %d",hr);@(negedge clk);end
    endtask
    initial begin
        repeat(5) @(negedge clk);rst_n=1;
        // 屏幕先提交一个延迟完成的错误操作，再同时到达USB请求和安全停音。
        screen(8'h40+99,0); // 范围外不能进入队列。
        screen(8'h43,0);
        wait(av);@(negedge clk);safety=1;
        fork host(10,120,0);begin @(negedge clk);safety=0;end join
        repeat(40) @(negedge clk);
        if(host_completions!=1 || apps!=3) $fatal(1,"ACK ownership/count host=%d apps=%d",host_completions,apps);
        host(1,2,0);host(30,2,0);host(31,3,0);host(32,16'h0207,0);
        if(mode!=2 || mapping[3*16+:16]!=16'h0207) $fatal(1,"atomic mapping write failed");
        host(32,16'hff00,1);host(1,4,0);if(mode!=4) $fatal(1,"settings mode rejected");
        screen(8'h70,8'h02);screen(8'h74,8'h12);screen(8'h75,8'h34);screen(8'h76,8'h56);screen(8'h77,8'h78);screen(8'h62,0);
        wait(pv);if(px!=2 || pa!=32'h78563412) $fatal(1,"full 32-bit aux staging failed %h",pa);
        repeat(10) @(negedge clk);
        if(host_completions!=7) $fatal(1,"screen ADSR emitted host ACK");
        screen(8'h43,0);wait(av);screen(8'h43,0);screen(8'h43,0);
        emergency=1;@(negedge clk);emergency=0;repeat(2) @(negedge clk);snapshot_apps=apps;
        repeat(50) @(negedge clk);
        if(apps!=snapshot_apps || dut.count!=0 || dut.pending_host) $fatal(1,"emergency did not clear queued play commands");
        host(10,100,0);
        $display("PASS tb_workstation_v2_commands ownership/queue/panic/atomic-map/full-aux");$finish;
    end
    initial begin #100_000;$fatal(1,"command arbitration timeout");end
endmodule
