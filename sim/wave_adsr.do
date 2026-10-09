onerror {quit -code 1 -f}
if {![file exists work]} {vlib work}
vlog -sv ../rtl/audio/adsr.v ../tb/adsr_waveform_tb.sv
vsim -gui -voptargs=+acc work.adsr_waveform_tb
add wave -divider "ADSR envelope"
add wave -radix unsigned sim:/adsr_waveform_tb/sample_tick
add wave -radix unsigned sim:/adsr_waveform_tb/note_on
add wave -radix unsigned sim:/adsr_waveform_tb/note_off
add wave -radix unsigned sim:/adsr_waveform_tb/note_active
add wave -radix unsigned sim:/adsr_waveform_tb/dut/gain
add wave -radix unsigned sim:/adsr_waveform_tb/dut/voice_active
run 9000ns
wave zoom range 0ns 9000ns
# 波形导出成可缩放的矢量图。
write wave ../docs/progress/2026-10-09_single-dds-voice/2026-10-09_single-voice-envelope-waveform.ps -start 0ns -end 9000ns -landscape