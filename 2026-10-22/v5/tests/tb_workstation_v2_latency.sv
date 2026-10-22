`timescale 1ns/1ps
// 实际V2顶层、50MHz、SPI1MHz、UART115200、I2S48.828125kHz。
// 仅标定帧数缩为4；HDMI厂商IP用隔离桩，不参与音频延迟判断。
module tb_workstation_v2_latency;
    reg clk=0,rst_n=0,rx=1;always #10 clk=~clk;
    localparam [191:0] IDLE={16{12'd1095}};
    reg [191:0] values=IDLE;wire sclk,cs0,cs1,mosi,miso0,miso1,bck,ws,din;
    instrument_workstation_v2_top dut(.sys_clk(clk),.sys_rst_n(rst_n),.uart_rx_i(1'b1),.mode_key_n(1'b1),.timbre_key_n(1'b1),
        .screen_rx_i(rx),.mcp0_sclk(sclk),.mcp0_mosi(mosi),.mcp0_cs_n(cs0),.mcp1_cs_n(cs1),.mcp0_miso(miso0),.mcp1_miso(miso1),
        .hp_bck(bck),.hp_ws(ws),.hp_din(din));
    defparam dut.key_matrix.CALIBRATION_SAMPLES=4;
    mcp3208_dynamic_model adc0(.cs_n(cs0),.sclk(sclk),.mosi(mosi),.values(values[95:0]),.miso(miso0));
    mcp3208_dynamic_model adc1(.cs_n(cs1),.sclk(sclk),.mosi(mosi),.values(values[191:96]),.miso(miso1));
    reg previous_ws=1;reg [15:0] word_value=0;integer bit_position=0;
    time last_nonzero=0,started,elapsed,physical_max=0,uart_max=0;
    integer case_index,key;
    always @(posedge bck) if(rst_n) begin
        if(ws!=previous_ws) begin bit_position=0;previous_ws=ws;end
        else bit_position=bit_position+1;
        if(bit_position>=1 && bit_position<=16) word_value={word_value[14:0],din};
        if(bit_position==16 && word_value!=0) last_nonzero=$time;
    end
    task byte_send(input [7:0] value);
        integer b;begin
            @(negedge clk);rx=0;repeat(434) @(negedge clk);
            for(b=0;b<8;b=b+1) begin rx=value[b];repeat(434) @(negedge clk);end
            rx=1;repeat(434) @(negedge clk);
        end
    endtask
    task frame(input [7:0] op,input [7:0] value);
        begin byte_send(8'ha5);byte_send(8'h5a);byte_send(op);byte_send(value);byte_send(8'hff^op^value);end
    endtask
    task settle;
        begin values=IDLE;
            // 等待真实滤波和ADSR释音完成，不额外消耗固定300个静音采样周期。
            fork:release_deadline
                begin wait(dut.key_down==0 && dut.voice_mask==0 && dut.effects_pcm===0);end
                begin #10_000_000;$fatal(1,"release failed to settle");end
            join_any
            disable release_deadline;
            repeat(3) @(posedge dut.live_sample_tick); // 排空效果器及I2S上一帧快照。
        end
    endtask
    task measure;
        begin
            fork:deadline
                begin wait(last_nonzero>started);end
                begin #10_000_001;
                    $display("DIAG input=%h applied=%h active=%h mode=%d panic=%b patch=%d note0=%d velocity0=%d env0=%d phase0=%h synth=%d dry=%d",dut.input_keys,dut.applied,dut.voice_mask,dut.app_mode,dut.synth_panic,dut.live_patch,dut.engine.note[0],dut.engine.velocity[0],dut.engine.envelope[0],dut.engine.phase[0],dut.synth_pcm,dut.dry_pcm);
                    $fatal(1,"V2 >10ms keys=%h pcm=%d vel=%h",dut.key_down,dut.effects_pcm,dut.velocity_values);end
            join_any
            disable deadline;
            elapsed=last_nonzero-started;
            $display("V2_LATENCY case=%0d key=%0d ms=%0.6f",case_index,key,elapsed/1.0e6);
        end
    endtask
    initial begin
        repeat(8) @(negedge clk);rst_n=1;frame(5,2);wait(dut.calibrated);settle();
        for(case_index=0;case_index<4;case_index=case_index+1) begin
            key=case_index==0 ? 0:12+case_index;
            @(posedge dut.sample_frame_valid);repeat(1100+case_index*3500) @(negedge clk);
            started=$time;values[key*12+:12]=1111;measure();
            if(elapsed>physical_max) physical_max=elapsed;settle();
        end
        for(case_index=4;case_index<6;case_index=case_index+1) begin
            key=case_index==4 ? 0:15;@(negedge clk);started=$time;frame(1,key);measure();
            if(elapsed>uart_max) uart_max=elapsed;frame(0,key);settle();
        end
        if(dut.deadline_error) $fatal(1,"sample compute deadline missed");
        $display("PASS tb_workstation_v2_latency physical_max_ms=%0.6f uart_max_ms=%0.6f cases=6",physical_max/1.0e6,uart_max/1.0e6);$finish;
    end
    initial begin #120_000_000;$fatal(1,"V2 latency simulation timeout");end
endmodule
