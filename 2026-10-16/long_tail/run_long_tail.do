# 2026-10-16: long_tail
# 用法：在本目录执行  vsim -c -do run_long_tail.do
onerror {quit -code 1 -f}
onbreak {quit -code 1 -f}
if {![file exists work]} {vlib work}
vmap work work
vlog -sv pt8211_tx.v key_debounce.v sampled_piano_a4.v tang_mega_60k_top.v tb_piano_long_tail.sv
vsim -c work.tb_piano_long_tail
run -all
if {[examine sim:/tb_piano_long_tail/test_pass] != 1} {quit -code 1 -f}
quit -code 0 -f
