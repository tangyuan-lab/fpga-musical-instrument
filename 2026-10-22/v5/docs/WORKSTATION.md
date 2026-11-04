# 演奏工作站与扩展接口

## 本版工程

- 中文总界面：鼓点模式、弹琴模式、混音模式、实体键设置。
- 屏幕键固定发出本模式的声音：鼓点页16种鼓音；弹琴/混音页16个琴音；混音页另有4个鼓垫。
- 实体键按每个模式的独立配置发声，可逐键选择旋律/打击乐、音色和音高。鼓点页也可以把实体键配成琴音，弹琴页也可以把实体键配成鼓音。
- 2026-10-12采集板改为裸两线FSR接3.3V与CHx，板上10kΩ下拉形成按压升压；本版工作站方向已改为升压。接线与配置见[压力输入说明](WORKSTATION_PRESSURE_INPUT.md)。
- 两组SPI约束按用户现有导线适配：SCLK/MISO/MOSI/CS分别为AA19/AA20/AB21/Y21与AB20/AA21/AB22/Y22，使用独立`instrument_workstation.cst`。
- 鼓点支持四轨16步、40..240 BPM、轨道音色、空白/摇滚/四拍预设。混音模式有独立鼓点与MIDI启停、同时启动、三路音量及静音。
- 返回首页和模式切换停止播放，但保留编排、音量和MIDI文件。换模式/改映射后须松开已按住的实体键再按。
- 旋律合并为一路混音输入，其中实体键4声部、屏幕键4声部；MIDI4声部；鼓音8声部。超过各分配器上限会抢占声部。
- 和弦识别读取实际旋律按键（含实体映射后的音高），使用88种和弦字典；MIDI伴奏及鼓音不计入。

HMI源码：`screen/TJC1060X570/generated/instrument_workstation_fixed/instrument_workstation.HMI`（2026-10-12修正版）。
官方编译和实物验证仍需完成；生成脚本不会把源码校验当作TFT编译成功。

2026-10-11：中文HMI通过971项源码/事件/字库检查，240个控件，原生CFS校验通过；各模式手动返回及停音顺序已验证。
工作站FPGA构建通过，Setup/Hold违例0/0；配套SRAM位流已生成，尚未下载新版。
上述2026-10-11位流使用降压方向；2026-10-12升压改动须重新构建并下载，构建结果见压力输入说明。
2026-10-12现有SPI接线的升压版已重新构建且Setup/Hold为0/0，8个实际PnR引脚核对通过。12:19重新SRAM下载退出码0，COM15 PING/ACK通过，`audio_ready=True`；用户随后确认弹琴模式下实体压力变化且有声音。位流SHA256为`35B8F988F4809A539552D622944BF57C9B823EF31A3CE6347C669AE1EB997FA2`；16路逐键及延迟实测边界见压力输入说明。
2026-10-12修正官方编辑器发现的问题：tmRestore为50ms，中文字库改用官方混合中英子集头与小端uint16码表升序。修正版1166项源码/事件/字库检查通过，官方编译待确认。
数字起音仿真六个用例通过：实体压力路径最大3.555610ms，UART路径最大0.460470ms。

## 页面设计源码

首页采用深色工作室风格、四个卡片入口；鼓音用琥珀/紫/青色区分，琴键采用真实黑白键布局。
白键文字在下方，黑键的触摸层级在白键之上；刷新白键后重绘相邻黑键。
按下时先发送声音帧，再高亮控件；描边短暂衰减后保留按住状态，松开后恢复。
同一音高还有实体键保持时，屏幕松开不清掉该音的高亮。空闲时不循环绘制动画。
所有模式页（含节奏编排和实体键设置）右上角都有“返回首页”。随时点击立即停音、清除触摸保持并返回总界面，保留已保存的配置，无须等待空闲超时。
“最高压力”显示16路实体压力最大值；它不把映射后的音高编号当作传感器编号。
演奏页连续120秒无操作/演奏后自动回首页；按键保持、鼓点/MIDI播放、四音测试及映射恢复期间不计时。
设置页不自动退出。超时在注册表`ui_settings.auto_home_idle_seconds`设置，0表示关闭。

- 色彩、首页图稿和几何：`screen/TJC1060X570/design/workstation_theme.py`。
- 控件、触摸事件、EEPROM及状态联动：`screen/TJC1060X570/design/create_workstation.py`。
- 中文标签及中文和弦名称：`screen/TJC1060X570/design/workstation_zh.py`；音高仍用C4等通用记号。
- 中文ZI字库生成：`screen/TJC1060X570/design/build_workstation_font.py`；保留已有ASCII字形，增加159个中文字形。使用官方7.zi的子集模式2及uint16升序索引，字库已嵌入HMI。
- 一条命令重新生成HMI并检查：`python scripts/verify_workstation.py`。
- 预览输出：`build/tests/workstation_home.png`、`workstation_piano_pressed.png`及其他模式图。

预览使用生成HMI所用的ZI字形；仍须通过官方编辑器编译及屏幕实测确认最终显示。
编辑画布会叠加各模式的控件；page0运行时由drawView隐藏其他模式并重绘。请编译后用“调试”查看实际页面。

## 设置及持久保存

在“实体键设置”选择鼓点/弹琴/混音配置，再选实体键，选择声音类型、音色、音符/鼓，点击“保存此键”。
“恢复本组”恢复当前配置的默认值。当前旋律音色为三角波、柔和方波；鼓音由DDS、噪声、包络合成，没有录制PCM。

“保存此键”只写一个映射，使用X5屏幕EEPROM地址512..703。每槽4字节，小端值为`0x57010000 + descriptor`。
写后等至少1秒再断电。这个地址范围属于本工程，不与其他页面共用。
FPGA映射寄存器掉电恢复默认；屏幕每50ms恢复一个槽，48槽约2.4s，完成后发送BOOT_ACK并解锁首页入口。
FPGA重启会再次请求恢复，避免“屏幕先下载、FPGA后烧录”丢掉保存的设置。
编排、音量、上传MIDI目前只在本次上电期间保留。

## 分层与稳定接口

| 层 | 接口/职责 |
|---|---|
| 硬件 | 两片MCP3208、C18/C19屏幕UART、USB UART、板载PT8211和HDMI |
| 协议 | 五字节屏幕帧解析；原USB CRC16文件协议；数字状态回传 |
| 应用 | `instrument_mode_control`管理模式/三套映射；`instrument_key_router`分开实体与屏幕输入；`drum_sequencer`只产生事件 |
| 音源 | 按统一`sample_tick`输出有符号PCM16，禁止分别驱动DAC引脚 |
| 混音 | `pcm_source_mixer #(SOURCES=N)`；每路PCM16、7位音量0..100、使能；平滑增益、宽位相加、饱和限幅 |
| 页面 | 一个原生page0中的逻辑视图；状态由FPGA回传，本地触摸保持只用于触摸保活 |

注册表源为`config/instrument_registry.json`，生成器读取音符/鼓名称并输出一份注册表副本。
描述符16位：`kind[15:14] / timbre[13:8] / note[7:0]`，预留4类声音、64个音色编号、256个音符/事件编号。
当前实际接受kind=0、timbre=0/1、note=0..15，或kind=1、timbre=0、note=0..15。
未实现的编号拒绝提交。编号容量不代表相应音色已经实现。
模式容量8套，当前模式0..4；5..7为扩展编号，默认禁止。

新增音色：更新注册表，增加/扩展合成模块，更新支持范围和页面选择器，再补波形/事件验证。
新增音源：接入PCM16采样接口，扩大SOURCES及对应音量/使能总线，保持唯一DAC发送器。
新增模式：启用保留模式编号，定义实体配置及屏幕事件路由，增加逻辑视图及校验用例。
不得更改旧编号含义、把实体映射应用到屏幕键，或把未知音色映射成另一个现有声音。

同鼓并发事件在路由层锁存各键按下瞬间的力度，再用平衡比较树取最大值。
四拍流水线在50MHz下为80ns；模式/映射切换或STOP清除各级事件，避免切换后补发旧鼓音。
合成器启用输入流水时先寄存声部力度，再计算ADSR；波形差值、两次乘法和交叉淡化分别寄存。
波形路径五拍共100ns，乘法数据寄存器采用同步复位，输出复位立即清零。

## 屏幕到FPGA协议

115200、8N1；`A5 5A OP VALUE CHECK`，`CHECK=FF xor OP xor VALUE`。
每帧只携带一个字节参数，数值多字段配置以分阶段编辑＋提交实现。

| OP（十六进制） | VALUE及作用 |
|---|---|
| 00 / 01 | 琴键0..15松开/按下或保活；重复保活不重触发 |
| 02 | FF：全部停止，清触摸、实体保持音、鼓音、编排和MIDI；重置八度/测试 |
| 03 / 04 | 八度0/1/2为原/高/低；四频TEST为0/1，TEST须150ms保活 |
| 05 | 模式0 HOME、1 DRUMS、2 PIANO、3 MIX、4 SETUP |
| 06 / 07 / 08 | 鼓触发0..15；BPM40..240；屏幕琴音音色0/1 |
| 09 / 0A / 0B | 琴音/鼓音/MIDI音量0..100 |
| 0C / 0D | 设置/清除某步，VALUE=轨号×16＋步号；重复设置幂等 |
| 0E / 0F | 轨道鼓音，VALUE=轨号×16＋鼓号；编排0停止/1启动 |
| 10 / 12 | MIDI0停止/1启动（仅MIX且文件有效）；预设0空白/1摇滚/2四拍 |
| 20 / 21 | 编辑配置bank=1..3；实体键号0..15 |
| 22 / 23 / 24 | 分别暂存声音类型、6位音色编号、8位音符/鼓编号 |
| 25 / 26 / 27 | 1提交完整映射；恢复bank默认；1确认启动映射恢复完成 |

USB COM15继续使用现有MIDI/FTB上传、PING、PLAY/STOP和STATUS协议；新增屏幕控制帧目前走C19。
不能把五字节屏幕帧直接发送到COM15当作USB文件协议。

## FPGA到屏幕

ASCII `rxNAME.val=DECIMAL`后跟`FF FF FF`；优先发送模式、实际按键位图、鼓触发事件。

- rxKeys：16位实际旋律音高位图；rxDrums：每次鼓触发翻转相应位，页面比较变化触发动画。
- rxConfig：一次原子快照，`bank<<20 | key<<16 | descriptor`，避免设置页拼接不同时刻的数据。
- rxFlags：bit0编排、bit1 MIDI播放、bit2文件已接收、bit3解析忙、bit4音频就绪、bit5解析错误、bit6命令错误脉冲、bit7需恢复映射。
- rxBpm/rxStep/rxPat0..3/rxSnd0..3/rxVol0..2：节奏与音量；rxP0..15是真实12位压力值。
- 声音发送先于屏幕绘图；50ms动画帧间隔不作为声音延迟指标。屏幕是否支持多指输入仍待实测。

## 生成、检查、编译下载

项目根目录执行：

```powershell
python scripts/prepare_workstation.py
python scripts/verify_workstation.py
python scripts/run_tests.py tb_poly_synth_pipeline tb_key_router_events tb_workstation_services tb_workstation_screen_tx tb_drum_synth tb_key_sound_mapping tb_midi_player_engine tb_workstation_latency
scripts/build.ps1 -Target instrument_workstation
```

生成顶层硬件与MIDI服务代码；应用连接源码在`rtl/board/workstation_body.inc`。
Gowin工程是`gowin/instrument_workstation.gprj`，顶层`instrument_workstation_top`，推荐上面的CLI构建以明确顶层和时序门槛。

USART HMI打开本版HMI，点击编译；有错误时不要下载旧TFT。成功后USB转TTL直接下载屏幕，FPGA C18断开屏幕RX。
下载完成断开转接器TX，恢复C18→屏幕RX，C19←屏幕TX，共地；保持5V供电和FPGA输入电平适配。
编译的TFT可用`python scripts/collect_touch_tft.py --project instrument_workstation`收集并校验。
FPGA使用`build/ready-to-program/instrument_workstation_sram.fs`，只有时序检查通过才会发布到该目录。
`scripts/program_workstation.ps1`检查哈希、源码和Setup/Hold后SRAM下载，不写Flash。

延迟测试只验证数字输入到串行音频非零样本，MIDI/鼓点背景在测量起音时静音；不包含触摸扫描、模拟传感器及DAC/功放延迟。
板载PT8211为右对齐LSBJ格式，不能用标准I2S模块替换后仍声称板载接口兼容。
