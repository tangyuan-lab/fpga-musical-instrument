# 2026-10-22：完整工程依赖归档与验证

承接 [10 月 21 日发布](../2026-10-21/README.md) 的鼓组、四声部共享音源和工作站音频链路，本批补齐原项目的源码层级、ROM、测试、构建脚本、上位机、串口屏和许可证，提供可继续开发的工程入口。

## 今天做了什么

- 整理 `TangMega60K_Handoff_20261019/source` 的 248 个文件到 `handoff/`。
- 按 `fpga-music-workstation-v5/SOURCE_MANIFEST.json` 收录 521 个文件，并保留原清单，共 522 个文件到 `v5/`。原有历史校验报告已在清单内。
- 19 个 Gowin 工程逐一检查文件引用，未发现缺失；V5 收录时的 521 个原文件 SHA256 全部匹配；发布时对行尾属性与对应清单做了可追溯调整。
- 重跑四声部主工程编译和基础仿真，修正一处 I2S 测试的计数方式。详见 [本次验证](VERIFICATION.md)。

**这一天的工作量是完整源码整理、依赖补齐和复核。770 个来源文件约 31.4 MB，多数为已有文件，不代表一天新开发了这些功能。** 昨日目录继续保留，后续开发优先使用本批完整目录。

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

## 发布边界

原文件中的 10 月 19 日和历史版本号保留，它们标识来源快照。原 `RELEASE_CHECKS.json`、报告中的通过记录属于历史结果；本次结果以 [VERIFICATION.md](VERIFICATION.md) 为准。

本批提供源码和项目资源；固件归档、旧位流、Gowin/ModelSim 安装器、官方屏幕模板及第三方可选音源需按各项目说明准备。最新 Gowin 综合、布局布线、时序和整机上板验收仍待完成。不能将编译或主机测试通过写成硬件验收通过。

[INVENTORY.json](INVENTORY.json) 记录来源文件与发布哈希，修订包括 `handoff/sim/tb_i2s_tx_16.sv` 的测试采样方式，以及两项目的 `.gitattributes` 与 V5 对应清单哈希。两项目关闭各自归档目录的 Git 行尾自动转换，以保持清单哈希在推送后有效；原始清单另存为 `v5_SOURCE_MANIFEST.original.json`。两个原始目录均未修改。[project_references.json](project_references.json) 记录全部工程引用检查结果。
