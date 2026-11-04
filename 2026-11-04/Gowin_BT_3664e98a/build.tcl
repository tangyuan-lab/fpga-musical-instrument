set root [file dirname [file normalize [info script]]]
cd $root
set_device GW5AST-LV138PG484AC1/I0 -device_version C
add_file -type verilog [file join $root {audio_chorus.sv}]
add_file -type verilog [file join $root {audio_effects.sv}]
add_file -type verilog [file join $root {audio_params.sv}]
add_file -type verilog [file join $root {audio_startup.sv}]
add_file -type verilog [file join $root {piano_velocity_gain.sv}]
add_file -type verilog [file join $root {bend_factor_rom.sv}]
add_file -type verilog [file join $root {button_filter.sv}]
add_file -type verilog [file join $root {control_ram_sdp.sv}]
add_file -type verilog [file join $root {control_ram_sp32.sv}]
add_file -type verilog [file join $root {i2s48_stereo.sv}]
add_file -type verilog [file join $root {mcp3208_dual_scan.sv}]
add_file -type verilog [file join $root {midi_file_ram32_sdp.sv}]
add_file -type verilog [file join $root {modal_piano32.sv}]
add_file -type verilog [file join $root {modal_piano_coeff_rom.sv}]
add_file -type verilog [file join $root {packed_table_sp32.sv}]
add_file -type verilog [file join $root {pcm_master_gain.sv}]
add_file -type verilog [file join $root {pcm_percent_gain.sv}]
add_file -type verilog [file join $root {piano_note_rom.sv}]
add_file -type verilog [file join $root {pressure_key_matrix_serial.sv}]
add_file -type verilog [file join $root {pt8211_48_stereo.sv}]
add_file -type verilog [file join $root {reset_sync.sv}]
add_file -type verilog [file join $root {sample_ram.sv}]
add_file -type verilog [file join $root {screen_touch_keys_rx.sv}]
add_file -type verilog [file join $root {snapshot_cdc.sv}]
add_file -type verilog [file join $root {source_mix_sync.sv}]
add_file -type verilog [file join $root {track_gain_bank_packed.sv}]
add_file -type verilog [file join $root {uart_frame_protocol.sv}]
add_file -type verilog [file join $root {uart_frame_tx_v2.sv}]
add_file -type verilog [file join $root {uart_rx.sv}]
add_file -type verilog [file join $root {uart_tx.sv}]
add_file -type verilog [file join $root {voice_context_bank.sv}]
add_file -type verilog [file join $root {voice_postmix32.sv}]
add_file -type verilog [file join $root {workstation_screen_tx.sv}]
add_file -type verilog [file join $root {workstation_v2_emergency.sv}]
add_file -type verilog [file join $root {workstation_v2_screen.sv}]
add_file -type verilog [file join $root {audio_observer.sv}]
add_file -type verilog [file join $root {diagnostic_dds32.sv}]
add_file -type verilog [file join $root {fft512_observer.sv}]
add_file -type verilog [file join $root {led8_guide.sv}]
add_file -type verilog [file join $root {mega138_screen_tx.sv}]
add_file -type verilog [file join $root {mega138_models8_top.sv}]
add_file -type verilog [file join $root {instrument_models8_modes.sv}]
add_file -type verilog [file join $root {workstation_models8_router.sv}]
add_file -type verilog [file join $root {field_test_models8_control.sv}]
add_file -type verilog [file join $root {mega138_models8_diagnostics.sv}]
add_file -type verilog [file join $root {workstation_cut123_player.sv}]
add_file -type verilog [file join $root {workstation_cut123_resources.sv}]
add_file -type verilog [file join $root {workstation_cut123_commands.sv}]
add_file -type verilog [file join $root {unified_models8_32.sv}]
add_file -type verilog [file join $root {model_voice_control_models8_32.sv}]
add_file -type verilog [file join $root {voice_postmix_models8_32.sv}]
add_file -type verilog [file join $root {voice_transition32.sv}]
add_file -type verilog [file join $root {shared_modal_math.sv}]
add_file -type verilog [file join $root {shared_modal_scheduler32.sv}]
add_file -type verilog [file join $root {shared_modal_scheduler32_compact.sv}]
add_file -type verilog [file join $root {shared_modal_backend32.sv}]
add_file -type verilog [file join $root {shared_models8_render32.sv}]
add_file -type verilog [file join $root {midi_tracks_parser.sv}]
add_file -type verilog [file join $root {rtl/workstation_async_fifo.sv}]
add_file -type verilog [file join $root {rtl/workstation_ddr_bridge.sv}]
add_file -type verilog [file join $root {rtl/workstation_ddr_phy.sv}]
add_file -type verilog [file join $root {rtl/workstation_song_store.sv}]
add_file -type verilog [file join $root {rtl/workstation_track_mix.sv}]
add_file -type verilog [file join $root {ip/ddr3/ddr3_memory_interface.v}]
add_file -type verilog [file join $root {ip/pll/gowin_pll.v}]
add_file -type verilog [file join $root {ip/pll/gowin_pll_mod.v}]
add_file -type verilog [file join $root {ip/pll/pll_init.v}]
add_file -type verilog [file join $root {rtl/workstation_hw_status.sv}]
add_file -type verilog [file join $root {rtl/workstation_chord.sv}]
add_file -type verilog [file join $root {rtl/workstation_voice_count.sv}]
add_file -type verilog [file join $root {pcm_source_sends.sv}]
add_file -type verilog [file join $root {pcm_peak_limiter.sv}]
add_file -type verilog [file join $root {pcm_gain_stats.sv}]
add_file -type verilog [file join $root {screen_scope_capture.sv}]
add_file -type verilog [file join $root {rtl/pressure_touch_curve.sv}]
add_file -type verilog [file join $root {rtl/audio_runtime_metrics.sv}]
add_file -type verilog [file join $root {rtl/live_note_pitch.sv}]
add_file -type verilog [file join $root {rtl/pressure_lesson.sv}]
add_file -type verilog [file join $root {rtl/screen_status_mux.sv}]
add_file -type verilog [file join $root {rtl/r7_bt_control.sv}]
add_file -type verilog [file join $root {rtl/r7_bt_frame_rx.sv}]
add_file -type verilog [file join $root {rtl/r7_bt_host_bridge.sv}]
add_file -type verilog [file join $root {rtl/r7_bt_uart_link.sv}]
add_file -type verilog [file join $root {rtl/r7_bt_usb_guard.sv}]
add_file -type cst [file join $root {constraints/workstation.cst}]
add_file -type sdc [file join $root {constraints/workstation.sdc}]
set_option -top_module mega138_models8_top
set_option -output_base_name workstation_nodrum_ddr
set_option -synthesis_tool gowinsynthesis
set_option -verilog_std sysv2017
set_option -global_freq 50.000
set_option -cst_warn_to_error 1
set_option -use_jtag_as_gpio 0
set_option -use_cpu_as_gpio 1
set_option -use_sspi_as_gpio 1
set_option -convert_sdp32_36_to_sdp16_18 0
set_option -place_option 3
set_option -route_option 2
set_option -route_maxfan 50
set_option -gen_text_timing_rpt 1
set_option -gen_posp 1
set status FAILED
set rc 1
if {[catch {run syn} message]} {
    puts "BUILD_FAILED: $message"
} else {set status COMPLETED;set rc 0}
set f [open [file join $root {runs/syn_terminal.txt}] w]
puts $f $status
close $f
exit $rc
