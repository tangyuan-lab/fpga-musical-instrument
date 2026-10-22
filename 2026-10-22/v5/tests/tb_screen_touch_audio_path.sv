`timescale 1ns/1ps
`default_nettype none

// 不接 MCP3208：从屏幕 UART 引脚接收固定力度按键，经过实时输入合并，
// 使用实际四声部合成器验证频率、非零音频、释音和来源重叠。
module tb_screen_touch_audio_path;
    localparam integer KEY_COUNT = 13;
    localparam integer CLKS_PER_BIT = 16;
    localparam integer WATCHDOG_CYCLES = 12000;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg screen_rx_i = 1'b1;
    reg sample_tick = 1'b0;
    reg live_enable = 1'b1;
    reg [12:0] physical_keys = 13'd0;
    reg [103:0] physical_velocity = 104'd0;
    wire [12:0] touch_keys;
    wire [12:0] held_keys;
    wire [12:0] key_on_pulse;
    wire [12:0] key_off_pulse;
    wire [103:0] velocity_values;
    wire [3:0] active_key_count;
    wire signed [15:0] sample_out;
    wire [3:0] voice_gate;
    wire [3:0] voice_assigned;
    wire [15:0] voice_keys;
    wire [51:0] voice_levels;
    wire [127:0] voice_phase_steps;
    integer on_count = 0;
    integer off_count = 0;
    integer trigger_count = 0;
    integer saved_on_count;
    integer saved_off_count;
    integer saved_trigger_count;
    integer nonzero_count = 0;
    reg [31:0] saved_phase;

    always #10 clk = ~clk;
    screen_touch_keys_rx #(
        .CLKS_PER_BIT(CLKS_PER_BIT), .POLYPHONIC(1), .FRAME_TIMEOUT_CYCLES(480),
        .WATCHDOG_CYCLES(WATCHDOG_CYCLES)
    ) receiver (
        .clk(clk), .rst_n(rst_n), .screen_rx_i(screen_rx_i),
        .held_keys(touch_keys)
    );
    live_touch_key_merge #(.TOUCH_VELOCITY(8'd160)) input_merge (
        .clk(clk), .rst_n(rst_n), .live_enable(live_enable),
        .physical_keys(physical_keys), .physical_velocity(physical_velocity),
        .touch_keys(touch_keys), .held_keys(held_keys),
        .key_on_pulse(key_on_pulse), .key_off_pulse(key_off_pulse),
        .velocity_values(velocity_values), .active_key_count(active_key_count)
    );
    poly_synth_4voice #(.MIX_SHIFT(0)) synth (
        .clk(clk), .rst_n(rst_n), .sample_tick(sample_tick), .timbre(1'b0),
        .key_on_pulse(key_on_pulse), .key_off_pulse(key_off_pulse),
        .velocity_values(velocity_values), .sample_out(sample_out),
        .voice_gate(voice_gate), .voice_assigned(voice_assigned),
        .voice_keys(voice_keys), .voice_levels(voice_levels),
        .voice_phase_steps(voice_phase_steps)
    );

    // 合并器边沿为组合输出，实体输入在负边沿驱动；在消费事件的正边沿
    // 计数，避免测试监视器与负边沿驱动同时执行造成事件计数竞争。
    always @(posedge clk) begin
        if (rst_n) begin
            if (|key_on_pulse) begin
                on_count = on_count + 1;
            end
            if (|key_off_pulse) begin
                off_count = off_count + 1;
            end
            if (|synth.voice_trigger) begin
                trigger_count = trigger_count + 1;
            end
        end
    end

    task automatic send_byte(input [7:0] value);
        integer bit_index;
        begin
            @(negedge clk);
            screen_rx_i = 1'b0;
            repeat (CLKS_PER_BIT) @(negedge clk);
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                screen_rx_i = value[bit_index];
                repeat (CLKS_PER_BIT) @(negedge clk);
            end
            screen_rx_i = 1'b1;
            repeat (CLKS_PER_BIT) @(negedge clk);
        end
    endtask

    task automatic send_frame(input [7:0] operation, input [7:0] note);
        begin
            send_byte(8'ha5);
            send_byte(8'h5a);
            send_byte(operation);
            send_byte(note);
            send_byte(8'hff ^ operation ^ note);
            // 给合并边沿、声部分配和 retrigger 留足流水线时间。
            repeat (12) @(negedge clk);
        end
    endtask

    task automatic next_audio_sample;
        begin
            @(negedge clk);
            sample_tick = 1'b1;
            @(negedge clk);
            sample_tick = 1'b0;
            repeat (3) @(negedge clk);
            if (sample_out != 16'sd0) begin
                nonzero_count = nonzero_count + 1;
            end
        end
    endtask

    task automatic expect_note(input [3:0] note, input [31:0] phase_step);
        begin
            if (voice_gate !== 4'b0001 || voice_keys[3:0] !== note ||
                voice_phase_steps[31:0] !== phase_step || active_key_count !== 4'd1) begin
                $fatal(1, "note mapping note=%0d gates=%b keys=%h step=%0d active=%0d",
                       note, voice_gate, voice_keys, voice_phase_steps[31:0], active_key_count);
            end
            saved_phase = synth.voice_0.phase_acc;
            next_audio_sample();
            if (synth.voice_0.phase_acc !== saved_phase + phase_step) begin
                $fatal(1, "phase did not advance by note frequency step");
            end
        end
    endtask

    task automatic expect_silence;
        begin
            repeat (270) next_audio_sample();
            repeat (5) @(negedge clk);
            if (voice_gate !== 4'd0 || voice_assigned !== 4'd0 ||
                voice_levels !== 52'd0 || sample_out !== 16'sd0) begin
                $fatal(1, "release failed gates=%b assigned=%b levels=%h sample=%0d",
                       voice_gate, voice_assigned, voice_levels, sample_out);
            end
        end
    endtask

    initial begin
        repeat (5) @(negedge clk);
        rst_n = 1'b1;
        repeat (5) @(negedge clk);
        // 没有实体键、实体力度全零，屏幕 C4 仍产生固定力度与实际声音。
        send_frame(8'h01, 8'd0);
        expect_note(4'd0, 32'd23_012_828);
        if (physical_keys !== 13'd0 || physical_velocity !== 104'd0 ||
            velocity_values[7:0] !== 8'd160) begin
            $fatal(1, "touch C4 depends on ADC or has wrong fixed velocity");
        end
        repeat (160) next_audio_sample();
        if (voice_levels[12:0] !== 13'd2560 || nonzero_count < 120) begin
            $fatal(1, "touch C4 missing actual samples/level nonzero=%0d level=%0d gate=%b held=%h velocity=%h target=%0d trigger=%b counts=%0d/%0d",
                   nonzero_count, voice_levels[12:0], voice_gate, held_keys, velocity_values,
                   synth.target_level_0, synth.voice_trigger, on_count, trigger_count);
        end
        saved_on_count = on_count;
        saved_trigger_count = trigger_count;
        repeat (WATCHDOG_CYCLES / 2) @(negedge clk);
        send_frame(8'h01, 8'd0);
        repeat (WATCHDOG_CYCLES / 2) @(negedge clk);
        if (voice_gate !== 4'b0001 || on_count != saved_on_count ||
            trigger_count != saved_trigger_count || voice_levels[12:0] !== 13'd2560) begin
            $fatal(1, "heartbeat retriggered envelope or did not extend hold");
        end
        send_frame(8'h00, 8'd0);
        if (voice_gate !== 4'd0 || active_key_count !== 4'd0) begin
            $fatal(1, "touch release did not close gate");
        end
        expect_silence();

        // A4=440 Hz 的实际相位步进，不仅检查屏幕文本键号。
        send_frame(8'h01, 8'd9);
        expect_note(4'd9, 32'd38_702_809);
        if (velocity_values[9*8 +: 8] !== 8'd160) begin
            $fatal(1, "touch A4 fixed velocity incorrect");
        end
        repeat (100) next_audio_sample();
        send_frame(8'h00, 8'd9);
        expect_silence();

        // 同音双来源不重复起音：较小实体力度被160覆盖，较大实体力度保留。
        @(negedge clk);
        physical_keys[0] = 1'b1;
        physical_velocity[7:0] = 8'd80;
        repeat (12) @(negedge clk);
        expect_note(4'd0, 32'd23_012_828);
        saved_on_count = on_count;
        saved_trigger_count = trigger_count;
        send_frame(8'h01, 8'd0);
        if (on_count != saved_on_count || trigger_count != saved_trigger_count ||
            velocity_values[7:0] !== 8'd160 || active_key_count !== 4'd1) begin
            $fatal(1, "overlapping touch retriggered note or wrong max velocity");
        end
        @(negedge clk);
        physical_velocity[7:0] = 8'd220;
        repeat (2) @(negedge clk);
        if (velocity_values[7:0] !== 8'd220) begin
            $fatal(1, "higher physical velocity was not preserved");
        end
        repeat (160) next_audio_sample();
        if (voice_levels[12:0] !== 13'd3520) begin
            $fatal(1, "higher physical velocity did not reach envelope");
        end
        saved_off_count = off_count;
        send_frame(8'h00, 8'd0);
        if (voice_gate !== 4'b0001 || held_keys[0] !== 1'b1 ||
            off_count != saved_off_count || velocity_values[7:0] !== 8'd220) begin
            $fatal(1, "touch release cut still-held physical note");
        end
        @(negedge clk);
        physical_keys[0] = 1'b0;
        physical_velocity[7:0] = 8'd0;
        repeat (12) @(negedge clk);
        if (voice_gate !== 4'd0 || off_count != saved_off_count + 1) begin
            $fatal(1, "last physical release failed note off");
        end
        expect_silence();

        // 丢失松开事件后，watchdog 自动关闭声音并走完释音包络。
        send_frame(8'h01, 8'd0);
        repeat (100) next_audio_sample();
        repeat (WATCHDOG_CYCLES + 20) @(negedge clk);
        if (touch_keys !== 13'd0 || held_keys !== 13'd0 || voice_gate !== 4'd0) begin
            $fatal(1, "watchdog did not stop screen note");
        end
        expect_silence();

        // C 大三和弦与 Cmaj7：逐键 ON 必须保留先前声部，每键 OFF 只释放本键。
        send_frame(8'h01, 8'd0);
        send_frame(8'h01, 8'd4);
        send_frame(8'h01, 8'd7);
        repeat (20) next_audio_sample();
        if (held_keys !== 13'h091 || active_key_count !== 4'd3 || voice_gate !== 4'b0111) begin
            $fatal(1, "C major chord lost a key held=%h voices=%b", held_keys, voice_gate);
        end
        if (voice_keys[11:0] !== 12'h740) begin
            $fatal(1, "C major chord voice allocation wrong: %h", voice_keys);
        end
        send_frame(8'h01, 8'd11);
        repeat (100) next_audio_sample();
        if (held_keys !== 13'h891 || active_key_count !== 4'd4 || voice_gate !== 4'b1111 ||
            voice_keys !== 16'hb740 || voice_levels !== {4{13'd2560}}) begin
            $fatal(1, "Cmaj7 four-voice chord failed held=%h voices=%b levels=%h", held_keys, voice_gate, voice_levels);
        end
        saved_trigger_count = trigger_count;
        send_frame(8'h01, 8'd4);
        if (trigger_count != saved_trigger_count || voice_gate !== 4'b1111) begin
            $fatal(1, "polyphonic heartbeat retriggered chord");
        end
        send_frame(8'h00, 8'd4);
        if (held_keys !== 13'h881 || active_key_count !== 4'd3 || voice_gate !== 4'b1101) begin
            $fatal(1, "E4 release cut other chord notes");
        end
        send_frame(8'h02, 8'hff);
        expect_silence();

        // 每键独立失联：只给 E4 保活，C4 应超时，E4 应继续保持。
        send_frame(8'h01, 8'd0);
        send_frame(8'h01, 8'd4);
        repeat (WATCHDOG_CYCLES / 2) @(negedge clk);
        send_frame(8'h01, 8'd4);
        repeat (WATCHDOG_CYCLES / 2) @(negedge clk);
        if (touch_keys !== 13'h010) begin
            $fatal(1, "per-key watchdog failed: %h", touch_keys);
        end
        send_frame(8'h02, 8'hff);
        expect_silence();

        // MIDI/关闭实时模式时，即便收到合法屏幕 ON，也不分配声部。
        @(negedge clk);
        live_enable = 1'b0;
        saved_on_count = on_count;
        saved_trigger_count = trigger_count;
        send_frame(8'h01, 8'd9);
        repeat (160) next_audio_sample();
        if (touch_keys[9] !== 1'b1 || held_keys !== 13'd0 || active_key_count !== 4'd0 ||
            velocity_values !== 104'd0 || on_count != saved_on_count ||
            trigger_count != saved_trigger_count || voice_gate !== 4'd0 || sample_out !== 16'sd0) begin
            $fatal(1, "disabled LIVE path produced audio");
        end
        send_frame(8'h02, 8'hff);
        $display("PASS tb_screen_touch_audio_path C4=PASS A4=PASS nonzero=%0d heartbeat=PASS merge=PASS watchdog=PASS chord=PASS per_key_timeout=PASS disabled=PASS",
                 nonzero_count);
        $finish;
    end

    initial begin
        #5_000_000;
        $fatal(1, "test timeout");
    end
endmodule

`default_nettype wire
