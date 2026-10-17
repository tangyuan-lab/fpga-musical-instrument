`default_nettype none

// 1024x600 实时状态页，不使用帧缓存：
// 顶部状态条显示故障/等待/就绪，左侧青色柱为压力，右侧紫色柱为实际音量，
// 中间方块在音符门控有效时变绿。所有输入均为像素域中的帧快照。
module pressure_audio_ui_1024x600 (
    input  wire [10:0] x,
    input  wire [9:0]  y,
    input  wire [11:0] pressure,
    input  wire [12:0] volume,
    input  wire        gate,
    input  wire        adc_ready,
    input  wire        calibrated,
    input  wire        audio_ready,
    input  wire        fault,
    output reg  [23:0] rgb
);
    integer pressure_height;
    integer volume_base;
    integer volume_height;
    wire system_ready = adc_ready && calibrated && audio_ready && !fault;

    always @(*) begin
        // 压力满力度为 224 码；移位近似放大到 320 像素，避免综合通用除法器。
        if (pressure >= 12'd224)
            pressure_height = 320;
        else
            pressure_height = pressure + (pressure >> 2) + (pressure >> 3);

        // 音量 0～4096 先缩为 0～256，再乘 1.25 映射到 0～320 像素。
        volume_base = volume >> 4;
        volume_height = volume_base + (volume_base >> 2);
        if (volume_height > 320)
            volume_height = 320;

        rgb = 24'h0c_12_20;

        // 顶部总状态条：红=ADC故障，绿=全部就绪，橙=仍在启动或校准。
        if (x >= 40 && x < 984 && y >= 28 && y < 80)
            rgb = fault ? 24'hee_44_44 : system_ready ? 24'h20_cc_88 : 24'hee_aa_33;

        // 四个独立状态灯，从左至右为 ADC、校准、音频和门控。
        if (y >= 96 && y < 124) begin
            if (x >= 100 && x < 180) rgb = adc_ready   ? 24'h37_b8_ee : 24'h30_37_44;
            if (x >= 196 && x < 276) rgb = calibrated  ? 24'h37_b8_ee : 24'h30_37_44;
            if (x >= 748 && x < 828) rgb = audio_ready ? 24'hb0_72_ff : 24'h30_37_44;
            if (x >= 844 && x < 924) rgb = gate        ? 24'h20_d8_9b : 24'h30_37_44;
        end

        // 左右量柱的外框与内部背景。
        if ((x >= 96 && x < 424 && y >= 144 && y < 520) ||
            (x >= 600 && x < 928 && y >= 144 && y < 520))
            rgb = 24'hd9_e2_f0;
        if ((x >= 116 && x < 404 && y >= 164 && y < 500) ||
            (x >= 620 && x < 908 && y >= 164 && y < 500))
            rgb = 24'h1b_2b_40;

        if (x >= 116 && x < 404 && y >= 484-pressure_height && y < 484)
            rgb = gate ? 24'h37_b8_ee : 24'h2b_68_82;
        if (x >= 620 && x < 908 && y >= 484-volume_height && y < 484)
            rgb = 24'hb0_72_ff;

        // 门控指示块：按下时绿色，松开时深灰。
        if (x >= 456 && x < 568 && y >= 388 && y < 500)
            rgb = gate ? 24'h20_d8_9b : 24'h30_37_44;
    end
endmodule

`default_nettype wire

