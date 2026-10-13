# FPGA 实时多音色合成电子乐器引擎

基于 Tang Mega 60K + Dock 的 FPGA 实时音频合成项目，目标是在 FPGA 内完成音符控制、振荡器、ADSR 包络、多声部混音和 I2S 音频输出。

> 当前阶段：Day04 钢琴近似音色与音量调整，ModelSim 验证已完成。

## 最新演示

- 当前版本：Day04 本地功能分支
- 当前进度：项目 Day04；本日完成钢琴近似音色、提亮和音量调整三个阶段
- 下一里程碑：真实 A4 采样与片上存储边界

## 系统架构

```text
输入与交互
    │
    ▼
按键消抖 / 音符映射
    │
    ▼
DDS 振荡器 → ADSR 包络 → 多声部混音 → 饱和处理 → I2S 发送 → 板载音频输出
```

第一版正式数据流将在 Day 5 架构评审后冻结；接口变化必须通过 Issue 和 PR 记录。

## 当前进度

| 里程碑 | 状态 | 验证证据 |
| --- | --- | --- |
| GitHub 协作体系 | 准备提交 | `CONTRIBUTING.md`、Issue/PR 模板 |
| 单音 DDS 仿真 | 已完成 | Day02 分支和进度记录 |
| PT8211 音频链路 | 已完成 | Day01 分支和进度记录 |
| ADSR | 已完成 | Day02 分支和进度记录 |
| 4 复音与混音 | 已完成 | Day03 分支和进度记录 |
| 钢琴近似音色 | 待审核 | `day04/` 与本阶段进度记录 |

详细记录见 [`docs/progress/README.md`](docs/progress/README.md)。

## 赛题要求对应

| 要求 | 计划实现 | 证据位置 |
| --- | --- | --- |
| 至少两个独立交互维度 | 音符触发 + 力度/音量控制 | 压力输入与音色声部代码 |
| 完整音频链路由 FPGA HDL 实现 | 控制、DDS、ADSR、混音、PT8211 均使用 RTL | `rtl/` 与阶段文档 |
| 延迟不超过 10 ms | 从输入事件到有效音频输出进行实测 | 指标表，待测 |
| 基础复音数不少于 4 | 四个独立相位、频率和包络声部 | Day03 多声部 RTL |
| 禁止播放预录 PCM | 逐样本实时计算音频 | Day04 钢琴声部说明 |

## 核心指标

| 指标 | 当前结果 | 验证方法 |
| --- | --- | --- |
| 采样率 | 48 kHz | PT8211 仿真与 RTL 参数 |
| 位深 | 16 bit | PT8211 串行输出 |
| 独立复音数 | 4 | 四声部 RTL 与 testbench |
| 输入到音频延迟 | 待测，目标不超过 10 ms | 逻辑分析仪或示波器 |
| LUT / FF / DSP / BRAM | 待综合 | Gowin 资源报告 |
| 时序余量 | 待综合 | Gowin 时序报告 |

资源扩展记录见 [`docs/metrics/resource-scaling.md`](docs/metrics/resource-scaling.md)。不以无用逻辑填满器件；每项资源消耗必须能对应有效复音、吞吐量、音质或效果。

## 团队分工

| 角色 | 主要职责 | 姓名 |
| --- | --- | --- |
| 成员 A / 负责人 | 系统架构、时钟复位、I2S、顶层集成、代码审核 | 待填写 |
| 成员 B | DDS、波表、ADSR、复音与混音 | 待填写 |
| 成员 C | 按键与交互、测试、指标记录和仓库展示 | 待填写 |

## 文档导航

- [协作规范](CONTRIBUTING.md)
- [开发进度](docs/progress/README.md)
- [资源与性能扩展表](docs/metrics/resource-scaling.md)
- [新功能 Issue 模板](.github/ISSUE_TEMPLATE/01-feature.md)
- [问题 Issue 模板](.github/ISSUE_TEMPLATE/02-bug.md)
- [测试 Issue 模板](.github/ISSUE_TEMPLATE/03-test.md)
- [Pull Request 模板](.github/PULL_REQUEST_TEMPLATE.md)

## 复现状态

工程尚未进入 RTL 开发阶段。Day 5 接口冻结后补充 Gowin 版本、器件型号、工程打开方式、约束文件和从干净 Clone 开始的编译步骤。

## 开发纪律

- 开始任务前创建 Issue；一个分支只处理一个 Issue。
- 禁止直接向 `main` 提交开发代码。
- PR 至少由另一名成员审核，由负责人使用 Merge Commit 合并。
- 提交必须包含真实修改和验证证据，禁止空提交和截止前一次性上传。
- 自动生成缓存、临时日志、许可证、个人绝对路径和大视频不得进入 Git 历史。


