onerror {quit -code 1 -f}
onbreak {quit -code 1 -f}
if {![file exists work]} {vlib work}
vlog -sv ../../../rtl/polyphony/voice_allocator_4.sv ../../../tb/unit/tb_voice_allocator_4.sv
vsim -c work.tb_voice_allocator_4
run -all
if {[examine sim:/tb_voice_allocator_4/test_pass] != 1} {quit -code 1 -f}
quit -code 0 -f
