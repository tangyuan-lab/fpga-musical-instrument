`timescale 1ns/1ps
`default_nettype none

// 单个可重触发三角波声部。retrigger 用于新音符分配或声部抢占：相位与包络从零开始，
// 避免把旧音符的随机相位直接带到新音符。力度变化只在音频采样点更新。
module poly_synth_voice #(
    parameter integer ADSR_ENABLE = 0,
    parameter [12:0] ATTACK_STEP  = 13'd32,
    parameter [12:0] DECAY_STEP   = 13'd8,
    // 2 对应维持幅度 75%；0 对应 100%，用于兼容旧 AR 声部测试。
    parameter integer SUSTAIN_DROP_SHIFT = 2,
    parameter [12:0] RELEASE_STEP = 13'd16
) (
    input  wire               clk,
    input  wire               rst_n,
    input  wire               sample_tick,
    input  wire               gate,
    input  wire               retrigger,
    input  wire               timbre,
    input  wire [31:0]        phase_step,
    input  wire [12:0]        target_level,
    output reg  signed [15:0] sample_out,
    output reg  [12:0]        current_level,
    output reg  [7:0]         timbre_blend,
    output wire               idle
);
    reg [31:0] phase_acc;
    localparam [2:0] ENV_IDLE=0, ENV_ATTACK=1, ENV_DECAY=2, ENV_SUSTAIN=3, ENV_RELEASE=4;
    reg [2:0] envelope_stage;
    wire [12:0] sustain_target = (SUSTAIN_DROP_SHIFT == 0) ? target_level :
                                 target_level - (target_level >> SUSTAIN_DROP_SHIFT);
    wire [12:0] effective_target;
    wire [14:0] triangle_folded;
    wire signed [15:0] triangle_centered;
    wire signed [15:0] triangle_wave;
    wire signed [15:0] square_wave;
    wire signed [16:0] triangle_extended;
    wire signed [16:0] square_extended;
    wire signed [16:0] waveform_difference;
    wire signed [8:0] blend_factor;
    wire signed [25:0] blend_delta;
    wire signed [16:0] blended_waveform;
    wire signed [15:0] selected_waveform;
    wire signed [29:0] scaled_shifted;
    reg signed [16:0] difference_pipeline;
    reg signed [8:0] factor_pipeline;
    reg signed [15:0] triangle_pipeline, square_pipeline;
    reg signed [15:0] triangle_delayed, square_delayed;
    reg full_square_pipeline, full_square_delayed;
    reg signed [25:0] blend_product_pipeline;
    reg  signed [15:0] waveform_pipeline;
    reg signed [29:0] scaled_product_pipeline;

    assign effective_target = gate ? target_level : 13'd0;
    assign idle = !gate && current_level == 13'd0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase_acc     <= 32'd0;
            current_level <= 13'd0;
            timbre_blend  <= 8'd0;
            envelope_stage <= ENV_IDLE;
        end else if (retrigger) begin
            phase_acc     <= 32'd0;
            current_level <= 13'd0;
            envelope_stage <= ENV_ATTACK;
        end else if (sample_tick) begin
            if (gate || current_level != 13'd0)
                phase_acc <= phase_acc + phase_step;
            else
                phase_acc <= 32'd0;

            if (ADSR_ENABLE != 0) begin
                if (!gate) begin
                    envelope_stage <= ENV_RELEASE;
                    if (current_level <= RELEASE_STEP) begin
                        current_level <= 13'd0;
                        envelope_stage <= ENV_IDLE;
                    end else begin
                        current_level <= current_level - RELEASE_STEP;
                    end
                end else begin
                    case (envelope_stage)
                        ENV_IDLE, ENV_ATTACK: begin
                            envelope_stage <= ENV_ATTACK;
                            if (current_level >= target_level || target_level-current_level <= ATTACK_STEP) begin
                                current_level <= target_level;
                                envelope_stage <= ENV_DECAY;
                            end else begin
                                current_level <= current_level + ATTACK_STEP;
                            end
                        end
                        ENV_DECAY: begin
                            if (current_level <= sustain_target || current_level-sustain_target <= DECAY_STEP) begin
                                current_level <= sustain_target;
                                envelope_stage <= ENV_SUSTAIN;
                            end else begin
                                current_level <= current_level - DECAY_STEP;
                            end
                        end
                        ENV_SUSTAIN: begin
                            // 保持阶段仍跟踪实体压力，避免维持阶段丢失持续力度表达。
                            if (current_level < sustain_target) begin
                                current_level <= (sustain_target-current_level <= ATTACK_STEP) ?
                                                 sustain_target : current_level+ATTACK_STEP;
                            end else if (current_level > sustain_target) begin
                                current_level <= (current_level-sustain_target <= RELEASE_STEP) ?
                                                 sustain_target : current_level-RELEASE_STEP;
                            end
                        end
                        default: envelope_stage <= ENV_ATTACK;
                    endcase
                end
            end else if (current_level < effective_target) begin
                if (effective_target - current_level <= ATTACK_STEP)
                    current_level <= effective_target;
                else
                    current_level <= current_level + ATTACK_STEP;
            end else if (current_level > effective_target) begin
                if (current_level - effective_target <= RELEASE_STEP)
                    current_level <= effective_target;
                else
                    current_level <= current_level - RELEASE_STEP;
            end

            // 约 32 个采样点完成音色切换，48.8 kHz 下约 0.66 ms。
            if (timbre && timbre_blend < 8'hff) begin
                if (timbre_blend >= 8'd247)
                    timbre_blend <= 8'hff;
                else
                    timbre_blend <= timbre_blend + 8'd8;
            end else if (!timbre && timbre_blend != 8'd0) begin
                if (timbre_blend <= 8'd8)
                    timbre_blend <= 8'd0;
                else
                    timbre_blend <= timbre_blend - 8'd8;
            end
        end
    end

    // 每个声部满力度峰值约为 4096；四声部混音器随后再统一降低 6 dB。
    assign triangle_folded   = phase_acc[31] ? ~phase_acc[30:16] : phase_acc[30:16];
    assign triangle_centered = $signed({1'b0, triangle_folded}) - 16'sd16384;
    assign triangle_wave     = triangle_centered >>> 2;
    // 第二种音色采用降低幅度的柔和方波；交叉淡化避免切换瞬间出现明显爆音。
    assign square_wave        = phase_acc[31] ? 16'sd2304 : -16'sd2304;
    assign triangle_extended  = {triangle_wave[15], triangle_wave};
    assign square_extended    = {square_wave[15], square_wave};
    assign waveform_difference = square_extended - triangle_extended;
    assign blend_factor       = $signed({1'b0, timbre_blend});
    assign blend_delta        = blend_product_pipeline >>> 8;
    assign blended_waveform   = $signed({triangle_delayed[15], triangle_delayed}) + blend_delta[16:0];
    assign selected_waveform  = full_square_delayed ? square_delayed :
                                blended_waveform[15:0];
    assign scaled_shifted    = scaled_product_pipeline >>> 12;

    // 差值、音色乘法、交叉淡化、力度乘法分别寄存。数据级使用同步复位，
    // 允许乘法器吸收寄存器进入DSP；相关三角波/方波/选择标志逐级对齐。
    // 5级共100ns，远小于1024周期采样间隔；输出仍异步清零保证停止立即静音。
    always @(posedge clk) begin
        if (!rst_n) begin
            difference_pipeline <= 17'sd0;
            factor_pipeline <= 9'sd0;
            triangle_pipeline <= 16'sd0;
            square_pipeline <= 16'sd0;
            full_square_pipeline <= 1'b0;
            blend_product_pipeline <= 26'sd0;
            triangle_delayed <= 16'sd0;
            square_delayed <= 16'sd0;
            full_square_delayed <= 1'b0;
            waveform_pipeline <= 16'sd0;
            scaled_product_pipeline <= 30'sd0;
        end else begin
            difference_pipeline <= waveform_difference;
            factor_pipeline <= blend_factor;
            triangle_pipeline <= triangle_wave;
            square_pipeline <= square_wave;
            full_square_pipeline <= timbre_blend == 8'hff;
            blend_product_pipeline <= difference_pipeline * factor_pipeline;
            triangle_delayed <= triangle_pipeline;
            square_delayed <= square_pipeline;
            full_square_delayed <= full_square_pipeline;
            waveform_pipeline <= selected_waveform;
            scaled_product_pipeline <= waveform_pipeline * $signed({1'b0, current_level});
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sample_out <= 16'sd0;
        end else begin
            sample_out <= scaled_shifted[15:0];
        end
    end
endmodule

`default_nettype wire
