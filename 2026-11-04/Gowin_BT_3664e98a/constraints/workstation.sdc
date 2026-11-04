# 50MHz板载参考，PLL倍频8，DDR用户时钟由PHY除4。SUG940-2.0.4E §5.2.2。
create_clock -name ref50 -period 20 [get_ports {sys_clk}]
create_generated_clock -name sys_clk -source [get_ports {sys_clk}] -divide_by 1 [get_pins {ddr/Gowin_PLL_inst/u_pll/PLL_inst/CLKOUT1}]
create_generated_clock -name ddr400 -source [get_ports {sys_clk}] -multiply_by 8 [get_pins {ddr/Gowin_PLL_inst/u_pll/PLL_inst/CLKOUT2}]
create_generated_clock -name ddr100 -source [get_pins {ddr/Gowin_PLL_inst/u_pll/PLL_inst/CLKOUT2}] -master_clock ddr400 -divide_by 4 [get_pins {ddr/u_ddr3/gw3_top/u_ddr_phy_top/fclkdiv/CLKOUT}]
# 2026-10-30用户选择首次实机门槛：移除额外3ns优化预留。
# 50MHz实际20ns及PLL/CLKDIV关系保持；厂商原语/时钟固有不确定度仍由工具分析。
# 完整Setup/Hold/Recovery/Removal和例外路径仍必须通过。
# 仅异步输入的第一级同步器、异步复位断言被豁免；不切断50/100MHz整对时钟。
set_false_path -from [get_ports {sys_rst_n}]
set_false_path -from [get_ports {uart_rx_i}] -to [get_regs {usb_rx/rx_meta_s0}]
set_false_path -from [get_ports {screen_rx_i}] -to [get_regs {touch/uart_receiver/rx_meta_s0}]
set_false_path -from [get_ports {mode_key_n}] -to [get_regs {mode_button/key_sync_n_0_s0}]
set_false_path -from [get_ports {timbre_key_n}] -to [get_regs {timbre_button/key_sync_n_0_s0}]
set_false_path -from [get_ports {mcp0_miso}] -to [get_regs {adc_spi/mcp0_miso_meta_s0}]
set_false_path -from [get_ports {mcp1_miso}] -to [get_regs {adc_spi/mcp1_miso_meta_s0}]
# Gray码首级：只限定目标D以覆盖综合与bin指针合并的MSB；8ns目标另核实际物理传播。
# SUG940 §5.4.2最大绝对延迟保留setup分析；仅hold是异步首级无固定相位的检查。
set_max_delay -to [get_pins {storage_bridge/requests/rgray_w1*_s0/D}] 8.000
set_max_delay -to [get_pins {storage_bridge/requests/wgray_r1*_s0/D}] 8.000
set_max_delay -to [get_pins {storage_bridge/responses/rgray_w1*_s0/D}] 8.000
set_max_delay -to [get_pins {storage_bridge/responses/wgray_r1*_s0/D}] 8.000
set_false_path -hold -to [get_pins {storage_bridge/requests/rgray_w1*_s0/D}]
set_false_path -hold -to [get_pins {storage_bridge/requests/wgray_r1*_s0/D}]
set_false_path -hold -to [get_pins {storage_bridge/responses/rgray_w1*_s0/D}]
set_false_path -hold -to [get_pins {storage_bridge/responses/wgray_r1*_s0/D}]
set_false_path -to [get_regs {ddr/reinit_sync_0_s0}]
report_high_fanout_nets -max_nets 50
report_route_congestion -max_grids 100
report_timing -max_paths 12000 -max_common_paths 12000
report_exceptions -setup -max_paths 12000
report_exceptions -hold -max_paths 12000

# 硬件计数快照：只豁免请求/确认的第一级同步器，保持打包数据路径受检。
set_false_path -to [get_regs {hardware_monitor/counters/ack_sync_0_s0}]
set_false_path -to [get_regs {hardware_monitor/counters/req_sync_0_s0}]
set_false_path -to [get_regs {hardware_monitor/pll_sync_0_s0}]

# IDES8_MEM的CALIB进入原语内部三级同步链（本机prim_sim.v/IDES8_MEM）。
# 只豁免该配置输入的首级入口；PCLK/FCLK及数据通路仍受检，见evidence/vendor_model_binding.json。
set_false_path -from [get_regs {ddr/u_ddr3/gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen*.u_ddr_phy_data_lane/u_ddr_phy_data_io/ides_calib_d_s0}] -to [get_pins {ddr/u_ddr3/gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen*.u_ddr_phy_data_lane/u_ddr_phy_data_io/iserdes_gen*.u_ides8_mem/CALIB}]

# 100->50MHz整包握手：数据随request锁存，目标经过2级同步再捕获，返回ack前源保持。
# 最早捕获至少2个20ns周期后；限制整包路径20ns，保留至少1个目标周期的稳定裕量。
# 该路径的同沿hold不对应协议捕获事件；只切此100位数据路径的hold，不切整对时钟。
set_max_delay -from [get_regs {hardware_monitor/counters/held_data*}] -to [get_regs {hardware_monitor/counters/dst_data*}] 20
set_false_path -hold -from [get_regs {hardware_monitor/counters/held_data*}] -to [get_regs {hardware_monitor/counters/dst_data*}]
# 单独列出同域路径，避免被DDR跨域路径挤出总表。
report_timing -setup -from_clock [get_clocks {sys_clk}] -to_clock [get_clocks {sys_clk}] -max_paths 100 -max_common_paths 1

report_timing -hold -max_paths 12000 -max_common_paths 12000
report_timing -recovery -max_paths 12000 -max_common_paths 1
report_timing -removal -max_paths 12000 -max_common_paths 1

# 当前IP与公开原语模型同源：每个首级Q仅到对应次级D，见audit_result.json。
# 精确限定三个异步单比特入口；二级、复位和所有功能路径保留检查。
set_false_path -to [get_pins {ddr/u_ddr3/gw3_top/u_ddr_phy_top/ddr_sync/lock_syn_0_s0/D}]
set_false_path -to [get_pins {ddr/u_ddr3/gw3_top/u_ddr_phy_top/ddr_sync/recalib_s_0_s0/D}]
set_false_path -to [get_pins {ddr/u_ddr3/gw3_top/u_ddr_phy_top/ddr_init_st_r_s0/D}]

# 专用异步断言/同步释放链：中间Q仅传递释放级，末级才允许消费者运行。
# 仅这些同步器的异步CLEAR没有固定采样相位；其Q到功能寄存器的复位仍分析。
set_false_path -to [get_pins {ddr/control_release_0_s0/CLEAR ddr/control_release_1_s0/CLEAR ddr/control_release_2_s0/CLEAR}]
set_false_path -to [get_pins {storage_bridge/app_release_0_s0/CLEAR storage_bridge/app_release_1_s0/CLEAR storage_bridge/app_release_2_s0/CLEAR}]
set_false_path -to [get_pins {storage_bridge/mem_release_0_s0/CLEAR storage_bridge/mem_release_1_s0/CLEAR storage_bridge/mem_release_2_s0/CLEAR}]
set_false_path -to [get_pins {reset_sync_inst/stages_0_s0/CLEAR reset_sync_inst/stages_1_s0/CLEAR}]
# 在线电平只进入首级；请求接收和消费仍要求两侧已同步上线。
set_false_path -to [get_pins {storage_bridge/mem_online_app_0_s0/D storage_bridge/app_online_mem_0_s0/D}]


# 停钟配置窗口：同源可达控制图见ddr_stop_window.json，不改变时钟频率。
# 初始化启动在所有恢复点至少已稳定10个20ns控制周期；仅约束此源到100MHz功能域。
set_max_delay -from [get_pins {ddr/u_ddr3/gw3_top/u_ddr_phy_top/ddr_sync/ddr_init_st_s0/Q}] -to [get_clocks {ddr100}] 20.000
# RLOADN的pause配置在恢复点至少已稳定19个控制周期；其他DQS输入不豁免。
set_max_delay -from [get_regs {ddr/u_ddr3/gw3_top/u_ddr_phy_top/ddr_sync/cs_memsync_2_s0}] 20.000
# DLL更新在恢复前至少关闭19周期、恢复后4周期仍关闭；STEP由复位后的三级使能捕获。
# 40ns只作为配置传播上限；保留这些端点的普通hold分析。
set_max_delay -to [get_regs {ddr/u_ddr3/gw3_top/u_ddr_phy_top/dll_step_base*_s0}] 40.000
# 五级异步关门/同步释放保护给出至少四个完整控制周期的名义静止区间。
# 只将这个复位源到PHY异步端点限制为20ns传播；实际全负载、偏斜与门控仍需报告审查。
set_max_delay -from [get_regs {ddr/u_ddr3/gw3_top/u_ddr_phy_top/ddr_rsti_reg_2_s0}] -to [get_clocks {ddr100}] 20.000
set_max_delay -from [get_regs {ddr/u_ddr3/gw3_top/u_ddr_phy_top/ddr_rsti_reg_2_s0}] -to [get_clocks {ddr400}] 20.000
# 唯一用途为PLL时钟开放的专用释放链；其下游PHY功能复位没有被false path。
set_false_path -to [get_pins {ddr/clock_guard*_s0/CLEAR}]
report_exceptions -recovery -max_paths 12000 -max_common_paths 1
report_exceptions -removal -max_paths 12000 -max_common_paths 1

# 额外列出低扇出控制网，核对PLL ENCLK2及RLOADN实际网络延迟。
report_high_fanout_nets -min_fanout 1 -max_fanout 8 -max_nets 150000

# IP外部复位释放也受同一clock_guard保护：ip_rst_n=0异步清链并关闭PLL ENCLK2，
# 释放后必须经过五次50MHz采样才开400MHz/派生100MHz；至少80ns名义静止窗口。
# 仅此50MHz同步释放源到停钟100MHz域限定20ns传播，普通50MHz端点仍按原时序；
# 不切时钟对，不豁免hold/removal。新报告须核全部目标与传播，见IP释放四相位测试/控制结构证明。
set_max_delay -from [get_regs {ddr/ip_release_sync_2_s0}] -to [get_clocks {ddr100}] 20.000

# 单独核DQS/HOLD发送源全部setup/hold，确保近邻放置没有引入短路径问题。
report_timing -setup -from [get_regs {ddr/u_ddr3/gw3_top/u_ddr_phy_top/u_ddr_init/hold_gen[1].hold_i_s0}] -max_paths 100 -max_common_paths 100
report_timing -hold -from [get_regs {ddr/u_ddr3/gw3_top/u_ddr_phy_top/u_ddr_init/hold_gen[1].hold_i_s0}] -max_paths 100 -max_common_paths 100

# hardware_monitor专用复位同步链：输入为sys_clk释放，目的为ddr100。
# 只切两级同步器自身CLEAR；末级Q到计数器/快照功能寄存器仍完整分析。
# 两级同源异步置零、D0恒1/D1=Q0，最小复位脉宽/停钟/重新初始化见证据契约。
set_false_path -from [get_pins {reset_sync_inst/stages_1_s0/Q}] -to [get_pins {hardware_monitor/mem_reset_release_0_s0/CLEAR hardware_monitor/mem_reset_release_1_s0/CLEAR}]

# Independent asynchronous HC-05 RX: only the first synchronizer ingress is excepted.
set_false_path -from [get_ports {bt_rx_i}] -to [get_regs {bt_link/receiver/rx_meta_s0}]
