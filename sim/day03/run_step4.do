onerror {quit -code 1 -f}
onbreak {quit -code 1 -f}
if {![file exists work]} {vlib work}
vlog -sv ../rtl/audio/pt8211_tx.v ../rtl/audio/dds_sine_voice.v ../rtl/audio/key_debounce.v ../rtl/audio/adsr.v ../rtl/audio/audio_mixer_4ch.v ../rtl/audio/step4_A4_B4_top.v ../tb/day03/tb_step4.sv
vsim -c work.tb_step4
run -all
if {[examine sim:/tb_step4/test_pass] != 1} {quit -code 1 -f}
quit -code 0 -f
