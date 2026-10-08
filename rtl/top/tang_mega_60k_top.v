// 第 01 阶段顶层：固定方波足以验证串行音频链路。
// 逐帧翻转，一周期 2 帧，频率 = 48000/2 = 24 kHz
module tang_mega_60k_top (
    input wire sys_clk, input wire sys_rst_n,
    output wire HP_BCK, output wire HP_WS, output wire HP_DIN, output wire PA_EN
);
    wire frame_tick;
    reg signed [15:0] sample = 16'sd4096;
    reg [9:0] startup_frames = 10'd0;

    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            sample <= 16'sd0;
            startup_frames <= 10'd0;
        end else if (frame_tick) begin
            sample <= -sample;
            if (startup_frames != 10'd1023)
                startup_frames <= startup_frames + 1'b1;
        end
    end

    pt8211_tx audio_tx (
        .clk(sys_clk), .rst_n(sys_rst_n), .sample_in(sample),
        .bck(HP_BCK), .ws(HP_WS), .din(HP_DIN), .frame_tick(frame_tick)
    );
    assign PA_EN = !sys_rst_n || (startup_frames != 10'd1023);
endmodule

