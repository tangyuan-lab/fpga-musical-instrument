create_clock -name sys_clk -period 20.000 [get_ports {sys_clk}]
set_false_path -from [get_ports {sys_rst_n}]

// display_bridge 只把最新状态快照送到 HDMI 像素域；握手同步器不参与功能时序。
set_false_path -to [get_pins {display_bridge/req_sync_0_s0/D display_bridge/ack_sync_0_s0/D}]
set_max_delay -from [get_regs {display_bridge/held_data*}] -to [get_regs {display_bridge/dst_data*}] 20.000
set_false_path -from [get_regs {display_bridge/held_data*}] -to [get_regs {display_bridge/dst_data*}] -hold

// DVI TX IP 的复位在像素域释放；启动阶段只检查一次 recovery。
set_false_path -to [get_pins {transmitter/rgb2dvi_inst/u_OSER10_*/RESET}] -setup
