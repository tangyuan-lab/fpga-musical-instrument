set root [file normalize [file join [file dirname [info script]] ..]]
set variant instrument_workstation_v2
file mkdir [file join $root build gowin $variant]
cd [file join $root build gowin $variant]
set_device GW5AT-LV60PG484AC1/I0 -device_version B
add_file -type verilog [file join $root rtl common reset_sync.sv]
add_file -type verilog [file join $root rtl common snapshot_cdc.sv]
add_file -type verilog [file join $root rtl common button_filter.sv]
add_file -type verilog [file join $root rtl common control_ram_sdp.sv]
add_file -type verilog [file join $root rtl io uart_rx.sv]
add_file -type verilog [file join $root rtl io uart_tx.sv]
add_file -type verilog [file join $root rtl io uart_frame_protocol.sv]
add_file -type verilog [file join $root rtl io uart_frame_tx_v2.sv]
add_file -type verilog [file join $root rtl io midi_file_ram_sdp.sv]
add_file -type verilog [file join $root rtl io workstation_v2_resources.sv]
add_file -type verilog [file join $root rtl io workstation_v2_emergency.sv]
add_file -type verilog [file join $root rtl io screen_touch_keys_rx.sv]
add_file -type verilog [file join $root rtl io mcp3208_dual_scan.sv]
add_file -type verilog [file join $root rtl io workstation_v2_screen.sv]
add_file -type verilog [file join $root rtl control pressure_key_matrix.sv]
add_file -type verilog [file join $root rtl control pressure_max16.sv]
add_file -type verilog [file join $root rtl control workstation_v2_router.sv]
add_file -type verilog [file join $root rtl control instrument_mode_control_v2.sv]
add_file -type verilog [file join $root rtl control drum_sequencer.sv]
add_file -type verilog [file join $root rtl control workstation_v2_player.sv]
add_file -type verilog [file join $root rtl control workstation_v2_commands.sv]
add_file -type verilog [file join $root rtl midi midi_type0_parser_v2.sv]
add_file -type verilog [file join $root rtl audio synth32_generated.sv]
add_file -type verilog [file join $root rtl audio audio_effects.sv]
add_file -type verilog [file join $root rtl audio sample_ram.sv]
add_file -type verilog [file join $root rtl audio i2s_tx.sv]
add_file -type verilog [file join $root rtl audio audio_startup.sv]
add_file -type verilog [file join $root rtl audio drum_synth.sv]
add_file -type verilog [file join $root rtl video video_pll.sv]
add_file -type verilog [file join $root rtl video video_timing.sv]
add_file -type verilog [file join $root rtl video tmds_encoder.sv]
add_file -type verilog [file join $root rtl video dvi_tx.sv]
add_file -type verilog [file join $root rtl video gowin_dvi_ip DVI_TX_Top.v]
add_file -type verilog [file join $root rtl video instrument_ui_1024x600.sv]
add_file -type verilog [file join $root rtl board instrument_workstation_v2_top.sv]
add_file -type cst [file join $root gowin instrument_workstation_v2.cst]
add_file -type sdc [file join $root gowin instrument_workstation_v2.sdc]
set_option -top_module instrument_workstation_v2_top
set_option -output_base_name instrument_workstation_v2
set_option -synthesis_tool gowinsynthesis
set_option -verilog_std sysv2017
set_option -global_freq 50.000
set_option -cst_warn_to_error 1
set_option -use_cpu_as_gpio 1
set_option -use_jtag_as_gpio 0
set_option -vccx 1.8
set_option -route_option 1
run syn
