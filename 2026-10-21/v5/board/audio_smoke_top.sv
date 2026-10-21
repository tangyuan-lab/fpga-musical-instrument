`default_nettype none

// 仅用于首次耳机通路检查：上电等待约 100 ms 后持续输出低音量 A4 三角波。
// 确认能听到声音后，应改烧 pressure_audio_sram.fs 进行压力控制测试。
module audio_smoke_top #(
    parameter integer STARTUP_CYCLES = 5_000_000
) (
    input  wire sys_clk,
    input  wire sys_rst_n,
    output wire hp_bck,
    output wire hp_ws,
    output wire hp_din,
    output wire pa_en
);
    localparam [31:0] PHASE_STEP_A4 = 32'd38_702_809;
    // 数字峰值约为 4096，仅占 16 位满量程的 12.5%。
    localparam [12:0] SAFE_VOLUME   = 13'd4096;

    wire rst_n;
    wire audio_ready;
    wire sample_tick;
    wire signed [15:0] sample_value;
    wire [12:0] volume_level;

    reset_sync u_reset_sync (
        .clk(sys_clk), .arst_n(sys_rst_n), .rst_n(rst_n)
    );

    audio_startup #(.STARTUP_CYCLES(STARTUP_CYCLES)) u_audio_startup (
        .clk(sys_clk), .rst_n(rst_n),
        .audio_ready(audio_ready), .pa_en(pa_en)
    );

    pressure_tone u_pressure_tone (
        .clk(sys_clk), .rst_n(rst_n), .sample_tick(sample_tick),
        .gate(audio_ready), .phase_step(PHASE_STEP_A4),
        .target_level(SAFE_VOLUME), .sample_out(sample_value),
        .current_level(volume_level)
    );

    pt8211_tx u_pt8211_tx (
        .clk(sys_clk), .rst_n(rst_n),
        .sample_left(sample_value), .sample_right(sample_value),
        .sample_tick(sample_tick), .hp_bck(hp_bck),
        .hp_ws(hp_ws), .hp_din(hp_din)
    );

    wire _unused = &{1'b0, volume_level};
endmodule

`default_nettype wire
