# 电脑端构建验证记录

日期：2026-09-23（MIDI 目标最终重建）

## 已通过

- `tb_pressure_control`：基线、触发/释放迟滞和压力到音量映射通过。
- `tb_pressure_key_matrix`：13 路独立校准、四键同时按下、单键释放、抗抖和 ADC 掉线静音通过。
- `tb_poly_synth_4voice`：13 个半音查表、四音和弦、第五键抢占、独立释音和混音限幅通过。
- `tb_13key_audio_path`：13 路假 ADC 压力到四声部音频输出的完整链路通过。
- `tb_polyphony_demo_top`：Cmaj7、Fmaj7、G7、Am7 自动轮播顺序和四声部分配通过。
- `tb_polyphony_timbre_demo_top`：AA13/AB13 双功能键消抖、双音色往返切换和LED状态通过。
- `tb_pressure_tone`：起音、力度跟踪、释音和安全幅值通过。
- `tb_pressure_audio_path`：轻按峰值 472，重按峰值 4085，松开后归零。
- `tb_pt8211_tx`：左右各 16 bit 的 PT8211 帧和采样周期通过。
- `tb_snapshot_cdc`：系统时钟域到像素时钟域的状态快照传输通过。
- `tb_video_1024x600`：完整一帧 853440 个像素、有效区、同步脉宽、界面颜色和 TMDS 编解码通过。
- `audio_smoke`：Gowin 综合、布局布线、位流生成通过，Setup/Hold 违例端点 0/0。
- `pressure_audio`：Gowin 综合、布局布线、位流生成通过，Setup/Hold 违例端点 0/0。
- `pressure_audio_hdmi`：Gowin 综合、布局布线、位流生成通过，Setup/Hold 违例端点 0/0。
- `hdmi_colorbar_800x600`：Gowin 综合、布局布线、位流生成通过，Setup/Hold 违例端点 0/0；
  功耗报告确认 VCCX 为 1.800 V。
- `usb_touch_probe`：Tang Mega 60K 全速 USB Host、VexRiscv 和串口探针构建通过，
  Setup/Hold 违例端点 0/0，VCCX 为 1.800 V；资源为 Logic 2555、Register 1066、
  BSRAM 36/118、PLLA 1/8。
- `polyphony_demo`：四声部自动和弦试听工程构建通过，Setup/Hold 违例端点 0/0；
  Logic 1023/59904、Register 313/60780、MULTALU27X18 4 个。
- `polyphony_timbre_demo`：四声部双音色试听工程构建通过，Setup/Hold 违例端点 0/0；
  Logic 1387/59904、Register 384/60780、MULTALU27X18 8 个。
- 最终工程日志没有 `ERROR` 条目，引脚报告与 CST 一致。

## 最终压力工程资源

- Logic：749 / 59904（报告显示 2%）。
- Register：334 / 60780（小于 1%）。
- `MULTALU27X18`：2。
- `ADC_SAR`：1。

## HDMI 压力音频工程资源

- Logic：1165 / 59904（2%）。
- Register：489 / 60780（小于 1%）。
- `MULTALU27X18`：2。
- `OSER10`：3。
- `PLLA`：1 / 8。
- `ADC_SAR`：1 / 1。
- HDMI 数据差分对：J14/H14、J15/H15、K17/J17；时钟差分对：G15/G16。

## FPGA 内 MIDI 播放工程

目标：`gowin/midi_player.gprj`；最终位流：`build/ready-to-program/midi_player_sram.fs`。

电脑端已通过：

- `tb_midi_type0_parser`：MIDI Type 0 头、PPQN、Tempo、Running Status、Note On/Off 和 velocity=0 Note Off。
- `tb_midi_type0_parser_sync`：同步 SDPB 读口延迟下的解析流程。
- `tb_midi_type0_parser_64k`：大于 255 字节的轨道长度拼接正确，且恰好 65536 字节时不会在 `0xffff` 后回绕到文件开头。
- `tb_midi_player_scheduler`：Tempo 调度和三次 Note On/Note Off 事件。
- `tb_midi_player_top`：完整顶层的 FILE_BEGIN/FILE_DATA/FILE_END/PLAY 握手，确认
  `PLAY` 延后一拍后仍能启动 FPGA 内 MIDI 解析器，并验证 ACK 丢失后的同序号 MIDI 块不会重复写入。
- Python 上位机协议测试：CRC、分块重组、坏帧处理、MIDI 文件头、上传/播放语义和示例文件生成校验。
- FTB CRC、ADSR 参数、256 点波表写入和同序号数据块安全重试测试。

Gowin 最终构建已通过：

- Setup violated endpoints：`0`。
- Hold violated endpoints：`0`。
- Logic：`17124/59904`（29%）。
- Register：`12323/60780`（21%）。
- BSRAM：`42/118`（36%）。
- DSP：`13/118`（12%）。
- I/O：`16/297`（6%）。
- Device：`GW5AT-LV60PG484AC1/I0`，Device Version B。

`PR1014` 通用时钟布线提示仍存在，但不产生 Setup/Hold 违例；首次上板仍需观察板卡稳定性。

## 位流哈希

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

midi_player_sram.fs
SHA256 019DC8BC1CF157728FDAD79893352EF226CE382B57E8162465099C5B8C70A295

instrument_full_sram.fs
SHA256 5644FD6C7F8D130149DCD6B0583D89AE956923774AFE5B4806E124D68DE69A5F
```

## 已知构建提示

布局布线会报告 `PR1014`：`sys_clk_d` 使用通用时钟布线。各目标（包括 `midi_player`）均完成时序分析且
Setup/Hold 违例端点为 0。这个提示也出现在先前能工作的 60K 工程中，但最终结论仍以
真实板卡的固定音和压力演奏测试为准。

HDMI 的 PLLA 参数为 `MDIV=10.25`、`ODIV0=4`、`ODIV1=20`。厂商原语手册规定
`MDIV_FRAC_SEL=2` 表示 0.25，因此实际目标频率是 51.25/256.25 MHz。修正版按
Sipeed 官方 60K `cam_dvi` 工程的通道顺序使用 CLKOUT0 作为 256.25 MHz 串行时钟、
CLKOUT1 作为 51.25 MHz 像素时钟，并将 K13 HDMI HPD 控制固定拉高。当前 Gowin
静态报告把分数反馈倍频按整数部分显示为 50/250 MHz。最坏逻辑频率报告仍为
65.306 MHz，高于 51.25 MHz，且布局布线后的 Setup/Hold 违例端点为 0/0。

实机闪屏排查后，最终版进一步改用 Sipeed 官方 `cam_dvi` 中的 Gowin DVI TX IP，并把
VCCX 从工具默认的 3.3 V 修正为官方 NEO Dock 工程要求的 1.8 V。功耗报告确认最终构建的
VCCX 为 1.800 V；DVI IP 的 OSER10 上电复位只在屏幕锁定前变化，对该单次 recovery 路径
进行了定向豁免，其余视频和音频时序继续检查且 Setup/Hold 违例端点为 0/0。

## 尚未由电脑端证明

- 耳机是否实际听到固定测试音。
- NEO Dock 模拟功放与当前耳机的实际响度。
- 当前 FSR 的轻按、重按范围是否正好匹配 16/224 默认阈值。
- 连续运行 10 分钟的实机稳定性。
- 当前 1024×600 HDMI 控制板是否能锁定 1344×635、约 60.06 Hz 的时序。
- USB-C 与 FPGA 的双向 UART 实物通信是否稳定。
- 真实 MIDI 文件是否能在板上完成上传、解析、四声部播放和断开电脑后继续播放。
- 自定义 FTB 音色及长时间 MIDI 播放的耳机听感与稳定性。

## V13 整合演示工程（TJC 串口屏）

目标：`gowin/instrument_full.gprj`；顶层：`instrument_full_top`；位流：
`build/ready-to-program/instrument_full_sram.fs`。

本轮运行的 21 项 RTL 测试全部以 `PASS` 结束。整合顶层包含实时 MCP3208/13 键压力路径、
MIDI 子系统和 C18/C19 的 TJC/Nextion 风格串口屏；HDMI 状态快照宽度为 146 bit，
AB13 切换模式，AA13 切换实时音色。串口屏使用 C18/C19、115200/8N1，并发送 `t0`～`t15`
文本控件的状态和压力值。

当前 C18/C19 位流的 Gowin 构建（2026-10-09 17:49）结果：

- Setup violated endpoints：`0`。
- Hold violated endpoints：`0`。
- Logic：`22615/59904`（38%）。
- Register：`14771/60780`（25%）。
- CLS：`16825/29952`（57%）。
- BSRAM：`46/118`（39%）。
- DSP：`19/118`（17%）。
- I/O：`35/297`（12%）。
- PLLA：`1/8`。
- Device：`GW5AT-LV60PG484AC1/I0`，Device Version B。
- SHA256：`5644FD6C7F8D130149DCD6B0583D89AE956923774AFE5B4806E124D68DE69A5F`。

整合工程的时序修复均为实际 RTL 流水或缓存：MIDI 文件 RAM/Tempo 同步读寄存、音频
波形和力度乘法流水、UART 应答帧缓存与逐字节 CRC、FTB 暂存区固定复制、MIDI 音高常量
查表、MIDI 文件暂存区固定 128 字节复制、音色上传帧接受流水、PLAY 锁存事件数量，以及
释音槽同步读取后比较到期 tick，以缩短可变选择及写使能路径。没有用全局 false path
豁免这些功能路径。`PR1014` 为 `sys_clk_d` 通用时钟布线提示。

输出引脚报告确认 `screen_tx_o=C18`、`screen_rx_i=C19`，均为 LVCMOS33。
2026-10-09 17:50 已通过 USB Debugger A/0、15 MHz JTAG 执行 **SRAM Program**，目标
`GW5AT-60B(0x0001481B)`；编程进度 100%、`Finished`、退出码 0，耗时 14.33 秒。
记录见 `build/ready-to-program/instrument_full_sram.program.log`。烧录后
`python -m host_app.cli ping --port COM15` 返回 `ACK nonce=0x3BD9CA30`，退出码 0。

此次电脑端验证包括仿真、静态时序、实际 SRAM 下载与 USB-C PING；屏幕实际显示及触摸
尚未验证，配套 USART HMI 工程需按屏幕完整型号创建 `t0`～`t15`、字库并配置 115200。

