# 2026-10-16: retrigger
# 用法：在本目录执行  vsim -c -do run_retrigger.do
onerror {quit -code 1 -f}
onbreak {quit -code 1 -f}
if {![file exists work]} {vlib work}
vmap work work
vlog -sv pt8211_tx.v key_debounce.v sampled_piano_a4.v tang_mega_60k_top.v tb_retrigger.sv
vsim -c work.tb_retrigger
run -all
if {[examine sim:/tb_retrigger/test_pass] != 1} {quit -code 1 -f}
quit -code 0 -f
