# MIDI 与 FTB 上板测试文件

这些文件只包含 MIDI 乐谱事件或 256 点单周期音色。它们不含 PCM 歌曲录音，播放时仍由
FPGA 完成 MIDI 解析、Tempo 调度、四声部分配、相位累加、ADSR、混音和 PT8211 输出。

建议按以下顺序测试：

1. `01_single_note.mid`：一个 C4，持续一拍。先验证最短的完整上传和播放路径。
2. `02_four_voice_chords.mid`：Cmaj7、Fmaj7、G7、Am7，每次四个音同时发声。
3. `03_tempo_change_scale.mid`：八音阶中途从 120 BPM 改为 180 BPM，后半段应明显加快。
4. `04_long_note_10s.mid`：一个 C4 持续 10 秒，用于较长时间的状态观察和耳机听测。
5. `soft_sine.ftb`：柔和正弦单周期波表。
6. `bright_harmonic.ftb`：含二、三次谐波的明亮单周期波表。

示例命令：

```powershell
python -m host_app.cli ping --port COMx
python -m host_app.cli send-midi --port COMx examples\midi\01_single_note.mid
python -m host_app.cli play --port COMx --timbre 0
python -m host_app.cli status --port COMx

python -m host_app.cli upload-ftb --port COMx examples\timbres\soft_sine.ftb
python -m host_app.cli send-midi --port COMx examples\midi\02_four_voice_chords.mid --play --timbre 2
```

需要重新生成时执行：

```powershell
python scripts\generate_demo_assets.py
```
