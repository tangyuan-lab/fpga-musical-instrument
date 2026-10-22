`timescale 1ns/1ps
// 顶层并发检查：真实ADC/SPI、USB UART、屏幕UART、32声部和效果器。
// 视频厂商IP使用隔离桩；控制到声部的时间不冒充模拟输出延迟。
module tb_workstation_v2_full_load;
    reg clk=0,rst_n=0,usb_rx=1;always #10 clk=~clk;
    reg [191:0] values={16{12'd1095}};
    wire sclk,cs0,cs1,mosi,miso0,miso1,usb_tx,screen_tx;
    instrument_workstation_v2_top dut(.sys_clk(clk),.sys_rst_n(rst_n),.uart_rx_i(usb_rx),.uart_tx_o(usb_tx),
        .mode_key_n(1'b1),.timbre_key_n(1'b1),.screen_rx_i(1'b1),.screen_tx_o(screen_tx),
        .mcp0_sclk(sclk),.mcp0_mosi(mosi),.mcp0_cs_n(cs0),.mcp1_cs_n(cs1),.mcp0_miso(miso0),.mcp1_miso(miso1));
    defparam dut.key_matrix.CALIBRATION_SAMPLES=4;
    mcp3208_dynamic_model adc0(.cs_n(cs0),.sclk(sclk),.mosi(mosi),.values(values[95:0]),.miso(miso0));
    mcp3208_dynamic_model adc1(.cs_n(cs1),.sclk(sclk),.mosi(mosi),.values(values[191:96]),.miso(miso1));
    wire [7:0] usb_data,screen_data;wire usb_valid,screen_valid;
    uart_rx usb_monitor(.clk(clk),.rst_n(rst_n),.rx(usb_tx),.data(usb_data),.valid(usb_valid));
    uart_rx screen_monitor(.clk(clk),.rst_n(rst_n),.rx(screen_tx),.data(screen_data),.valid(screen_valid));
    integer log_file,samples=0,screen_bytes=0,i,j,matched;reg checking=0;
    time started,control_elapsed;
    always @(negedge clk) if(rst_n) begin
        if(usb_valid) $fwrite(log_file,"%02x\n",usb_data);
        if(screen_valid) screen_bytes=screen_bytes+1;
        if(checking && dut.live_sample_tick) begin
            samples=samples+1;
            if(dut.deadline_error || dut.engine.busy || dut.effects.state!=0) $fatal(1,"full top sample deadline missed");
            if(dut.voices!=32 || dut.voice_mask!==32'hffffffff) $fatal(1,"full top lost voices");
            if((^dut.effects_pcm)===1'bx) $fatal(1,"full top unknown audio");
        end
    end
    task usb_send(input [7:0] value);
        integer bit_index;begin
            @(negedge clk);usb_rx=0;repeat(434) @(negedge clk);
            for(bit_index=0;bit_index<8;bit_index=bit_index+1) begin usb_rx=value[bit_index];repeat(434) @(negedge clk);end
            usb_rx=1;repeat(434) @(negedge clk);
        end
    endtask
    function integer live_matches;
        integer slot;begin
            live_matches=0;
            for(slot=0;slot<32;slot=slot+1)
                if(dut.engine.active[slot] && dut.engine.gate[slot] && dut.engine.source[slot]==0 &&
                   (dut.engine.identity[slot]==0 || dut.engine.identity[slot]==13 || dut.engine.identity[slot]==14 || dut.engine.identity[slot]==15))
                    live_matches=live_matches+1;
        end
    endfunction
    initial begin
        log_file=$fopen("build/tests/workstation_v2_full_load_usb.hex","w");
        repeat(8) @(negedge clk);rst_n=1;wait(dut.calibrated);
        `include "workstation_v2_full_load_setup.svh"
        wait(dut.voices==32 && dut.voice_mask==32'hffffffff);
        repeat(4) @(posedge dut.live_sample_tick);@(negedge clk);checking=1;started=$time;
        values[0+:12]=1111;values[13*12+:12]=1111;values[14*12+:12]=1111;values[15*12+:12]=1111;
        fork:live_deadline
            begin while(live_matches()!=4) @(negedge clk);control_elapsed=$time-started;end
            begin #10_000_000;$fatal(1,"four live keys not allocated under full load");end
        join_any
        disable live_deadline;
        `include "workstation_v2_full_load_query.svh"
        repeat(500) @(posedge dut.live_sample_tick);
        if(live_matches()!=4 || screen_bytes<50 || samples<500) $fatal(1,"concurrent activity missing");
        if(dut.delay_mix!=64 || dut.reverb_mix!=64) $fatal(1,"effects not enabled through protocol");
        checking=0;
        `include "workstation_v2_full_load_emergency.svh"
        repeat(100) @(posedge dut.live_sample_tick);
        if(dut.voice_mask!=0 || dut.midi_playing || dut.player.test_running || dut.resources.uploading)
            $fatal(1,"USB emergency did not silence full top or held physical keys retriggered");
        `include "workstation_v2_full_load_after_stop.svh"
        repeat(400000) @(negedge clk);
        $fclose(log_file);
        $display("PASS tb_workstation_v2_full_load voices=32 live_keys=4 samples=%0d screen_bytes=%0d control_to_voice_ms=%0.6f",samples,screen_bytes,control_elapsed/1.0e6);$finish;
    end
    initial begin #100_000_000;$fatal(1,"full top load timeout");end
endmodule
