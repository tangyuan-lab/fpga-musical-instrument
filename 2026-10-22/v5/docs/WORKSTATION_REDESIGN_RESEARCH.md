# 上位机重构调查与实施记录

日期：2026-10-18（北京时间）。这是官方资料对照、本机实验和首轮修复记录，**不是整个重构计划的完成报告**。
调查从10月17日23:00开始，期间按用户要求暂停，10月18日01:01恢复；暂停不算连续研究。

## 1. 调查范围与结论

对照19款编曲软件及8个记谱／识谱项目的官方文档或项目源码。商业软件为文档研究，未声称逐款安装实操或按市场份额证明覆盖“大部分”。

保留已经选定的 Cakewalk 主框架、FL Studio 卷帘方向。真正需要借鉴的是共享工程、轨道／片段／乐器／总线的边界、上下文编辑与可收起视图。单纯复制配色或堆叠更多按钮不能修复现有数据损失。

| 参考产品／项目 | 工作方式 | 对本项目的启发 |
| --- | --- | --- |
| [FL Studio](https://www.image-line.com/fl-studio-learning/fl-studio-online-manual/html/playlist.htm) | Pattern / Playlist / Piano roll / Mixer | 音型、播放列表、混音通道是不同对象；Track Mode可建立一对一关系。 |
| [Cakewalk Sonar](https://help.cakewalk.com/hc/en-us/articles/41033604592537-Cakewalk-Sonar-Views) | Track view + MultiDock + Console | 轨道为主窗口；卷帘、谱面、事件表共享项目；工作区按任务保存布局。 |
| [Cubase](https://www.steinberg.help/r/cubase-pro/15.0/en/cubase_nuendo/topics/project_window/project_window_overview_r.html) | Project window with zones | 中央轨道、左检查器、右浏览器和下编辑区；区域按需显示。 |
| [Ableton Live](https://www.ableton.com/en/live-manual/12/arrangement-view/) | Arrangement and Session | 线性编排与片段触发区分；统一传输、概览与小节时间标尺。 |
| [Logic Pro](https://support.apple.com/guide/logicpro/logic-pro-main-window-lgcp2a07a994/10.7/mac/11.0) | Tracks area + inspector + editors | 轨道区域是主体；检查器随所选轨道和片段变化。 |
| [Pro Tools](https://www.avid.com/pro-tools/user-guide/smart-tool) | Edit / Mix / MIDI editor | 上下文智能工具减少切换；轨道混音与MIDI编辑状态应一致。 |
| [REAPER](https://www.reaper.fm/userguide.php) | Arrange + TCP + mixer + dockers | 可配置轨道控制与停靠编辑器；快捷操作强调选择上下文。 |
| [Bitwig Studio](https://www.bitwig.com/userguide/latest/the_arrange_view_and_tracks/) | Arrange / Mix + inspector | 检查器展示当前选择；轨道、片段、事件和设备分层。 |
| [Fender Studio Pro / Studio One](https://fenderstudiopromanual.fender.com/en/Content/Mixing_Topics/Channel%20Overview%20and%20Editor.htm) | Arrangement + Browser + Channel Overview | 通道概览集中当前通道信息，浏览器内容支持拖入编排。 |
| [Reason](https://docs.reasonstudios.com/reason12/common-operations-and-concepts) | Sequencer / Rack / Mixer | 乐器机架、音符序列和混音分区；专注区可最大化。 |
| [Digital Performer](https://cdn-data.motu.com/manuals/software/dp/v101/Digital%20Performer%20User%20Guide.pdf) | Consolidated Window | 主窗口分区可配置，Window Sets保存不同制作阶段的布局。 |
| [Waveform](https://www.tracktion.com/training/manuals) | Edit-oriented workspace | 官方用户手册索引已查；详细编辑行为继续核实。 |
| [Harrison Mixbus](https://rsrc.harrisonconsoles.com/mixbus/manuals/harrison_mixbus_v3_manual.pdf) | Editor and console-style Mixer | 编辑窗口组织音轨，混音窗口组织信号流；本条为历史版官方手册。 |
| [Renoise](https://tutorials.renoise.com/index.php?redirect=no&title=Pattern_Editor) | Pattern editor / matrix / mixer | Tracker为不同创作范式；音型序列与发送、分组和主通道分别建模。 |
| [Ardour](https://manual.ardour.org/ardourmanual.html) | Editor / Mixer / Cue Grid | 各工作视图共享传输条，编辑时间轴和混音信号流分工。 |
| [LMMS](https://docs.lmms.io/user-manual/production/creating-a-track) | Song Editor / Beat editor / Piano roll | 旋律片段双击进入卷帘；鼓节奏以可复用音型编排。 |
| [Qtractor](https://qtractor.org/doc/Manual%20-%205%20Qtractor%20Menus.html) | Track / Clip / MIDI editor / Mixer | 明确区分轨道、片段与范围选择；复制片段提供解除关联语义。 |
| [Rosegarden](https://www.rosegardenmusic.com/tour/notation/) | Track / Notation / Matrix / Event | 记谱信息超出MIDI表达；多个编辑器同步，记谱量化与演奏时序可分离。 |
| [Zrythm](https://manual.zrythm.org/en/zrythm-interface/main-panel.html) | Timeline / editor / mixer panels | 界面采用主时间线与可切换编辑/混音面板；当前文档标为开发版。 |
| [MuseScore Studio](https://handbook.musescore.org/appendix/command-line-usage) | Notation / properties / playback | MusicXML用于符号结构交换，MIDI用于演奏；排版器不等于PDF识别器。 |
| [Dorico](https://www.steinberg.help/r/dorico-pro/6.2/en/dorico/topics/play_mode/play_mode_project_window_r.html) | Setup / Write / Engrave / Play | 音乐内容、版面和演奏阶段区分；显示与演奏时值不应互相破坏。 |
| [ScanScore](https://scan-score.com/en/start-tips/) | Original + recognized side-by-side | 先核小节线和拍号，再校音符细节；原谱对照和试听参与校正。 |
| [SmartScore](https://www.musitek.com/smartscore-online-help/professional/music_recognition/tiff_pdf_recognition.php) | Recognition / structure report / editor | 识别后先检查系统和声部数量，再进入编辑；原稿与识别稿分开。 |
| [Audiveris](https://audiveris.github.io/audiveris/_pages/reference/limitations/) | Symbol graph and MusicXML | 官方记录仅支持3/6连音；异常小节与声部校正不能用解析成功替代。 |
| [homr](https://github.com/liebharc/homr) | Segmentation + transformer + MusicXML | 支持钢琴大谱表的候选；目前已隔离安装0.7.0，正在实际评测，尚不判定优于现有方案。 |
| [Oemer](https://github.com/BreezeWhite/oemer) | Segmentation / geometry / MusicXML | 借鉴谱线、音头和符号定位流程；官方README推荐homr改进路线。 |
| [Sheet Music Transformer](https://github.com/antoniorv6/SMT) | Image-to-sequence polyphonic transcription | 研究复音与整页建模、公开评测；首轮不以自训练模型替代产品交付。 |

## 2. 架构取舍

| 路径 | 结果 |
| --- | --- |
| 只换样式、沿用四设备声部作为全部编辑模型 | 无法保存原始乐器、左右手、程序号及变拍，不能作为完整方案 |
| 直接分叉一套完整DAW | 引入音频宿主、插件及大量无关功能；FPGA通信和校谱仍需重写，本阶段不采用 |
| 保留PySide6，分离乐谱、编曲和设备编译 | 符合现有工程、用户选择和设备责任边界，作为后续重构方向 |

后续数据关系应为：原始文件／原始MusicXML → ScoreDocument（记谱） → 轨道与片段（编曲） → 显式设备映射 → Song／WSV2（设备资源）。

- 原始MusicXML保留谱表、声部、调号、谱号、休止、延音、连音及稳定ID，不能把播放事件重生成的谱面冒充原谱。
- 记谱时值与演奏时值分开。编辑和导入不自动量化；精确分数在设备编译时才转换PPQN，无法表示时阻止下发。
- 电脑可以有较多源轨道，设备四个逻辑声部仅在编译前映射。32个振荡器声部不等于32条编曲轨道。
- 轨道、片段、片段实例与源音符必须分别拥有身份；普通复制与链接副本明确区分。跨片段边界的持续音不能直接丢弃。
- 工程格式4与源轨道参考试听已接入，兼容读取2／3并另存 `_v4`；完整片段内容／实例模型仍未完成。旧时间线丢失的记谱信息不会因迁移自动恢复。

## 3. 已复现的问题

1. 匹配原应用字体／样式后，1366×768请求得到1366×912窗口，谱面视口只有816×173。
2. MIDI保真探针中，原channel3、channel4均折叠成设备part2；钢琴／弦乐程序号未保留；在1920tick处的变拍变成从曲首使用3/4。
3. 现有Nocturne V3工程的原始XML为空，重建谱没有调号节点；四条设备角色被写成多个谱表，并非原钢琴双谱表。
4. 原默认导入先走特定矢量PDF启发式，可能在光学识别前就覆盖原结构。
5. 后台识谱仅检查资源ID，会覆盖同资源的新编辑。
6. 组合执行主线程和后台排版时，Verovio存在字体资源初始化失败；单独运行部分测试不能暴露该问题。

详细证据位于 `build/research/daw_omr_20261017/`：`midi_preservation_probe.json`、`notation_structure_audit.json`、`observations.json`。

## 4. 实际识谱实验

测试对象为用户原始四页《Nocturne in D Minor 第二版.pdf》，原文件未修改。原谱共102小节，人工读取的初始速度为四分音符158，谱面有两个降号及五／九连音。不能依据文件名推断调号。

| 引擎／处理 | 本机结果 | 可据此作出的判断 |
| --- | --- | --- |
| 已有Audiveris原始结果 | 102小节；保留-2调号；只有3:2、6:4连音；未输出158速度 | 官方声明只支持三／六连音；不能单独修准本曲五／九连音 |
| homr 0.7.0 默认分割批量 | 首页面完成，其他页出现分配失败 | 只说明本次环境及配置有资源问题，未测独占峰值 |
| homr分割批量限制为4，CPU | 四页均完成，每页约39～45秒 | 证明能运行，不证明准确 |
| homr原始谱面检查 | 首页面19小节，原谱20；未识别速度，后续单页缺拍号上下文 | 不能直接拼接／下发，必须先处理小节对齐与上下文 |
| homr关闭过度连音清理的首页面实验 | 仍19小节，只得到3:2连音 | 该补丁未解决本曲复杂连音 |
| MuseScore归一化homr结果 | MusicXML转换退出0、Partitura可读取；仍19小节，少量人工锚点仍不匹配 | 格式兼容性成功不是音乐正确性 |
| Clarity-OMR | 游戏并行及内存紧张时按用户要求停止，未输出XML | 不以中断判断引擎独占性能；该源码版本的XML导出显式忽略连音时间缩放，当前仍不能直接采用 |

来源：[Audiveris限制](https://audiveris.github.io/audiveris/_pages/reference/limitations/)、[homr](https://github.com/liebharc/homr)、[Clarity导出代码](https://github.com/clquwu/Clarity-OMR/blob/main/src/pipeline/export_musicxml.py)。

识谱策略：原稿、两引擎候选、当前校正版分别保存；先对齐小节和声部，再显示冲突。缺失速度、调号、连音和不平衡小节必须显式呈现，不能默认填值后自动标为正确。双引擎一致也不替代原谱核对。

已生成102个原谱小节裁剪及索引，均保留未完成审核状态。现有959个事件、MusicXML合法及往返成功都不能作为整曲正确答案。

完整双引擎任务中心、Windows进程内存上限／取消、逐小节差异界面及102小节逐音审核仍待实现。此次没有重新启动大模型推理来占用用户游戏资源。

## 5. 本轮已落地的代码

- 从主窗口提取 `host_app/workstation_layout.py`，提供编曲、校谱、音色、设备四个工作区；串口、下发、分段配器和诊断集中到设备区。
- 顶部共享试听控制；文件与高级编辑进入菜单；源谱与当前记谱可并排、翻页、适宽显示；检查器可收起，F11最大化编辑区域。
- 在窄屏收起侧栏，在低高度收起概览，音色和设备详细页面允许滚动。文字输入框保留空格及本地撤销操作。
- 后台结果比对原资源完整快照；原曲变化／关闭时另存候选工程，保留原谱文件，避免覆盖新编辑或会话结束后丢失结果。
- 默认五线谱识别改为Audiveris原始MusicXML路径，矢量启发式只允许显式选择为诊断候选；所有识别音符仍待确认。
- 每个Verovio实例显式加载包内字体，修复后台字体初始化失败。实现依据[官方Python接口](https://book.verovio.org/installing-or-building-from-sources/python.html)。
- 修复切换到无原谱曲目时仍显示旧图片的问题；保留原来的WSV2通信和资源审核规则。
- 增加 `source_tracks.py`：应用导入保留轨道ID、原part／staff／voice、GM乐器、MIDI控制顺序及变拍；卷帘按源轨道筛选，参考试听使用独立通道，保留踏板及乐器变化。源轨道可设参考音量／静音／独奏。
- 设备映射单独保存，生成下发副本时才投影成四逻辑声部，不改写原XML。未映射或含未转换的控制事件时阻止下发；源谱GM音色不能直接当成FPGA自定义音色。
- MIDI参考试听目前最多15条独立旋律轨道，鼓用通道10；超限及多端口MIDI明确报错，不静默丢轨。完整片段、控制器编辑和控制事件到设备的转换仍待实现。
- 导入原谱的节奏／声部结构编辑暂交给MuseScore，阻止此前整曲重建导致的调号丢失。重新记谱的MIDI／旧时间线仍可用卷帘编辑。

启动入口为根目录 `启动音乐工作站.bat`；原 `start_workstation_v2.bat` 保留。已有打开的软件需关闭后重新启动才会载入新界面。使用说明见 `docs/MUSIC_WORKSTATION_QUICKSTART.md`。

## 6. 与题目二的边界

题目PDF印刷页13～14为验收来源，逐项表见 `build/research/daw_omr_20261017/requirements_crosswalk.json`。

- 电脑参考试听与设备模型是校谱工具；比赛验证关闭电脑出声。设备演奏仍要求FPGA独立完成解析、调度、振荡器、ADSR、力度、效果和混音，电脑不得推送PCM或依赖逐音符实时串流替代。
- 单周期波表与参数可以下发；整段录音、整首歌曲PCM不能作为设备曲谱播放资源。电脑SoundFont不进入FPGA曲库。
- 维持32独立状态、至少4复音、控制维度、变调、效果器及设备容量；UI不能以轨道数量、波表谐波或电脑音频替代硬件证据。
- 基础总延迟≤10ms与拓展≤5ms分别验收；数字仿真不替代传感器到模拟输出整机实测，不能声明无抖动已达标。
- 题目要求I2S到DAC，没有禁止“板载DAC”这个位置。板载PT8211的右对齐格式与标准Philips I2S有区别；本轮不改变或烧录FPGA。
- 设备屏幕动态曲库／音色库、断开电脑的自主演奏、屏幕官方TFT编译、标准I2S实物输出、LED指引／蓝牙／回传仍按各自真实证据标记，不能因界面有按钮就判完成。

目前的“符合题目要求”指设计边界和发布门禁持续遵守题目，不表示整机所有基础及拓展已经完成验收。

## 7. 当前验证与下一步

- 本轮主机回归76项通过，包含源轨道保真、同tick控制顺序、格式4、设备映射隔离、后台版本冲突、候选另存、视图切换、原图清理、谱面排版、参考试听及设备通信模型。
- 两种分辨率（1366×768、1920×1080）与100%／125%／150%缩放执行四工作区离屏检查；最终尺寸和截图保存在 `implemented_layout/`。这不代替完整真人编曲可用性测试。
- 下一步补完整片段内容／实例模型、双引擎候选界面和逐小节校谱；当前源轨道、卷帘和参考试听已读取同一份编辑数据。未审核谱面不自动下发。
- FPGA、引脚及ready位流不因本轮上位机修改而替换；新版硬件实测仍保持待完成。
