// 仅用于音频/压力顶层仿真：厂商加密DVI和PLL不参与延迟判据。
// 实际综合仍使用Gowin视频源文件；此文件不能加入Gowin工程。
module video_pll(input wire clkin,reset,output wire pixel_clk,serial_clk,locked);
    assign pixel_clk=0;assign serial_clk=0;assign locked=1;
endmodule
module DVI_TX_Top(input wire I_rst_n,I_serial_clk,I_rgb_clk,I_rgb_vs,I_rgb_hs,I_rgb_de,
    input wire [7:0] I_rgb_r,I_rgb_g,I_rgb_b,
    output wire O_tmds_clk_p,O_tmds_clk_n,output wire [2:0] O_tmds_data_p,O_tmds_data_n);
    assign O_tmds_clk_p=0;assign O_tmds_clk_n=1;assign O_tmds_data_p=0;assign O_tmds_data_n=7;
endmodule
