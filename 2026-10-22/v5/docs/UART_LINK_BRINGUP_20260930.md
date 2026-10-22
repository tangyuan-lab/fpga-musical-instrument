# NEO Dock UART 实物链路诊断（2026-09-30）

## 当前边界

- `uart_ping_echo` 的 115200/8N1 接收、PING CRC16、ACK 回传已通过完整引脚级 RTL 仿真。
- 当前电脑能枚举 `COM14`（FT2232 通道 A）和 `COM15`（通道 B）。本板通道 A 是 JTAG，应用 UART 优先使用 B；`scan-ping` 默认跳过 A。
- `COM15` 还没有收到 FPGA ACK；但在下载 `uart_tx_diag_sram.fs` 后，电脑已收到 `UART_LINK_OK\r\n`，确认 U15 发出数据并经板载 USB 串口到达电脑。
- 旧版 V02 实物记录中，主动发送和组合回环诊断也曾在 COM15 无响应。应先确认 DEBUG-USB2 连接、JTAG 下载、时钟和板级串口桥，再进入 MIDI。

## 1. 恢复 JTAG 与供电

1. 使用 NEO Dock 的 `USB-JTAG/UART`（`DEBUG-USB2`）USB-C 口，线缆直连电脑 USB 口；不要使用 USB3.0/CH569 口作为应用 UART。
2. 拔下并重新插入 DEBUG-USB2 线，松开板上按键；必要时用板卡正常供电方式重新上电。
3. 在 Gowin Programmer 确认能扫描到 `GW5AT-60B`。仅选择 `SRAM Program`，不要选择 Flash 操作。

本次自动化尝试中，Gowin Programmer CLI 报 `Cable failed to open via the channel`，且 Windows 拒绝软件重启该 USB 设备（`Access is denied`）。用户重新插拔 DEBUG-USB2 后，已自行通过 Programmer 将诊断位流下载到 SRAM。

## 2. 先测 FPGA 到电脑：TX U15

SRAM 下载：

```text
build\ready-to-program\uart_tx_diag_sram.fs
```

该诊断工程每约 0.5 秒从 U15 发送 `UART_LINK_OK\r\n`。它使用片内上电复位，不依赖外部按键复位 Y12。PMOD0 八颗 LED 为低电平点亮：

| LED | 诊断含义 |
|---|---|
| LED7 | 片内上电复位已释放，应常亮 |
| LED0 | 每发送完一条字符串翻转，正常时应闪烁 |
| LED1 | V14 收到一个完整字节后翻转 |
| LED2 | V14 发生 UART 帧错误后翻转 |

电脑端读取原始字节，不要对该诊断位流运行二进制 `ping`：

```powershell
cd .
python -m host_app.cli ports
python -m host_app.cli listen-diag --port COM15 --seconds 3
```

预期出现 `UART_LINK_OK\r\n`。若 COM 编号变化，先在 `ports` 中寻找 FT2232 的 B 通道并替换 COM15。

2026-09-30 实测：`COM15` 在 115200/8N1 下收到 `b'UART_LINK_OK\r\n'`，该方向通过。

## 3. 再测电脑到 FPGA：RX V14

保持诊断位流运行，执行：

```powershell
python -m host_app.cli listen-diag --port COM15 --seconds 3 --probe-rx
```

命令只发送一个 ASCII `X`。观察 LED1 是否翻转；LED2 不应因该字节翻转。若能收到周期字符串，但 LED1 始终不变，故障集中在电脑到 FPGA 的 V14 路径。

2026-09-30：曾从 COM15 发送 `X`，但随后无法确认板上运行的是哪个位流；一次 LED1 未翻转且无诊断字符串的结果因此不能用于判定 RX 故障。重新用 Gowin CLI 对 `GW5AT-60B` 执行诊断位流 SRAM Program，返回 `Finished`；重新发送一个 `X` 后，COM15 再次收到 `UART_LINK_OK\r\n`，用户观察到 PMOD0 LED1 翻转，确认 COM15→V14 接收方向工作。

## 4. 恢复 PING 测试

诊断 TX 和 RX 都通后，SRAM 下载重新构建的：

```text
build\ready-to-program\uart_ping_echo_sram.fs
```

再执行：

```powershell
python -m host_app.cli ping --port COM15
```

PING 顶层的 LED7 现在反映复位释放；LED0 每收到一个合法 PING 翻转；LED1 在 CRC 错误或 UART 帧错误时翻转。收到 ACK 后再进入 MIDI 文件上传。

2026-09-30 实测：CLI 把 `uart_ping_echo_sram.fs` 烧入 SRAM 并返回 `Finished`；`python -m host_app.cli ping --port COM15` 返回 `ACK nonce=0x60577238`。至此板载 USB-C UART 双向链路、PING 帧解析、CRC16 和 ACK 返回均已在实物上通过。

两种位流都只下载到 SRAM。诊断或 PING 运行期间，13 键压力音频功能不会运行；重新上电或下载原 13 键位流后恢复。
