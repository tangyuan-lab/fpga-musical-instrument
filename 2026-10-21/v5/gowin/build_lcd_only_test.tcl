set root [file normalize [file join [file dirname [info script]] ..]]
set build_dir [file join $root build gowin lcd_only_test]
file mkdir $build_dir
cd $build_dir

set_device GW5AT-LV60PG484AC1/I0 -device_version B
add_file -type verilog [file join $root rtl video video_pll.sv]
add_file -type verilog [file join $root rtl lcd lcd_timing_1024x600.sv]
add_file -type verilog [file join $root rtl lcd lcd_colorbar_1024x600.sv]
add_file -type verilog [file join $root rtl board lcd_only_test_top.sv]
add_file -type cst [file join $root gowin lcd_only_test.cst]
add_file -type sdc [file join $root gowin lcd_only_test.sdc]
set_option -top_module lcd_only_test_top
set_option -output_base_name lcd_only_test
set_option -synthesis_tool gowinsynthesis
set_option -verilog_std sysv2017
set_option -global_freq 50.000
set_option -cst_warn_to_error 1
set_option -use_cpu_as_gpio 1
set_option -use_sspi_as_gpio 1
set_option -use_i2c_as_gpio 1
set_option -use_jtag_as_gpio 0
set_option -vccx 1.8
run all
