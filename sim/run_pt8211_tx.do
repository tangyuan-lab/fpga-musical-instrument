onerror {quit -code 1 -f}
onbreak {quit -code 1 -f}
if {![file exists work]} {vlib work}
vlog -sv ../rtl/audio/pt8211_tx.v ../tb/pt8211_tx_tb.sv
vsim -c work.pt8211_tx_tb
run -all
if {[examine sim:/pt8211_tx_tb/test_pass] != 1} {quit -code 1 -f}
quit -code 0 -f
