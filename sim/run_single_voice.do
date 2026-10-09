onerror {quit -code 1 -f}
onbreak {quit -code 1 -f}
if {![file exists work]} {vlib work}
vlog -sv ../rtl/audio/pt8211_tx.v ../rtl/audio/dds_sine_voice.v ../rtl/audio/key_debounce.v ../rtl/audio/adsr.v ../rtl/audio/audio_gain.v ../rtl/top/tang_mega_60k_top.v ../tb/single_voice_tb.sv
vsim -c work.single_voice_tb
run -all
if {[examine sim:/single_voice_tb/test_pass] != 1} {quit -code 1 -f}
quit -code 0 -f