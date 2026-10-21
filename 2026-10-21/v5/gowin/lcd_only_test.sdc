create_clock -name sys_clk -period 20.000 [get_ports {sys_clk}]
set_false_path -from [get_ports {sys_rst_n}]

# video_pll 的 CLKOUT1 = 50 MHz * 41 / 40 = 51.25 MHz。
create_generated_clock -name lcd_pixel_clk -source [get_ports {sys_clk}] -master_clock sys_clk -divide_by 40 -multiply_by 41 [get_pins {lcd_pll/pll/CLKOUT1}]
set_clock_groups -asynchronous -group [get_clocks {sys_clk}] -group [get_clocks {lcd_pixel_clk}]
