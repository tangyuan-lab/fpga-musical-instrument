`timescale 1ns/1ps
`default_nettype none
// 实际 50 MHz / 1 MHz SPI / 115200 UART / 48.828 kHz 音频，不缩放时间。
// 测量数字传感器输入或 UART 首位开始，到引脚解码出第一个非零样本。
// 不包含屏幕触摸扫描、模拟传感器响应、DAC/功放模拟延迟；这些必须上板测量。
module tb_instrument_latency;
    reg clk=0,rst_n=0,rx=1;
    reg [191:0] analog_values={16{12'd3000}};
    wire sclk,mosi,cs0,cs1,miso0,miso1,frame,ready,fault;
    wire [95:0] adc0,adc1;
    wire [191:0] pressure;
    wire [127:0] physical_velocity,velocity;
    wire [15:0] physical_keys,touch_keys,keys,on_pulse,off_pulse;
    wire calibrated;
    wire [4:0] active;
    wire signed [15:0] audio;
    wire tick,pt_bck,pt_ws,pt_din,i2s_bck,i2s_ws,i2s_din;
    reg prev_pt_ws=0,prev_i2s_ws=1;
    reg [15:0] pt_word=0,i2s_word=0;
    integer pt_pos=0,i2s_pos=0,case_index,key;
    time last_pt_nonzero=0,last_i2s_nonzero=0,start_time,pt_elapsed,i2s_elapsed,max_physical=0,max_uart=0;
    always #10 clk=~clk;
    mcp3208_dual_scan scan(.clk(clk),.rst_n(rst_n),.mcp0_miso(miso0),.mcp1_miso(miso1),
        .mcp_sclk(sclk),.mcp_mosi(mosi),.mcp0_cs_n(cs0),.mcp1_cs_n(cs1),
        .samples0(adc0),.samples1(adc1),.frame_valid(frame),.ready(ready),.fault(fault));
    mcp3208_dynamic_model model0(.cs_n(cs0),.sclk(sclk),.mosi(mosi),.values(analog_values[95:0]),.miso(miso0));
    mcp3208_dynamic_model model1(.cs_n(cs1),.sclk(sclk),.mosi(mosi),.values(analog_values[191:96]),.miso(miso1));
    // 缩短启动标定次数；进入稳态后的扫描/滤波/音源参数全部保持板上默认值。
    pressure_key_matrix #(.KEY_COUNT(16),.CALIBRATION_SAMPLES(4)) matrix(.clk(clk),.rst_n(rst_n),.adc_ready(ready),
        .sample_frame_valid(frame),.adc_samples({adc1,adc0}),.calibrated(calibrated),
        .pressure_values(pressure),.velocity_values(physical_velocity),.key_down(physical_keys));
    screen_touch_keys_rx #(.KEY_COUNT(16),.POLYPHONIC(1)) receiver(
        .clk(clk),.rst_n(rst_n),.screen_rx_i(rx),.held_keys(touch_keys));
    live_touch_key_merge #(.KEY_COUNT(16)) merge(.clk(clk),.rst_n(rst_n),.live_enable(1'b1),
        .physical_keys(physical_keys),.physical_velocity(physical_velocity),.touch_keys(touch_keys),
        .held_keys(keys),.key_on_pulse(on_pulse),.key_off_pulse(off_pulse),.velocity_values(velocity),.active_key_count(active));
    poly_synth_4voice #(.KEY_COUNT(16),.MIX_SHIFT(0),.ADSR_ENABLE(1),.PIPELINE_INPUTS(1),.OCTAVE_CONTROL(1)) synth(
        .clk(clk),.rst_n(rst_n),.sample_tick(tick),.timbre(1'b0),.octave_shift(2'd0),.key_on_pulse(on_pulse),
        .key_off_pulse(off_pulse),.velocity_values(velocity),.sample_out(audio));
    pt8211_tx pt(.clk(clk),.rst_n(rst_n),.sample_left(audio),.sample_right(audio),
        .sample_tick(tick),.hp_bck(pt_bck),.hp_ws(pt_ws),.hp_din(pt_din));
    i2s_tx standard(.clk(clk),.rst_n(rst_n),.sample_left(audio),.sample_right(audio),
        .hp_bck(i2s_bck),.hp_ws(i2s_ws),.hp_din(i2s_din));
    always @(posedge pt_bck) if(rst_n) begin
        if(pt_ws!=prev_pt_ws) begin pt_pos=0;prev_pt_ws=pt_ws;end
        pt_word={pt_word[14:0],pt_din};
        if(pt_pos==15) begin if(pt_word!=0) last_pt_nonzero=$time; pt_pos=0;end
        else pt_pos=pt_pos+1;
    end
    always @(posedge i2s_bck) if(rst_n) begin
        if(i2s_ws!=prev_i2s_ws) begin i2s_pos=0; prev_i2s_ws=i2s_ws;end
        else i2s_pos=i2s_pos+1;
        if(i2s_pos>=1 && i2s_pos<=16) i2s_word={i2s_word[14:0],i2s_din};
        if(i2s_pos==16 && i2s_word!=0) last_i2s_nonzero=$time;
    end
    task measure;
        begin
            fork : deadline
                begin
                    wait(last_pt_nonzero>start_time && last_i2s_nonzero>start_time);
                end
                begin
                    #10_000_001;
                    $fatal(1,"no output within 10ms key=%0d calibrated=%b keys=%h pressure=%d audio=%d",key,calibrated,keys,pressure[key*12+:12],audio);
                end
            join_any
            disable deadline;
            pt_elapsed=last_pt_nonzero-start_time; i2s_elapsed=last_i2s_nonzero-start_time;
            if(pt_elapsed>10_000_000 || i2s_elapsed>10_000_000) $fatal(1,"control-to-output >10ms");
            $display("LATENCY case=%0d key=%0d pt_ms=%0.6f i2s_ms=%0.6f",case_index,key,pt_elapsed/1.0e6,i2s_elapsed/1.0e6);
        end
    endtask
    task settle;
        begin
            analog_values={16{12'd3000}};
            repeat(8) @(posedge frame);
            repeat(16) @(posedge tick);
            if(audio!==0 || keys!==0) $fatal(1,"did not settle silent");
        end
    endtask
    task uart_byte(input [7:0] value);
        integer b;
        begin
            @(negedge clk);rx=0; repeat(434) @(negedge clk);
            for(b=0;b<8;b=b+1) begin rx=value[b];repeat(434) @(negedge clk);end
            rx=1;repeat(434) @(negedge clk);
        end
    endtask
    task uart_frame(input [7:0] op,input [7:0] note);
        begin uart_byte(8'ha5);uart_byte(8'h5a);uart_byte(op);uart_byte(note);uart_byte(8'hff^op^note);end
    endtask
    initial begin
        repeat(5) @(negedge clk);rst_n=1;
        wait(calibrated);
        $display("CALIBRATED t_ms=%0.6f baseline0=%0d",$time/1.0e6,matrix.baseline_reg[0]);
        settle();
        $display("CALIBRATED steady-state latency test starts");
        // SPI 不同相位、首/末片新增键、最轻有效按压；UART 使用固定触摸力度。
        for(case_index=0;case_index<4;case_index=case_index+1) begin
            key=(case_index%4==0)?0:12+case_index%4;
            @(posedge frame);repeat(1100+case_index*3500) @(negedge clk);
            start_time=$time;
            analog_values[key*12+:12]=12'd2984;
            measure();
            if(pt_elapsed>max_physical) max_physical=pt_elapsed;
            if(i2s_elapsed>max_physical) max_physical=i2s_elapsed;
            settle();
        end
        for(case_index=4;case_index<6;case_index=case_index+1) begin
            key=(case_index==4)?0:15;
            @(negedge clk);start_time=$time;
            uart_frame(1,key);measure();
            if(pt_elapsed>max_uart) max_uart=pt_elapsed;
            if(i2s_elapsed>max_uart) max_uart=i2s_elapsed;
            uart_frame(0,key);settle();
        end
        $display("PASS tb_instrument_latency physical_max_ms=%0.6f uart_max_ms=%0.6f adc=1MHz uart=115200 fs=48828.125Hz cases=6",max_physical/1.0e6,max_uart/1.0e6);
        $finish;
    end
    initial begin #100_000_000; $fatal(1,"latency test timeout");end
endmodule
`default_nettype wire
