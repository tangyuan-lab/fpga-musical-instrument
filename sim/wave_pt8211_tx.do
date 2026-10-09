onerror {quit -code 1 -f}
if {![file exists work]} {vlib work}
if {![file exists waves]} {file mkdir waves}
vlog -sv ../rtl/audio/pt8211_tx.v ../tb/pt8211_waveform_tb.sv
vsim -gui -voptargs=+acc work.pt8211_waveform_tb
add wave -divider "PT8211 serial audio"
add wave -radix unsigned sim:/pt8211_waveform_tb/clk
add wave -radix unsigned sim:/pt8211_waveform_tb/rst_n
add wave -radix hexadecimal sim:/pt8211_waveform_tb/sample_in
add wave -radix unsigned sim:/pt8211_waveform_tb/dut/bck
add wave -radix unsigned sim:/pt8211_waveform_tb/dut/ws
add wave -radix unsigned sim:/pt8211_waveform_tb/dut/din
add wave -radix unsigned sim:/pt8211_waveform_tb/dut/frame_tick
run 16000ns
wave zoom range 0ns 16000ns
# 波形导出成可缩放的矢量图。采样点数据由 testbench 写到 waves/ 下，该目录已被 .gitignore 忽略。
write wave ../docs/progress/2026-10-08_pt8211-audio-link/2026-10-08_pt8211-serial-waveform.ps -start 0ns -end 16000ns -landscape
