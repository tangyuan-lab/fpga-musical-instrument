`default_nettype none

// HDMI 硬件排障工程：固定 800x600 色条，不依赖 ADC、音频或跨时钟状态数据。
module hdmi_colorbar_800x600_top (
    input  wire       sys_clk,
    input  wire       sys_rst_n,
    output wire [2:0] tmds_p,
    output wire [2:0] tmds_n,
    output wire       tmds_clk_p,
    output wire       tmds_clk_n,
    output wire       hpd_en
);
    wire pixel_clk;
    wire serial_clk;
    wire pll_locked;
    wire video_rst_n;
    wire [10:0] x;
    wire [9:0] y;
    wire de;
    wire hs;
    wire vs;
    reg [23:0] rgb;

    assign hpd_en = 1'b1;

    video_pll_800x600 clocks (
        .clkin(sys_clk), .reset(!sys_rst_n),
        .pixel_clk(pixel_clk), .serial_clk(serial_clk), .locked(pll_locked)
    );
    reset_sync video_reset (
        .clk(pixel_clk), .arst_n(sys_rst_n && pll_locked), .rst_n(video_rst_n)
    );
    video_timing_800x600 timing (
        .clk(pixel_clk), .rst_n(video_rst_n),
        .x(x), .y(y), .de(de), .hs(hs), .vs(vs)
    );

    always @(*) begin
        case (x[9:7])
            3'd0: rgb = 24'hff_00_00;
            3'd1: rgb = 24'hff_ff_00;
            3'd2: rgb = 24'h00_ff_00;
            3'd3: rgb = 24'h00_ff_ff;
            3'd4: rgb = 24'h00_00_ff;
            3'd5: rgb = 24'hff_00_ff;
            default: rgb = 24'hff_ff_ff;
        endcase
        if (x < 4 || x >= 796 || y < 4 || y >= 596)
            rgb = 24'hff_ff_ff;
    end

    DVI_TX_Top transmitter (
        .I_rst_n(video_rst_n), .I_serial_clk(serial_clk),
        .I_rgb_clk(pixel_clk), .I_rgb_vs(vs), .I_rgb_hs(hs), .I_rgb_de(de),
        .I_rgb_r(rgb[23:16]), .I_rgb_g(rgb[15:8]), .I_rgb_b(rgb[7:0]),
        .O_tmds_clk_p(tmds_clk_p), .O_tmds_clk_n(tmds_clk_n),
        .O_tmds_data_p(tmds_p), .O_tmds_data_n(tmds_n)
    );
endmodule

`default_nettype wire
