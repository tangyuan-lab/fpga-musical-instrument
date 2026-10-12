`timescale 1ns/1ns

// 移植自野火工程的四通道有符号混音器（原先的注释写的是 "WM8978 播放链路"，
// WM8978 是野火那块板上的编解码器，本工程实际送的是 PT8211）。
// 四路 16 位声部先使用保护位求和，再对齐为 24 位 PCM，
// 最后进行饱和处理，避免结果回绕。
module audio_mixer_4ch
#(
    parameter integer GAIN_SHIFT = 9
)
(
    input  wire signed [15:0] sample_0,
    input  wire signed [15:0] sample_1,
    input  wire signed [15:0] sample_2,
    input  wire signed [15:0] sample_3,

    output reg  signed [23:0] sample_out
);

    wire signed [17:0] sample_0_ext = {{2{sample_0[15]}}, sample_0};
    wire signed [17:0] sample_1_ext = {{2{sample_1[15]}}, sample_1};
    wire signed [17:0] sample_2_ext = {{2{sample_2[15]}}, sample_2};
    wire signed [17:0] sample_3_ext = {{2{sample_3[15]}}, sample_3};

    wire signed [17:0] mix_sum = sample_0_ext + sample_1_ext
                               + sample_2_ext + sample_3_ext;

    reg signed [26:0] mix_scaled;

    always @* begin
        // 当前 ROM 的幅值约为 +/-4096，右移 9 位可以为
        // 四个同时发声且包络为满量程的正弦声部留下足够余量。
        mix_scaled = $signed({{9{mix_sum[17]}}, mix_sum}) <<< GAIN_SHIFT;

        if (mix_scaled > 27'sd8_388_607)
            sample_out = 24'sh7fffff;
        else if (mix_scaled < -27'sd8_388_608)
            sample_out = 24'sh800000;
        else
            sample_out = mix_scaled[23:0];
    end

endmodule

