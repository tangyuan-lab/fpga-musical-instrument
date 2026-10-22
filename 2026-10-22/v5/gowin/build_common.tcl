set root [file normalize [file join [file dirname [info script]] ..]]
set build_dir [file join $root build gowin $variant]
file mkdir $build_dir
cd $build_dir

set_device GW5AT-LV60PG484AC1/I0 -device_version B
add_file -type verilog [file join $root rtl common reset_sync.sv]
add_file -type verilog [file join $root rtl audio audio_startup.sv]
add_file -type verilog [file join $root rtl audio pressure_tone.sv]
add_file -type verilog [file join $root rtl audio pt8211_tx.sv]

if {$variant eq "pressure_audio" || $variant eq "pressure_audio_hdmi"} {
    add_file -type verilog [file join $root rtl io uart_tx.sv]
    add_file -type verilog [file join $root rtl io pressure_audio_telemetry.sv]
    add_file -type verilog [file join $root rtl io onchip_adc_scan.sv]
    add_file -type verilog [file join $root rtl control pressure_control.sv]
}

if {$variant eq "polyphony_demo" || $variant eq "polyphony_timbre_demo" ||
    $variant eq "mcp3208_13key_hdmi"} {
    add_file -type verilog [file join $root rtl audio voice_allocator_4.sv]
    add_file -type verilog [file join $root rtl audio poly_synth_voice.sv]
    add_file -type verilog [file join $root rtl audio poly_synth_4voice.sv]
}

if {$variant eq "mcp3208_13key_hdmi"} {
    add_file -type verilog [file join $root rtl io mcp3208_dual_scan.sv]
    add_file -type verilog [file join $root rtl control pressure_key_matrix.sv]
}

if {$variant eq "polyphony_timbre_demo"} {
    add_file -type verilog [file join $root rtl common button_filter.sv]
}

if {$variant eq "pressure_audio"} {
    add_file -type verilog [file join $root rtl board pressure_audio_top.sv]
    set_option -top_module pressure_audio_top
} elseif {$variant eq "pressure_audio_hdmi"} {
    add_file -type verilog [file join $root rtl common snapshot_cdc.sv]
    add_file -type verilog [file join $root rtl video video_pll.sv]
    add_file -type verilog [file join $root rtl video video_timing.sv]
    add_file -type verilog [file join $root rtl video tmds_encoder.sv]
    add_file -type verilog [file join $root rtl video dvi_tx.sv]
    add_file -type verilog [file join $root rtl video gowin_dvi_ip DVI_TX_Top.v]
    add_file -type verilog [file join $root rtl video pressure_audio_ui_1024x600.sv]
    add_file -type verilog [file join $root rtl board pressure_audio_hdmi_top.sv]
    set_option -top_module pressure_audio_hdmi_top
} elseif {$variant eq "mcp3208_13key_hdmi"} {
    add_file -type verilog [file join $root rtl common snapshot_cdc.sv]
    add_file -type verilog [file join $root rtl io uart_tx.sv]
    add_file -type verilog [file join $root rtl io pressure_audio_telemetry.sv]
    add_file -type verilog [file join $root rtl video video_pll.sv]
    add_file -type verilog [file join $root rtl video video_timing.sv]
    add_file -type verilog [file join $root rtl video tmds_encoder.sv]
    add_file -type verilog [file join $root rtl video dvi_tx.sv]
    add_file -type verilog [file join $root rtl video gowin_dvi_ip DVI_TX_Top.v]
    add_file -type verilog [file join $root rtl video pressure_keys_ui_1024x600.sv]
    add_file -type verilog [file join $root rtl board mcp3208_13key_hdmi_top.sv]
    set_option -top_module mcp3208_13key_hdmi_top
} elseif {$variant eq "hdmi_colorbar_800x600"} {
    add_file -type verilog [file join $root rtl video video_pll_800x600.sv]
    add_file -type verilog [file join $root rtl video video_timing_800x600.sv]
    add_file -type verilog [file join $root rtl video gowin_dvi_ip DVI_TX_Top.v]
    add_file -type verilog [file join $root rtl board hdmi_colorbar_800x600_top.sv]
    set_option -top_module hdmi_colorbar_800x600_top
} elseif {$variant eq "polyphony_demo"} {
    add_file -type verilog [file join $root rtl board polyphony_demo_top.sv]
    set_option -top_module polyphony_demo_top
} elseif {$variant eq "polyphony_timbre_demo"} {
    add_file -type verilog [file join $root rtl board polyphony_timbre_demo_top.sv]
    set_option -top_module polyphony_timbre_demo_top
} else {
    add_file -type verilog [file join $root rtl board audio_smoke_top.sv]
    set_option -top_module audio_smoke_top
}

add_file -type cst [file join $root gowin $variant.cst]
if {$variant eq "pressure_audio_hdmi" || $variant eq "hdmi_colorbar_800x600" ||
    $variant eq "mcp3208_13key_hdmi"} {
    add_file -type sdc [file join $root gowin $variant.sdc]
} else {
    add_file -type sdc [file join $root gowin timing.sdc]
}
set_option -output_base_name $variant
set_option -synthesis_tool gowinsynthesis
set_option -verilog_std sysv2017
set_option -global_freq 50.000
set_option -cst_warn_to_error 1
set_option -use_cpu_as_gpio 1
set_option -use_jtag_as_gpio 0
if {$variant eq "pressure_audio_hdmi" || $variant eq "hdmi_colorbar_800x600" ||
    $variant eq "mcp3208_13key_hdmi"} {
    # NEO Dock 的板级 VCCX 为 1.8 V；Sipeed 官方 cam_dvi 工程明确要求此设置。
    set_option -vccx 1.8
}
run all
