`timescale 1ns/1ps
`default_nettype none
// 控制协议/持续音变调/四频测试集成自检；采样节拍加速，不用于延迟指标。
module tb_screen_performance_controls;
    reg clk=0,rst_n=0,rx=1,tick=0;
    wire [15:0] touch,keys,on_pulse,off_pulse;
    wire [127:0] velocity;
    wire [1:0] octave;
    wire test_mode;
    wire [3:0] gates;
    wire [15:0] voice_keys;
    wire [127:0] steps;
    wire [51:0] levels;
    wire signed [15:0] pcm;
    reg [31:0] saved_phase;
    reg [12:0] saved_level;
    integer n,f;
    always #5 clk=~clk;
    screen_touch_keys_rx #(.KEY_COUNT(16),.CLKS_PER_BIT(4),.POLYPHONIC(1),
        .PERFORMANCE_CONTROLS(1),.WATCHDOG_CYCLES(3000)) receiver(
        .clk(clk),.rst_n(rst_n),.screen_rx_i(rx),.held_keys(touch),
        .octave_shift(octave),.test_mode(test_mode));
    live_touch_key_merge #(.KEY_COUNT(16)) merge(.clk(clk),.rst_n(rst_n),.live_enable(1'b1),
        .physical_keys(test_mode?16'h0891:16'd0),
        .physical_velocity(test_mode?{16{8'd176}}:128'd0),.touch_keys(test_mode?16'd0:touch),
        .held_keys(keys),.key_on_pulse(on_pulse),.key_off_pulse(off_pulse),.velocity_values(velocity));
    poly_synth_4voice #(.KEY_COUNT(16),.ADSR_ENABLE(1),.PIPELINE_INPUTS(1),.OCTAVE_CONTROL(1),.MIX_SHIFT(0)) synth(
        .clk(clk),.rst_n(rst_n),.sample_tick(tick),.timbre(1'b0),
        .octave_shift(test_mode?2'd0:octave),.key_on_pulse(on_pulse),.key_off_pulse(off_pulse),
        .velocity_values(velocity),.sample_out(pcm),.voice_gate(gates),.voice_keys(voice_keys),
        .voice_phase_steps(steps),.voice_levels(levels));
    task uart_byte(input [7:0] value);
        integer b;
        begin
            @(negedge clk);rx=0;repeat(4) @(negedge clk);
            for(b=0;b<8;b=b+1) begin rx=value[b];repeat(4) @(negedge clk);end
            rx=1;repeat(4) @(negedge clk);
        end
    endtask
    task send(input [7:0] op,input [7:0] value);
        begin
            uart_byte(8'ha5);uart_byte(8'h5a);uart_byte(op);uart_byte(value);uart_byte(8'hff^op^value);
            repeat(20) @(negedge clk);
        end
    endtask
    task sample;
        begin @(negedge clk);tick=1;@(negedge clk);tick=0;repeat(2) @(negedge clk);end
    endtask
    initial begin
        repeat(5) @(negedge clk);rst_n=1;
        send(1,0);repeat(100) sample();
        saved_phase=synth.voice_0.phase_acc;saved_level=levels[12:0];
        send(3,1);
        if(octave!=1 || steps[31:0]!=32'd46025656 || gates!=1 ||
           synth.voice_0.phase_acc!=saved_phase || levels[12:0]!=saved_level)
            $fatal(1,"octave-up lost continuous phase/envelope/gate");
        send(3,2);
        if(steps[31:0]!=32'd11506414 || synth.voice_0.phase_acc!=saved_phase)
            $fatal(1,"octave-down failed");
        send(3,3);
        if(octave!=2) $fatal(1,"invalid octave accepted");
        send(2,255);send(4,1);
        if(gates!=15 || voice_keys!=16'hb740 || steps!={32'd43442435,32'd34480283,32'd28994347,32'd23012828})
            $fatal(1,"four-frequency test allocation failed gates=%h notes=%h",gates,voice_keys);
        f=$fopen("build/tests/four_voice_test_samples.csv","w");
        if(f==0) $fatal(1,"cannot create test spectrum samples");
        for(n=0;n<4096;n=n+1) begin
            if(n%256==0) send(4,1);
            sample();$fdisplay(f,"%0d",pcm);
            if(gates!=15 || !test_mode) $fatal(1,"test heartbeat or concurrency failed");
        end
        $fclose(f);
        repeat(3001) @(negedge clk);
        if(test_mode) $fatal(1,"test watchdog did not expire");
        send(4,1);send(2,255);
        if(test_mode || octave!=0 || touch!=0) $fatal(1,"all-off did not clear performance state");
        repeat(200) sample();
        if(pcm!==0) $fatal(1,"test did not release to silence");
        $display("PASS tb_screen_performance_controls octave_continuity=PASS four_frequencies=PASS watchdog=PASS panic=PASS");
        $finish;
    end
    initial begin #5_000_000; $fatal(1,"performance controls test timeout");end
endmodule
`default_nettype wire
