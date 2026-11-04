# 电脑端构建和仿真记录（2026-09-18）

这份记录覆盖电脑端仿真和构建结果。板级表现需要通过开发板测试确认，下面分别列出仿真、综合和
板级测试范围。

## 一、仿真通过的（当时那台机器上跑的）

- `tb_pressure_control`：基线、触发/释放迟滞、压力到音量的映射。
- `tb_pressure_key_matrix`：13 路独立校准、四键同时按下、单键松开、阈值抗抖、
  **ADC 掉线时静音**。
- `tb_poly_synth_4voice`：13 个半音查表、四音和弦、第五键抢占、独立释音、混音限幅。
- `tb_13key_audio_path`：13 路假 ADC 的压力一路走到四声部音频输出。
- `tb_polyphony_demo_top`：Cmaj7、Fmaj7、G7、Am7 的自动轮播顺序和四声部分配。
- `tb_polyphony_timbre_demo_top`：AA13/AB13 两个功能键的消抖、双音色往返切换和 LED 状态。
- `tb_pressure_tone`：起音、力度跟踪、释音、幅值安全。
- `tb_pressure_audio_path`：轻按峰值 **472**，重按峰值 **4085**，松开后归零。
- `tb_pt8211_tx`：左右各 16 bit 的 PT8211 帧和采样周期。
- `tb_snapshot_cdc`：系统时钟域到像素时钟域的状态快照传输。
- `tb_video_1024x600`：完整一帧 **853440** 个像素、有效区、同步脉宽、界面颜色和
  TMDS 编解码。

**这些 testbench 和它们的运行脚本没有随工程留下来**，所以在这个仓库里一条都重跑不了。
本仓库里能重跑的是另一批（TangMega 主线那 15 个），见 `docs/VERIFICATION.md`。

## 二、Gowin 综合 / 布局布线 / 位流（同样没重跑）

以下每个目标都是"综合、布局布线、位流生成通过，Setup/Hold 违例端点 0/0"：

`audio_smoke`、`pressure_audio`、`pressure_audio_hdmi`、`hdmi_colorbar_800x600`、
`usb_touch_probe`、`polyphony_demo`、`polyphony_timbre_demo`。

其中 `hdmi_colorbar_800x600`、`usb_touch_probe` 的功耗报告确认 VCCX 为 **1.800 V**。

最终工程日志没有 `ERROR` 条目，引脚报告和 CST 一致。

### 资源占用

| 工程 | Logic | Register | 其它 |
|---|---|---|---|
| `pressure_audio` | 749 / 59904（2%） | 334 / 60780（<1%） | `MULTALU27X18` 2、`ADC_SAR` 1 |
| `pressure_audio_hdmi` | 1165 / 59904（2%） | 489 / 60780（<1%） | `MULTALU27X18` 2、`OSER10` 3、`PLLA` 1/8、`ADC_SAR` 1/1 |
| `usb_touch_probe` | 2555 | 1066 | BSRAM 36/118、PLLA 1/8 |
| `polyphony_demo` | 1023 / 59904 | 313 / 60780 | `MULTALU27X18` 4 |
| `polyphony_timbre_demo` | 1387 / 59904 | 384 / 60780 | `MULTALU27X18` 8 |

HDMI 数据差分对：J14/H14、J15/H15、K17/J17；时钟差分对：G15/G16。

### 位流哈希（这份记录里有，但在这个仓库里核对不了）

```text
audio_smoke_sram.fs
SHA256 836125F068DFBF3E9C2A35A4C4717EB464149EBEDA4BE358AC8CFA9F92566551

pressure_audio_sram.fs
SHA256 6EBF78E6E120564DD44573E0DDB32535CA77995067BEB93D72121A99561F2F76

pressure_audio_hdmi_sram.fs
SHA256 8AED70A688ABA7A9F8E61B6EB231F696C8EB1A5C9B4682DAC0F63B55A5076857

hdmi_colorbar_800x600_sram.fs
SHA256 BA7AE7559C20B5662955D5B27398BDF7752A55368331F34CEC5AD0BFB336B08B

usb_touch_probe_sram.fs
SHA256 6CA5D5D1F10284A8E7833AB2C1C55B79D59C9A7F41E10FF3C16B956FB5C95537

polyphony_demo_sram.fs
SHA256 FA744422972029BE88CECB75FF6D8CEBF37180068DCBBAAB0E9FCD7CD1E45A3A

polyphony_timbre_demo_sram.fs
SHA256 57B96C2C3CB257548341CFC2EBF5FA586063352E3F1DCCA561469A51B1992FCE
```

位流文件（`.fs`）没有提交，因此这些哈希无法在当前仓库核对。重新综合会生成新的位流哈希；哈希
只用于确认文件内容是否一致，设计正确性仍由综合、时序和硬件测试确认。

## 三、一直存在的那个警告

布局布线会报 `PR1014`：`sys_clk_d` 使用通用时钟布线。

该提示从第一个工程就存在，也出现在**后来上板成功**的工程中。三个目标均完成时序分析且违例
端点为 0。通用时钟布线会带来额外的延迟和偏斜，最终需结合板上的固定音和压力演奏判断。

## 四、HDMI 的三个版本

PLLA 参数是 `MDIV=10.25`、`ODIV0=4`、`ODIV1=20`。厂商原语手册里 `MDIV_FRAC_SEL=2` 表示
0.25，所以目标频率是 **51.25 / 256.25 MHz**。Gowin 的静态报告会把分数反馈倍频按整数部分
显示成 50 / 250 MHz；该差异来自报告对分数反馈倍频的显示方式。

修正版按 Sipeed 官方 60K `cam_dvi` 工程的通道顺序来：CLKOUT0 作 256.25 MHz 串行时钟，
CLKOUT1 作 51.25 MHz 像素时钟，并把 K13（HDMI HPD 控制）固定拉高。最坏逻辑频率报告
65.306 MHz，高于 51.25 MHz，布局布线后违例端点 0/0。

实机闪屏排查之后，最终版又换成了官方 `cam_dvi` 里的 **Gowin DVI TX IP**，并把 **VCCX 从
工具默认的 3.3 V 改成官方 NEO Dock 工程要求的 1.8 V**。功耗报告确认最终构建的 VCCX 是
1.800 V。

DVI IP 的 `OSER10` 上电复位只在屏幕锁定前变化，所以对这条单次 recovery 路径做了定向豁免，
其余视频和音频时序继续检查，违例端点 0/0。

**但这一整套都没有把屏幕点亮。** 见 `HARDWARE_TEST.md`。

## 五、电脑端证明不了的

- 耳机里到底有没有声音。
- NEO Dock 的模拟功放配当前耳机，实际响度是多少。
- 当前这颗 FSR 的轻按/重按范围是不是正好匹配 16/224 那组默认阈值。
- 连续跑 10 分钟稳不稳。
- 手上这块 1024×600 屏幕控制板到底能不能锁定 1344×635、约 60.06 Hz 的时序。

这五项属于板级测试范围，需要连接开发板确认。
