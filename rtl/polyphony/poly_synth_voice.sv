`timescale 1ns/1ps
`default_nettype none

// 单个可重触发三角波声部。retrigger 用于新音符分配或声部抢占：相位与包络从零开始，
// 避免把旧音符的随机相位直接带到新音符。力度变化只在音频采样点更新。
module poly_synth_voice #(
    parameter [12:0] ATTACK_STEP  = 13'd32,
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
    output wire signed [15:0] sample_out,
    output reg  [12:0]        current_level,
    output reg  [7:0]         timbre_blend,
    output wire               idle
);
    reg [31:0] phase_acc;
    wire [12:0] effective_target;
    wire [14:0] triangle_folded;
    wire signed [15:0] triangle_centered;
    wire signed [15:0] triangle_wave;
    wire signed [15:0] square_wave;
    wire signed [16:0] triangle_extended;
    wire signed [16:0] square_extended;
    wire signed [16:0] waveform_difference;
    wire signed [8:0] blend_factor;
    wire signed [25:0] blend_product;
    wire signed [25:0] blend_delta;
    wire signed [16:0] blended_waveform;
    wire signed [15:0] selected_waveform;
    wire signed [29:0] scaled_product;
    wire signed [29:0] scaled_shifted;

    assign effective_target = gate ? target_level : 13'd0;
    assign idle = !gate && current_level == 13'd0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase_acc     <= 32'd0;
            current_level <= 13'd0;
            timbre_blend  <= 8'd0;
        end else if (retrigger) begin
            phase_acc     <= 32'd0;
            current_level <= 13'd0;
        end else if (sample_tick) begin
            if (gate || current_level != 13'd0)
                phase_acc <= phase_acc + phase_step;
            else
                phase_acc <= 32'd0;

            if (current_level < effective_target) begin
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
    assign blend_product      = waveform_difference * blend_factor;
    assign blend_delta        = blend_product >>> 8;
    assign blended_waveform   = triangle_extended + blend_delta[16:0];
    assign selected_waveform  = (timbre_blend == 8'hff) ? square_wave :
                                blended_waveform[15:0];
    assign scaled_product    = selected_waveform * $signed({1'b0, current_level});
    assign scaled_shifted    = scaled_product >>> 12;
    assign sample_out        = scaled_shifted[15:0];
endmodule

`default_nettype wire

