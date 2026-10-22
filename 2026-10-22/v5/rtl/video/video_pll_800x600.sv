`default_nettype none

// Sipeed 官方 60K 工程给出的 800x600 PLL 参数：
// 50 MHz * 16 = 800 MHz VCO；CLKOUT0 /4=200 MHz，CLKOUT1 /20=40 MHz。
module video_pll_800x600 (
    input  wire clkin,
    input  wire reset,
    output wire pixel_clk,
    output wire serial_clk,
    output wire locked
);
    PLLA #(
        .FCLKIN("50"), .IDIV_SEL(1), .FBDIV_SEL(1),
        .MDIV_SEL(16), .MDIV_FRAC_SEL(0),
        .ODIV0_SEL(4), .ODIV1_SEL(20),
        .CLKOUT0_EN("TRUE"), .CLKOUT1_EN("TRUE"),
        .CLKFB_SEL("INTERNAL")
    ) pll (
        .CLKIN(clkin), .CLKFB(1'b0), .RESET(reset), .PLLPWD(1'b0),
        .RESET_I(1'b0), .RESET_O(1'b0), .PSSEL(3'd0), .PSDIR(1'b0),
        .PSPULSE(1'b0), .SSCPOL(1'b0), .SSCON(1'b0),
        .SSCMDSEL(7'd0), .SSCMDSEL_FRAC(3'd0), .MDWDI(8'd0),
        .MDCLK(1'b0), .MDOPC(2'd0), .MDAINC(1'b0),
        .CLKOUT0(serial_clk), .CLKOUT1(pixel_clk), .CLKOUT2(),
        .CLKOUT3(), .CLKOUT4(), .CLKOUT5(), .CLKOUT6(),
        .CLKFBOUT(), .MDRDO(), .LOCK(locked)
    );
endmodule

`default_nettype wire
