# 只在脚本已核对RTL/SDC/电气属性与旧网表一致后使用。
set root [file normalize [file join [file dirname [info script]] ..]]
set variant instrument_workstation
cd [file join $root build gowin $variant]
set_device GW5AT-LV60PG484AC1/I0 -device_version B
add_file -type netlist [file join $root build gowin $variant impl gwsynthesis instrument_workstation.vg]
add_file -type cst [file join $root gowin instrument_workstation.cst]
add_file -type sdc [file join $root gowin instrument_full.sdc]
set_option -top_module instrument_workstation_top
set_option -output_base_name $variant
set_option -global_freq 50.000
set_option -cst_warn_to_error 1
set_option -use_cpu_as_gpio 1
set_option -use_jtag_as_gpio 0
set_option -vccx 1.8
run pnr
