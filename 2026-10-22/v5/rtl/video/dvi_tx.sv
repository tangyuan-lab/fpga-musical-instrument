`default_nettype none
// 仅输出 DVI 兼容视频，不在 HDMI 数据流中插入音频包。
// 三路 OSER10 在 5 倍像素时钟的双沿发送 10 bit，bit0 先发。
module dvi_tx(input wire pixel_clk,serial_clk,rst_n,de,hs_n,vs_n,
    input wire [23:0] rgb, output wire [2:0] tmds_p,tmds_n,
    output wire tmds_clk_p,tmds_clk_n
);
    wire [9:0] words[0:2];
    wire [2:0] serial;
    tmds_encoder blue(pixel_clk,rst_n,de,hs_n,vs_n,rgb[7:0],words[0]);
    tmds_encoder green(pixel_clk,rst_n,de,1'b0,1'b0,rgb[15:8],words[1]);
    tmds_encoder red(pixel_clk,rst_n,de,1'b0,1'b0,rgb[23:16],words[2]);
    genvar i;
    generate for(i=0;i<3;i=i+1) begin: lanes
        // rst_n 已在像素域同步释放；每路各保留一个复位寄存器，缩短到 IOLOGIC 的布线。
        // 保留 recovery/removal 检查，不把 OSER10 的复位端设为伪路径。
        (* syn_preserve=1, syn_keep=1 *) reg lane_reset;
        always @(posedge pixel_clk or negedge rst_n)
            if(!rst_n) lane_reset<=1'b1;
            else lane_reset<=1'b0;
        OSER10 serializer(.Q(serial[i]),.D0(words[i][0]),.D1(words[i][1]),.D2(words[i][2]),
            .D3(words[i][3]),.D4(words[i][4]),.D5(words[i][5]),.D6(words[i][6]),
            .D7(words[i][7]),.D8(words[i][8]),.D9(words[i][9]),
            .PCLK(pixel_clk),.FCLK(serial_clk),.RESET(lane_reset));
        // 60K 的这四对封装引脚支持真 LVDS；配合 NEO Dock 的交流耦合网络。
        TLVDS_OBUF output_pair(.I(serial[i]),.O(tmds_p[i]),.OB(tmds_n[i]));
    end endgenerate
    TLVDS_OBUF clock_pair(.I(pixel_clk),.O(tmds_clk_p),.OB(tmds_clk_n));
endmodule
`default_nettype wire
