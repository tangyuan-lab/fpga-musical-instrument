# Day04 阶段三 对照：已撤回的 阶段三 琴槌噪声版（仿真通过，但板上失败）
# 用法：在本目录执行  vsim -c -do run_hammer_withdrawn.do
onerror {quit -code 1 -f}
onbreak {quit -code 1 -f}
if {![file exists work]} {vlib work}
vmap work work
vlog -sv pt8211_tx.v key_debounce.v audio_gain.v withdrawn_hammer_v3/piano_voice.v withdrawn_hammer_v3/tang_mega_60k_top.v tb_step6.sv
vsim -c work.tb_step6
run -all
if {[examine sim:/tb_step6/test_pass] != 1} {quit -code 1 -f}
quit -code 0 -f

