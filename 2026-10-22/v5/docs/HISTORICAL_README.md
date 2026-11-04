# Tang Mega 60K：FPGA 实时多音色电子乐器

## V2 上下位机联动工作站

V2 上位机入口为 start_workstation_v2.bat，源码为 host_app/workstation_gui.py。它管理曲谱、单周期音色、分段配器和设备目录；播放期间声音只在 FPGA 合成。

V2 FPGA 工程为 gowin/instrument_workstation_v2.gprj，构建命令见 scripts/build_workstation_v2.ps1。

V2 使用标准 Philips I2S：BCK/WS/DIN 为 T21/U21/P16，应连接外置标准 I2S DAC。板载 PT8211-S 是右对齐格式，不能作为标准 I2S 验收依据。完整边界见 docs/WORKSTATION_V2_STATUS.md。

## 工作站：三模式＋独立实体键设置

新工程为 `gowin/instrument_workstation.gprj`，屏幕源码为
`screen/TJC1060X570/generated/instrument_workstation/instrument_workstation.HMI`。
包含鼓点、弹琴、混音及逐键设置；屏幕键固定对应本模式的声音，实体键保存三套独立映射。
音源、映射、模式和通用PCM混音接口分别管理，注册表为 `config/instrument_registry.json`。
设置操作、扩展方法、命令编号和编译下载见 [工作站说明](docs/WORKSTATION.md)。
HMI源码检查及RTL仿真已通过，官方TFT编译和实物演奏仍待验证；可下载位流以构建脚本时序门槛为准。

```powershell
python scripts/verify_workstation.py
scripts/build.ps1 -Target instrument_workstation
```

## 当前 16 键串口屏工程

使用 `gowin/instrument_touch16.gprj` 和 `screen/TJC1060X570/generated/instrument_touch16/instrument_touch16.HMI`。
新增两片 MCP3208 的完整 16 通道、实时 ADSR、按下/松开动画、88 类和弦识别、持续音八度切换和四频测试模式。
音源目前为四声部；多指触摸能力仍需屏幕硬件确认。屏幕工程仍需官方 USART HMI 编译下载。
板内耳机音频沿用 PT8211 匹配格式，C18/C19 串口接线不变。
题目要求、参考版本、操作和验证边界见 [题目二核对](docs/PROBLEM2_STATUS.md)。

```powershell
powershell -File scripts/build.ps1 -Target instrument_touch16
powershell -File scripts/program_instrument16.ps1
```

本工程面向 `Tang Mega 60K SOM + NEO Dock 31004/Rev 1.4`，包含压力演奏、MCP3208
多键演奏、FPGA 内 MIDI 播放以及把这些路径合在一起的整合演示目标。压力演奏部分使用已经实测成功的
片内 ADC 读取一个 FSR 压力模块，并通过底板 PT8211-S 和 3.5 mm 耳机口输出 A4
（440 Hz）三角波：松开静音，按下发声，压力越大声音越响。HDMI 版本同时在
1024×600 屏幕上显示系统状态、压力和实际音量。

旧的 `pressure_audio`、`pressure_audio_hdmi` 目标继续使用片内 ADC，`ADCV_P/ADCV_N`
的接线保持当前已经成功的方式不变。本目录另有一个独立的
`mcp3208_13key_hdmi` 目标：它使用两片外置 MCP3208 采集 13 个压力键；两套目标
共用音频、HDMI 和四声部代码，但不会互相覆盖。

## 主要可下载位流

为了把故障范围分开，工程生成彼此独立的 SRAM 位流：

1. `audio_smoke_sram.fs`：不读取 FSR，持续播放很小声的 440 Hz 测试音，用来先确认
   PT8211、功放和耳机通路。
2. `polyphony_demo_sram.fs`：不需要 MCP3208，自动循环播放四组四声部和弦，用于验证
   13 音符查表、声部分配、包络和混音。
3. `polyphony_timbre_demo_sram.fs`：在四声部演示上加入三角波/柔和方波双音色，
   AA13 或 AB13 任意一颗功能键都能切换。
4. `pressure_audio_sram.fs`：当前单压力键版本，FSR 同时作为琴键和力度控制器。
5. `pressure_audio_hdmi_sram.fs`：在已经通过实机测试的压力音频功能上增加
   1024×600 HDMI 状态画面。
6. `hdmi_colorbar_800x600_sram.fs`：只输出标准 800×600@60 Hz 彩条，用于排除
   ADC、音频、状态显示和 1024×600 非标准时序的影响。
7. `mcp3208_13key_hdmi_sram.fs`：两片 MCP3208 的 13 键版本，键位为 C4～C5 的
   十二平均律，最多四声部同时发声；HDMI 只显示各键压力柱和系统状态。
8. `midi_upload_probe_sram.fs`：只验证 UART 二进制帧、MIDI 文件分块写入和 FPGA
   文件缓存，不启动音频播放，适合先排查通信和文件接收。
9. `midi_player_sram.fs`：完整 MIDI Type 0 播放目标。FPGA 接收完整 MIDI 文件后，
   在片内解析 Tempo、Running Status、Note On/Off，调度四个声部并通过 PT8211 输出；
   上位机不发送 PCM 或播放期间的 Note On/Note Off 串流。
10. `instrument_full_sram.fs`：整合演示目标。默认进入 FSR/MCP3208 实时演奏模式；
    按 AB13 切换到 FPGA 内 MIDI 播放模式，UART、HDMI、四声部合成和 PT8211 共用一套顶层。

`instrument_full` 还通过 C18/C19 两路 GPIO 驱动陶晶驰 `TJC1060X570_011`（X5、7 寸、1024×600）串口屏：
C18 为 FPGA TX、C19 为 FPGA RX，USB-C UART 仍保留给电脑。接线、电平转换、`t0`～`t15`
控件和 115200/8N1 参数见 [`docs/SERIAL_SCREEN_UART.md`](docs/SERIAL_SCREEN_UART.md)。

所有带音频输出的目标都采用 16 位 PT8211 LSBJ（右对齐）串行格式，采样率约
48.828 kHz；左右声道发送相同样本。

## 一键测试与构建

在 PowerShell 中执行：

```powershell
cd .
python scripts\run_tests.py
powershell -ExecutionPolicy Bypass -File scripts\build.ps1 -Target audio_smoke
powershell -ExecutionPolicy Bypass -File scripts\build.ps1 -Target polyphony_demo
powershell -ExecutionPolicy Bypass -File scripts\build.ps1 -Target polyphony_timbre_demo
powershell -ExecutionPolicy Bypass -File scripts\build.ps1 -Target pressure_audio
powershell -ExecutionPolicy Bypass -File scripts\build.ps1 -Target pressure_audio_hdmi
powershell -ExecutionPolicy Bypass -File scripts\build.ps1 -Target hdmi_colorbar_800x600
powershell -ExecutionPolicy Bypass -File scripts\build.ps1 -Target mcp3208_13key_hdmi
powershell -ExecutionPolicy Bypass -File scripts\build.ps1 -Target midi_upload_probe
powershell -ExecutionPolicy Bypass -File scripts\build.ps1 -Target midi_player
powershell -ExecutionPolicy Bypass -File scripts\build.ps1 -Target instrument_full
```

其中 `run_tests.py` 当前运行 21 个 RTL 测试，其中包括 65536 字节文件边界、
`tb_midi_player_top` 的完整文件接收/重复块重试/PLAY 握手测试和 `tb_mcp3208_dual_scan`：后者用两片 MCP3208
行为模型检查 24 个 SPI 时钟、命令通道顺序和 B11～B0 的采样位序。若只想运行
这一项，可在 PowerShell 中执行：

```powershell
$env:PATH = "C:\msys64\ucrt64\bin;" + $env:PATH
$root = "."
& "C:\msys64\ucrt64\bin\iverilog.exe" -g2012 -Wall -s tb_mcp3208_dual_scan `
  -o "$root\build\tests\tb_mcp3208_dual_scan.vvp" `
  "$root\rtl\io\mcp3208_dual_scan.sv" `
  "$root\tests\mcp3208_model.sv" `
  "$root\tests\tb_mcp3208_dual_scan.sv"
& "C:\msys64\ucrt64\bin\vvp.exe" "$root\build\tests\tb_mcp3208_dual_scan.vvp"
```

预期输出以 `PASS tb_mcp3208_dual_scan` 开头。仿真模型只验证数字 SPI 协议，
不能替代上板时对模块供电、电平、VREF 和 DOUT 线序的核对。

只有在脚本显示 Setup/Hold 违例端点均为 0 后，才使用：

```text
build\ready-to-program\audio_smoke_sram.fs
build\ready-to-program\polyphony_demo_sram.fs
build\ready-to-program\polyphony_timbre_demo_sram.fs
build\ready-to-program\pressure_audio_sram.fs
build\ready-to-program\pressure_audio_hdmi_sram.fs
build\ready-to-program\hdmi_colorbar_800x600_sram.fs
build\ready-to-program\mcp3208_13key_hdmi_sram.fs
build\ready-to-program\midi_upload_probe_sram.fs
build\ready-to-program\midi_player_sram.fs
build\ready-to-program\instrument_full_sram.fs
```

## Gowin 图形界面

- 固定音测试：打开 `gowin/audio_smoke.gprj`。
- 自动四声部试听：打开 `gowin/polyphony_demo.gprj`。
- 自动四声部＋双音色试听：打开 `gowin/polyphony_timbre_demo.gprj`。
- 压力控制：打开 `gowin/pressure_audio.gprj`。
- 压力音频＋HDMI：打开 `gowin/pressure_audio_hdmi.gprj`。
- HDMI 标准彩条排障：打开 `gowin/hdmi_colorbar_800x600.gprj`。
- 两片 MCP3208、13 键、四声部＋HDMI：打开 `gowin/mcp3208_13key_hdmi.gprj`。
- MIDI 文件上传探针：打开 `gowin/midi_upload_probe.gprj`。
- FPGA 内 MIDI 播放：打开 `gowin/midi_player.gprj`。
- 压力/MCP3208 + MIDI + HDMI 整合演示：打开 `gowin/instrument_full.gprj`。
- 器件必须显示 `GW5AT-LV60PG484AC1/I0`，Device Version 必须为 `B`。
- HDMI 工程的 `Project → Configuration → Place & Route → Voltage → VCCX` 必须为 `1.8V`。
- 双击 `Synthesize`，成功后双击 `Place & Route`。
- Programmer 中先使用 `SRAM Program`，不要在首次测试时写入 Flash。

MCP3208 目标的 PMOD1/J8 接线、两片模块的 CS/MISO 分配、VREF 和 13 键通道顺序，
请先阅读 [`docs/MCP3208_13KEY_BRINGUP.md`](docs/MCP3208_13KEY_BRINGUP.md)。上板前
必须确认模块的 DOUT 不会输出 5 V；仿真通过不等于可以省略电平和供电检查。

## 上板顺序

1. 保持现有 FSR 与 `ADCV_P/ADCV_N` 接线不变，耳机插到底板 3.5 mm 接口。
2. 先烧录 `audio_smoke_sram.fs`。约 100 ms 后应听到低音量的持续测试音。
3. 确认固定音正常后，烧录 `pressure_audio_sram.fs`。
4. 烧录或复位时完全松开 FSR，等待前 64 次 ADC 事件完成零点校准。
5. LED7 常亮后轻按 FSR；LED0～6 逐级点亮，声音随力度增加。
6. 松开后声音约 5.2 ms 平滑归零。

## FPGA 内 MIDI 播放上板顺序

`midi_player` 是独立目标，不会修改已经验证的压力音频工程。第一次测试建议按下面顺序执行：

1. 将耳机音量调到最低，耳机先放在桌面上；确认 NEO Dock 通过 USB-C 连接电脑，且电脑能看到板载 UART 桥对应的 COM 口。
2. 用 Programmer 的 `SRAM Program` 下载 `build\ready-to-program\midi_player_sram.fs`。该位流的 SHA256 记录在 [`docs/BUILD_VERIFICATION.md`](docs/BUILD_VERIFICATION.md) 中。
3. 先使用 `python -m host_app.cli ping --port COMx` 做通信测试；再发送自带的最小 Type 0 文件：

   ```powershell
   python -m host_app.cli send-midi --port COMx examples\midi\01_single_note.mid
   python -m host_app.cli play --port COMx --timbre 0
   python -m host_app.cli status --port COMx
   ```

4. FPGA 收到完整文件并校验后才开始解析和播放。播放期间拔掉电脑，已经写入片内缓存的 MIDI 文件仍由 FPGA 继续处理；重新上电后需要重新上传文件。
5. 停止播放使用 `python -m host_app.cli stop --port COMx`。自定义音色必须先上传 FTB 单周期波表，再用 `--timbre 2` 播放。也可以给 `send-midi` 加 `--play`，在文件 ACK 后立即发送 PLAY。

`examples` 目录已经提供单音、四声部和弦、Tempo 变化音阶以及两种 FTB 音色，具体顺序见 [`examples/README.md`](examples/README.md)。

截至当前版本，MIDI 解析器、调度器、四声部合成器、FTB 校验、UART 协议和 Gowin 综合/布局布线已经在电脑端通过；USB-C 实物通信、真实 MIDI 文件耳机播放和自定义音色的板上效果仍待测试，不能把电脑端通过当作实物验收结论。

## 整合演示工程 `instrument_full`

这个目标把已经分别验证的实时压力路径和 MIDI 路径放到一个顶层，便于答辩时只烧录一个工程：

- 上电默认是实时演奏模式。两片 MCP3208 通过 PMOD1 接入 13 个 FSR，四声部音频从 PT8211/耳机输出，HDMI 显示 13 个压力柱。
- 按底板 AB13 功能键切换到 MIDI 模式；上位机发送完整 MIDI 文件后，FPGA 自己解析、调度、分配四个声部并播放，电脑不发送 PCM。
- 按 AA13 可在实时模式切换三角波/柔和方波；MIDI 模式的音色由 `play --timbre 0/1/2` 选择。
- MIDI 模式的 UART 引脚仍为 `U15` TX、`V14` RX；整合工程把 RX 接入 MIDI 子系统，压力模式不依赖 UART。
- HDMI 画面只负责反馈模式、文件/解析/播放状态、压力柱和声部门控，不承担音频计算。

整合工程的默认按键和外设引脚见 [`gowin/instrument_full.cst`](gowin/instrument_full.cst)。首次上板建议先用已经验证的 `mcp3208_13key_hdmi` 或 `midi_player` 单独排查硬件，再下载整合位流；整合位流已完成电脑端仿真、综合、布局布线和 0/0 时序检查，但 USB-C、MCP3208 与真实 MIDI 播放仍需要在用户板卡上实测。

## MCP3208 到货前试听四声部

烧录 `build/ready-to-program/polyphony_demo_sram.fs` 后等待约 100 ms，耳机将每隔约一秒
依次听到 Cmaj7、Fmaj7、G7、Am7，然后循环。该位流不读取压力传感器，也不需要 HDMI。

- LED7 常亮：音频功放已经启用。
- LED6～LED3：四个声部的门控状态，正常播放和弦时应全部点亮。
- LED1～LED0：当前和弦编号，从 0 到 3 循环。

首次试听先把耳机放在桌面上，不要直接佩戴。该演示经过 13 音符查表、三音/四音同时
分配、第五键轮询抢占、独立松键、混音限幅和完整 ADC 假数据链路仿真；Gowin 构建的
Setup/Hold 违例端点为 0/0。

若要测试双音色，改烧录 `polyphony_timbre_demo_sram.fs`。默认是三角波；按底板
AA13 或 AB13 对应的任意一颗功能小按键可切换为柔和方波，再按一次切回。LED2 点亮
表示方波音色，LED2 熄灭表示三角波。切换过程约 0.66 ms 交叉淡化。

## 1024×600 HDMI 版本

屏幕使用 1344×635 总时序：水平 `1024+160+20+140`，垂直
`600+12+3+20`，同步信号低有效。PLLA 从 50 MHz 产生 51.25 MHz 像素时钟和
256.25 MHz 串行时钟，刷新率约 60.06 Hz。该参数接近常见 1024×600 面板所用的
51.2 MHz 像素时钟。

1. 给 1024×600 屏幕供电，并用 HDMI 线连接 NEO Dock。
2. FSR 保持松开，使用 Programmer 的 `SRAM Program` 下载
   `pressure_audio_hdmi_sram.fs`。
3. 启动或校准时顶部为橙色；系统就绪后顶部变绿色；ADC 故障时顶部变红色。
4. 左侧青色柱显示压力，右侧紫色柱显示包络后的实际音量；按下 FSR 时中央方块变绿。
5. HDMI 仅显示状态，不参与音频控制。即使屏幕未识别，耳机、LED 和 UART 也应继续工作。

若使用 HDMI 触摸屏，显示画面仍走 HDMI，触摸坐标通常走另一根 USB 线。首次测试先让
屏幕使用独立、稳定的 5 V USB 电源，只连接 HDMI 视频；本工程当前尚未接收 USB 触摸数据。
发送端会按 Sipeed 官方 60K `cam_dvi` 示例把 K13（HDMI HPD 控制）固定拉高，使用
官方 Gowin DVI TX IP，并将项目 VCCX 设置为 NEO Dock 所需的 1.8 V。

当前 HDMI 位流已通过仿真、综合、布局布线和时序检查，真实屏幕兼容性仍需上板确认。
若显示器提示无信号，请记录屏幕控制板型号；不同 1024×600 控制板接受的消隐参数可能不同。

## MCP3208 到货前的 13 键准备

`rtl/control/pressure_key_matrix.sv` 已把外置 ADC 之后的 13 键处理独立出来。它接收一帧
13 路 12 bit 采样，分别完成 64 帧松开基线校准、低通滤波、16/8 迟滞判断、0～255
力度归一化，并输出每个键独立的起音和释音脉冲。`tb_pressure_key_matrix` 会用假 ADC
数据验证四键同时按下、单键独立松开、阈值抗抖和 ADC 掉线静音。

该模块目前没有加入可烧录工程，因此不会改变已经上板成功的 HDMI、压力和音频功能。
两块 MCP3208 到货并确认接线后，只需增加 SPI 扫描模块，将 13 个通道组成
`adc_samples`，每轮扫描结束产生一次 `sample_frame_valid`。

### HDMI 闪屏时的烧录顺序

1. 屏幕单独使用稳定的 5 V USB 电源，只连接 HDMI 视频线，暂时拔掉触摸 USB 线。
2. 先烧录 `pressure_audio_hdmi_sram.fs`。这是采用官方 DVI TX IP、K13 HPD 拉高和
   VCCX=1.8 V 的 1024×600 修正版。
3. 若仍闪屏，烧录 `hdmi_colorbar_800x600_sram.fs`。正常现象是稳定的红、黄、绿、青、
   蓝、紫、白竖向彩条，四周有白色边框。
4. 1024×600 闪而 800×600 稳定，说明 HDMI 物理链路正常，需要按屏幕控制板的准确时序
   修改 1024×600 参数；两个位流都闪，优先检查屏幕供电、HDMI 线或板卡 HDMI 链路。

> 固定音位流会持续播放。开始时不要佩戴入耳式耳机，把耳机放在桌面上确认声音，
> 再根据实际响度决定是否佩戴。

## LED 与串口

板载 USB-C UART 的实物收发排障见 [`docs/UART_LINK_BRINGUP_20260930.md`](docs/UART_LINK_BRINGUP_20260930.md)。
先用 `uart_tx_diag_sram.fs` 的主动发送字符串和 LED 分别验证 U15/V14，再下载
`uart_ping_echo_sram.fs` 运行二进制 PING；默认从 FT2232 通道 B 对应的 COM 口测试。

- LED7 慢闪：等待 ADC、基线或音频启动。
- LED7 常亮：系统已经可以演奏。
- LED0～6：压力等级。
- 两组 LED 交替闪烁：片内 ADC 转换超时。

UART 为 115200/8N1，每 50 ms 输出：

```text
R=xxxx P=xxx G=x V=xxxx S=x
```

- `R`：ADCV 原始值。
- `P`：相对松开基线的压力码差。
- `G`：音符门控，1 表示处于按下状态。
- `V`：实际平滑音量，范围 0000～1000（十六进制）。
- `S[3:0]`：`{ADC故障, 音频就绪, 基线完成, ADC就绪}`。

## USB 触摸屏接入

独立的 `usb_touch_probe` 目标已使用 NEO Dock USB-A2 的 `H13/G13` 引脚和 48 MHz
全速 USB Host 构建通过。它先枚举屏幕并通过 115200 波特率串口打印 VID、PID、接口及
端点信息；确认屏幕 HID 报告格式以后，再将绝对 X/Y 坐标接入 HDMI 界面。

完整接线、SW4 设置、供电注意事项和测试命令见
[`docs/TOUCH_BRINGUP.md`](docs/TOUCH_BRINGUP.md)。可直接烧录：

```text
build\ready-to-program\usb_touch_probe_sram.fs
```

## 关键参数

参数集中在以下两个模块中：

- `rtl/control/pressure_control.sv`：触发 16、释放 8、满力度 224。
- `rtl/audio/pressure_tone.sv`：起音步长 32、释音步长 16、最大数字幅度约 4096。

首次上板不要提高数字幅度。若声音正常但力度范围太窄，先通过 UART 记录松开、轻按、
重按的 `P` 数值，再调整压力阈值。

## 参考资料

- [Sipeed Tang Mega 60K 官方示例](https://github.com/sipeed/TangMega-60K-example)：核对 PMOD0 约束和板卡工程设置。
- [Sipeed Tang Mega 60K cam_dvi 示例](https://github.com/sipeed/TangMega-60K-example/tree/main/cam_dvi)：核对 HDMI 差分引脚、K13 HPD 控制和 PLL 输出通道。
- [Sipeed Tang Primer 20K PT8211 示例](https://github.com/sipeed/TangPrimer-20K-example/tree/main/PT8211)：核对 PT8211 每帧左右声道各 16 bit 的发送方式。
- [Tang Mega 60K 官方硬件页面](https://wiki.sipeed.com/hardware/en/tang/tang-mega-60k/mega-60k.html)：器件、底板资源和电平信息。
- [Leadtek 1024×600 面板时序表](https://www.leadtekdisplay.com/uploadfile/down/20260429/LTK070B40FPD-QC04-V5-SPEC-51.pdf)：核对 1344×635 总时序和约 51.2 MHz 像素时钟。

60K 官方仓库的 `audio_i2s` 目录截至 2026-09-18 只有占位 README，因此本工程没有把
该目录当成可直接编译的音频驱动。音频 RTL 来自本地先前完成的 MIT 练习工程，并针对
NEO Dock 的 50 MHz 时钟、引脚和低有效功放控制组合到本工程。

