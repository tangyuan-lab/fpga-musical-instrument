set root [file normalize [file join [file dirname [info script]] ../..]]
file mkdir [file join $root build gowin track_audio]
cd [file join $root build gowin track_audio]
set_device GW5AT-LV60PG484AC1/I0 -device_version B
add_file -type verilog [file join $root experiments workstation_tracks track_gain_bank.sv]
add_file -type verilog [file join $root experiments workstation_tracks synth32_tracks.sv]
set_option -top_module synth32_tracks
set_option -output_base_name track_audio
set_option -synthesis_tool gowinsynthesis
set_option -verilog_std sysv2017
set_option -global_freq 50.000
run syn
