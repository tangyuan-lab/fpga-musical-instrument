# 上板验收记录

## 1. 固定音频通路

- 位流：`build/ready-to-program/audio_smoke_sram.fs`
- 预期：下载后约 100 ms，左右耳机声道持续输出低音量 A4。
- 失败定位：先核对器件型号和 Y17/AB17/AA16/AB16 约束，再检查耳机插头是否完全插入。

| 项目 | 结果 | 备注 |
|---|---|---|
| SRAM Program 显示 Finished | 通过 | 2026-09-18 用户实测 |
| 能听到稳定测试音 | 通过 | 2026-09-18 用户实测 |
| 无明显持续爆音 | 通过 | 固定音测试成功 |

## 2. FSR 力度控制

- 位流：`build/ready-to-program/pressure_audio_sram.fs`
- 上电条件：FSR 完全松开，等待 LED7 常亮。

| 项目 | 结果 | 备注 |
|---|---|---|
| LED7 常亮 | 通过 | 2026-09-18 用户实测 |
| 轻按开始发声 | 通过 | 2026-09-18 用户实测 |
| 加大压力后更响 | 通过 | 2026-09-18 用户实测 |
| 松开后快速且平滑静音 | 通过 | 2026-09-18 用户实测 |
| LED0～6 随压力变化 | 通过 | 2026-09-18 用户实测 |
| 连续运行 10 分钟无异常 | 待测 | |

## 3. UART 定标

分别记录三种状态下的 `P` 值，若当前默认阈值不合适，再据此调整：

| 状态 | P 最小值 | P 最大值 |
|---|---:|---:|
| 完全松开 | | |
| 轻按 | | |
| 最大安全按压力度 | | |

## 4. 1024×600 HDMI 显示

- 工程：`gowin/pressure_audio_hdmi.gprj`
- 位流：`build/ready-to-program/pressure_audio_hdmi_sram.fs`
- 上电条件：屏幕已供电并接好 HDMI，FSR 完全松开。

| 项目 | 结果 | 备注 |
|---|---|---|
| SRAM Program 显示 Finished | 待测 | |
| 屏幕稳定显示且无滚动、闪烁 | 待测 | |
| 就绪后顶部状态条变绿 | 待测 | |
| 左侧压力柱随按压力度变化 | 待测 | |
| 右侧音量柱平滑起落 | 待测 | |
| 按下时中央方块变绿 | 待测 | |
| HDMI 工作时耳机力度控制仍正常 | 待测 | |

初版（SHA256 以 `4A4A...` 开头）和 HPD 修正版（以 `F4AD...` 开头）实测仍持续闪屏。
最终候选版改用官方 Gowin DVI TX IP，并把 VCCX 从错误的 3.3 V 改为 NEO Dock 要求的
1.8 V，待使用 SHA256 以 `8AED...` 开头的新位流复测。

若屏幕无信号，先确认烧录的是 `pressure_audio_hdmi_sram.fs`，再重新插拔 HDMI 并重启
屏幕控制板。耳机仍能受 FSR 控制，说明 ADC 和音频链路正常，问题可以限定在显示时序或
屏幕控制板兼容性。

## 5. HDMI 标准彩条排障

- 位流：`build/ready-to-program/hdmi_colorbar_800x600_sram.fs`
- 该工程不包含 ADC 和音频，只产生 VESA 800×600@60 Hz 彩条。
- 上电条件：屏幕用独立稳定的 5 V 电源供电，只接 HDMI 视频线，暂时不接触摸 USB。

| 项目 | 结果 | 备注 |
|---|---|---|
| SRAM Program 显示 Finished | 待测 | |
| 彩条与白色边框稳定显示 | 待测 | |
| 连续显示 2 分钟无闪烁 | 待测 | |

判断方法：若本彩条稳定而 1024×600 版本闪烁，则需要根据屏幕控制板型号调整 1024×600
时序；若本彩条也闪烁，则问题更可能在屏幕供电、HDMI 线或板卡 HDMI 物理链路。
## 6. FPGA 内 MIDI 文件播放（V11）

- 工程：`gowin/midi_player.gprj`
- 位流：`build/ready-to-program/midi_player_sram.fs`
- SHA256：`019DC8BC1CF157728FDAD79893352EF226CE382B57E8162465099C5B8C70A295`
- 串口：NEO Dock 板载 USB-C，115200/8N1

电脑端和 RTL 验证已经通过；以下表格只记录真实板卡验收，不把仿真或综合结果冒充实测：

| 项目 | 结果 | 备注 |
|---|---|---|
| `ping` 收到 FPGA ACK | 待测 | 需要确认板载 USB-C 对应 COM 口及 RX/TX 线 |
| 小型 Type 0 MIDI 文件完整上传 | 待测 | `FILE_BEGIN/DATA/END` 均需收到 ACK |
| `PLAY` 后 FPGA 自行解析并听到旋律 | 待测 | 播放期间电脑不发送 PCM |
| 四声部和弦能够同时输出 | 待测 | 使用 `examples/midi/02_four_voice_chords.mid` |
| 三角波/方波切换 | 待测 | `--timbre 0/1` |
| FTB 单周期音色上传并播放 | 待测 | `--timbre 2`，先完成 `upload-ftb` |
| 拔掉电脑后已上传文件继续播放 | 待测 | 重新上电后需重新上传 |
| 连续播放 10 分钟无异常 | 待测 | 记录卡音、爆音、复位和 UART 错误 |

建议的首次命令：

```powershell
python -m host_app.cli ping --port COMx
python -m host_app.cli send-midi --port COMx examples\midi\01_single_note.mid
python -m host_app.cli play --port COMx --timbre 0
python -m host_app.cli status --port COMx
```

耳机先放在桌面上并将系统音量调低；确认音频链路后再佩戴。

## 7. V12 整合演示工程

- 工程：`gowin/instrument_full.gprj`
- 位流：`build/ready-to-program/instrument_full_sram.fs`
- SHA256：`1426249812C77E2F1132B7E4DE17C9339D13CA615C1DAE3B7419CE71D4E1A9C7`
- 模式键：AB13；实时音色键：AA13；UART RX：V14；UART TX：U15。

电脑端 19 项 RTL 测试、综合、布局布线和 Setup/Hold `0/0` 已完成。以下是实际板卡
验收项目，当前仍应逐项填写：

| 项目 | 结果 | 备注 |
|---|---|---|
| 默认实时模式能完成 MCP3208 校准 | 待测 | 13 个 FSR 全部松开后复位 |
| HDMI 压力柱和模式状态稳定 | 待测 | 屏幕独立 5 V 供电 |
| AB13 切换到 MIDI 模式 | 待测 | 画面状态应改变 |
| `ping` 收到 FPGA ACK | 待测 | 115200/8N1 |
| 小型 MIDI 文件上传并由 FPGA 播放 | 待测 | 电脑不发送 PCM |
| 四声部和弦同时输出 | 待测 | 使用 `02_four_voice_chords.mid` |
| 三角波/方波及 FTB 音色 | 待测 | 低音量开始 |
| 连续运行 10 分钟无异常 | 待测 | 记录卡音、爆音、复位 |

