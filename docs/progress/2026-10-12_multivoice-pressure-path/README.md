# 2026-10-12：多声部与压力输入链路

## 目标

在 2026-10-09 的单音声部基础上，接出可以承载压力键盘的输入链路和四声部输出，同时让每个边界都能单独验证。

这一阶段没有把"多声部"写成一个孤立的演示，而是沿着真实信号链路分成四个增量：双声部与四音循环、MCP3208 双片扫描、压力键事件、四声部合成。每个增量都留了自己的顶层和 testbench，便于追溯设计为什么改。

## 里程碑

### 1. 双声部和四音循环

先把混音做成独立一级。`rtl/audio/audio_mixer_4ch.v` 在更宽的累加器里求和，最后统一缩放和饱和；直接截断会在满和弦时发生二补码回绕。`tb_step4.sv` 检查的正是混音不会截断仍在发声的另一个声部：双键同时按下、只松开其中一个时，另一个必须继续输出。

四音循环版在单声部基础上加了音符选择：`rtl/audio/dds_sine_voice_select.v` 每次按键取下一个音，A4 → B4 → C5 → D5 → A4，相位步进由顶层按当前音给出。输出多了一级 `audio_gain`（GAIN_SHIFT=1，约 +6 dB），`tb_step5.sv` 验证四音顺序、相位连续和放大后仍不削波。

两套顶层都保留：它们代表"多声部怎么做"的两种取舍，一起留着才看得出为什么最后选了混音加声部池。

### 2. MCP3208 双片 SPI 扫描

两片 MCP3208 共用 SCLK 和 MOSI，各自使用独立 MISO。扫描器每次转换发 24 个 SPI 时钟，16 个通道扫完后拉高 `frame_valid`。`tb_mcp3208_scan.sv` 验证命令帧在 SCLK 上升沿可被读取，以及恒定 MISO 输入能按通道顺序被捕获。

保留两根 MISO 而不是共用一根，是因为成品模块的 DOUT 在 CS 拉高时能否可靠释放没有实测证据，多一根输入线换取明确的电气边界。

扫描器只产生 16 个 12 位采样和 `frame_valid`，不判断"哪个键按下"。这样 SPI 命令、通道顺序和压力判断可以分别验证；ADC 返回全零时也不会被误判成按键逻辑错误。

### 3. 压力键矩阵

`rtl/input/pressure_key_matrix.sv` 把采样转成按下、松开和 8 位力度：先采 64 帧基线，再算 `baseline - current`，经过一阶低通后用 16/8 的按下和松开迟滞，最后映射到 0～255。没有新采样时主动清除门控状态，避免 ADC 或 SPI 掉线造成卡音。`rtl/input/button_filter.sv` 负责迟滞和滤波，`rtl/input/snapshot_cdc.sv` 把采样快照安全交给音频时钟域。

压力模块上有过 S 脚达到 3.3 V 的过压风险。这个问题发生在 ADC 转换之前，不能靠 RTL 缩放解决；上板前必须确认模块处于模拟模式，供电和 S 脚电压满足 ADC 输入范围。

### 4. 四声部

`rtl/polyphony/voice_allocator_4.sv` 管理最多四个活动音符，第五个事件需要抢占一个声部；`rtl/polyphony/poly_synth_voice.sv` 保存每个声部独立的相位和包络；`rtl/polyphony/poly_synth_4voice.sv` 用保护位累加并在末端饱和。波形不走波表，直接由相位高位折叠成三角波，所以每个声部不占块 RAM。`rtl/polyphony/audio_startup.sv` 负责上电静音，避免功放打开时把未初始化数据送出去。

## 结果

| 项目 | 结果 | 验证方式 |
| --- | --- | --- |
| 双声部混音 | ModelSim PASS | 本机已跑，`day03/run_step4.do` |
| 四音循环与增益 | ModelSim PASS | 本机已跑，`day03/run_step5.do` |
| MCP3208 命令与捕获路径 | ModelSim PASS | 本机已跑，`day03/run_scan.do` |
| 压力键矩阵 | ModelSim PASS | 本机已跑，`unit/pressure_key_matrix` |
| 上电静音 | ModelSim PASS | 本机已跑，`unit/audio_startup` |
| 四声部分配 | ModelSim PASS | 本机已跑，`unit/voice_allocator_4` |
| 四音循环顶层综合与时序 | Gowin 通过，100.733 MHz | 本机已跑 |
| 双声部顶层综合与时序 | Gowin 通过，79.748 MHz | 本机已跑 |
| 四声部引擎资源 | 综合完成，1255 LUT / 8 DSP / 0 BSRAM | 本机已跑，仅综合 |
| 四声部引擎布局布线 | 未通过，`PA2024` 端口数超限 | 未完成 |
| 13 键 + 两片 ADC + 四声部整机 | 尚未完成 | 未验证 |

其余 7 个模块（`reset_sync`、`snapshot_cdc`、`button_filter`、`onchip_adc_scan`、`pressure_tone`、`poly_synth_voice`、`poly_synth_4voice`）的单元测试还在补，通过后会加到上面的表里。

资源与时序的完整记录见 `docs/metrics/resource-scaling.md`。

## 可复现验证

集成仿真在 `sim/` 下执行，`$readmemh` 的路径按这个工作目录写的：

```powershell
cd sim
vsim -c -do day03/run_step4.do
vsim -c -do day03/run_step5.do
vsim -c -do day03/run_scan.do
```

单元测试每个模块一个目录，在各自目录下执行：

```powershell
cd sim\unit\pressure_key_matrix
vsim -c -do run_pressure_key_matrix.do
```

综合直接从 `constr/` 下的工程文件打开：

| 工程 | 顶层 | 约束 |
| --- | --- | --- |
| `constr/tang_mega_60k_audio.gprj` | `tang_mega_60k_top` | `tang_mega_60k.cst` |
| `constr/tang_mega_60k_cycle.gprj` | `top_step5_cycle_plus6db` | `tang_mega_60k.cst` |
| `constr/tang_mega_60k_dual.gprj` | `top_step4_dual_voice` | `tang_mega_60k_dual.cst` |
| `constr/poly_synth_4voice.gprj` | `poly_synth_4voice` | 无（只做综合） |

## 已知问题和下一步

- 四声部引擎的相位步进表按 48,828.125 Hz 计算，而那正是 2026-10-09 修掉的那个采样率。接上 48 kHz 的帧节拍之前必须按 48 kHz 重算这 13 个常数，否则每个音都会低约 29 音分。
- 四声部引擎没有板级顶层，`voice_levels`、`voice_phase_steps` 这些观察用的输出总线在综合时全被当成对外端口，布局布线报 `PA2024`（386 个端口超过器件可用的 273 个）。要上板得先写顶层，把观察信号收进内部或缩减宽度。
- `onchip_adc_scan` 的单元测试用行为模型替代了 Gowin 的 `ADC_SAR` 原语，只覆盖扫描控制逻辑，不覆盖原语本身的时序。
- `PRESS_FULL=2048` 是发布阶段参数，还需要真实 FSR 曲线确认。
- 四声部尚未在两片 ADC 到货后上板，资源、时序、声部分配和输入到输出的实际延迟都还没有硬件数据。
- 下一步进入钢琴近似音色和真实 A4 采样对照，继续记录片上 RAM 与 Fmax 的变化。
