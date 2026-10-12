`default_nettype none

// 32 位 DDS 三角波音源。current_level 在每个约 48.8 kHz 的采样点向目标音量靠近，
// 起音每点增加 32、释音每点减少 16；满量程变化分别约为 2.6 ms 和 5.2 ms。
module pressure_tone #(
    parameter [12:0] ATTACK_STEP  = 13'd32,
    parameter [12:0] RELEASE_STEP = 13'd16
) (
    input  wire               clk,
    input  wire               rst_n,
    input  wire               sample_tick,
    input  wire               gate,
    input  wire [31:0]        phase_step,
    input  wire [12:0]        target_level,
    output wire signed [15:0] sample_out,
    output reg  [12:0]        current_level
);
    reg [31:0] phase_acc;
    wire [12:0] effective_target;
    wire [14:0] triangle_folded;
    wire signed [15:0] triangle_centered;
    wire signed [15:0] triangle_wave;
    wire signed [29:0] scaled_product;
    wire signed [29:0] scaled_shifted;

    assign effective_target = gate ? target_level : 13'd0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase_acc    <= 32'd0;
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
        end
    end

    // 三角波原始峰值约为 4096；乘以 0～4096 的力度后右移 12 位，
    // 最终仍限制在约 12.5% 的 16 位满量程，适合首次耳机测试。
    assign triangle_folded  = phase_acc[31] ? ~phase_acc[30:16] : phase_acc[30:16];
    assign triangle_centered = $signed({1'b0, triangle_folded}) - 16'sd16384;
    assign triangle_wave    = triangle_centered >>> 2;
    assign scaled_product   = triangle_wave * $signed({1'b0, current_level});
    assign scaled_shifted   = scaled_product >>> 12;
    assign sample_out       = scaled_shifted[15:0];
endmodule

`default_nettype wire

