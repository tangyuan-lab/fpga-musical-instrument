create_clock -name sys_clk -period 20.000 -waveform {0 10.000} [get_ports {sys_clk}]
set_false_path -from [get_ports {sys_rst_n}]
