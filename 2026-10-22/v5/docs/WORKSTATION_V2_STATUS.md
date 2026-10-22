# V2 上下位机联动状态

> 2026-10-17 21:55最新状态：**V2完整构建通过并发布**，见[位流发布说明](WORKSTATION_V2_RELEASE.md)。50MHz，Setup/Hold0/0，15个实际引脚及源哈希核对通过。位流为`build/ready-to-program/instrument_workstation_v2_sram.fs`，SHA256以`C286B9BC0D9A366C`开头。32声部、16实体键及原接线保留，数字延迟和顶层并发复测通过。本轮未烧录，外部标准I2S DAC与整机实测仍待完成。下方保留历史证据。

## 已落地

- 上位机 `host_app.workstation_gui` 支持中文工程、MIDI/MusicXML、简谱文本、PDF/图片预览、音符校正、单周期 WAV/FTB、鼠标绘制波表、曲谱段落和音色参数。操作见 [快速使用](WORKSTATION_V2_QUICKSTART.md)。
- `.fpgamusic` 工程会嵌入原始谱面文件；未确认的识谱音符不能下发。
- 按用户更新的要求，增加独立本机校谱试听：无需板卡即可播放待确认音符；支持钢琴卷帘、四声部概览、拖动音高/时间、右端时长与力度编辑、撤销、静音/独奏、速度、定位、循环及音色草稿试听。参考 [FL Studio 卷帘](https://www.image-line.com/fl-studio-learning/fl-studio-online-manual/html/pianoroll.htm) 与 [Ableton 时间线](https://www.ableton.com/en/manual/arrangement-view/) 的交互。设备上传仍只有资源和控制，由 FPGA 独立合成。
- FPGA 资源协议支持 4 首曲谱、8 个自定义波表、曲谱分段、目录版本、CRC32、重复 DATA 重试和容量拒绝。
- FPGA 端实现 32 个独立声部、拨弦/管乐预设、导入波表、ADSR、压力力度、弯音、颤音、延迟和双梳状混响。
- USB 与串口屏命令共用一个仲裁器：屏幕操作进 FIFO，USB 回包只对应原 USB 请求；安全停音优先。
- 屏幕目录定期重发，屏幕单独重启后仍能恢复曲谱/音色名称；状态含当前音色 A/D/S/R。
- 当前硬件实例为 4 个映射 bank：0 为首页默认映射，1、2、3 分别保存鼓点、弹琴、混音的独立实体键配置；协议字段仍保留扩展编号。
- 标准 Philips I2S 已固定到 PMOD0 `T21/U21/P16`，采样率为 48.828125 kHz。旧板载 PT8211 右对齐输入不属于本 V2 输出链路。

## 验证证据

运行：

```powershell
cd .
python scripts/test_workstation_v2.py
```

2026-10-16：9 组 RTL 已通过；最新主机变更的14项工程、6项本机音频和12项GUI单元测试通过。覆盖 32 声部独立相位、实时四槽保留、扫描中途停音、压力更新保持相位、I2S 一位延迟、延迟/混响脉冲响应、清音、命令仲裁、完整 ADSR 参数、CRC/重试/目录/多曲谱/多音色/暂停/跳转/32 频现场测试。屏幕 UART 测试逐条核对 42 条实际发送指令；225 个 HMI 控件的源码事件检查通过，源事件验证不等于官方 TFT 编译通过。

本机试听另外执行真实 Qt/FFmpeg 后端静音自检（Realtek 输出设备，音量0）：实际播放位置推进、暂停后定位仍暂停、选中区间循环全部通过，见 `build/tests/workstation_preview_backend.json`。1101个待确认音符可生成158.10秒本机WAV，所有确认标记保持原样；频谱测试验证440/880 Hz复音、段落移调及声部静音。这里的WAV只在电脑缓存，鼓音与定点合成不完全匹配硬件；这些结果不作为题目要求的 FPGA 合成或整机延迟证据。

真实上位机 DeviceV2.upload_resource 生成的上传请求已用于RTL资源集成测试。资源名称和 UUID 已改为同步块 RAM，分段配器先暂存、CRC 成功后提交，错误上传不会覆盖原有效配器。

路由测试覆盖内置 0/1、自定义 2..9、跟随当前音色 63、无效编号拒绝、模式切换后先松键及旧工程兼容。已修正 V2 默认跟随音色被旧路由器拦截的问题。设备演奏台可直接从 FPGA 目录选曲及音色，无须本机工程含同一资源；实际状态显示来自 FPGA 回读。资源 ID/版本变化会拒绝旧选择。保存工程保留尚未提交的波表、ADSR 与分段表编辑；异步识谱不会覆盖用户后来选中的另一首歌曲。

官方 Audiveris 5.11.0 控制台包已校验 GitHub 发布 SHA256 并解包到 `build/tools/audiveris/runtime`；不注册系统安装。通过 `scripts/prepare_audiveris.ps1` 可重建，识谱模块自动查找。实际批处理官方 `zizi.png` 示例并导入 102 个音符，均保留待校正确认标记，结果见 `build/tests/omr/result.json`。这验证导出/导入链路，不表示每个识别音符正确。官方来源：[安装](https://audiveris.github.io/audiveris/_pages/tutorials/install/binaries/)、[CLI](https://audiveris.github.io/audiveris/_pages/guides/advanced/cli/)。

声部分配已改为逐槽扫描、音频帧间提交，压力最大值改为四级流水线；最新综合估计系统 Fmax 为 60.032 MHz（目标50 MHz），LUT 40,603、ALU 5,804、寄存器25,433、BSRAM 73。此前191级组合路径已消除。2026-10-16 12:42 的完整 PnR 运行约96分钟后报告 **3936 条未布通网络**，因此没有发布 V2 位流；该失败结果不能烧录，下一步需要继续降低布线拥塞。

2026-10-16 后续优化：新增逐键扫描路由，保留同鼓最大力度、屏幕键及模式切换保护。新旧路由对照和随机输入测试通过；路由 LUT 从6545降至759、寄存器从1248降至581，整机综合 LUT 从40611降至34474、ALU为5169、寄存器24765。综合估计 sys_clk 为65.702 MHz；已复用新网表重新开始 PnR，结果尚未完成，未发布或烧录 V2。旧失败报告及网表保存在 `build/baselines/v2_route_3936_unrouted`。

完整 V2 顶层数字起音六例通过，测量到实际标准 I2S 引脚的第一个非零音频样本：

| 路径 | 最小 | 最大 | 测试变化范围 |
| --- | --- | --- | --- |
| 实体键0/13/14/15，不同SPI相位，轻按1095→1111码 | 2.959850 ms | 3.573690 ms | 0.613840 ms |
| 屏幕UART首位，键0/15 | 0.496790 ms | 0.496790 ms | 本次两例为0 |

时钟50 MHz、SPI1 MHz、UART115200、音频48.828125 kHz；仅启动标定帧数缩为4，稳态时钟不缩放。报告 `build/tests/workstation_v2_latency.json` 记录编译产物、日志及源文件 SHA256。**这些用例没有覆盖32声部+效果器+界面同时工作的最坏延迟，也不含FSR模拟响应/RC、触摸扫描及DAC/功放延迟，不能据此宣称整机≤5ms或无抖动。**

四频模式另采集实际 `synth32` RTL 的8192个PCM样本并FFT验证，C4/E4/G4/B4的独立峰为262.260/327.826/393.391/494.719 Hz，FFT分辨率5.960 Hz。报告 `build/tests/synth32_spectrum.json`；这是数字仿真频谱，不是模拟输出录音。实际PnR端口报告的两片ADC、USB UART、屏幕UART及标准I2S共15个脚号、方向与LVCMOS33检查通过。

同一声部同一音高的重叠音符超出当前MIDI解析器表达范围。MusicXML双谱表默认拆为旋律/和弦/低音，冲突同音尝试分配到空闲旋律声部，保留音高、起止并标记待确认；也预留按(part_id, staff, voice)指定映射的接口。无法分配或直接MIDI导入的冲突会明确拒绝下发，不静默截断。

用户的4页《Nocturne in D Minor 第二版.pdf》已实际识别并保存 `build/imported_scores/Nocturne_D_Minor_待校正.fpgamusic`：1101个音符，声部0/1/2分别353/280/468个，14个同音冲突重新分配、全部时值保留。仅在测试副本中清除待确认标记后，结构校验通过；交付工程的1101个音符仍全部待校正。GUI可切换4页原谱，导入PDF自动启动识谱，官方MusicXML原始结果缓存供后续重复导入；缓存不保留用户的确认状态。

## 尚未宣称完成

2026-10-16识谱纠正：上文1101音符的旧Audiveris结果存在实际音乐错误，解析链路通过不能证明识谱正确。现优先读取此MuseScore/Leland矢量PDF：1775个音头、102小节，按真实曲线合并816段延音，得到959个播放音符；速度从误用120修正为谱面158，正确处理行内谱号、附点、3/5/9连音及跨小节临时变音延音。`scripts/verify_nocturne_pdf.py` 有原谱手工锚点回归，覆盖开头4小节及29/46小节省略休止入口。新工程为 `build/imported_scores/Nocturne_D_Minor_矢量校正版.fpgamusic`，全部959个音符仍待人工确认，不宣称整曲逐音审核。选中音符后原谱会切到对应页并用红框标出位置。其他PDF继续辅助识别并报告小节超拍/不连续延音。

- `instrument_workstation_v2_sram.fs` 必须由最新 Gowin PnR 产生且 Setup/Hold 为 0/0 后才发布；外接标准 I2S DAC 和 PMOD0 接线未确认前不烧录。
- USART HMI 工程已生成，但官方 `.TFT` 编译和屏幕实物下载仍需在 USART HMI 中完成；`.HMI` 的 `official_compile_status` 保持 pending。
- Audiveris 已完成运行及单份官方样谱链路验证，复杂谱识别质量与人工校正仍需验证。蓝牙移动端、FPGA 音频录音回传、整机模拟链路延迟和频谱仪结果尚未完成，不能用 RTL 结果替代实物证据。
