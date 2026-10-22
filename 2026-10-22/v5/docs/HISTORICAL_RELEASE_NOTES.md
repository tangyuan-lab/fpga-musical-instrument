# V12_instrument_full

日期：2026-09-23

本版本把实时 FSR/MCP3208 演奏、FPGA 内 MIDI 播放、四声部合成、PT8211 音频和 1024×600 HDMI 状态界面合并到 `instrument_full` 顶层。上电默认是实时演奏模式，按 AB13 切换到 MIDI 模式；上位机仍只发送完整 MIDI 文件、FTB 单周期波表和控制帧，MIDI 解析、Tempo、事件调度、声部分配、相位累加、ADSR、混音和音频输出全部在 FPGA 内完成。

本轮为整合工程增加了同步 MIDI 文件 RAM 输出寄存器、同步 Tempo 表读取、音频波形/力度流水级、UART 应答帧缓存与逐字节 CRC、FTB 分块暂存优化，以及 MIDI 音高常量相位查表。19 项 RTL 仿真全部通过，Gowin 综合、布局布线和时序检查通过：Setup/Hold 违例端点为 0/0。

最终位流：`build/ready-to-program/instrument_full_sram.fs`  
SHA256：`1426249812C77E2F1132B7E4DE17C9339D13CA615C1DAE3B7419CE71D4E1A9C7`

最终资源：Logic `22362/59904`（38%）、Register `14436/60780`（24%）、CLS `17006/29952`（57%）、BSRAM `46/118`（39%）、DSP `19/118`（17%）、I/O `35/297`（12%）、PLLA `1/8`。器件为 `GW5AT-LV60PG484AC1/I0`，Device Version B。

仍待真实板卡验收：USB-C 双向 UART、MCP3208 13 键完整接线、真实 MIDI 文件耳机播放、自定义 FTB 音色听感、HDMI 长时间稳定性和连续运行测试。`PR1014` 通用时钟布线提示仍存在，但本轮 Setup/Hold 均为 0。

# V11_uart_midi_bridge

日期：2026-09-23

本版本在 V10 的 MCP3208/13 键音频链路基础上，加入“完整 MIDI 文件上传到 FPGA、由 FPGA 自行解析和播放”的独立目标 `midi_player`。压力演奏、MCP3208 和 MIDI 目标共用音频合成核心，但各自使用独立 Gowin 工程，下载一个目标不会改写其他目标。

## 本版本内容

- 增加 UART 二进制帧协议：同步字 `55 AA`、版本、消息类型、序号、长度、payload 和 CRC16。
- 增加 64 KiB Gowin BSRAM MIDI 文件缓存；`FILE_DATA` 每块最多 128 字节，写入完成并校验后才允许播放。
- FPGA 内支持 MIDI Type 0 文件头、单轨道、PPQN、Tempo Meta Event、可变长度数、Running Status、Note On/Off，以及 velocity=0 的 Note Off。
- 修正大于 255 字节轨道的 32 位长度拼接，并用 17 位文件位置处理恰好 65536 字节时的地址回绕；新增 64 KiB 边界仿真。
- 修正 PLAY 请求的时钟握手：文件存储模块产生的延后一拍请求现在使用已锁存的音色编号，且错误长度的 PLAY 不会复用旧请求；新增顶层接收/启动仿真覆盖。
- MIDI/FTB 数据块支持同一序号安全重试：ACK 丢失时 FPGA 重新确认上一块，但不会重复写 RAM、累计字节或 CRC。
- 增加四声部 MIDI 调度和独立相位/ADSR/力度处理。
- 内置三角波和柔和方波；音色 2 使用已经上传的 256 点、16 位有符号 FTB 单周期波表。
- 上位机提供 `ping`、MIDI 分块上传、FTB 上传、`play`、`stop` 和 `status` 命令；上位机不发送 PCM，也不在播放期间发送逐音符串流。
- 保留原有 FSR 压力、MCP3208、HDMI 和 PT8211 目标。

## 电脑端验证与构建

- Python 协议测试：CRC、分片重组、坏帧丢弃、MIDI Type 0 文件头、上传/播放语义和示例文件生成校验通过。
- RTL 仿真：MIDI Type 0 解析、同步 BSRAM 读口、Tempo 调度、三次 Note On/Off、四声部合成、FTB CRC/波表写入和现有压力/MCP3208/HDMI 测试通过。
- Gowin 工程：`gowin/midi_player.gprj`。器件为 `GW5AT-LV60PG484AC1/I0`，Device Version B。
- 最终位流：`build/ready-to-program/midi_player_sram.fs`。
- Setup violated endpoints：`0`；Hold violated endpoints：`0`。
- 资源：Logic `17124/59904`（29%），Register `12323/60780`（21%），BSRAM `42/118`（36%），DSP `13/118`（12%），I/O `16/297`（6%）。
- SHA256：

  ```text
  019DC8BC1CF157728FDAD79893352EF226CE382B57E8162465099C5B8C70A295
  ```

构建日志仍可能出现 `PR1014`（`sys_clk_d` 使用通用时钟布线）提示；这是警告，不是 Setup/Hold 违例。

## 尚未完成的实物验收

以下项目截至发布日期尚未由真实板卡证明：

- NEO Dock USB-C 与电脑的双向 UART 实物通信。
- 真实 MIDI 文件上传后的 FPGA 耳机播放。
- 自定义 FTB 音色在真实 PT8211/耳机链路中的声音效果。
- 播放期间拔掉电脑后，板上音频是否按预期继续完成。
- 连续运行和不同 MIDI 文件的长时间稳定性。

因此，本版本的“通过”仅指电脑端协议/RTL 仿真和 Gowin 构建；首次上板必须按 README 的 MIDI 上板顺序，从低音量和小型 Type 0 文件开始。

## 上一版本 V10_mcp3208_volume_tuning

- `PRESS_FULL` 从 512 调整为 2048 个 ADC 码，扩大有效力度范围。
- 力度映射用右移 3 位替代实时除法器。
- `poly_synth_4voice` 使用 `MIX_SHIFT=0`，并保留四声部 16 位饱和保护。
- V10 位流 `mcp3208_13key_hdmi_sram.fs` 的 SHA256 为：

  ```text
  8FD0A382707713FA2684DC299B14D45C9CEB1A871CCB49B64FBC2B8982163A35
  ```

