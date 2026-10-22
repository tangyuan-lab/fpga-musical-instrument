# MIDI 静音问题检查与 RAM 修复（2026-10-04）

## 当前工程核对

工程目录为 `.`。
此前加入的 `parser_error`、`parser_error_code` 状态字段仍保留在源码中；本次构建前，
`midi_player_sram.fs` 的修改时间为 2026-09-23，尚未包含这些诊断字段。
修改前的相关源码及位流保存在 `build/snapshots/midi_before_ram_fix_20261004/`。

## 已确认的代码问题

`midi_file_ram_sdp.sv` 配置每个 SDPB 为 8 位 × 2048 字节。在此模式下，
原语的字节地址位于 `ADA/ADB[13:3]`，低三位补 0。原代码把字节地址放在
`[10:0]`，会使每八个相邻字节覆盖同一个物理地址，破坏 MIDI 文件头。

地址现在改为 `{write_address[10:0], 3'b000}` 和
`{read_address[10:0], 3'b000}`。64 KiB 容量、bank 选择及两拍同步读取保持原设计。
规则核对依据为本机 Gowin GW5A `prim_sim.v` 及
[Gowin BSRAM & SSRAM 用户指南 UG285](https://cdn.gowinsemi.com.cn/UG285E.pdf)。

原 `tb_midi_player_top` 的简化 SDPB 模型也错误地读取 `[10:0]`，因此此前仿真无法发现
这个硬件地址问题。已改为读取 `[13:3]`；修复前复现 `err=1 code=1 ready=0 count=0`，
修复后得到 `PASS tb_midi_player_top parser_start=1 event_count=1`。
另外使用 Gowin 官方仿真库替换简化模型，完整接收与解析测试同样通过。

## 10 秒测试音

新增 `examples/midi/04_long_note_10s.mid`：42 字节，Type 0、PPQN=480，
Tempo 为每拍 500000 微秒，C4 音符起点 0、终点 9600 tick，持续 10 秒。
Gowin 官方 RAM 模型下已验证上传后能够解析为一个事件，起止 tick 正确。

生成脚本 `scripts/generate_demo_assets.py` 已包含该文件。上位机协议测试 5 项通过。

## 新位流构建

Gowin V1.9.11.03 Education 已完成独立 `midi_player` 构建；Setup/Hold 违例端点均为 0。
文件为 `build/ready-to-program/midi_player_sram.fs`，SHA256：

```text
3011C0A7A94BC7B6390368DBA82D56E0DFE06D96D5BCEBB0EA84E14CCA1B3284
```

构建日志保存在 `build/midi_player_ram_fix_20261004.log`。本次只重新构建独立 MIDI 目标；
现有 `instrument_full_sram.fs` 尚未包含该共享 RAM 模块的修复，使用整合目标前需重新构建。

## 上板复测

2026-10-04 检查时，电脑未枚举到 USB 串口，尚未烧入本次修复位流或进行听测。
连接 DEBUG-USB2 后先确认 FT2232 B 通道的实际 COM 编号。SRAM Program 下载
`build/ready-to-program/midi_player_sram.fs`，随后在工程目录执行：

```powershell
py -3.13 -m host_app.cli ping --port COM15
py -3.13 -m host_app.cli send-midi --port COM15 examples\midi\04_long_note_10s.mid
py -3.13 -m host_app.cli play --port COM15 --timbre 0
py -3.13 -m host_app.cli status --port COM15
```

预期播放中 `parser_ready=True`、`parser_error=False`、`event_count=1`、`playing=True`。
耳机真实出声需用户观察，不能用仿真或命令 ACK 替代。
