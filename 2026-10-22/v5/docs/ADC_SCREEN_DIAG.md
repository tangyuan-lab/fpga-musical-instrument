# 串口屏压力值不变：原始 ADC 诊断

适用于屏幕能被 AB13 切换 LIVE/MIDI，但 LIVE 下压力为 000、ACTIVE 不变的情况。
正式工程的 READY 只表示扫描及初始化完成，不是 MCP3208 接线正常的证明。

## 文件与编译

- 顶层：`rtl/board/adc_screen_diag_top.sv`
- 编译：`powershell -ExecutionPolicy Bypass -File scripts/build.ps1 -Target adc_screen_diag`
- 位流：`build/ready-to-program/adc_screen_diag_sram.fs`
- 恢复正式工程：`build/ready-to-program/instrument_full_sram.fs`

用 Gowin Programmer 的 **SRAM Program** 下载诊断位流。现有串口屏工程无需重新下载。
诊断期间音频关闭，USB UART 不接受 MIDI；HDMI 不输出。
SRAM 位流断电后失效，重上电会加载原来的 Flash 位流。

## 操作

1. 屏幕保持稳定 5 V 供电，FPGA C18 → 屏幕 RX，GND 共地。
   USB 转 TTL 的 TX 不应同时驱动屏幕 RX；屏幕 TX/C19 不需要接入本诊断。
2. 松开所有压力键，下载位流或按复位重新校准。
3. 模式显示 **RAW**，13 个位置显示原始 ADC，十六进制 000～FFF。
   记录一个键松开和按住时的数值。
4. AB13 切换 **DIFF**：显示原始值相对松开基线的绝对变化量。
   ACTIVE 是变化量至少 16 码的通道数量，不是正式音源的活动声部数。

## 判断

| 观察 | 下一步 |
| --- | --- |
| RAW 按压后下降，DIFF 增大 | 与正式工程默认低有效方向一致，检查校准及正式位流版本 |
| RAW 按压后上升，DIFF 增大 | 对应键的 ACTIVE_LOW_MASK 位需要设为 0，再编译正式工程 |
| RAW 始终 000 或 FFF | 检查供电、VREF、共地、DOUT、信号电压；不能仅凭固定值定位某一根线 |
| RAW 数值固定但不是端点 | 检查压力模块 S 到 ADC CHx 的连接、传感器供电和按压电压变化 |
| RAW 有轻微波动，但 DIFF 小于 010 | 尚未达到正式工程 16 码触发门限，先核实实际电压变化 |

同一组命令也从板载 USB UART TX（U15）输出，115200/8N1，可由电脑读取；
电脑不需要向 FPGA 发送任何指令。

## MCP3208 接线沿用正式工程

| 信号 | 第一片 MCP3208（键 1～8） | 第二片 MCP3208（键 9～13） |
| --- | --- | --- |
| CLK/SCLK | PMOD1 IO0 / Y21 | PMOD1 IO1 / Y22 |
| DOUT/OUT/MISO | PMOD1 IO2 / AB21 | PMOD1 IO3 / AB22 |
| DIN/MOSI | PMOD1 IO4 / AA20 | PMOD1 IO5 / AA21 |
| CS/SHDN | PMOD1 IO6 / AA19 | PMOD1 IO7 / AB20 |

这里的 Y21、AB21 等是 FPGA 封装引脚名，不是排针脚号。
两片 ADC 的 VDD、VREF 使用 3.3 V，并与 FPGA 和压力模块共地；
具体排针方向见 `docs/MCP3208_13KEY_BRINGUP.md`，从板背面观察时左右会翻转。

## 验证范围

`tb_adc_screen_diag_top` 从两个 MCP3208 行为模型经 SPI 到实际 UART 位流，
验证 13 路映射、上升/下降变化量、释放恢复、AB13 消抖切换和音频关闭。
原有 `tb_serial_screen_nextion_tx` 验证默认 LIVE/MIDI 行为保持兼容。
这些仿真不能代替实物 ADC 接线验证。
