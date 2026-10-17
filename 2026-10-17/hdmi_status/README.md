# HDMI 状态页与显示链路验证

目录里是 `video_timing.sv`、`tmds_encoder.sv`、`dvi_tx.sv`、`video_pll.sv`、
`pressure_audio_ui_1024x600.sv`、`pressure_keys_ui_1024x600.sv`，以及两个顶层。

## 为什么要做这个

压力采样和四声部音频都上了之后，上板调试变成一件很别扭的事：只听声音，我分不清系统现在是
在扫 SPI、在等校准、已经就绪，还是 ADC 故障了。全都表现成"没声音"或者"声音不对"。

所以加一块 1024×600 的状态页：顶部状态条、左侧压力柱、右侧实际音量柱、按键指示。把"猜声音"
换成"看状态"。

时序参数用的是 1344×635 的总时序，水平 `1024 + 160 + 20 + 140`、垂直 `600 + 12 + 3 + 20`，
同步信号低有效。PLLA 从 50 MHz 产生 51.25 MHz 像素时钟和 256.25 MHz 串行时钟，刷新率约
60.06 Hz。这个参数接近常见 1024×600 面板用的 51.2 MHz。

视频域是像素时钟，ADC/SPI/音频是 50 MHz 系统时钟。视频域只读已经同步好的帧快照，不直接去
读 SPI 的采样总线或音频包络。不然画面会随机抖，而且这种 bug 很难查——它不在任何一个时钟
域里，在两个之间。

## 闪屏的三个版本

这是这一天真正的内容。

第一次是初版（位流 SHA256 以 `4A4A...` 开头）。下载上去，屏幕上电后持续闪屏。

第二次是 HPD 修正版（`F4AD...`）。该版本将 K13（HDMI HPD 控制）固定拉高，以处理热插拔
检测信号。实测仍然持续闪屏。

第三次改用官方 DVI TX IP 并调整 VCCX：

1. 改用 Sipeed 官方 60K `cam_dvi` 示例里的 Gowin DVI TX IP，通道顺序也照它来——
   CLKOUT0 给 256.25 MHz 串行时钟，CLKOUT1 给 51.25 MHz 像素时钟。
2. VCCX 从工具默认的 3.3 V 改成 1.8 V。官方 NEO Dock 工程要求 1.8 V，功耗报告确认修改后
   VCCX 为 1.800 V。

PLLA 参数是 `MDIV=10.25`、`ODIV0=4`、`ODIV1=20`。厂商原语手册里 `MDIV_FRAC_SEL=2` 表示
0.25，所以目标频率是 51.25 / 256.25 MHz；Gowin 的静态报告会把分数反馈倍频按整数部分显示成
50 / 250 MHz；该差异来自报告对分数反馈倍频的显示方式。

还有一个一直存在的警告 `PR1014`（`sys_clk_d` 使用通用时钟布线）。它是警告，不是这几次闪屏的
原因。

到这一步仍然没有确认成功。`HARDWARE_TEST.md` 里 1024×600 那张表每一项都还是"待测"。

所以我另外做了一块 800×600@60 Hz 的标准彩条位流，里面没有 ADC、没有音频、没有非标准时序，
目的就是把问题范围切开：

- 彩条稳定、1024×600 闪 → HDMI 物理链路是好的，问题在 1024×600 的时序参数，得按屏幕控制板
  的实际型号调整；
- 两个都闪 → 优先查屏幕供电、HDMI 线、板卡 HDMI 物理链路。

排查的时候屏幕单独用一个稳定的 5 V 电源，只接 HDMI 视频线，先把触摸 USB 拔掉。

还顺手做了个 `usb_touch_probe` 目标：用 NEO Dock USB-A2 的 `H13/G13`，把屏幕枚举出来，
通过串口打印 VID、PID、接口和端点信息。构建是通的。但它只负责识别设备，还没有去读触摸
报告。拿到屏幕的 HID 报告格式之后才谈得上把坐标接进界面。

## 验证

本目录只做了编译：

```powershell
vlib work
vlog -sv dvi_tx.sv pressure_audio_hdmi_top.sv pressure_audio_hdmi_touch_probe_top.sv pressure_audio_ui_1024x600.sv pressure_keys_ui_1024x600.sv tmds_encoder.sv video_pll.sv video_timing.sv
```

Errors: 0, Warnings: 0。

`video_pll.sv` 里面用的是 Gowin 的 `PLLA` 原语，DVI 输出那边还有 `OSER10`、`TLVDS_OBUF`。
这些原语需要在 Gowin 工程中完成综合和布局布线，普通 ModelSim 仅用于 HDL 编译检查。

## 本目录验证等级

- `[本次重跑]` `vlog -sv` 编译：Errors 0, Warnings 0（仅编译。Gowin 原语无法在 ModelSim 中仿真）
- `[导入记录·未复现]` 三个版本的实测过程、VCCX 1.8 V 的功耗报告、`PR1014` 警告、以及 800×600 彩条位流。均来自原始工程记录，本次未重跑。
- `[未验证]` HDMI 显示至今没有确认工作。最终候选版是否解决闪屏，`HARDWARE_TEST.md` 里仍是"待测"。
- `[未验证]` 屏幕控制板兼容性、USB 触摸数据接入。
