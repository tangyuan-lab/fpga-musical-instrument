set root [file normalize [file join [file dirname [info script]] ../..]]
file mkdir [file join $root build gowin midi_tracks]
cd [file join $root build gowin midi_tracks]
set_device GW5AT-LV60PG484AC1/I0 -device_version B
add_file -type verilog [file join $root experiments workstation_tracks midi_tracks_parser.sv]
set_option -top_module midi_tracks_parser
set_option -output_base_name midi_tracks
set_option -synthesis_tool gowinsynthesis
set_option -verilog_std sysv2017
set_option -global_freq 50.000
run syn
