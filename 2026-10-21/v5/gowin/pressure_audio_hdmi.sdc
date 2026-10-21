create_clock -name sys_clk -period 20.000 [get_ports {sys_clk}]
set_false_path -from [get_ports {sys_rst_n}]

// PLL 自动推导 CLKOUT0=256.25 MHz OSER10 快时钟和 CLKOUT1=51.25 MHz 像素时钟。
// 快照握手只豁免同步器第一级，30位数据总线仍限制在一个像素周期内。
set_false_path -to [get_pins {bridge/req_sync_0_s0/D bridge/ack_sync_0_s0/D}]
set_max_delay -from [get_regs {bridge/held_data*}] -to [get_regs {bridge/dst_data*}] 20.000
set_false_path -from [get_regs {bridge/held_data*}] -to [get_regs {bridge/dst_data*}] -hold

// DVI TX IP 的四个 OSER10 共用已在像素域同步释放的启动复位。它只在上电消隐期间
// 变化，屏幕锁定前已经保持稳定；忽略其跨到 5 倍串行时钟的单次 recovery 检查。
set_false_path -to [get_pins {transmitter/rgb2dvi_inst/u_OSER10_*/RESET}] -setup
