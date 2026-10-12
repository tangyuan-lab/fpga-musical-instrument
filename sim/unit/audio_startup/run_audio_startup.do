# 单元测试：audio_startup 上电静音计数
# 用法：在本目录执行  vsim -c -do run_audio_startup.do
onerror {quit -code 1 -f}
onbreak {quit -code 1 -f}
if {![file exists work]} {vlib work}
vmap work work
vlog -sv ../../../rtl/polyphony/audio_startup.sv ../../../tb/unit/tb_audio_startup.sv
vsim -c work.tb_audio_startup
run -all
if {[examine sim:/tb_audio_startup/test_pass] != 1} {quit -code 1 -f}
quit -code 0 -f
