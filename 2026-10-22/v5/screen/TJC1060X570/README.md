# TJC1060X570 串口屏工程

## 当前工作站工程

请打开 `generated/instrument_workstation_fixed/instrument_workstation.HMI`（2026-10-12中文/计时器修正版）。
它与 FPGA 的 `instrument_workstation` 目标配套，包含中文首页、鼓点模式、弹琴模式、混音模式和实体键设置，中文字库已嵌入。
屏幕按键固定对应所在模式的声音；16 个实体键可逐键设置，并分别保存鼓点、弹琴和混音三套配置。
操作、扩展接口和下载步骤见 [工作站说明](../../docs/WORKSTATION.md)。

本版 HMI 源码检查和 RTL 仿真已通过；官方 TFT 编译及实物验证仍待完成。
编辑画布会显示同一page0中的全部模式控件；实际视图通过事件隐藏/显示，编译后请用“调试”查看首页与模式切换。
旧工程的 TFT 和旧 FPGA 位流不包含这些新增控制命令，下载时请核对完整工程名。

## 历史界面 V2

历史工程为 `generated/instrument_v2/instrument_v2.HMI`，使用说明见该目录的 `README.md`。
新版提供 13 路压力条、HEX/DEC 切换、峰值保持与重置、通道详情和无需 FPGA 的本地 DEMO。
保留原有 `t0`～`t15` UART 输入，触摸操作在屏幕内处理。

直接修改布局与事件源码 `design/create_dashboard_v2.py` 后，在项目根目录执行：

```powershell
python screen/TJC1060X570/design/create_dashboard_v2.py
python screen/TJC1060X570/build_dashboard_hmi.py
```

生成时请关闭正在打开该工程的 USART HMI。之后用官方编辑器编译、导出 TFT；重新生成 HMI 后需重新编译，避免下载旧 TFT。
旧版 `generated/instrument_full/` 保留供回退。

## 历史 13 键页面源码

页面位置、RGB565 颜色、初值和文本容量定义在 `design/controls_manifest.json`。
`build_native_hmi.py` 从官方保存的 `uart_minimal_manual.HMI` 复制背景和字库，批量生成 `t0`～`t15`，不需要逐项创建控件。

在项目根目录执行：

```powershell
python screen/TJC1060X570/build_native_hmi.py
```

编辑器必须先保存并关闭模板，否则 Windows 会拒绝读取。
输出为 `generated/instrument_full/instrument_full.HMI`，校验报告为同目录的 `build_manifest.json`。
官方 CFS 目录记录当前页面；文件开头的备份目录可能仍指向旧页面。本脚本使用当前页面并同步两个目录，刷新 PageSafe 和 CFS 校验。

## 通用编译与下载

使用 USART HMI 1.68.1 打开生成的 HMI，保存、编译。确认没有错误，再使用 USB 转 TTL 下载到屏幕。
单独导出 TFT：文件 → 输出生产文件。

下载时断开 FPGA C18/C19。USB-TTL TXD→屏幕 RX，RXD→屏幕 TX，GND→屏幕 GND；屏幕独立 5 V 供电。
完成后断开转接器信号线，恢复 FPGA C18→屏幕 RX，并共地。暂不接 C19，直到确认屏幕 TX 电平适配 FPGA 输入。

## 历史 13 键显示检查

- t0：LIVE / MIDI，AB13 切换。
- t1：活动键数，十六进制 0～D。
- t2：WAIT / READY / PLAY。
- t3～t15：C4～C5 的 13 个压力值，三个十六进制字符 000～FFF。

FPGA 当前位流已发送这些控件的文本更新，沿用该位流即可。
生成 HMI 和通过文件校验，不代表已编译 TFT 或通过实物验证；最终状态查看构建报告。

## 旧工具

旧 `build_hmi.py` 的无界面编译桥与本机运行库不兼容，旧离线页面生成缺少 PageSafe 刷新；请使用新的 `build_native_hmi.py`。
