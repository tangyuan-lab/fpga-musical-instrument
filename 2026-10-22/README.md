# 2026-10-22：完整工程依赖归档与验证

承接 [10 月 21 日发布](../2026-10-21/README.md) 的鼓组、四声部共享音源和工作站音频链路，本批补齐原项目的源码层级、ROM、测试、构建脚本、上位机、串口屏和许可证，提供可继续开发的工程入口。

## 今天做了什么

相较于 10 月 21 日发布的鼓组音源、四声部共享引擎和工作站音频链路，本次发布进一步增加以下内容：

| 方向 | 前一天已发布 | 今天新增或推进 |
| --- | --- | --- |
| 电脑端编曲与校谱 | 工作站板级、输入输出和音频 RTL | 新增 `v5/host_app/`：中文工作区、MusicXML/MIDI 导入、五线谱与钢琴卷帘、小节校正、参考试听和工程保存 |
| 演奏控制与曲谱播放 | 压力输入、UART 和音频合成模块 | 增加 `v5/rtl/control/`、`v5/rtl/midi/` 等模块，补齐模式控制、曲谱解析与播放调度，以及上位机资源交互代码 |
| 串口屏交互 | 已有通信接口及相关 RTL | 新增可编辑 HMI、页面与事件生成源码，提供基线与 V2 两套屏幕工程入口 |
| 四声部工程可复现性 | 已有 `.gprj` 和部分音源文件，但目录层级与工程引用不对应 | 补齐主工程引用的 `src/poly4_shared/`、约束、公共模块及测试脚本，26 个工程输入全部可定位，严格源码检查通过 |
| 验证与问题修复 | 主要记录 RTL 编译结果 | 增加键盘映射、整数规则、I2S 三项基础仿真；修正 I2S 测试重复计数误报；V5 主机测试 113 项通过、1 项跳过，界面布局检查 6 项通过 |

本次发布从音源与音频链路继续推进到电脑端编曲校谱、设备演奏控制和串口屏工程。上述“新增”以相较于前一天公开内容为准；综合、布局布线和整机上板的待验收项见 [本次验证](VERIFICATION.md)。

## 工程入口

| 方向 | 入口 | 用途 |
| --- | --- | --- |
| 四声部共享音源 | `handoff/piano_drums_poly4_shared.gprj` | Tang Mega 鼓组、钢琴共享音源；保留 `src/` 和 `integration/` 层级 |
| 工作站基线 | `v5/gowin/instrument_workstation.gprj` | 压力键、串口屏、板载 PT8211 |
| 工作站 V2 | `v5/gowin/instrument_workstation_v2.gprj` | V2 合成与标准 I2S DAC；音频接法与基线不同 |
| 上位机 | `v5/README.md` | 环境安装、中文编曲校谱、工程编辑与参考试听 |
| 串口屏 | `v5/screen/TJC1060X570/` | HMI、页面事件源码及工具；使用官方 USART HMI 编译 |

`handoff/` 与 `v5/` 各自保留原工程结构。两者是不同架构，使用目标工程自己的文件清单；本次目录整合尚未把两套 RTL 接成统一整机。

## 开始验证

在 `handoff/` 中：

```powershell
python scripts/check_project.py --strict-source
python scripts/run_tests.py --suite basic
```

第二条需要安装 Icarus Verilog，可通过 `--iverilog-dir` 指定位置。本次基础测试实际使用 ModelSim 10.6d 执行相同的三个 testbench。

在 `v5/` 中，先按该目录 README 建立虚拟环境并安装 `requirements.txt`，再运行：

```powershell
python -m unittest discover -s tests -q
python scripts/test_workstation_v2.py
python scripts/test_midi_tracks.py
python scripts/test_track_audio.py
python scripts/verify_v5_layout.py
```