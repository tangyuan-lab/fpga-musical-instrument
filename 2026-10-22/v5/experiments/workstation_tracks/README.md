# 逐轨混音候选核心

本目录与当前整机RTL、Gowin构建清单隔离。**尚未接入屏幕/串口协议，不是可直接烧录的完整工程。**

## 已实现与验证

- `host_app/track_compiler.py`：最多16个源轨道、共享16个MIDI通道。同轨同音重叠按区间分配通道，通道共享原轨归属和角色。起止tick、原始力度及源ID保留；超限不裁剪。主界面“设备 → 设备轨道容量检查”只做检查，不上传。
- `midi_tracks_parser.sv`：FPGA解析完整Type0文件、16通道和2048音符；64项速度表。挂起表按通道/音高寻址，不把channel9猜成鼓。每次解析前串行清表，不给RAM阵列复位。
- `track_gain_bank.sv`：18个归属（16个歌曲轨、实体键、屏幕键），Q1.15增益，32768为0dB。每个目标从当前值开始128采样平滑过渡并精确到达；帧快照36时钟完成。
- `synth32_tracks.sv`：由保留的`synth32`生成，32个独立振荡器状态、实时演奏保留4槽。音符持有归属，后级增益与力度分离，9时钟/声部；含增益快照的固定音频帧耗时325时钟，小于1024时钟周期。
- 直接调低持续音所在轨道12dB，另一轨不变：恒定波表混音由799变为500，符合整数舍入下的比例。相位连续、包络维持态和原力度不变；逐轨静音不清除声部，恢复无需重新起音。

## 可复现命令

```powershell
python -m unittest discover -s tests -p test_track_compiler.py -v
python scripts/test_midi_tracks.py
python scripts/test_track_audio.py
& C:/Gowin/Gowin_V1.9.12.03_x64/IDE/bin/gw_sh.exe experiments/workstation_tracks/synthesize_parser.tcl
& C:/Gowin/Gowin_V1.9.12.03_x64/IDE/bin/gw_sh.exe experiments/workstation_tracks/synthesize_audio.tcl
```

结果位于`build/tests/midi_tracks/result.json`、`build/tests/track_audio.json`。独立综合报告位于`build/gowin/midi_tracks`、`build/gowin/track_audio`。综合估计不能替代整机PnR或模拟音频延迟测量。

## WSMX/1 候选元数据

各多字节整数为小端。长度严格等于`32 + 56 × 轨数`；MIDI、配器与本元数据应联合校验和发布。

|偏移|字段|
|---|---|
|0|4字节`WSMX`|
|4|版本1、轨数1～16、使用通道数1～16、保留0，各1字节|
|8|音符数u32，最大2048|
|12|持续tick u32|
|16|16字节通道→轨道归属；FF未使用|
|32起，每轨56字节|轨UUID16、GB2312显示名32、目标增益u16、角色u8、静音u8、独奏u8、旧工程兼容力度百分比u8、保留u16=0|

角色0/1/2/3对应主旋律/和弦/低音/鼓。兼容力度参数独立保存，MIDI不先改力度；不传GM SoundFont给设备。

## 集成前剩余工作

1. 元数据长度/CRC/解析与歌曲/配器的联合发布、稳定资源ID和版本绑定。
2. 播放器读取通道→归属→角色，分段配器、角色增益及轨道增益按独立层合成；当前整机仍使用旧四角色播放器。
3. 鼓声部保存归属，并对尾音应用混音；当前候选测试仅覆盖旋律核心。
4. MIX_SET/SNAPSHOT、两端确认及推子合并队列。当前固件不声明功能bit3。
5. 屏幕回读、停止/跳转/暂停恢复、满载效果器、PnR与整机验收。

当前电脑推子可实时混音；选择FPGA演奏时逐轨推子禁用，防止把尚未生效的设备设置显示成可用。工作中的板卡位流未改。
