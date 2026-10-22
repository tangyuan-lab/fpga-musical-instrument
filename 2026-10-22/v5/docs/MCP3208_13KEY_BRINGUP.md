# MCP3208 双片 13 键接线与上板步骤

## 先确认一件事

13 个模拟压力输入不能由一片 MCP3208 完成。当前工程按两片模块设计：

- 第一片 `MCP0`：CH0～CH7 对应键 1～8；
- 第二片 `MCP1`：CH0～CH4 对应键 9～13；
- 第二片 CH5～CH7 暂时保留。

如果手上只有一片，先只能验证前 8 个键；不要把第二片的 5 路压力线并到第一片的通道上。

## PMOD1 数字引脚

原理图第 19 页把 PMOD1 标成连接器 **J8**。`J8 pin 11` 不是一根叫
`J8-11` 的信号线，而是 J8 器件的第 11 个管脚；实物模块上的 `CLK/OUT/DIN/CS`
才是需要接线的信号名称。PMOD1 在原理图中位于 PMOD0（J9）的下方。

下面的分配与 NEO Dock 31004/Rev1.4 的 `J8`（PMOD1）约束一致。表中的 FPGA 引脚是芯片脚号，接线时以底板丝印和排针编号为准。

| 模块信号 | PMOD1 信号名 | FPGA 引脚 | MCP3208 模块端 |
|---|---|---:|---|
| MCP1 时钟 | `PMOD1_IO0` | Y21 | `CLK/SCLK` |
| MCP2 时钟 | `PMOD1_IO1` | Y22 | `CLK/SCLK` |
| MCP1 输出 | `PMOD1_IO2` | AB21 | `OUT/DOUT/MISO` |
| MCP2 输出 | `PMOD1_IO3` | AB22 | `OUT/DOUT/MISO` |
| MCP1 输入 | `PMOD1_IO4` | AA20 | `DIN/MOSI` |
| MCP2 输入 | `PMOD1_IO5` | AA21 | `DIN/MOSI` |
| MCP1 片选 | `PMOD1_IO6` | AA19 | `CS/SHDN` |
| MCP2 片选 | `PMOD1_IO7` | AB20 | `CS/SHDN` |

按 PDF 图面方向，J8 的信号脚排列为：左侧从上到下 `11/IO0、9/IO2、7/IO4、5/IO6`，
右侧从上到下 `12/IO1、10/IO3、8/IO5、6/IO7`；`1/2` 是 +3V3，`3/4` 是 GND。
实物从背面观察时左右会反过来，不能只按“左边第一脚”猜测。

当前版本按左右两列分配：MCP1 使用 `IO0/IO2/IO4/IO6`，MCP2 使用 `IO1/IO3/IO5/IO7`。两片模块完全不共用物理导线。

## 供电和模拟线

1. 两片模块的 `VDD/VCC` 接稳定的 **3.3 V**，`GND` 接 NEO Dock 的 `GND`。FPGA、两片 ADC、13 个 FSR 模块必须共地。
2. `VREF` 接模块要求的参考电压。若模块有独立 `VREF` 引脚，当前工程按 3.3 V 参考设计；不能悬空，也不能超过 `VDD`。
3. 每个 FSR 模块的 `S` 只接一个 MCP3208 `CHx`，不要把两个 `S` 并在一起。FSR 模块输出必须保持在 `0…VREF` 内。
4. 先确认成品模块的逻辑电平。MCP3208 芯片本身支持 2.7～5.5 V，但部分淘宝模块带 5 V 电平转换或把 VCC 标成 5 V；若 `DOUT` 可能输出 5 V，不能直接接 FPGA 的 LVCMOS33 输入。
5. 断电后再插拔 PMOD。上电前用万用表确认 `VCC-GND`、`VREF-GND` 和每个 `S-GND` 的电压范围。

## 13 键通道顺序

| 键编号 | 音名 | ADC 来源 |
|---:|---|---|
| 1 | C4 | MCP0-CH0 |
| 2 | C#4 | MCP0-CH1 |
| 3 | D4 | MCP0-CH2 |
| 4 | D#4 | MCP0-CH3 |
| 5 | E4 | MCP0-CH4 |
| 6 | F4 | MCP0-CH5 |
| 7 | F#4 | MCP0-CH6 |
| 8 | G4 | MCP0-CH7 |
| 9 | G#4 | MCP1-CH0 |
| 10 | A4 | MCP1-CH1 |
| 11 | A#4 | MCP1-CH2 |
| 12 | B4 | MCP1-CH3 |
| 13 | C5 | MCP1-CH4 |

程序每轮扫描两片各 8 个通道，再把 13 个有效通道送入压力矩阵。默认按“按压后 ADC 数值下降”处理，因为之前的 FSR 分压实验就是这个方向；如果串口观察到按压后数值上升，把顶层参数 `ACTIVE_LOW_MASK` 改为 `13'd0` 后重新综合。

## 下载顺序

1. 上电前全部 FSR 松开，先只接两片 MCP3208 的数字线和电源，确认没有 5 V 进入 FPGA。
2. 打开 `gowin/mcp3208_13key_hdmi.gprj`，顶层应为 `mcp3208_13key_hdmi_top`。
3. 综合并生成 `mcp3208_13key_hdmi.fs`，烧录 SRAM。
4. 复位后等待约 30 ms 的松开基线校准。PMOD0 的 LED7 常亮表示 SPI 首轮采样、校准和音频启动均完成；LED0～LED6 是最大压力档位。
5. 校准期间不要按压任何键。校准结束后逐个轻按，HDMI 画面对应柱子升高，耳机声音随压力增大而变响。
6. 如果所有柱子都是 0 或满格，先看 SPI 线序（尤其 `DIN/DOUT`、两根 `CS`）和模块的 VREF；再根据串口 `R/P/G/V/S` 判断扫描、校准和门控状态。

## 工程入口

- 顶层：`rtl/board/mcp3208_13key_hdmi_top.sv`
- SPI 扫描：`rtl/io/mcp3208_dual_scan.sv`
- 13 键处理：`rtl/control/pressure_key_matrix.sv`
- HDMI 显示：`rtl/video/pressure_keys_ui_1024x600.sv`
- 约束：`gowin/mcp3208_13key_hdmi.cst`
- 构建脚本：`scripts/build.ps1 -Target mcp3208_13key_hdmi`
