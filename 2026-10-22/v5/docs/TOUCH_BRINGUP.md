# NEO Dock USB 触摸屏接入步骤

## 已确认的板级连接

- NEO Dock Rev 1.4 的 J18 是 USB Host 接口，5 V 输出限流约 0.45 A。
- 默认只有 USB-A2 的数据线接到 FPGA；USB-A1 焊盘默认未连接。
- USB-A2 的 D+、D- 分别使用 FPGA `H13`、`G13`。
- USB 选择开关 `SW4` 必须拨到 `FPGA` 一侧；留在 `DBG` 会把 USB-A 接到板载调试器。

## 供电方式

屏幕继续使用已经验证稳定的独立 5 V 电源。若屏幕有独立的 `POWER` 和 `TOUCH` USB 口，
只把 `TOUCH` 线接到 NEO Dock USB-A2。

若屏幕像当前实物一样，由 HDMI 加一根 Micro-USB（老安卓线）连接，而且这根 USB 同时负责
屏幕供电和触摸数据，则使用带独立供电的 USB Hub：

```text
NEO Dock USB-A2 ── Hub 上行线 ── 有源 USB Hub
                                      ├── Hub 独立 5 V 电源
                                      └── 屏幕 Micro-USB 数据/供电线
NEO Dock HDMI ─────────────────────────── 屏幕 HDMI
```

USB 线必须是四芯数据线；只支持充电的两芯线无法传输触摸报告。不建议使用简单的电源 Y 线，
因为可能把外部 5 V 回灌到底板 USB 电源。

## 第一次枚举测试

1. 先拔下屏幕触摸 USB 线，把 `SW4` 拨到 `FPGA`。
2. 使用 Gowin Programmer 的 `SRAM Program` 烧录组合调试位流
   `build/ready-to-program/pressure_audio_hdmi_touch_probe_sram.fs`。
3. 该组合位流保留 HDMI、压力检测和音频；串口在此版本中专门输出 USB 枚举信息。
4. 在 PowerShell 执行：

   ```powershell
   cd .
   python scripts\read_touch_probe.py --seconds 90
   ```

5. 看到串口已打开后，把触摸 USB 插入 USB-A2。若没有 `USB device detected`，把线换到
   同一个双层 USB-A 座的另一个插口再试一次。
6. 保存从 `USB device detected` 到 `DEVICE READY` 的全部输出，其中应包含 VID、PID、
   Manufacturer、Product、Interface 和 Interrupt IN Endpoint。
7. 测试完成后可以继续使用组合位流；若要恢复压力遥测串口，再烧录
   `pressure_audio_hdmi_sram.fs`。

这个探针目前只负责识别设备。拿到屏幕的 HID 报告格式以后，下一版会持续轮询触摸中断端点，
把按下状态和绝对 X/Y 坐标送到 HDMI 界面，并用于点击音色按钮。
