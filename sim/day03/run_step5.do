# Day04 第二步：单键四音循环 + audio_gain 2 倍（STEP5）
# 用法：在 sim/ 下执行  vsim -c -do day03/run_step5.do
onerror {quit -code 1 -f}
onbreak {quit -code 1 -f}
if {![file exists work]} {vlib work}
vmap work work
vlog -sv ../rtl/audio/pt8211_tx.v ../rtl/audio/dds_sine_voice_select.v ../rtl/audio/key_debounce.v ../rtl/audio/adsr.v ../rtl/audio/audio_gain.v ../rtl/audio/step5_cycle_plus6db_top.v ../tb/day03/tb_step5.sv
vsim -c work.tb_step5
run -all
if {[examine sim:/tb_step5/test_pass] != 1} {quit -code 1 -f}
quit -code 0 -f
