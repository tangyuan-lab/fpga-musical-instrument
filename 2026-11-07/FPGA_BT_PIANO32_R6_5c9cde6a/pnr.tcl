set root [file dirname [file normalize [info script]]]
cd $root
set_device GW5AST-LV138PG484AC1/I0 -device_version C
add_file [file join $root {impl/gwsynthesis/workstation_nodrum_ddr.vg}]
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
if {[catch {run pnr} message]} {
    puts "BUILD_FAILED: $message"
} else {set status COMPLETED;set rc 0}
set f [open [file join $root {runs/pnr_terminal.txt}] w]
puts $f $status
close $f
exit $rc
