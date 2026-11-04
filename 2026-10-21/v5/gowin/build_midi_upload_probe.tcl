set root [file normalize [file join [file dirname [info script]] ..]]
set build_dir [file join $root build gowin midi_upload_probe]
file mkdir $build_dir
cd $build_dir
set_device GW5AT-LV60PG484AC1/I0 -device_version B
add_file -type verilog [file join $root rtl common reset_sync.sv]
add_file -type verilog [file join $root rtl io uart_tx.sv]
add_file -type verilog [file join $root rtl io uart_rx.sv]
add_file -type verilog [file join $root rtl io uart_frame_protocol.sv]
add_file -type verilog [file join $root rtl io uart_frame_tx.sv]
add_file -type verilog [file join $root rtl io midi_file_store.sv]
add_file -type verilog [file join $root rtl board midi_upload_probe_top.sv]
add_file -type cst [file join $root gowin midi_upload_probe.cst]
add_file -type sdc [file join $root gowin midi_upload_probe.sdc]
set_option -top_module midi_upload_probe_top
set_option -output_base_name midi_upload_probe
set_option -synthesis_tool gowinsynthesis
set_option -verilog_std sysv2017
set_option -global_freq 50.000
set_option -cst_warn_to_error 1
set_option -use_cpu_as_gpio 1
set_option -use_jtag_as_gpio 0
run all

