# Issue 草稿：实现钢琴近似音色与音量调整

## 目标

将项目 Day03 的压力驱动四声部扩展为项目 Day04 的钢琴近似音色。Day04 内部整合来源工程 阶段一～阶段五，并记录各阶段的频谱、音量和板上反馈。

## 工作范围

- 三张周期谐波表的实时钢琴近似声部；
- 提亮音色 v2；
- 琴槌噪声版的撤回记录；
- 最终音量调整；
- 对应 testbench、ModelSim 脚本、试听 WAV 和 PCM 证据；
- README、阶段进度和验证等级更新。

## 验收条件

- `run_timbre_v1.do`、`run_timbre_bright.do`、`run_volume_final.do` 和 `run_hammer_withdrawn.do` 可从各自目录执行；
- 四个版本的 ModelSim testbench 均输出 PASS；
- README 记录音色结构、峰值变化、Fmax 来源和硬件待测项；
- 不提交 Gowin 缓存、临时日志、位流或个人路径。

## 证据

- `day04/day04_timbre_v1/`、`day04/day04_timbre_bright/`、`day04/day04_volume_final/` 和 `day04/gowin/`；
- `docs/progress/2026-10-13_piano-timbre-tuning/README.md`；
- `docs/metrics/resource-scaling.md`。

