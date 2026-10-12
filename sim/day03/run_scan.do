# Day05：两片 MCP3208 扫描器的命令帧与采样捕获检查
# 用法：在 sim/ 下执行  vsim -c -do day03/run_scan.do
onerror {quit -code 1 -f}
onbreak {quit -code 1 -f}
if {![file exists work]} {vlib work}
vmap work work
vlog -sv ../rtl/input/mcp3208_dual_scan.sv ../tb/day03/tb_mcp3208_scan.sv
vsim -c work.tb_mcp3208_scan
run -all
if {[examine sim:/tb_mcp3208_scan/test_pass] != 1} {quit -code 1 -f}
quit -code 0 -f
