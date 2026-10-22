# FPGA 音乐工作站

Tang Mega 60K / GW5AT-60B 的16键压力电子乐器、中文电脑编曲校谱工具与串口屏工程。

**版本：0.5.0-dev，2026-10-19源码快照。完整源码可编辑、测试和构建；尚未完成全部整机验收。**

## 包含什么

|模块|内容|状态|
|---|---|---|
|电脑端V5|中文工作区、MusicXML/MIDI导入、五线谱/卷帘、逐小节校正、实时逐轨混音、工程保存|主机回归已通过；PDF识别仍需校正|
|工作站基线|16路MCP3208压力键、鼓点/弹琴/混音、三套逐键映射、板载PT8211|历史版本已确认实体压力变化且发声|
|FPGA V2|32独立旋律声部、ADSR、多音色、多歌曲、分段配器、变调/颤音、延迟/混响、标准I2S|此前V2构建通过；本快照含后续急停修改，最新整机尚未通过发布验收|
|16轨候选|共享16通道、同音重叠、持续音逐轨增益|独立RTL验证/综合通过，尚未集成整机|
|串口屏|TJC1060X570_011的中文可编辑HMI、页面与事件生成源码|需官方USART HMI编译；未附旧TFT冒充新版|

设备演奏的解析、调度、波形、包络、效果和混音在FPGA完成。电脑参考试听是校谱工具；不会把整段PCM或播放期间的逐音符流当作设备曲谱。

## 快速启动（Windows x64 / Python 3.13）

在解压后的仓库根目录执行：

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe -m host_app.workstation_gui --project examples/workstation_v2_demo.fpgamusic
```

以后双击根目录“启动音乐工作站.bat”。启动检查：`cmd /c start_workstation_v2.bat --check`。

- 无板卡可选择“设备合成模型（电脑）”试听。
- FluidSynth参考乐器与默认音源：`python scripts/prepare_music_stack.py`（在`.venv`中运行）；需能访问其官方下载源。
- Audiveris印刷谱识别：`pwsh -File scripts/prepare_audiveris.ps1`。MusicXML/MIDI可直接导入，无需先识谱。
- 缺少可选工具时可编辑工程；组件状态页显示准备情况。
- 优先导入原软件导出的MusicXML或MIDI。PDF转换成功不代表音高、连音和节奏正确。

## FPGA构建

安装Gowin EDA及Icarus Verilog，设置自己的工具位置：

```powershell
$env:GOWIN_SH = 'C:/Gowin/Gowin_V1.9.12.03_x64/IDE/bin/gw_sh.exe'
$env:FPGA_SIM_BIN = 'C:/msys64/ucrt64/bin'
pwsh -File scripts/build_workstation_v2.ps1
```

基线工程是`gowin/instrument_workstation.gprj`；V2是`gowin/instrument_workstation_v2.gprj`。
基线构建：`pwsh -File scripts/build.ps1 -Target instrument_workstation`。
构建脚本保留布通、Setup/Hold、源码哈希及引脚门槛。**此源码包不附与当前源码不一致的旧位流**；重新构建成功后才使用`build/ready-to-program`中的输出。

|接口|引脚|
|---|---|
|ADC0 SCLK/MISO/MOSI/CS|AA19 / AA20 / AB21 / Y21|
|ADC1 SCLK/MISO/MOSI/CS|AB20 / AA21 / AB22 / Y22|
|屏幕 FPGA TX/RX|C18 / C19|
|USB UART FPGA TX/RX|U15 / V14|
|V2标准I2S BCLK/WS/DATA|T21 / U21 / P16|

V2采用48.828125kHz、32位声道时隙、16位有效数据，须匹配标准I2S DAC。基线板载PT8211使用右对齐格式，两版音频接法不同。

## 串口屏

- 基线：`screen/TJC1060X570/generated/instrument_workstation_fixed/instrument_workstation.HMI`。
- V2：`screen/TJC1060X570/generated/instrument_workstation_v2/instrument_workstation_v2.HMI`。

用官方USART HMI打开对应工程并编译，成功后再下载。仅编译上述现成HMI不需要工厂模板。
脚本重新生成HMI需要自己提供官方工厂模板及已保存的最小页面；见[屏幕模板说明](screen/TJC1060X570/vendor/README.md)。独立MIT工具库已随源码提供，不依赖原电脑的`build/tools`目录。

## 验证

```powershell
python -m unittest discover -s tests -q
python scripts/test_workstation_v2.py
python scripts/test_midi_tracks.py
python scripts/test_track_audio.py
python scripts/verify_v5_layout.py
```

主机测试不要求板卡；未安装参考音源的可选实音源测试会明确跳过。RTL数字延迟和综合估计不代表整机模拟输出延迟。满载、外部DAC、官方TFT及题目全部条目的实物验收仍待完成。

## 目录

`host_app/`电脑端；`rtl/`整机HDL；`gowin/`工程/约束；`screen/`屏幕源码；`config/`配置注册表；`tests/`测试；`experiments/`未集成候选；`examples/`自生成样例；`third_party/`带许可的工具库；`docs/`说明与历史证据。

历史文档记录当时状态，**当前交付边界以本README和[快照状态](docs/RELEASE_STATUS.md)为准**。
查看[上位机操作](docs/V5_QUICK_START.md)、[上传GitHub](docs/UPLOAD_GITHUB.md)、[第三方来源](THIRD_PARTY_NOTICES.md)。

自编代码沿用MIT许可；第三方文件保留各自许可及声明。未包含个人乐谱/聊天附件、安装器、模型权重、编译缓存和旧USB Host诊断依赖。
