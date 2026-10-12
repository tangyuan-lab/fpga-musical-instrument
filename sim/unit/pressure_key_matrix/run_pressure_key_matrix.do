# 压力键矩阵单元检查：基线校准、迟滞、力度映射、掉线保护、多键
# 用法：在本目录执行  vsim -c -do run_pressure_key_matrix.do
onerror {quit -code 1 -f}
onbreak {quit -code 1 -f}
if {![file exists work]} {vlib work}
vmap work work
vlog -sv ../../../rtl/input/pressure_key_matrix.sv ../../../tb/unit/tb_pressure_key_matrix.sv
vsim -c work.tb_pressure_key_matrix
run -all
if {[examine sim:/tb_pressure_key_matrix/test_pass] != 1} {quit -code 1 -f}
quit -code 0 -f
