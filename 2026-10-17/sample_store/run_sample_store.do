# 采样存储边界拆分
# 用法：在本目录执行  vsim -c -do run_sample_store.do
onerror {quit -code 1 -f}
onbreak {quit -code 1 -f}
if {![file exists work]} {vlib work}
vmap work work
file mkdir sim
vlog -sv pt8211_tx.v key_debounce.v piano_a4_sample_store.v sampled_piano_a4.v tang_mega_60k_top.v tb_sample_store.sv
vsim -c work.tb_sample_store
run -all
if {[examine sim:/tb_sample_store/test_pass] != 1} {quit -code 1 -f}
quit -code 0 -f
