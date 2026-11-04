# DDR3 原生接口读写自测（用 mock 模型，非真实 DDR3）
# 用法：在本目录执行  vsim -c -do run_ddr3.do
onerror {quit -code 1 -f}
onbreak {quit -code 1 -f}
if {![file exists work]} {vlib work}
vmap work work
vlog -sv ddr3_selftest.v tb_ddr3_selftest.sv
vsim -c work.tb_ddr3_selftest
run -all
if {[examine sim:/tb_ddr3_selftest/test_pass] != 1} {quit -code 1 -f}
quit -code 0 -f
