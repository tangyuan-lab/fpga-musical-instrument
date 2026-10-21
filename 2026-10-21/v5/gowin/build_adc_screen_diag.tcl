set root [file normalize [file join [file dirname [info script]] ..]]
set variant adc_screen_diag
set build_dir [file join $root build gowin $variant]
file mkdir $build_dir
cd $build_dir
set_device GW5AT-LV60PG484AC1/I0 -device_version B
foreach source {
    {rtl common reset_sync.sv}
    {rtl common button_filter.sv}
    {rtl io uart_tx.sv}
    {rtl io uart_rx.sv}
    {rtl io serial_screen_nextion_tx.sv}
    {rtl io mcp3208_dual_scan.sv}
    {rtl control pressure_key_matrix.sv}
    {rtl board adc_screen_diag_top.sv}
} {
    add_file -type verilog [file join $root {*}$source]
}
add_file -type cst [file join $root gowin adc_screen_diag.cst]
add_file -type sdc [file join $root gowin adc_screen_diag.sdc]
set_option -top_module adc_screen_diag_top
set_option -output_base_name $variant
set_option -synthesis_tool gowinsynthesis
set_option -verilog_std sysv2017
set_option -global_freq 50.000
set_option -cst_warn_to_error 1
set_option -use_cpu_as_gpio 1
set_option -use_jtag_as_gpio 0
set_option -vccx 1.8
run all
