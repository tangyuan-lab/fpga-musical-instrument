`timescale 1ns/1ps
`default_nettype none

// 可配置 13/16 键、四声部、12 平均律三角波合成器。
// 键号 0～15 对应 C4～D#5 的连续半音；默认 13 键保留旧工程行为。
// phase_step 表按 50 MHz/1024 = 48.828125 kHz 采样率计算。
module poly_synth_4voice #(
    parameter integer KEY_COUNT  = 13,
    parameter integer MIX_SHIFT  = 1,
    parameter integer ADSR_ENABLE = 0,
    parameter integer PIPELINE_INPUTS = 0,
    parameter integer OCTAVE_CONTROL = 0,
    parameter integer PER_KEY_SOUND = 0,
    parameter [12:0] ATTACK_STEP = 13'd32,
    parameter [12:0] DECAY_STEP = 13'd8,
    parameter integer SUSTAIN_DROP_SHIFT = 2,
    parameter [12:0] RELEASE_STEP = 13'd16
) (
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire                         sample_tick,
    input  wire                         timbre,
    input  wire [1:0]                   octave_shift,
    input  wire [KEY_COUNT-1:0]         key_on_pulse,
    input  wire [KEY_COUNT-1:0]         key_off_pulse,
    input  wire [KEY_COUNT*8-1:0]       velocity_values,
    input  wire [KEY_COUNT*8-1:0]       key_notes,
    input  wire [KEY_COUNT*6-1:0]       key_timbres,
    output reg  signed [15:0]           sample_out,
    output wire [3:0]                   voice_gate,
    output wire [3:0]                   voice_assigned,
    output wire [15:0]                  voice_keys,
    output wire [51:0]                  voice_levels,
    output wire [31:0]                  timbre_blends,
    output wire [127:0]                 voice_phase_steps
);
    wire [3:0] voice_trigger;
    wire [3:0] voice_idle_raw;
    reg  [3:0] voice_idle_registered;
    wire [31:0] phase_step_0;
    wire [31:0] phase_step_1;
    wire [31:0] phase_step_2;
    wire [31:0] phase_step_3;
    reg [31:0] transposed_step [0:3];
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
    reg [KEY_COUNT-1:0] key_on_q, key_off_q;
    reg [12:0] target_level_q0, target_level_q1, target_level_q2, target_level_q3;
    wire [12:0] target_raw_0, target_raw_1, target_raw_2, target_raw_3;
    // 把输入模式门控与 16 键优先编码分开；每级只增加一个 20 ns 系统周期。
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key_on_q <= {KEY_COUNT{1'b0}};
            key_off_q <= {KEY_COUNT{1'b0}};
        end else begin
            key_on_q <= key_on_pulse;
            key_off_q <= key_off_pulse;
        end
    end

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
                4'd13: note_phase_step = 32'd48_762_484; // C#5
                4'd14: note_phase_step = 32'd51_662_052; // D5
                4'd15: note_phase_step = 32'd54_734_038; // D#5
                default: note_phase_step = 32'd0;
            endcase
        end
    endfunction

    function automatic [7:0] key_velocity;
        input [3:0] key_number;
        input [KEY_COUNT*8-1:0] values;
        begin
            if (key_number < KEY_COUNT)
                key_velocity = values[key_number*8 +: 8];
            else
                key_velocity = 8'd0;
        end
    endfunction

    voice_allocator_4 #(.KEY_COUNT(KEY_COUNT)) allocator (
        .clk(clk),
        .rst_n(rst_n),
        .key_on_pulse(PIPELINE_INPUTS ? key_on_q : key_on_pulse),
        .key_off_pulse(PIPELINE_INPUTS ? key_off_q : key_off_pulse),
        .voice_idle(voice_idle_registered),
        .voice_gate(voice_gate),
        .voice_assigned(voice_assigned),
        .voice_trigger(voice_trigger),
        .voice_keys(voice_keys)
    );

    function automatic [31:0] transpose_step(input [31:0] base, input [1:0] shift);
        case(shift)
            2'd1: transpose_step = base << 1;
            2'd2: transpose_step = base >> 1;
            default: transpose_step = base;
        endcase
    endfunction
    // 实体键分配器仍按物理键编号分配声部；音高、音色在此读取描述符。
    // 关闭 PER_KEY_SOUND 时不会读取新增端口，旧工程连接方式保持有效。
    function automatic [31:0] sound_step(input [3:0] key_id,input [KEY_COUNT*8-1:0] notes);
        sound_step=note_phase_step(PER_KEY_SOUND ? notes[key_id*8+:4] : key_id);
    endfunction
    function automatic sound_timbre(input [3:0] key_id,input [KEY_COUNT*6-1:0] timbres,input global_timbre);
        sound_timbre=PER_KEY_SOUND ? (timbres[key_id*6+:6]==6'd1) : global_timbre;
    endfunction
    // 参考 synth-piano 的持续音八度控制。更新频率时保留相位与包络，
    // 不生成新的起音；寄存输出把变调选择与相位加法拆成两级。
    integer transpose_voice;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for(transpose_voice=0; transpose_voice<4; transpose_voice=transpose_voice+1)
                transposed_step[transpose_voice] <= 0;
        end else begin
            for(transpose_voice=0; transpose_voice<4; transpose_voice=transpose_voice+1)
                transposed_step[transpose_voice] <= transpose_step(
                    sound_step(voice_keys[transpose_voice*4+:4],key_notes),octave_shift);
        end
    end
    assign phase_step_0 = OCTAVE_CONTROL ? transposed_step[0] : sound_step(voice_keys[3:0],key_notes);
    assign phase_step_1 = OCTAVE_CONTROL ? transposed_step[1] : sound_step(voice_keys[7:4],key_notes);
    assign phase_step_2 = OCTAVE_CONTROL ? transposed_step[2] : sound_step(voice_keys[11:8],key_notes);
    assign phase_step_3 = OCTAVE_CONTROL ? transposed_step[3] : sound_step(voice_keys[15:12],key_notes);
    assign voice_phase_steps = {phase_step_3, phase_step_2, phase_step_1, phase_step_0};

    // 8 bit 力度左移 4 位得到 0～4080，保持与当前单音工程相同的安全幅度范围。
    // 力度总线作为显式函数参数，保证音符编号不变时力度更新也重新计算。
    // 先寄存声部力度，再计算包络；切断模式/映射门控、16选1与ADSR串联路径。
    // 与起音输入一起由 PIPELINE_INPUTS 启用，旧工程默认仍直接读取力度。
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            target_level_q0 <= 13'd0;
            target_level_q1 <= 13'd0;
            target_level_q2 <= 13'd0;
            target_level_q3 <= 13'd0;
        end else begin
            target_level_q0 <= target_raw_0;
            target_level_q1 <= target_raw_1;
            target_level_q2 <= target_raw_2;
            target_level_q3 <= target_raw_3;
        end
    end
    assign target_raw_0 = {1'b0, key_velocity(voice_keys[3:0], velocity_values), 4'b0000};
    assign target_level_0 = PIPELINE_INPUTS ? target_level_q0 : target_raw_0;
    assign target_raw_1 = {1'b0, key_velocity(voice_keys[7:4], velocity_values), 4'b0000};
    assign target_level_1 = PIPELINE_INPUTS ? target_level_q1 : target_raw_1;
    assign target_raw_2 = {1'b0, key_velocity(voice_keys[11:8], velocity_values), 4'b0000};
    assign target_level_2 = PIPELINE_INPUTS ? target_level_q2 : target_raw_2;
    assign target_raw_3 = {1'b0, key_velocity(voice_keys[15:12], velocity_values), 4'b0000};
    assign target_level_3 = PIPELINE_INPUTS ? target_level_q3 : target_raw_3;

    poly_synth_voice #(.ADSR_ENABLE(ADSR_ENABLE), .ATTACK_STEP(ATTACK_STEP), .DECAY_STEP(DECAY_STEP), .SUSTAIN_DROP_SHIFT(SUSTAIN_DROP_SHIFT), .RELEASE_STEP(RELEASE_STEP)) voice_0 (
        .clk(clk), .rst_n(rst_n), .sample_tick(sample_tick),
        .gate(voice_gate[0]), .retrigger(voice_trigger[0]), .timbre(sound_timbre(voice_keys[3:0],key_timbres,timbre)),
        .phase_step(phase_step_0), .target_level(target_level_0),
        .sample_out(sample_0), .current_level(current_level_0),
        .timbre_blend(timbre_blend_0), .idle(voice_idle_raw[0])
    );
    poly_synth_voice #(.ADSR_ENABLE(ADSR_ENABLE), .ATTACK_STEP(ATTACK_STEP), .DECAY_STEP(DECAY_STEP), .SUSTAIN_DROP_SHIFT(SUSTAIN_DROP_SHIFT), .RELEASE_STEP(RELEASE_STEP)) voice_1 (
        .clk(clk), .rst_n(rst_n), .sample_tick(sample_tick),
        .gate(voice_gate[1]), .retrigger(voice_trigger[1]), .timbre(sound_timbre(voice_keys[7:4],key_timbres,timbre)),
        .phase_step(phase_step_1), .target_level(target_level_1),
        .sample_out(sample_1), .current_level(current_level_1),
        .timbre_blend(timbre_blend_1), .idle(voice_idle_raw[1])
    );
    poly_synth_voice #(.ADSR_ENABLE(ADSR_ENABLE), .ATTACK_STEP(ATTACK_STEP), .DECAY_STEP(DECAY_STEP), .SUSTAIN_DROP_SHIFT(SUSTAIN_DROP_SHIFT), .RELEASE_STEP(RELEASE_STEP)) voice_2 (
        .clk(clk), .rst_n(rst_n), .sample_tick(sample_tick),
        .gate(voice_gate[2]), .retrigger(voice_trigger[2]), .timbre(sound_timbre(voice_keys[11:8],key_timbres,timbre)),
        .phase_step(phase_step_2), .target_level(target_level_2),
        .sample_out(sample_2), .current_level(current_level_2),
        .timbre_blend(timbre_blend_2), .idle(voice_idle_raw[2])
    );
    poly_synth_voice #(.ADSR_ENABLE(ADSR_ENABLE), .ATTACK_STEP(ATTACK_STEP), .DECAY_STEP(DECAY_STEP), .SUSTAIN_DROP_SHIFT(SUSTAIN_DROP_SHIFT), .RELEASE_STEP(RELEASE_STEP)) voice_3 (
        .clk(clk), .rst_n(rst_n), .sample_tick(sample_tick),
        .gate(voice_gate[3]), .retrigger(voice_trigger[3]), .timbre(sound_timbre(voice_keys[15:12],key_timbres,timbre)),
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
