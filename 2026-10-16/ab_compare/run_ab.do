# 2026-10-16: ab_compare
# 用法：在本目录执行  vsim -c -do run_ab.do
onerror {quit -code 1 -f}
onbreak {quit -code 1 -f}
if {![file exists work]} {vlib work}
vmap work work
vlog -sv pt8211_tx.v key_debounce.v piano_voice.v sampled_piano_a4.v tang_mega_60k_top.v tb_sample_a4_ab.sv
vsim -c work.tb_sample_a4_ab
run -all
if {[examine sim:/tb_sample_a4_ab/test_pass] != 1} {quit -code 1 -f}
quit -code 0 -f
