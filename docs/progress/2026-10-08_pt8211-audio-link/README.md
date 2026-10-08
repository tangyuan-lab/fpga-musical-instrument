# 2026-10-08：PT8211 音频出口

## 这一天做了什么

只做音频输出这一环：50 MHz 时钟、复位、PT8211-S 串行输出、NS4263 功放启动时序。
没有音源、没有按键、没有音色。

先做音频输出，是因为它是整条音频链路上唯一的出口，所有音源都要从这里出去，它错了就全白做。
而它的正确性又正好能脱离音源单独判定：不需要按键、不需要音源，只看 BCK/WS/DIN 三根线上的
位序和边沿。

正弦波还得去数点。音源部分就这么两行：

```verilog
if (frame_tick) sample <= -sample;   // 每个采样帧换一次正负
```

## 音频接口格式：这里是 PT8211-S，不是标准 I2S

总览 README 写的是 I2S。这块底板上的芯片是 **PT8211-S**，它接受的是 **LSBJ / 右对齐**格式：

- 一帧 32 个 BCK 周期，左右声道各 16 位
- MSB 先发，16 位二补码
- 数据在 BCK 下降沿改变、上升沿被采样
- `ws` 低电平是右声道，高电平是左声道

这**不是标准 I2S 的一位延迟格式**。

## 端口与引脚

| 端口 | 方向 | 引脚 | 说明 |
| --- | --- | --- | --- |
| `sys_clk` | in | V22 | 50 MHz，LVCMOS33 |
| `sys_rst_n` | in | AA13 | 低有效，LVCMOS15，内部上拉 |
| `HP_BCK` | out | Y17 | 位时钟 |
| `HP_WS` | out | AB17 | 声道选择 |
| `HP_DIN` | out | AA16 | 串行数据 |
| `PA_EN` | out | AB16 | 功放使能，高电平为关 |

引脚约束在 `constr/tang_mega_60k.cst`，50 MHz 时钟约束在 `constr/tang_mega_60k.sdc`。

## 验证方法

在 `sim/` 下执行：

```powershell
cd sim
vsim -c -do run_pt8211_tx.do
```

testbench 逐位解码**实际的 PT8211 引脚**（BCK/WS/DIN），不是看内部 PCM 线。它检查：

- 每个 BCK 周期是否为 80 个时间单位；
- `ws` 在低 16 位是 0、高 16 位是 1；
- `din` 是否按 MSB 先发逐位等于期望值；
- **跨帧样本保持**：在第 0 帧第 7 位中途改 `sample_in`，第 0 帧仍须发旧值、第 1 帧才发新值；
- 拉低复位后三根线是否回到 `1/0/0`。

testbench 把参数缩到 `CLK_HZ=128, SAMPLE_HZ=1`，真实参数下一帧要 1041 个时钟，缩了之后
几十微秒跑完，而且完全确定。

## 验证结果

- **仿真：通过。** `PASS: PT8211 protocol, sample hold and reset`，Errors 0，Warnings 0。
- **综合与布局布线：通过。** Gowin V1.9.12.03，器件 GW5AT-60B，顶层 `tang_mega_60k_top`。
  50 MHz 约束下 setup/hold 违规端点 0/0，TNS 0.000，Fmax 130.872 MHz，逻辑级数 6。
  布局布线报了一条 `PR1014`，说 `sys_clk_d` 走了通用时钟布线，不是失败原因。

## 证据

- `2026-10-08_pt8211-serial-waveform.png` / `.ps`：ModelSim 波形。信号从上到下是 `clk`、
  `rst_n`、`sample_in`（固定 `16'h1234`）、`bck`、`ws`、`din`、`frame_tick`，时间轴
  0–16000 ns。可以看出一帧 32 个 BCK 周期、`ws` 每 16 位翻转一次、`din` 的位模式和
  `sample_in` 的 `1234` 一致。
- 重新导出波形：`cd sim` 后执行 `vsim -gui -do wave_pt8211_tx.do`。
- 资源与时序摘要见 `docs/metrics/resource-scaling.md`。


## 下一步

接 DDS 单音正弦波，并把采样率修准。
