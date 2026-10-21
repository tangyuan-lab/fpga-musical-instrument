# FPGA 实时音频乐器工程

基于 Tang Mega 60K + Dock，包含实时谐波波表合成与 A4 录音对照实验，音频由 FPGA 输出至 PT8211。

## 内容与入口

| 日期 | 内容 | 入口 |
| --- | --- | --- |
| 2026-10-13 | 钢琴近似音色、提亮、琴槌噪声评估与音量调整 | [开发记录](docs/progress/2026-10-13_piano-timbre-tuning/README.md) |
| 2026-10-16 | A4 音色对照、长尾衔接与快速重触发 | [工程说明](2026-10-16/README.md) |
| 2026-10-17 | 采样存储边界、DDR3 mock、HDMI 状态页与发布验证 | [工程说明](2026-10-17/README.md) |
| 2026-10-21 | 鼓组试听、四声部共享音源、工作站音频链路与 Gowin 工程 | [工程说明](2026-10-21/README.md) |

`2026-10-13/` 使用周期谐波波表实时生成声音。`2026-10-16/` 播放真实录音 PCM，作为音色和连续性的对照实验；赛题实时合成方案使用前者。

## 运行与验证

2026-10-16 的三个 ModelSim 入口已重跑通过，包括音源交替、长尾交接和快速重触发。运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\2026-10-16\run_all.ps1
```

脚本自动在英文临时路径执行，适配本机 ModelSim 10.6d。各实验目录包含 RTL、ROM、testbench、仿真入口和试听材料。

Gowin 工程位置：

- 实时合成：`2026-10-13/gowin/tang_mega_60k_audio.gprj`。
- A4 对照：`2026-10-16/ab_compare/2026-10-16_audio.gprj`。
- 长尾交接：`2026-10-16/long_tail/2026-10-16_audio.gprj`。
- 快速重触发：`2026-10-16/retrigger/2026-10-16_audio.gprj`。

各工程均附引脚与时钟约束。本次整理尚未重新运行 Gowin 综合；资源数据与历史板上反馈见对应说明。

## 文档

- [本次验证结果](2026-10-16/VERIFICATION.md)
- [开发进度](docs/progress/README.md)
- [2026-10-13 资源摘要](docs/metrics/2026-10-13-resource-summary.md)
- [2026-10-16 资源摘要](docs/metrics/2026-10-16-resource-summary.md)
- [采样署名与许可证](2026-10-16/ATTRIBUTION.md)
- [本次 PR 描述](docs/PR_2026-10-16_AUDIO_CONTINUITY.md)

后续工作为存储接口拆分与外部存储验证。
