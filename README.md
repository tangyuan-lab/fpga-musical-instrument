# 芯弦：FPGA 多音色交互演奏与教学系统

芯弦 R6 集成 16 键压力演奏、钢琴／吉他／Bass 共享 32 声部合成、曲谱播放与跟弹教学、效果处理，以及 USB、串口屏和蓝牙交互。

本版 **R6 `0x5c9cde6a`** 完成屏幕协议与业务分层、ADC 采样事务拆分及控制路径优化。**本版已完成上板功能测试，运行正常。** 源工程完成综合、四阶段布局布线及 FS 位流生成。

## 项目功能

| 功能 | 实现内容 |
| --- | --- |
| 压力演奏 | 16 键压力输入，分别处理起音力度与持续压力，接入音量、音高及音色控制逻辑 |
| 多音色合成 | 钢琴、吉他与 Bass 共享 32 个声部槽，统一管理音符身份、声部状态及渲染任务 |
| 音频处理 | ADSR、阻尼、延迟、混响、合唱、主增益与限幅处理 |
| 曲谱与教学 | 支持 DDR3 曲谱存储、曲谱播放、逐音跟弹与键位提示 |
| 控制与显示 | USB／串口屏提供递进控制，HC-05 提供参数控制与状态回读，串口屏呈现状态、波形、频谱与李萨如图形 |
| 钢琴递进 | 按 MIDI 音高 48～79 顺序调度钢琴起音，依据引擎完成反馈推进计数，并处理保持与统一清音 |

## 系统架构与关键实现

```text
压力键盘 ───────────────┐
USB / 串口屏 / HC-05 ──┼─→ 事件解析、会话管理与命令仲裁
DDR3 曲谱 → 播放调度 ──┘                │
                                      ▼
                           音符身份与 32 声部控制
                                      │
                                      ▼
                          钢琴 / 吉他 / Bass 共享合成
                                      │
                                      ▼
                           效果 → 主增益 → 限幅
                                      │
                                      ▼
                           PT8211 / 标准 I2S 输出
                                      │
                                      └─→ 波形、频谱与屏幕状态
```

### 共享声部与音源计算

三种音色共用 32 个声部槽和共享模态渲染后端，各声部独立保存音符身份与状态。钢琴沿用 64 模态计算结构；音频链路采用 50 MHz 控制时钟和 48 kHz 采样配置，输出为 16 位双通道接口。

### 基于引擎反馈的递进调度

递进控制器区分“请求接收”和“执行完成”：起音事务先经过 `ready` 握手，再由引擎的 `done/result` 返回推进完成数。默认起音请求间隔参数为 100 ms，32 次成功完成后进入 2 s 保持阶段，再通过公共清音链结束演示。USB 与匹配协议的串口屏提供递进入口。

递进演示按序触发 32 个音符。共享合成引擎另有 32 个声部槽，用于保存各声部的音符身份与状态。顶层 RTL 仿真在缩短的演示等待参数下检查了 32 个声部槽同时活跃和混音输出。

### 屏幕请求与原子状态

屏幕控制使用请求号、会话号和来源归属匹配一次演示。启动、保活和停止均关联对应请求；状态帧携带构建身份、能力、阶段、完成数和快照序号。发送器在同一时刻锁存整帧数据，由屏幕在完整快照提交后统一更新显示。

### 控制路径结构优化

蓝牙会话与请求比较采用显式分组归约树。声部控制器在空闲状态预采样事务数据，并在事务处理期间保持。模态后端在既有预取时点采样按键保持状态，将声部选择与后续衰减计算分离，保持控制语义和数据对齐关系清晰。

## 本版变化与设计优点

对照版本：R6 `0x0b02fc49` → R6 `0x5c9cde6a`。

| 方向 | 本版实现 | 设计优点 |
| --- | --- | --- |
| 屏幕协议与业务分层 | 拆分帧解析、触键业务、事件分发、命令适配、显示服务、页面字段和指令编码 | 各模块分别管理协议、业务状态与显示握手，职责清晰 |
| 二进制串口发送 | 独立帧发送模块，分离协议字节生成与 UART 握手 | 字节推进与实际发送完成对应 |
| 压力采样事务 | MCP3208 SPI 事务独立封装 | 采样调度与物理事务分别管理，便于核对采样时序 |
| 控制路径优化 | 调整计数器宽度、比较结构、预采样及固定声部字槽写入 | 缩短控制组合路径，明确取消、提交与数据归属 |
| 工程组织 | 生产 HDL 从 88 个增至 97 个，保留多音色共享引擎 | 以独立模块承接协议、显示、采样和发送职责 |
| 实现成果 | 交付同版本工程、FS、原生综合与布局布线记录、时序报告和引脚表 | 源码、实现产物和验证资料按构建标识关联 |

## 验证与实现成果

以下结果对应 R6 `0x5c9cde6a`。详细记录见[验证索引](2026-11-07/FPGA_BT_PIANO32_R6_5c9cde6a/docs/verification.md)和[上板功能测试](2026-11-07/FPGA_BT_PIANO32_R6_5c9cde6a/docs/board_test.md)。

| 项目 | 结果 |
| --- | --- |
| 上板功能测试 | 本版已完成上板功能测试，运行正常 |
| 功能仿真 | 12 项通过，覆盖声部计数、触键、屏幕语义、蓝牙等价、边界时限、渲染等价和顶层交互 |
| 检查有效性 | 4 项定向反例命中指定断言，覆盖急停、屏幕取消、代次身份和混音输出 |
| Gowin 综合 | 完成，进程退出码 0 |
| 布局布线与 FS | 四阶段 routing 和位流生成完成，进程退出码 0 |
| Setup | 报告路径无负 slack，最差 **+0.029 ns** |
| Hold | 报告路径无负 slack，最差 **+0.133 ns** |
| Recovery | 报告路径无负 slack，最差 **+4.036 ns** |
| Removal | 报告路径无负 slack，最差 **+0.256 ns** |
| 版本一致性 | 149 项生产输入校验通过，源工程与交付 FS 按记录关联 |
| 工程迁移检查 | 两次原生 CLI 打开与导出保存通过，核对 75 项选项和 97 项生产 HDL |

## 下载与工程使用

**[下载本版 Release](https://github.com/tangyuan-lab/fpga-musical-instrument/releases/tag/r6-5c9cde6a)** · [源码 ZIP](https://github.com/tangyuan-lab/fpga-musical-instrument/releases/download/r6-5c9cde6a/R6_5c9cde6a_source.zip) · [FS 位流](https://github.com/tangyuan-lab/fpga-musical-instrument/releases/download/r6-5c9cde6a/R6_5c9cde6a_UserCode000063F0.fs) · [验证资料](https://github.com/tangyuan-lab/fpga-musical-instrument/releases/download/r6-5c9cde6a/R6_5c9cde6a_verification.zip) · [附件校验值](https://github.com/tangyuan-lab/fpga-musical-instrument/releases/download/r6-5c9cde6a/SHA256SUMS.txt)

| 项目 | 配置／入口 |
| --- | --- |
| Gowin 工程 | [workstation_r6_piano32_bt.gprj](2026-11-07/FPGA_BT_PIANO32_R6_5c9cde6a/workstation_r6_piano32_bt.gprj) |
| 目标器件 | `GW5AST-LV138PG484AC1/I0`，C 版 |
| 工具与顶层 | Gowin FPGA Designer V1.9.12.03；`mega138_models8_top` |
| 音频配置 | 50 MHz 控制时钟，48 kHz 采样配置，32 声部，16 位双通道 |
| 生产文件 | [sources.json](2026-11-07/FPGA_BT_PIANO32_R6_5c9cde6a/sources.json)，97 个生产 HDL |
| 约束与引脚 | [CST](2026-11-07/FPGA_BT_PIANO32_R6_5c9cde6a/constraints/workstation.cst)、[SDC](2026-11-07/FPGA_BT_PIANO32_R6_5c9cde6a/constraints/workstation.sdc)、[引脚表](2026-11-07/FPGA_BT_PIANO32_R6_5c9cde6a/docs/pinout.csv) |
| 构建身份 | RTL BUILD `0x5c9cde6a`；FS UserCode `0x000063F0` |
| 构建工具 | [build.tcl](2026-11-07/FPGA_BT_PIANO32_R6_5c9cde6a/build.tcl)、[pnr.tcl](2026-11-07/FPGA_BT_PIANO32_R6_5c9cde6a/pnr.tcl) |
| 校验与仿真 | [源码校验](2026-11-07/FPGA_BT_PIANO32_R6_5c9cde6a/scripts/check_project.py)、[测试入口](2026-11-07/FPGA_BT_PIANO32_R6_5c9cde6a/scripts/run_tests.py) |
| 使用说明 | [编译、仿真与 SRAM Program](2026-11-07/FPGA_BT_PIANO32_R6_5c9cde6a/docs/usage.md) |
| 工程追溯 | [构建身份](2026-11-07/FPGA_BT_PIANO32_R6_5c9cde6a/build_identity.json)、[来源清单](2026-11-07/FPGA_BT_PIANO32_R6_5c9cde6a/PACKAGING_ORIGIN.json)、[发布清单](2026-11-07/FPGA_BT_PIANO32_R6_5c9cde6a/SOURCE_MANIFEST.json) |

完整解压源码包，在 Gowin FPGA Designer 中打开工程文件。使用工程内配置、源文件与约束构建，或从 Release 下载对应 FS，通过 Gowin Programmer 的 SRAM Program 入口加载。

## 配套资料

- [系统架构](2026-11-07/FPGA_BT_PIANO32_R6_5c9cde6a/docs/architecture.md)
- [验证与实现记录](2026-11-07/FPGA_BT_PIANO32_R6_5c9cde6a/docs/verification.md)
- [上板功能测试](2026-11-07/FPGA_BT_PIANO32_R6_5c9cde6a/docs/board_test.md)
- [钢琴递进屏幕协议](2026-11-07/FPGA_BT_PIANO32_R6_5c9cde6a/PIANO32_SCREEN_PROTOCOL_V1.md)
- [上一版 R6 0x0b02fc49](https://github.com/tangyuan-lab/fpga-musical-instrument/tree/f19f394c6c1c1204e6af43227d5878a972893449/2026-11-04/FPGA_BT_PIANO32_R6)
