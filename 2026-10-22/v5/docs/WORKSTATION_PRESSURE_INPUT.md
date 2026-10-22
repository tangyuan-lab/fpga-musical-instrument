# 工作站压力输入：裸两线FSR与MCP3208

## 当前硬件与代码方向

2026-10-12根据用户提供的电路图确认：仍使用MCP3208，VDD/VREF均为3.3V，AGND/DGND与FPGA共地。
每块板8路；16键使用两块板，第一块CH0..CH7对应键1..8，第二块CH0..CH7对应键9..16。

每一路压力片的接法如下，电阻与电容已在图中的采集板上：

```text
3.3V ── FSR压力片 ──●── 390Ω ──●── MCP3208 CHx
                    │          │
                   10kΩ       100nF
                    │          │
                   GND        GND
```

不要在原有10kΩ旁再并一只下拉，否则会改变压力与电压的对应关系。
松开时FSR阻值大，CHx接近0V；按压时FSR阻值减小，CHx电压上升。
忽略ADC输入电流时，稳态电压约为`3.3V × 10kΩ / (R_FSR + 10kΩ)`。
MCP3208把模拟电压转换成12位数字码，再通过SPI发送到FPGA；FSR本身不发送数字协议。

## 软件配置

`config/instrument_registry.json`的`pressure_inputs.active_low_mask`为16位逐键方向掩码：

- `0`（当前）：16路均为按压升压，压力=当前ADC值−松开基线，负值钳为0。
- `65535`：16路均为旧降压接法，压力=松开基线−当前ADC值，负值钳为0。
- 混合接法按位设置；bit0对应键1，bit15对应键16，1为降压、0为升压。

仅独立工作站的默认值被覆盖，生成器不会修改历史顶层的方向。
修改配置后须执行`python scripts/prepare_workstation.py`并重新构建FPGA。
不要只编辑生成的`rtl/board/instrument_workstation_top.sv`，否则下次生成会覆盖。

上电或复位时松开所有实体键，待基线校准完成后演奏。
压力处理继续使用低通滤波、起音16码/释音8码迟滞及2048码满力度；这些阈值是电压码差，不是力的物理单位。
不同FSR可能需要实测标定；压力不是线性力值测量。

## MCP3208到FPGA数字线

| 采集板信号 | 第一块FPGA引脚 | 第二块FPGA引脚 |
|---|---|---|
| SPI_SCLK/CLK（排针3） | AA19 | AB20 |
| SPI_MISO/DOUT（排针4） | AA20 | AA21 |
| SPI_MOSI/DIN（排针5） | AB21 | AB22 |
| ADC_CS/CS（排针6） | Y21 | Y22 |

2026-10-12用户确认采集板排针从左到右为SCLK/MISO/MOSI/CS，代码按两组现有导线适配。
对应NEO Dock PMOD1的IO6/IO4/IO2/IO0和IO7/IO5/IO3/IO1，接线以底板实际丝印核对。
工作站使用独立`gowin/instrument_workstation.cst`，由注册表`pressure_inputs.spi_pins`生成。
历史工程的`instrument_full.cst`仍是旧顺序，本次适配仅用于工作站；不要用历史位流验收此接法。
压力片只接采集板3.3V与对应模拟端口，不接FPGA数字GPIO。

## 验证与预期现象

```powershell
python scripts/prepare_workstation.py
python scripts/prepare_workstation_tests.py
python scripts/run_tests.py tb_16key_pressure_rising_audio_path tb_16key_pressure_audio_path tb_mcp3208_dual_scan tb_workstation_latency
powershell -File scripts/build.ps1 -Target instrument_workstation
```

新接法的四音复音、独立力度、释音静音和16键计数测试已通过；SPI扫描模型已通过。
2026-10-12现有接线版已完成构建，Setup/Hold违例0/0，实际PnR报告的8个SPI脚号、输入/输出方向及LVCMOS33全部核对通过。
文件：`build/ready-to-program/instrument_workstation_sram.fs`；SHA256：`35B8F988F4809A539552D622944BF57C9B823EF31A3CE6347C669AE1EB997FA2`。
2026-10-12 12:19通过Gowin CLI重新下载到GW5AT-60B SRAM（设备ID0x0001481B），退出码0，未写Flash。
随后COM15 PING返回ACK（nonce=0x4660D18A），状态查询`audio_ready=True`、`parser_error=False`。
同日用户在弹琴模式按压实体压力片，确认“压力变化且有声音”。这确认已试按键的实物采集与发声链路；不代表16路逐键、复音、力度范围及模拟总延迟已全部测量。
2026-10-12新升压配置的数字起音延迟六个用例全部通过：实体压力输入最大3.555610ms、UART首位到串行非零样本最大0.460470ms。
SPI为1MHz、UART为115200、音频采样率48828.125Hz。仿真基线为1095码，轻按升至1111码；实际基线由上电松开校准取得。
仿真不包含模拟传感器、RC滤波、触摸扫描和DAC/功放；不能直接当作整机实测总延迟。

100nF电容会带来模拟响应时间，近似时间常数为`(390Ω + R_FSR并联10kΩ) × 100nF`，上界约1.039ms。
时间常数不等于从压力到可闻声音的总延迟；还需计入传感器响应、扫描、数字滤波、DAC与功放。

屏幕工程、UART报文与声音映射接口无需因压力极性改变重新生成。
若屏幕尚未完成编译，烧录后松开实体键等待校准，按AB13两次即可从首页经鼓点进入弹琴模式，直接验证实体琴键发声。
AB13依次循环：首页→鼓点→弹琴→混音→首页；返回或换模式后松开已经按住的键再按。
配套新版工作站屏幕已下载时，烧录新FPGA并松开全部实体键复位，选择弹琴模式：
按压对应实体键应发声，“最高压力”增加，映射音高对应琴键高亮；松开后压力回落并释音。
鼓点/混音模式的实体键仍按各自保存的映射发声。

## 电脑直接诊断，无需依赖屏幕

暂时断开屏幕C18/C19，把独立3.3V信号USB转TTL的RXD接C18、TXD接C19、GND共地，VCC不接。
在实际转接器端口执行（端口可能变化，例如COM19，不是板载COM15）：

```powershell
python -m host_app.workstation_probe --port COM19 --piano --seconds 15
python -m host_app.workstation_probe --port COM19 --tone-seconds 10 --seconds 5
```

第一条直接切到弹琴，读取16路滤波压力、实际音符位图与模式；按压/松开时应能看到对应数据变化。
第二条发送持续四音测试，跳过压力输入；测试后停音并保留弹琴模式，实体键松开后再按。
记录保存到`build/workstation_pressure_probe.json`。
`audio_ready=True`只说明音频启动完成，不证明ADC数据变化或耳机实际发声；`voice_count`是USB MIDI服务声部数，不代表实体键声部数。

## 现有接线版构建

已核对本次只改变8个SPI脚号，RTL、50MHz SDC和3.3V电气设置与上一版一致。
可运行`./scripts/build.ps1 -Target instrument_workstation -ReuseSynthesis`，脚本验证旧位流/网表绑定、RTL/SDC哈希和仅球号变化后，直接导入网表重新PnR；仍要求Setup/Hold均为0再发布。
本次接线版已编译并完成SRAM下载；之前的5B103CAF位流不包含此脚位顺序。
引脚报告：`build/instrument_workstation_spi_pinout_verification.json`；下载日志：`build/instrument_workstation_program.log`。
续接时首次COM15查询未收到ACK，重新SRAM下载后通信恢复；SRAM配置掉电丢失，重新上电后需重新下载本版再验收。
