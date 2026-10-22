create_clock -name sys_clk -period 20.000 [get_ports {sys_clk}]
set_false_path -from [get_ports {sys_rst_n}]
set_false_path -from [get_ports {ctp_int}]
set_false_path -from [get_ports {ctp_sda}]
set_false_path -from [get_ports {ctp_scl}]

# 触摸控制器运行在 50 MHz sys_clk，LCD 像素逻辑运行在 PLL 输出的
# 51.25 MHz 域。显式声明 PLL 输出后，将两级同步寄存器之间的 CDC
# 路径设为异步，避免把正确的跨域采样误报为 hold 违例。
create_generated_clock -name lcd_pixel_clk -source [get_ports {sys_clk}] -master_clock sys_clk -divide_by 40 -multiply_by 41 [get_pins {lcd_pll/pll/CLKOUT1}]
set_clock_groups -asynchronous -group [get_clocks {sys_clk}] -group [get_clocks {lcd_pixel_clk}]
# touch coordinates are held in the 50 MHz I2C controller domain and are
# sampled by a two-register synchronizer in the PLL pixel-clock domain.
# Their first synchronizer stage is intentionally asynchronous to sys_clk;
# exclude only the first-stage D pins from setup/hold analysis. The wildcard
# matches Gowin's synthesized register suffix (_s0/_s1, etc.).
set_false_path -to [get_pins {touch_x_p1_*_s*/D touch_y_p1_*_s*/D touch_down_p1_s*/D}]
