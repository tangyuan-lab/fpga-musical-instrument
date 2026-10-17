# 采样存储边界与 DDR3 接口自检

这一目录把采样来源从播放器中拆开，并验证外部存储接口的基本行为。播放器只处理播放位置、长尾、松键和快速重触发；存储模块负责同步地址/数据访问。

## 设计

- `piano_a4_sample_store.v` 提供前段 72,001×16 位和尾段 41,367×8 位采样的同步读取接口。
- `sampled_piano_a4.v` 通过该接口播放 A4，不依赖具体的 ROM 实现。
- 读取时序为 50 MHz 下一拍返回地址对应的数据。将来替换成 DDR3 时，预取和缓存由存储模块承担，播放器接口保持不变。

## Gowin 工程

打开 `tang_mega_60k_sample_store.gprj` 可载入本目录的音频顶层、RTL 和约束。工程使用 GW5AT-60B，采样数据从 `mem/` 下的两个 ROM 文件初始化。当前工程仍是片上 ROM 播放版本；DDR3 控制器没有接入播放路径，`ddr3_selftest.v` 只用于仿真自检。

## 可重跑验证

```powershell
vsim -c -do run_sample_store.do
```

该测试检查四次长尾 A4 按键、左右声道一致、松键和复位静音。输出与连续性实验的参考输出逐字节一致：

```text
SHA256 = 494CBFA8AB2574F6FC6C82C8D6E2C5F6BB6CDF84382F23CAEBFE945CF3EB7777
```

```powershell
vsim -c -do run_ddr3.do
```

DDR3 mock 测试覆盖两个 128 位 BL8 数据往返、故意翻转数据的错误检测和校准超时看门狗，结果为：

```text
PASS: DDR3 command sequence, two 128-bit round trips, mismatch and calibration timeout
```

## 验证边界

历史综合记录为 Fmax 62.888 MHz、104/118 BSRAM、3/118 DSP，未在当前环境重跑。真实 DDR3 的初始化、校准、带宽和预取缓存仍需在 Gowin 工程与开发板上验证；当前播放器仍从片上 ROM 读取 A4。
