# 上位机与 FPGA 通信协议

本协议服务于高云“实时多音色合成电子乐器引擎”。上位机发送完整 MIDI 文件和
单周期音色参数，FPGA 在收到文件后自行解析 MIDI、调度音符并逐采样生成音频。
上位机不发送 PCM，也不在播放过程中逐条发送 Note On/Note Off。

## 物理链路

使用 NEO Dock 板载 USB-C 的 BL616 UART 桥：

| 方向 | FPGA 信号 | FPGA 芯片脚 |
|---|---|---|
| FPGA 到电脑 | FPGA_UART.TX | U15 |
| 电脑到 FPGA | FPGA_UART.RX | V14 |

串口为 115200/8N1。USB-A2 继续保留给触摸屏，不作为上位机通信口。

## 帧格式

```text
55 AA | version | type | sequence_le16 | length_le16 | payload | crc16_le
```

CRC-CCITT 初值 `FFFF`、多项式 `1021`，覆盖 `version` 到 `payload`，不覆盖 `55 AA`。

## 文件传输

`FILE_BEGIN` 的 payload：

```text
4 bytes  ASCII MID0
4 bytes  文件长度 uint32 little-endian
4 bytes  文件 CRC32 uint32 little-endian
```

`FILE_DATA` 的 payload：

```text
4 bytes  文件偏移 uint32 little-endian
N bytes  原始 MIDI 字节，N <= 128
```

`FILE_END` 的 payload 是文件 CRC32。FPGA 校验通过后才能接受 `PLAY`。

上位机的每次重试保留原序号。若某个 `FILE_DATA` 或 `TIMBRE_DATA` 已写入，但其 ACK 在链路上丢失，FPGA 会识别相同序号、偏移和长度，只重新发送 ACK，不再次写 RAM 或更新 CRC。

第一版支持标准 MIDI Type 0：一个轨道、16 位 PPQN、Tempo Meta Event、Note On、
Note Off 和 Running Status。电脑可以先做文件头校验，但 MIDI 的音符解析和播放调度
必须在 FPGA 内完成。

## 音色边界

内置音色编号为 0（三角波）和 1（柔和方波）。自定义音色只能是 256 点、16 位有符号
的单周期波表以及 ADSR 等合成参数。普通歌曲、长录音和 PCM 音频不能作为音色上传。
## 当前实现状态

协议已经在 `rtl/io/uart_frame_protocol.sv`、`midi_file_store.sv`、`timbre_file_store.sv` 和
`rtl/board/midi_player_top.sv` 中实现。文件数据块写入 BSRAM 完成后才返回该块的 ACK，避免
上位机过快发送造成暂存数据覆盖；`FILE_END` 校验通过后才接受 `PLAY`。

对应的上位机命令为：

```powershell
python -m host_app.cli ports
python -m host_app.cli ping --port COMx
python -m host_app.cli send-midi --port COMx song.mid
python -m host_app.cli send-midi --port COMx song.mid --play --timbre 0
python -m host_app.cli upload-ftb --port COMx timbre.ftb
python -m host_app.cli play --port COMx --timbre 0
python -m host_app.cli status --port COMx
python -m host_app.cli stop --port COMx
```

`send-midi` 默认只上传；独立 `play` 命令更适合分步排障，`--play` 可在上传完成后立即启动。`FILE_DATA` 的偏移必须与当前接收位置一致，块大小不能超过 128 字节；MIDI 文件最大 64 KiB。
第一版 FPGA 播放器只承诺标准 MIDI Type 0，不接受 Type 1/2、复杂 SysEx 或超出 64 KiB 的文件。

## 实物验证边界

Python 协议测试和 FPGA 仿真已经通过，`midi_player` 的 Gowin 综合、布局布线及 Setup/Hold
检查也已通过（0/0）。USB-C COM 口的真实收发、MIDI 文件耳机播放和长时间稳定性仍待上板
验证；在这些测试完成前，不能把 COM 口枚举或仿真 ACK 当作实物通信结论。

