`timescale 1ns/1ps
`include "sim/ddr_phy_model.sv"
module gain_dac_timing_case #(parameter ONBOARD=1)(input wire clk,output reg done=0);
    reg rst_n=0,enable=0;reg signed [15:0] stimulus=0;
    wire [31:0] dq;wire [3:0] dqs,dqsn;
    mega138_models8_top #(.ONBOARD_DAC(ONBOARD),.USB_CLKS_PER_BIT(8),.SCREEN_CLKS_PER_BIT(8),
        .CALIBRATION_SAMPLES(1),.STARTUP_CYCLES(10),.SCREEN_STARTUP_CYCLES(100),.SCREEN_UPDATE_CYCLES(5000)) dut(
        .bt_rx_i(1'b1),.bt_tx_o(),.sys_clk(clk),.sys_rst_n(rst_n),.uart_rx_i(1'b1),.uart_tx_o(),.mode_key_n(1'b1),.timbre_key_n(1'b1),
        .led_n(),.hp_bck(),.hp_ws(),.hp_din(),.pa_en(),.screen_rx_i(1'b1),.screen_tx_o(),
        .mcp0_sclk(),.mcp1_sclk(),.mcp0_mosi(),.mcp1_mosi(),.mcp0_cs_n(),.mcp1_cs_n(),.mcp0_miso(1'b0),.mcp1_miso(1'b0),.hpd_en(),
        .ddr_addr(),.ddr_bank(),.ddr_cs(),.ddr_ras(),.ddr_cas(),.ddr_we(),.ddr_ck(),.ddr_ck_n(),.ddr_cke(),.ddr_odt(),.ddr_reset_n(),
        .ddr_dm(),.ddr_dq(dq),.ddr_dqs(dqs),.ddr_dqs_n(dqsn));
    wire latch;
    wire signed [15:0] held_left,held_right;
    generate if(ONBOARD)begin
        assign latch=dut.g_onboard.output_tx.advance&&dut.g_onboard.output_tx.bck&&dut.g_onboard.output_tx.bit_index==0;
        assign held_left=dut.g_onboard.output_tx.left_hold;
        assign held_right=dut.g_onboard.output_tx.right_hold;
    end else begin
        assign latch=dut.g_i2s.output_tx.advance&&dut.g_i2s.output_tx.bck&&dut.g_i2s.output_tx.bit_index==0;
        assign held_left=dut.g_i2s.output_tx.left_hold;
        assign held_right=dut.g_i2s.output_tx.right_hold;
    end endgenerate
    reg signed [15:0] completed_pcm=0,expected_frame=0;
    integer ticks=0,outputs=0,latches=0,limited_count=0,clip_count=0,frame_outputs=0;
    initial begin
        force dut.chorus_pcm=stimulus;
        force dut.master_boost=2'd3;
        force dut.limiter_enabled=enable;
        repeat(6)@(negedge clk);rst_n=1;
        wait(ticks>=170);
        // Alternating small/overload inputs cross the serial divider's two
        // latency paths. Both must reach the DAC after the same frame delay.
        for(integer i=0;i<100;i=i+1)begin
            @(negedge clk);
            enable=(i<80);
            case(i%4)
                0:stimulus=16'sd700;
                1:stimulus=16'sd30000;
                2:stimulus=-16'sd1100;
                3:stimulus=-16'sd28000;
            endcase
            wait(ticks>=172+i);
        end
        wait(ticks>=275);@(negedge clk);
        if(outputs<270||latches<270||limited_count<40||clip_count<5)
            $fatal(1,"DAC route %0d insufficient coverage outputs=%0d latches=%0d limited=%0d clips=%0d",ONBOARD,outputs,latches,limited_count,clip_count);
        $display("DAC route %0d PASS frames=%0d limited=%0d bypass_clips=%0d",ONBOARD,latches,limited_count,clip_count);
        done=1;
    end
    always @(posedge clk)if(dut.rst_n&&!done)begin
        if(dut.live_sample_tick)begin
            if(ticks>2&&frame_outputs!=1)$fatal(1,"DAC route %0d lost or duplicated a master output",ONBOARD);
            expected_frame=completed_pcm;frame_outputs=0;ticks=ticks+1;
        end
        if(dut.master_valid)begin
            completed_pcm=dut.output_pcm;outputs=outputs+1;frame_outputs=frame_outputs+1;
            if(dut.master_limited)limited_count=limited_count+1;
            if(dut.master_clipped)clip_count=clip_count+1;
        end
        if(latch&&ticks>2)begin
            #1;
            if(held_left!==expected_frame||held_right!==expected_frame)
                $fatal(1,"DAC route %0d frame %0d sample drift: L=%0d R=%0d expected=%0d",ONBOARD,ticks,held_left,held_right,expected_frame);
            latches=latches+1;
        end
    end
endmodule
module tb_gain_dac_timing;
    `include "sim/result.svh"
    GSR GSR(.GSRI(1'b1));
    reg clk=0;always #10 clk=~clk;
    wire onboard_done,i2s_done;
    gain_dac_timing_case #(.ONBOARD(1)) onboard(clk,onboard_done);
    gain_dac_timing_case #(.ONBOARD(0)) i2s(clk,i2s_done);
    initial begin
        wait(onboard_done&&i2s_done);complete_test("tb_gain_dac_timing",2);
        $display("PASS tb_gain_dac_timing onboard_and_i2s_fixed_frame=1");$finish;
    end
    initial begin #10000000;$fatal(1,"DAC timing timeout");end
endmodule
