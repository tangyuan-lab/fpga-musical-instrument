# V12 `instrument_full` 使用记录

## 版本结果

`instrument_full` 是当前用于整合演示的 Gowin 工程：默认实时读取两片 MCP3208 的 13 个压力键，按 AB13 切换到 FPGA 内 MIDI 播放模式；HDMI 显示状态，PT8211 输出音频，UART 负责接收完整 MIDI/FTB 文件和控制命令。

最终位流：

```text
build/ready-to-program/instrument_full_sram.fs
SHA256 1426249812C77E2F1132B7E4DE17C9339D13CA615C1DAE3B7419CE71D4E1A9C7
```

Gowin 最终检查：Setup/Hold `0/0`；器件 `GW5AT-LV60PG484AC1/I0`，Device Version B。

## 上板顺序

1. 先只接 PT8211/耳机、PMOD1 的 MCP3208 和 HDMI，FSR 全部松开。
2. 打开 `gowin/instrument_full.gprj`，确认器件和 Device Version B，执行 SRAM Program。
3. 默认实时模式下，等待 MCP3208 校准完成；HDMI 显示压力柱，LED 按压力状态变化。
4. 按 AB13，画面切换到 MIDI 模式；电脑通过板载 USB-C 对应的 UART 发送文件。
5. 先发送最小文件，再测试四声部和弦：

```powershell
python -m host_app.cli ports
python -m host_app.cli ping --port COMx
python -m host_app.cli send-midi --port COMx examples\midi\01_single_note.mid
python -m host_app.cli play --port COMx --timbre 0
python -m host_app.cli status --port COMx
```

AA13 只改变实时模式的三角波/柔和方波；MIDI 模式音色由 `play --timbre 0/1/2` 选择。

## 引脚速查

- UART：TX `U15`，RX `V14`。
- PT8211：BCK `Y17`，WS `AB17`，DIN `AA16`，功放使能 `AB16`。
- 模式键：AB13；实时音色键：AA13。
- PMOD1：MCP1 使用 IO0/IO2/IO4/IO6，MCP2 使用 IO1/IO3/IO5/IO7；精确 FPGA 封装引脚以 `gowin/instrument_full.cst` 为准。
- HDMI：沿用 NEO Dock 已验证的差分约束，HPD `K13` 固定有效。

## 验证边界

19 项 RTL 仿真、综合、布局布线和时序检查已通过。当前仍需用户在真实板卡上确认 USB-C 双向通信、两片 MCP3208 的实际接线/电平、真实 MIDI 耳机播放、自定义 FTB 听感以及长时间运行稳定性；这些项目不能用电脑端仿真结果替代。
