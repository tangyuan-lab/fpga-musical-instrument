set root [file normalize [file join [file dirname [info script]] ..]]
set variant instrument_full
set build_dir [file join $root build gowin $variant]
file mkdir $build_dir
cd $build_dir

set_device GW5AT-LV60PG484AC1/I0 -device_version B

foreach source {
    {rtl common reset_sync.sv}
    {rtl common snapshot_cdc.sv}
    {rtl common button_filter.sv}
    {rtl common u64_divider.sv}
    {rtl io uart_tx.sv}
    {rtl io uart_rx.sv}
    {rtl io uart_frame_protocol.sv}
    {rtl io uart_frame_tx.sv}
    {rtl io serial_screen_nextion_tx.sv}
    {rtl io screen_touch_keys_rx.sv}
    {rtl io midi_file_store.sv}
    {rtl io midi_file_ram_sdp.sv}
    {rtl io timbre_file_store.sv}
    {rtl io mcp3208_dual_scan.sv}
    {rtl control pressure_key_matrix.sv}
    {rtl control live_touch_key_merge.sv}
    {rtl midi midi_type0_parser.sv}
    {rtl midi midi_player_scheduler.sv}
    {rtl audio audio_startup.sv}
    {rtl audio pt8211_tx.sv}
    {rtl audio i2s_tx.sv}
    {rtl audio voice_allocator_4.sv}
    {rtl audio poly_synth_voice.sv}
    {rtl audio poly_synth_4voice.sv}
    {rtl audio midi_voice_allocator_4.sv}
    {rtl audio midi_poly_synth_4voice.sv}
    {rtl audio custom_wavetable_reader.sv}
    {rtl video video_pll.sv}
    {rtl video video_timing.sv}
    {rtl video tmds_encoder.sv}
    {rtl video dvi_tx.sv}
    {rtl video gowin_dvi_ip DVI_TX_Top.v}
    {rtl video instrument_ui_1024x600.sv}
    {rtl board midi_player_top.sv}
    {rtl board instrument_full_top.sv}
} {
    add_file -type verilog [file join $root {*}$source]
}

add_file -type cst [file join $root gowin instrument_full.cst]
add_file -type sdc [file join $root gowin instrument_full.sdc]
set_option -top_module instrument_full_top
set_option -output_base_name $variant
set_option -synthesis_tool gowinsynthesis
set_option -verilog_std sysv2017
set_option -global_freq 50.000
set_option -cst_warn_to_error 1
set_option -use_cpu_as_gpio 1
set_option -use_jtag_as_gpio 0
set_option -vccx 1.8
run all
