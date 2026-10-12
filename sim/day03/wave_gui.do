onerror {quit -code 1 -f}
if {![file exists work]} {vlib work}
vlog -sv mcp3208_dual_scan.sv ../docs/waveforms/testbench/waveform_tb_mcp_gui.sv
vsim -gui -voptargs=+acc work.waveform_tb_mcp_gui
add wave -divider "MCP3208 SPI scan"
add wave -radix unsigned sim:/waveform_tb_mcp_gui/dut/mcp_sclk
add wave -radix unsigned sim:/waveform_tb_mcp_gui/dut/mcp_mosi
add wave -radix unsigned sim:/waveform_tb_mcp_gui/dut/mcp0_cs_n
add wave -radix unsigned sim:/waveform_tb_mcp_gui/dut/mcp1_cs_n
add wave -radix unsigned sim:/waveform_tb_mcp_gui/dut/frame_valid
add wave -radix unsigned sim:/waveform_tb_mcp_gui/dut/ready
run 28000ns
wave zoom range 0ns 28000ns
# SPI 时序以 ModelSim Wave 的 PostScript 形式保存。
write wave ../docs/waveforms/day05_mcp3208_modelsim.ps -start 0ns -end 28000ns -landscape
