# 陶晶驰 TJC 串口屏接线与显示协议

`instrument_full` 使用 C18/C19 两个独立 FPGA IO 作为串口屏接口，同时保留 USB-C 板载 UART 给电脑上传 MIDI 和控制命令。

## 已确认的设备型号

用户提供的型号为 **TJC1060X570_011**。USART HMI 选型时按基础型号 `TJC1060X570` 查找，
选择 **X5 系列、7.0 寸、1024×600**，本项目使用横屏布局。
参见 [官方型号选择说明](http://wiki.tjc1688.com/QA/QA72.html) 和
[官方型号页](http://wiki.tjc1688.com/product/new_datasheet/X5/TJC1060X570_011C_I.html)。

当前官方资料列有电容、电阻和无触摸变体；用户未提供触摸后缀，不能据此确定触摸类型。
本地保存的 [官方 C_I 变体规格书](../screen/TJC1060X570/vendor/TJC1060X570_011C_I.pdf)
作为硬件参数参考：PDF 第 8 页为串口参数、第 9 页为接口、第 13 页为供电参数。
该参考规格推荐 5 V / 1 A 稳压电源，串口为 8N1，支持 TTL/232 切换。
连接 FPGA GPIO 时须使用 **TTL 模式**。规格中的“3.3V/5V CMOS/TTL”未单独给出 TX 高电平
或 RX 输入阈值，不能仅根据 5 V 供电推定 UART 信号电压。

已下载未修改的 [官方原厂 HMI 工程](../screen/TJC1060X570/vendor/TJC1060X570_factory.HMI)，
来源为 [厂商下载地址](http://filedown.tjc1688.com/tjcwiki/factory_project/X5/TJC1060X570.HMI)。
SHA256：`9341CADCC3EE657BAE0D318E38782F2AB7EB46B46A401B63E1F725372735D880`。
它是原厂界面模板，尚未改成乐器页面，也未编译或下载到屏幕。
配套的最小上电脚本见 [program.s](../screen/TJC1060X570/program.s)，需要导入或粘贴到实际 HMI 工程。

## 接线

| FPGA 引脚 | 串口屏连接 | 说明 |
|---|---|---|
| C18 | 屏幕 RX | FPGA `screen_tx_o`，3.3 V 输出 |
| C19 | 屏幕 TX | FPGA `screen_rx_i`，若回传为 5 V 则先降到 3.3 V |
| 板卡 GND | 屏幕 GND | 必须共地 |

屏幕电源使用独立稳定的 5 V 供电，不能把 5 V 接到 FPGA 的 3.3 V IO。屏幕 TX 若输出 5 V，必须使用电阻分压或 5 V-to-3.3 V 电平转换器后再接 C19。FPGA TX 是 3.3 V；屏幕 RX 是否能可靠识别 3.3 V 高电平，应按该屏幕型号的 VIH 规格确认。

USB-C UART 仍使用原来的 U15（FPGA TX）和 V14（FPGA RX）；C18/C19 不再占用 PMOD0 的 LED 引脚。

## 默认 UART 参数

- 115200 baud、8 data bits、no parity、1 stop bit（8N1）
- FPGA 系统时钟 50 MHz，对应 `CLKS_PER_BIT=434`
- 若屏幕工程固定为 9600 baud，把顶层参数 `SCREEN_CLKS_PER_BIT` 改为 5208 后重新编译
- 上电后约 1 秒发送第一帧，之后每整帧发完等待 100 ms（含发送时间约 120 ms 一帧）

## TJC/Nextion 文本控件

默认使用 16 个文本控件：`t0`～`t15`。每次发送的命令格式为：

```text
t0.txt="LIVE"<FF><FF><FF>
```

字段定义：

- `t0`：`LIVE` 或 `MIDI`
- `t1`：活动键数，单个十六进制字符
- `t2`：`WAIT`、`READY` 或 `PLAY`
- `t3`～`t15`：13 个压力值，三个十六进制字符，范围 `000`～`FFF`

因此，TJC 工程中至少需要建立 `t0`～`t15` 且类型为 Text 的控件。若屏幕工程使用 `page0.mode`、`n0.val` 等其他控件名，需要修改 `rtl/io/serial_screen_nextion_tx.sv` 的命令生成部分。

## USART HMI 上位机配置

淘晶驰官方的界面编辑软件为 **USART HMI**，提供控件编辑、脚本、模拟调试和屏幕工程下载。
参见 [官方使用入门](https://www.tjc1688.com/contents/25/463.html) 和
[官方资料中心](https://wiki.tjc1688.com/)（资料下载 → 上位机下载）。

本机桌面已有 `<USER_HOME>\Desktop\USARTHMIsetup_latest.zip`，压缩包内为
`USARTHMIsetup_1.68.1.exe`；这里只确认安装包内容，不代表已安装软件。

与当前 FPGA 位流配套的最小屏幕工程：

1. 新建工程或打开原厂模板，设备选 `TJC1060X570` 对应的 X5 / 1024×600，方向为横屏。
2. 创建 ASCII 字库并给文本控件设置正确的 `font`，在启动页建立 `t0`～`t15`。
   `t0` 和 `t2` 文本容量至少 5 字符，`t1` 至少 1 字符，`t3`～`t15` 至少 3 字符。
3. 在 `program.s` 的上电初始化中保留已有全局变量声明，将以下设置放在 `page 0` 之前。
   若已有同名设置，修改原设置即可。依据
   [官方波特率与解析模式说明](https://wiki.tjc1688.com/QA/baudrate.html)：

   ```text
   bauds=115200
   recmod=0
   bkcmd=3
   page 0
   ```

   `recmod=0` 使用标准字符串指令；`bkcmd=3` 用于调试时返回成功和失败的执行结果，
   参见 [官方 bkcmd 设置说明](https://www.tjc1688.com/contents/25/84.html)。
   `page 0` 后面的初始化代码不再执行。当前 FPGA 只记录回传字节活动，尚未解析执行结果。
4. 在模拟器中测试 `t0.txt="LIVE"`、`t2.txt="READY"` 和 `t3.txt="FFF"`，确认控件名及字库正常。
5. 将编译后的屏幕工程下载到屏幕，再连接 C18/C19。使用 USART HMI 串口下载时，需让 USB-TTL
   适配器直接连接屏幕；该适配器的 TX 连接屏幕 RX 时，应断开 FPGA C18，避免两个 TX 同时驱动。
   电脑 COM15 连接的是 FPGA USB-C UART，当前位流没有将其透传到屏幕。

FPGA 的 `.fs` 位流和屏幕的界面工程分别下载到 FPGA 与串口屏。只下载 FPGA 位流不会在屏幕中
创建 `t0`～`t15`，需要先准备配套屏幕页面。

## 常用指令与回传

通过物理 UART 发送时，字符串命令后追加 **三个原始字节 `FF FF FF`**，不能发送可见字符
“FF FF FF”或仅发送换行。参见 [官方 Python 发送示例](https://wiki.tjc1688.com/debug/python/python1.html)。

| 命令文本 | 作用 | 当前 FPGA 是否发送 |
|---|---|---|
| `t0.txt="LIVE"` | 修改文本控件 | 是 |
| `n0.val=123` | 修改数字控件 | 否 |
| `page 0` | 切换到第 0 页 | 否，屏幕初始化使用 |
| `vis t0,0` / `vis t0,1` | 隐藏 / 显示控件 | 否 |
| `get t0.txt` | 查询文本变量 | 否 |
| `sendme` | 请求当前页面 ID | 否 |

完整命令参见 [官方指令集](https://wiki.tjc1688.com/commands/index.html)。调试时关注
[官方回传格式](https://wiki.tjc1688.com/return/index.html)：`01 FF FF FF` 表示执行成功，
`1A FF FF FF` 表示变量名称无效（例如当前页没有 `t0`）；`00 FF FF FF` 表示无效指令。
触摸事件、字符串查询和数值查询分别使用 `65`、`70` 和 `71` 类型码。
当前 FPGA 不处理这些回传帧的含义，也没有接入触摸播放控制。

## 实物验收：什么现象算通过

先将含 `t0`～`t15`、正确字库和 115200 配置的配套界面下载到屏幕。未修改的原厂模板
不能作为本项目显示验收页面；仅屏幕点亮不能证明 UART 显示命令已经生效。

| 操作 | 配套页面应出现的现象 | 可以证明 |
|---|---|---|
| FPGA 复位并等待约 1 秒 | `t0` 显示 `LIVE` | 屏幕能够接收并执行文本命令 |
| 按 AB13 模式键，再按一次 | `t0` 随操作在 `LIVE`、`MIDI` 间切换 | FPGA 状态变化实际传到屏幕，排除仅显示固定初始文本 |
| 回到 LIVE，按住并松开一个压力键 | 对应 `t3`～`t15` 压力值上升/回落，`t1` 活动键数随阈值变化 | 压力采集、键判定与显示更新路径工作 |
| LIVE 系统就绪后按住并松开压力键 | `t2` 从 `READY` 到 `PLAY`，松开后回到 `READY`；耳机随按键发声并在松开后停止 | 状态显示和音频路径均有实物响应 |

优先验收 AB13 的 `LIVE`/`MIDI` 切换，这一步不依赖 MCP3208、压力传感器或耳机。
若 `t0` 能切换但 `t2` 为 `WAIT`，屏幕发送路径仍已验证，应继续检查采集/校准或 MIDI
文件准备状态。压力值是 `000`～`FFF` 的十六进制文本，并非十进制。

COM15 的 PING ACK 只验证电脑与 FPGA 的 USB-C UART，不单独证明 C18/C19 屏幕链路。
PMOD0 LED2 只记录有效回传字节活动；成功和错误帧都可能使其翻转，而且一帧的字节数
为偶数时灯可能回到原状态，因此不把 LED 闪烁作为屏幕通过标准。

## 工程与位流

工程文件：`gowin/instrument_full.gprj`。构建命令：

```powershell
cd .
powershell -ExecutionPolicy Bypass -File scripts\build.ps1 -Target instrument_full
```

成功后烧录：

```text
build\ready-to-program\instrument_full_sram.fs
```

首次验证使用 SRAM Program；烧录后等待约 1 秒再观察屏幕。屏幕工程的 UART 波特率需设为 115200，当前页需有 `t0`～`t15` 文本控件。当前代码发送显示数据；触摸回传尚未解析，每收到一个有效 UART 字节，`rx_activity` 翻转并通过 PMOD0 LED2 显示。
