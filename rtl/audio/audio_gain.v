`timescale 1ns/1ns

// 移植自野火工程的增益/饱和模块。
// 数字增益 + 16 位饱和。源 ROM 有意保持不变，这一级只改送到 DAC 的幅度，
// 并挡住有符号溢出。
//
// GAIN_SHIFT 的默认值写 2，但实际在用的顶层都会显式传值，别被默认值误导。
module audio_gain
#(
    parameter integer GAIN_SHIFT = 2
)
(
    input  wire signed [15:0] sample_in,
    output reg  signed [15:0] sample_out
);

    reg signed [17:0] sample_scaled;

    always @* begin
        // 移位前先符号扩展，否则 GAIN_SHIFT 多出来的位会被截掉。
        sample_scaled = $signed({{2{sample_in[15]}}, sample_in}) <<< GAIN_SHIFT;

        if (sample_scaled > 18'sd32767)
            sample_out = 16'sh7fff;
        else if (sample_scaled < -18'sd32768)
            sample_out = 16'sh8000;
        else
            sample_out = sample_scaled[15:0];
    end

endmodule
