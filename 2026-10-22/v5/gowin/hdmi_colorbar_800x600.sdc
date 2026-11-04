create_clock -name sys_clk -period 20.000 [get_ports {sys_clk}]
set_false_path -from [get_ports {sys_rst_n}]

// 上电后 PLL 已锁定且画面仍处于消隐，OSER10 复位只释放一次。
set_false_path -to [get_pins {transmitter/rgb2dvi_inst/u_OSER10_*/RESET}] -setup
