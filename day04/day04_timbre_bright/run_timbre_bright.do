# Day04 阶段二：提亮起音 v2（阶段二）
# 用法：在本目录执行  vsim -c -do run_timbre_bright.do
onerror {quit -code 1 -f}
onbreak {quit -code 1 -f}
if {![file exists work]} {vlib work}
vmap work work
vlog -sv pt8211_tx.v key_debounce.v audio_gain.v piano_voice.v tang_mega_60k_top.v tb_step6.sv
vsim -c work.tb_step6
run -all
if {[examine sim:/tb_step6/test_pass] != 1} {quit -code 1 -f}
quit -code 0 -f

