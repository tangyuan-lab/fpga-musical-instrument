# FPGA 内 MIDI 电子乐器实现说明

## 数据流

```text
电脑：完整 MIDI Type 0 文件、FTB 单周期音色、PLAY/STOP
  ↓ 115200/8N1 二进制帧
FPGA：UART 帧校验 → 64 KiB BSRAM 文件缓存
  ↓ PLAY
FPGA：MThd/MTrk、VLQ、Tempo、Running Status、Note On/Off 解析
  ↓ tick 事件
FPGA：Tempo 调度 → 四声部声部槽 → 相位累加器/三角波/方波/FTB 波表
  ↓ 每个音频采样点
FPGA：ADSR、混音、PT8211-S → 耳机接口
```

上位机没有把 MIDI 解析成 Note On/Note Off 串流，也没有上传 PCM。播放期间拔掉电脑，FPGA 中已经保存的文件仍然可以继续完成解析和播放。

## FPGA 模块

- `rtl/io/midi_file_ram_sdp.sv`：32 个 Gowin `SDPB` 原语组成 64 KiB 字节寻址缓存。
- `rtl/io/midi_file_store.sv`：接收 `FILE_BEGIN/DATA/END`，增量 CRC32 和写缓存接口；同序号重传只重新 ACK，不重复写入。
- `rtl/midi/midi_type0_parser.sv`：解析标准 Type 0，保存音符起止 tick、力度和 Tempo 表。
- `rtl/midi/midi_player_scheduler.sv`：将 tick 转成 Q16.16 播放时间，Tempo 变化用 64 位迭代除法器更新。
- `rtl/audio/midi_voice_allocator_4.sv`：四声部独立分配、抢占和释音回收。
- `rtl/audio/midi_poly_synth_4voice.sv`：四套独立相位、包络和音色路径；音色 0 为三角波，1 为柔和方波，2 为 256 点 FTB 波表。
- `rtl/board/midi_player_top.sv`：USB-C UART、播放控制、LED、PT8211 顶层。

## 资源与时序边界

MIDI 文件缓存必须使用 BSRAM。若写成普通 `reg [7:0] mem[0:65535]`，综合器会推断为七万多个触发器，超过 GW5AT-60 资源上限。当前工程明确实例化 32 个 `SDPB`，避免这个问题。

MIDI 解析只在上传完成后进行，音频数据路径只在 `sample_tick` 更新；调度器的 64 位除法器不位于 48.8 kHz 音频采样组合路径。整合工程没有用全局 false path 豁免这些功能路径，而是通过同步 RAM 读寄存、音频流水级、UART 帧缓存和常量相位查表满足系统时序。

## 上位机命令

```powershell
python -m host_app.cli ports
python -m host_app.cli ping --port COMx
python -m host_app.cli send-midi --port COMx song.mid
python -m host_app.cli send-midi --port COMx song.mid --play --timbre 0
python -m host_app.cli upload-ftb --port COMx timbre.ftb
python -m host_app.cli play --port COMx --timbre 0
python -m host_app.cli stop --port COMx
python -m host_app.gui
```

图形界面会显示板载 USB-C COM 口的设备描述，并提供“连接并测试”、MIDI/FTB 文件
选择、上传进度、播放控制、FPGA 状态卡片和操作日志。第一次使用建议在窗口中先点
“刷新”，选择 NEO Dock 的 FPGA UART/BL616 端口，再点“连接并测试”；触摸屏 USB
端口不能用于这个上位机。也可以在工程根目录执行：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\start_host_gui.ps1
```

Windows 用户也可以直接双击工程根目录的 `start_host_gui.bat`。它会自动检查 Python
和 `pyserial`，再打开图形界面；首次运行缺少依赖时会先安装 `host_app\requirements.txt`。
如果不希望看到命令行窗口，直接双击根目录的 `上位机双击启动.vbs`；这个启动器会
隐藏检查和安装过程，只显示图形界面。

`send-midi` 默认只上传，随后用独立 `play` 命令启动；`--play` 用于上传成功后立即播放。`--timbre 0` 是三角波，`1` 是方波，`2` 在已经上传 FTB 后选择自定义单周期波表。

## 当前验证

- Python 协议单元测试：CRC、分片重组、坏帧丢弃、MIDI Type 0 头部、上传/播放语义和示例文件校验通过。
- `tb_midi_player_top`：完整顶层文件接收、CRC 后就绪和 PLAY 启动握手通过。
- 该顶层测试还覆盖了错误长度 PLAY，以及 ACK 丢失后的同序号 MIDI 数据块安全重试。
- `tb_timbre_file_store` 覆盖 FTB CRC、256 点波表写入和同序号块重试；重试不会二次写波表。
- `tb_midi_type0_parser`：一首最小 MIDI 文件被 FPGA 解析为 MIDI 音高 60、力度 100、起点 0、终点 480，PPQN=480。
- `tb_midi_type0_parser_64k`：验证 32 位轨道长度以及恰好 65536 字节文件的末地址处理，不会在 `0xffff` 后回绕。
- 原有压力键、四声部、PT8211、MCP3208 和 HDMI 仿真保持通过。
- 2026-09-30 实物验证：DEBUG-USB2 的 FT2232 B 通道为 COM15；FPGA UART 双向收发和完整 MIDI 位流的 PING/ACK 均通过。
- 2026-09-30 实物验证：`01_single_note.mid`（42 字节）和 `02_four_voice_chords.mid`（165 字节，跨两个数据块）均收到上传完成 ACK；`status` 显示 `file_ready=True`、`audio_ready=True`。耳机输出和真实 MIDI 播放仍待听测。
- 2026-10-04：修复 SDPB 的 8 位字节地址排列错误，并修正原仿真模型；旧代码在正确模型下复现 MIDI 文件头错误，修复后简化模型及 Gowin 官方模型均通过。详见 [RAM 修复记录](MIDI_RAM_FIX_20261004.md)。
## 构建结果

独立 MIDI 工程为 `gowin/midi_player.gprj`，目标器件为 `GW5AT-LV60PG484AC1/I0`（Device Version B）。位流文件为 `build/ready-to-program/midi_player_sram.fs`，SHA256 为：

```text
3011C0A7A94BC7B6390368DBA82D56E0DFE06D96D5BCEBB0EA84E14CCA1B3284
```

2026-10-04 使用 Gowin V1.9.11.03 Education 重新构建。布局布线报告结果：Setup violated endpoints `0`，Hold violated endpoints `0`；Logic `16390/59904`（28%），Register `12446/60780`（21%），BSRAM `46/118`（39%），DSP `11/118`（10%），I/O `16/297`（6%）。`PR1014` 通用时钟布线提示仍存在，但没有产生 Setup/Hold 违例。

## 从上传到播放的板上步骤

1. 在 Gowin Programmer 中使用 `SRAM Program` 下载 `midi_player_sram.fs`，不要首次就写 Flash。
2. NEO Dock USB-C 连接电脑，串口按 115200/8N1 打开；耳机音量调低并先放在桌面上。
3. 先运行 `python -m host_app.cli ping --port COMx`，再上传 `examples/midi/01_single_note.mid`。
4. 收到文件完成 ACK 后运行 `python -m host_app.cli play --port COMx --timbre 0`；状态可用 `status` 查询，停止使用 `stop`。
5. 上传 FTB 后才选择音色 2。FTB 只包含单周期波表和合成参数，不能把歌曲或长 PCM 录音当作音色。

FPGA 在收到完整文件后才解析 MIDI 和安排事件；播放期间电脑不发送 PCM 或逐个 Note On/Note Off。重新上电后片内文件缓存会清空，需要重新上传。

## 验证边界

以下项目已经通过电脑端协议/RTL 测试和 Gowin 构建：MIDI Type 0 解析、VLQ、Tempo、Running Status、Note On/Off、同步 BSRAM 读口、四声部调度、FTB CRC/波表写入、协议分片重组和时序检查。

截至 2026-09-30，USB-C 实物收发、PING/ACK 和 MIDI 文件分块上传已通过。真实 MIDI 文件耳机播放、自定义 FTB 听感以及断开电脑后的长时间播放验证仍需在板上完成。

## V12 整合顶层

`gowin/instrument_full.gprj` 在同一个顶层中复用实时 MCP3208/13 键压力路径、MIDI
播放器、HDMI 状态界面和 PT8211 输出。AB13 切换实时/MIDI 模式，AA13 切换实时三角波/
柔和方波。该目标的最终位流为 `build/ready-to-program/instrument_full_sram.fs`，
SHA256 为 `1426249812C77E2F1132B7E4DE17C9339D13CA615C1DAE3B7419CE71D4E1A9C7`，
Setup/Hold 为 0/0。USB-C、MCP3208 和真实耳机播放仍需上板验收。

