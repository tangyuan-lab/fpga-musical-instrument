# 2026-10-21：鼓组音源、四声部共享引擎与工作站音频

## 当日内容

合并鼓组单独试听与桶鼓激励合成、四声部共享音源候选及工作站音频链路。把试听工程依赖的钢琴参数 ROM、四声部 Gowin 工程和工作站公共模块放在同一发布批次，便于按天推送和定位依赖。

## 主要目录

| 路径 | 内容 |
| --- | --- |
| `handoff/kick_audition/`、`handoff/snare_audition/`、`handoff/clap_audition/` | 底鼓、军鼓和拍手试听 |
| `handoff/hihat_audition/`、`handoff/rimshot_audition/`、`handoff/sidestick_audition/` | 踩镲、边击和侧棒试听 |
| `handoff/excitation_v3/` | 桶鼓激励合成候选及查表数据 |
| `handoff/mem/` | 正弦表、钢琴接受系数及鼓音参数 ROM |
| `handoff/poly4_opt/`、`handoff/shared/`、`handoff/single_voice/` | 四声部优化、共享引擎和单声部基线变体 |
| `handoff/piano_drums_poly4_shared.gprj` | 四声部共享 Gowin 工程 |
| `v5/board/`、`v5/io/` | 工作站板级顶层、压力输入、UART、触摸输入和遥测 |
| `v5/audio/`、`v5/common/` | 音频链路、公共逻辑及多声部合成 |
| `v5/gowin/` | 工作站 Gowin 工程、脚本和约束 |

鼓试听与共享引擎是不同工程变体，不应把目录中的所有 RTL 一次性合并编译。按目标 `.gprj` 的文件清单选择源文件；独立试听候选没有各自的 `.gprj`，但本批包含它们引用的钢琴参数 ROM。rimshot 的板级约束文件位于 `handoff/rimshot_audition/`。


## 验证状态

- ModelSim 10.6d 对记录中的 90 个鼓试听/激励 Verilog/SystemVerilog 文件执行 `vlog -sv`：Errors 0，Warnings 0。
- 六种鼓试听和激励工程没有配套 testbench，未进行功能仿真；没有记录本批鼓试听工程的独立 Gowin 综合或上板验证。
- 四声部主工程 24 个 Verilog 文件通过 ModelSim 10.6d 编译：Errors 0，Warnings 0。修复后的 Gowin 综合、布局布线和 FIR 映射检查尚未重跑。
- 工作站音频模块的分组结果及其限制见本批原始记录；不同架构变体不能直接合并编译。

上述编译结果只覆盖语法和模块声明，不代表功能仿真、综合或硬件试听通过。板卡历史状态见 `handoff/BOARD_STATE.md`；其中实际下载日期仍按记录保留。
