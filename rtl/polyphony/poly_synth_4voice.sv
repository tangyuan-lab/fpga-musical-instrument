`timescale 1ns/1ps
`default_nettype none

// 13 键、四声部、12 平均律三角波合成器。
// 键号 0～12 对应 C4、C#4、D4、D#4、E4、F4、F#4、G4、G#4、A4、A#4、B4、C5。
// phase_step 表按 50 MHz/1024 = 48.828125 kHz 采样率计算。
module poly_synth_4voice #(
    parameter integer KEY_COUNT  = 13,
    parameter integer MIX_SHIFT  = 1,
    parameter [12:0] ATTACK_STEP = 13'd32,
    parameter [12:0] RELEASE_STEP = 13'd16
) (
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire                         sample_tick,
    input  wire                         timbre,
    input  wire [KEY_COUNT-1:0]         key_on_pulse,
    input  wire [KEY_COUNT-1:0]         key_off_pulse,
    input  wire [KEY_COUNT*8-1:0]       velocity_values,
    output reg  signed [15:0]           sample_out,
    output wire [3:0]                   voice_gate,
    output wire [3:0]                   voice_assigned,
    output wire [15:0]                  voice_keys,
    output wire [51:0]                  voice_levels,
    output wire [31:0]                  timbre_blends,
    output wire [127:0]                 voice_phase_steps
);
    // 四个固定声部对第一次上板测试够用，而且让
    // "压力到声音"这条链路在波形窗口里容易看。
    wire [3:0] voice_trigger;
    wire [3:0] voice_idle_raw;
    reg  [3:0] voice_idle_registered;
    wire [31:0] phase_step_0;
    wire [31:0] phase_step_1;
    wire [31:0] phase_step_2;
    wire [31:0] phase_step_3;
    wire [12:0] target_level_0;
    wire [12:0] target_level_1;
    wire [12:0] target_level_2;
    wire [12:0] target_level_3;
    wire [12:0] current_level_0;
    wire [12:0] current_level_1;
    wire [12:0] current_level_2;
    wire [12:0] current_level_3;
    wire [7:0] timbre_blend_0;
    wire [7:0] timbre_blend_1;
    wire [7:0] timbre_blend_2;
    wire [7:0] timbre_blend_3;
    wire signed [15:0] sample_0;
    wire signed [15:0] sample_1;
    wire signed [15:0] sample_2;
    wire signed [15:0] sample_3;
    wire signed [17:0] sample_ext_0;
    wire signed [17:0] sample_ext_1;
    wire signed [17:0] sample_ext_2;
    wire signed [17:0] sample_ext_3;
    wire signed [17:0] mix_sum;
    wire signed [17:0] mix_scaled;

    function automatic [31:0] note_phase_step;
        input [3:0] key_number;
        begin
            case (key_number)
                4'd0:  note_phase_step = 32'd23_012_828; // C4
                4'd1:  note_phase_step = 32'd24_381_242; // C#4
                4'd2:  note_phase_step = 32'd25_831_026; // D4
                4'd3:  note_phase_step = 32'd27_367_019; // D#4
                4'd4:  note_phase_step = 32'd28_994_347; // E4
                4'd5:  note_phase_step = 32'd30_718_440; // F4
                4'd6:  note_phase_step = 32'd32_545_054; // F#4
                4'd7:  note_phase_step = 32'd34_480_283; // G4
                4'd8:  note_phase_step = 32'd36_530_588; // G#4
                4'd9:  note_phase_step = 32'd38_702_809; // A4 = 440 Hz
                4'd10: note_phase_step = 32'd41_004_198; // A#4
                4'd11: note_phase_step = 32'd43_442_435; // B4
                4'd12: note_phase_step = 32'd46_025_656; // C5
                default: note_phase_step = 32'd0;
            endcase
        end
    endfunction

    function automatic [7:0] key_velocity;
        input [3:0] key_number;
        begin
            if (key_number < KEY_COUNT)
                key_velocity = velocity_values[key_number*8 +: 8];
            else
                key_velocity = 8'd0;
        end
    endfunction

    voice_allocator_4 #(.KEY_COUNT(KEY_COUNT)) allocator (
        .clk(clk),
        .rst_n(rst_n),
        .key_on_pulse(key_on_pulse),
        .key_off_pulse(key_off_pulse),
        .voice_idle(voice_idle_registered),
        .voice_gate(voice_gate),
        .voice_assigned(voice_assigned),
        .voice_trigger(voice_trigger),
        .voice_keys(voice_keys)
    );

    assign phase_step_0 = note_phase_step(voice_keys[3:0]);
    assign phase_step_1 = note_phase_step(voice_keys[7:4]);
    assign phase_step_2 = note_phase_step(voice_keys[11:8]);
    assign phase_step_3 = note_phase_step(voice_keys[15:12]);
    assign voice_phase_steps = {phase_step_3, phase_step_2, phase_step_1, phase_step_0};

    // 8 bit 力度左移 4 位得到 0～4080，保持与当前单音工程相同的安全幅度范围。
    assign target_level_0 = {1'b0, key_velocity(voice_keys[3:0]), 4'b0000};
    assign target_level_1 = {1'b0, key_velocity(voice_keys[7:4]), 4'b0000};
    assign target_level_2 = {1'b0, key_velocity(voice_keys[11:8]), 4'b0000};
    assign target_level_3 = {1'b0, key_velocity(voice_keys[15:12]), 4'b0000};

    poly_synth_voice #(.ATTACK_STEP(ATTACK_STEP), .RELEASE_STEP(RELEASE_STEP)) voice_0 (
        .clk(clk), .rst_n(rst_n), .sample_tick(sample_tick),
        .gate(voice_gate[0]), .retrigger(voice_trigger[0]), .timbre(timbre),
        .phase_step(phase_step_0), .target_level(target_level_0),
        .sample_out(sample_0), .current_level(current_level_0),
        .timbre_blend(timbre_blend_0), .idle(voice_idle_raw[0])
    );
    poly_synth_voice #(.ATTACK_STEP(ATTACK_STEP), .RELEASE_STEP(RELEASE_STEP)) voice_1 (
        .clk(clk), .rst_n(rst_n), .sample_tick(sample_tick),
        .gate(voice_gate[1]), .retrigger(voice_trigger[1]), .timbre(timbre),
        .phase_step(phase_step_1), .target_level(target_level_1),
        .sample_out(sample_1), .current_level(current_level_1),
        .timbre_blend(timbre_blend_1), .idle(voice_idle_raw[1])
    );
    poly_synth_voice #(.ATTACK_STEP(ATTACK_STEP), .RELEASE_STEP(RELEASE_STEP)) voice_2 (
        .clk(clk), .rst_n(rst_n), .sample_tick(sample_tick),
        .gate(voice_gate[2]), .retrigger(voice_trigger[2]), .timbre(timbre),
        .phase_step(phase_step_2), .target_level(target_level_2),
        .sample_out(sample_2), .current_level(current_level_2),
        .timbre_blend(timbre_blend_2), .idle(voice_idle_raw[2])
    );
    poly_synth_voice #(.ATTACK_STEP(ATTACK_STEP), .RELEASE_STEP(RELEASE_STEP)) voice_3 (
        .clk(clk), .rst_n(rst_n), .sample_tick(sample_tick),
        .gate(voice_gate[3]), .retrigger(voice_trigger[3]), .timbre(timbre),
        .phase_step(phase_step_3), .target_level(target_level_3),
        .sample_out(sample_3), .current_level(current_level_3),
        .timbre_blend(timbre_blend_3), .idle(voice_idle_raw[3])
    );

    // 把包络空闲状态寄存一次，切断包络比较器到事件分配器的长组合路径。
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            voice_idle_registered <= 4'b1111;
        else
            voice_idle_registered <= voice_idle_raw;
    end

    assign voice_levels = {current_level_3, current_level_2, current_level_1, current_level_0};
    assign timbre_blends = {timbre_blend_3, timbre_blend_2, timbre_blend_1, timbre_blend_0};
    assign sample_ext_0 = {{2{sample_0[15]}}, sample_0};
    assign sample_ext_1 = {{2{sample_1[15]}}, sample_1};
    assign sample_ext_2 = {{2{sample_2[15]}}, sample_2};
    assign sample_ext_3 = {{2{sample_3[15]}}, sample_3};
    assign mix_sum = sample_ext_0 + sample_ext_1 + sample_ext_2 + sample_ext_3;
    assign mix_scaled = mix_sum >>> MIX_SHIFT;

    // 饱和处理保证任何参数调整或极端同相叠加都不会发生二进制回绕爆音。
    always @(*) begin
        if (mix_scaled > 18'sd32767)
            sample_out = 16'sh7fff;
        else if (mix_scaled < -18'sd32768)
            sample_out = -16'sd32768;
        else
            sample_out = mix_scaled[15:0];
    end
endmodule

`default_nettype wire

