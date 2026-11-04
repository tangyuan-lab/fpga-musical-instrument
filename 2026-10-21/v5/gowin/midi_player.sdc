create_clock -name sys_clk -period 20.000 [get_ports {sys_clk}]
set_false_path -from [get_ports {sys_rst_n}]

# 解析器、调度器和合成器都运行在同一个 50 MHz 时钟域，不能用
# false_path 把它们自身的路径豁免掉；保留完整时序检查更适合上板前验收。
