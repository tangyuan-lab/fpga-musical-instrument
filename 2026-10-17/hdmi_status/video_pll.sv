`default_nettype none
// GW5AT-60B 的 PLLA：50/2*4*10.25=1025 MHz VCO。
// CLKOUT0 /4=256.25 MHz 串行时钟，CLKOUT1 /20=51.25 MHz 像素时钟。
// 通道顺序与 Sipeed 官方 Tang Mega 60K cam_dvi 工程一致，比例严格为 5:1。
// PFD=25 MHz；配合 1344x635 总时序，1024x600 刷新率约 60.06 Hz。
// 此包装仅声明厂商原语及静态参数；模拟与物理有效性由 Gowin 工具核查。
module video_pll(input wire clkin,reset,output wire pixel_clk,serial_clk,locked);
    PLLA #(.FCLKIN("50"),.IDIV_SEL(2),.FBDIV_SEL(4),
        .MDIV_SEL(10),.MDIV_FRAC_SEL(2),
        .ODIV0_SEL(4),.ODIV1_SEL(20),
        .CLKOUT0_EN("TRUE"),.CLKOUT1_EN("TRUE"),
        .CLKFB_SEL("INTERNAL")) pll(
        .CLKIN(clkin),.CLKFB(1'b0),.RESET(reset),.PLLPWD(1'b0),.RESET_I(1'b0),.RESET_O(1'b0),
        .PSSEL(3'd0),.PSDIR(1'b0),.PSPULSE(1'b0),.SSCPOL(1'b0),.SSCON(1'b0),
        .SSCMDSEL(7'd0),.SSCMDSEL_FRAC(3'd0),.MDWDI(8'd0),.MDCLK(1'b0),.MDOPC(2'd0),.MDAINC(1'b0),
        .CLKOUT0(serial_clk),.CLKOUT1(pixel_clk),.CLKOUT2(),.CLKOUT3(),.CLKOUT4(),
        .CLKOUT5(),.CLKOUT6(),.CLKFBOUT(),.MDRDO(),.LOCK(locked));
endmodule
`default_nettype wire

