# 上位机开源参考与改造选择

调研日期：2026-10-16。2026-10-17 已接入 Verovio、Partitura 和 FluidSynth；本文件保留选型背景。当前实现、测试和未完成项见 [V3 实现与验收](OPEN_SOURCE_IMPLEMENTATION.md)。

## 1. 当前代码需要解决的问题

- `music_project.Song` 主要保存音高、起止 tick、力度和四个设备声部。它没有完整保存书面谱的小节、休止、谱号、音名拼写、连音分组和变拍信息，不适合作为五线谱编辑的唯一数据源。
- `preview_audio` 的内置音色是简单波形与包络，适合检查基本起止和音高；它缺少真实钢琴等参考音色。识谱准确性与试听音色质量需要分别验证。
- 当前钢琴卷帘、音符表和原 PDF 已有联动，但缺少成熟的五线谱校正工作流、标准乐谱交换和编曲片段操作。
- Audiveris 的原始识别与后来人工编辑必须保留不同版本。能解析、能播放、测试通过，均不能直接证明音符与原谱一致。

## 2. 已核查的项目

| 项目 | 官方能力 | 本工程采用方式 |
| --- | --- | --- |
| [MuseScore Studio](https://github.com/musescore/MuseScore) | 完整乐谱编辑、播放、MusicXML/MIDI 交换 | 参考音符输入、连音/休止编辑和小节校正；支持通过 MusicXML 交给它精细校谱，再导回当前曲目 |
| [LMMS](https://www.lmms.io/) | 歌曲编排、钢琴卷帘、节奏编辑、混音和 SoundFont | 参考轨道、片段、力度栏、播放控制的工作流；保留本工程中文资源管理和 FPGA 联动 |
| [Verovio](https://github.com/rism-digital/verovio) | 乐谱排版库，支持 MusicXML 输入、SVG 输出和 Python 接口 | 作为应用内的五线谱显示候选，用已有 Qt SVG 能力显示；不把它当 PDF 识别器 |
| [FluidSynth](https://www.fluidsynth.org/wiki/GettingStarted/) | 使用 SF2/SF3 SoundFont 的软件合成器 | 增加电脑“参考乐器试听”；音源文件单独选择与记录，不上传整套 SoundFont 冒充 FPGA 音色 |
| [Audiveris](https://audiveris.github.io/audiveris/_pages/handbook/) | 印刷五线谱识别、交互校正、MusicXML 导出 | 已用于本工程，继续作为印刷谱辅助识别入口；保留原稿、疑点和人工确认 |
| [Partitura](https://github.com/CPJKU/partitura) | MusicXML/MIDI 读写，包含谱表、声部、小节等符号模型 | 作为结构检查与转换的候选；先验收复杂连音、延音与变拍，再决定是否替代现有手写解析器 |

不将整套 MuseScore 或 LMMS 源码移植到 PySide 窗口。优先使用可独立集成的排版与合成组件，通过标准文件与完整编辑软件互通。

官方说明中的两个边界：

- Audiveris 明确说明识别并不完美，提供 GUI 用于检查和校正，并支持交给外部乐谱编辑器继续处理。复杂谱仍需核对。[官方手册](https://audiveris.github.io/audiveris/_pages/handbook/)
- Verovio 的 MIDI 导出有节奏处理边界，例如当前文档说明速度变化仅支持小节开始位置。谱面显示与权威播放时间线需要分开，不直接用其 MIDI 导出覆盖设备演奏数据。[输出格式](https://book.verovio.org/toolkit-reference/output-formats.html)

## 3. 选择的应用结构

### 乐谱文档与设备资源分层

工程保存以下三层：

1. **来源层**：原 PDF/图片、原始 MusicXML、原始识别结果、来源摘要。
2. **编辑层**：保留小节、声部、谱号、调号、拍号、休止、连音、延音、速度及用户校正记录的乐谱文档。
3. **演奏层**：从用户选定的编辑版本生成音符时间线，分配到设备四个逻辑声部，检查容量后编译为 FPGA 资源。

原始 MusicXML 应随工程嵌入。对于已有的简化时间线工程，不能凭空恢复被丢弃的书面记谱结构；应保留旧工程并标明导出乐谱属于重新记谱结果。

Partitura 等符号库作为文档适配器和检查器使用，原始文件另存，避免反复导入导出时静默丢弃未支持的记号。

### 界面布局

- 顶部：工程名、保存状态、播放/暂停/停止、小节位置、速度、循环、电脑/FPGA 目标。
- 左侧：曲谱、段落、音色资源，显示来源、待校正和已同步状态。
- 中部：轨道与片段时间线，显示段落边界；轨头提供音色、音量、静音、独奏。
- 下方：钢琴卷帘与力度栏；切换到五线谱时显示真实乐谱文档。
- 右侧：当前音符/片段属性、原谱对应区域、识谱疑点。
- 设备诊断保留独立页，避免串口字段挤占日常编曲区域。

先做片段的移动、复制、循环和段落配器联动，随后再扩展混音效果控件。

### 两种电脑试听

| 试听选择 | 用途 | 限制 |
| --- | --- | --- |
| 参考乐器 | FluidSynth + 用户选择的 SoundFont，检查旋律、节奏、和声 | 音色与 FPGA 合成器不等价；SoundFont 是单独的资源 |
| 设备合成模型 | 本机波表/ADSR 模型，检查段落配器与导入波表 | 不作为实际 FPGA 定点结果或实物发声证据 |

两者使用同一份已编排时间线、速度表、静音/独奏及循环范围。切换试听引擎时停止旧播放，防止两个引擎同时出声。

真正下位机演奏继续由 FPGA 完成音符调度、振荡器、包络、混音及数字音频输出；电脑参考试听不改变题目验收链路。

## 4. 按收益排序的实施步骤

1. **保留完整谱面与校谱交换**：保存原始 MusicXML；实现“导出到乐谱编辑器”“导入校正结果”，保持歌曲资源 ID，增加版本；导回后显示音符和时值差异，避免覆盖其他曲目。
2. **接入标准参考试听**：增加可选 FluidSynth 后端、SoundFont 选择与音色表；缺少组件时明确显示状态；保留现有设备合成模型。
3. **成熟五线谱显示**：通过 Verovio 显示 MusicXML，支持翻页、缩放；建立源音符 ID 与时间线映射后再做点击与播放高亮。只显示原始识别稿时必须标出版本，不能让用户误认为与修改后的卷帘一致。
4. **整理编曲工作区**：参考 LMMS 的轨头、片段、力度和时间标尺，把通用编曲与设备下发信息分别放在对应区域；全程保留撤销/重做。
5. **再升级识谱**：在真实样谱中验证符号模型与识别器，用每小节疑点和对照编辑提高可修正性；本次 PDF 专用矢量解析器保持限定范围。

## 5. 验收标准

- 同一份已校正 MusicXML 在 MuseScore 与本程序中得到相同的音高、起止、速度变化与延音；差异有报告。换排版器不能自动算作通过。
- 检查至少包括跨小节延音、行内换谱号、三/五/九连音、休止、同音叠置、弱起、变拍和重复段。无法支持的记号必须提示。
- 新增参考试听能播放真实 SoundFont 音色，独奏、静音、暂停后定位和循环行为与当前时间线一致；待确认音符可在电脑听，但不能自动确认并下发。
- 导出、外部校正、导回和保存重开后，原谱与识别初稿保留，资源 ID 不混用，设备容量超限明确提示。
- FPGA 部分保留当前验证过的 MCP3208 接线和下发协议。界面改进不替代时序、I2S、容量及整机延迟验收。

## 6. 官方参考入口

- MuseScore：[MusicXML 工作流](https://handbook.musescore.org/file-management/working-with-musicxml-files)
- LMMS：[源码与功能](https://github.com/LMMS/lmms)
- Verovio：[Python 接口与 Windows 支持](https://book.verovio.org/installing-or-building-from-sources/python.html)
- Partitura：[乐谱对象模型](https://partitura.readthedocs.io/en/latest/modules/partitura.score.html)
- FluidSynth：[官方下载](https://www.fluidsynth.org/download/)

组件已在工程工具目录准备，版本、许可和音源来源见 `build/tools/music/manifest.json`。MuseScore构造样谱与完整Nocturne959音符演奏时间线均已实际往返通过。schema3修复重新记谱的连音分组，全部PDF识谱待确认标志保留；原始工程和旧板卡位流均保留。
