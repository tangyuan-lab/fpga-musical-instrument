`timescale 1ns/1ps
// 直接驱动路由输出，验证新增流水线的快照、音高饱和、轻按和停音边界。
module tb_workstation_v2_key_pipeline;
    reg clk=0,rst_n=0;always #10 clk=~clk;
    reg [31:0] keys=0;reg [127:0] offsets=0,velocities=0;
    reg signed [6:0] transpose=0;reg [1:0] octave=0;reg panic=0;
    instrument_workstation_v2_top dut(.sys_clk(clk),.sys_rst_n(rst_n),.uart_rx_i(1'b1),
        .mode_key_n(1'b1),.timbre_key_n(1'b1),.screen_rx_i(1'b1),.mcp0_miso(1'b0),.mcp1_miso(1'b0));
    task check_note(input [6:0] expected);
        begin
            fork: timeout_note
                begin wait(dut.realtime_valid && dut.realtime_id==0 && dut.realtime_source==0);
                    if(dut.realtime_note!==expected || dut.realtime_velocity!==1)
                        $fatal(1,"pitch/velocity actual=%d/%d expected=%d/1",dut.realtime_note,dut.realtime_velocity,expected);
                end
                begin repeat(300) @(negedge clk);$fatal(1,"no realtime command");end
            join_any
            disable timeout_note;
        end
    endtask
    task clear_pipeline;
        begin @(negedge clk);panic=1;@(negedge clk);panic=0;end
    endtask
    initial begin
        force dut.input_keys=keys;force dut.physical_notes=offsets;force dut.velocity_values=velocities;
        force dut.live_transpose=transpose;force dut.live_octave_shift=octave;
        force dut.synth_panic=panic;force dut.synth_ready=1'b1;
        repeat(4) @(negedge clk);rst_n=1;repeat(4) @(negedge clk);
        keys=1;velocities[7:0]=1;transpose=-64;octave=2;clear_pipeline();check_note(0);
        transpose=63;octave=1;offsets[7:0]=255;clear_pipeline();check_note(127);
        transpose=0;octave=0;offsets[7:0]=0;clear_pipeline();
        wait(dut.scan_key==0 && dut.scan_phase==1);@(negedge clk);
        // 改写快照来源，已经采到的键仍应按旧音高60提交。
        offsets[7:0]=12;transpose=12;check_note(60);
        clear_pipeline();check_note(84);
        @(negedge clk);panic=1;@(negedge clk);
        if(dut.realtime_valid || dut.applied!==0 || dut.scan_phase!==0) $fatal(1,"panic left stale command");
        $display("PASS tb_workstation_v2_key_pipeline saturation snapshot low_velocity panic");$finish;
    end
    initial begin #100000;$fatal(1,"pipeline timeout");end
endmodule
