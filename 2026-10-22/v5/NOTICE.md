# 来源与验证边界

本工程自编 RTL、测试、构建脚本和文档按 MIT 许可提供。

`onchip_adc_scan.sv`、`reset_sync.sv` 和 `uart_tx.sv` 复制自本地
`tangmega60k-peripherals` 工程；其中片内 ADC 版本已经在当前 Tang Mega 60K + NEO Dock
上通过压力灯条实测。`audio_startup.sv` 和 `pt8211_tx.sv` 复制自本地
`tangmega60k-labs` MIT 练习工程，压力音量控制、集成顶层和测试为本工程新增。

设计依据包括 Sipeed NEO Dock 原理图、官方 Tang Mega 60K 引脚约束、PT8211 数据手册、
Sipeed Tang Mega 60K 官方示例，以及 Sipeed Tang Primer 20K 官方 PT8211 示例。厂商资料
与示例仍遵循各自许可；这里只引用其接口事实和链接。

电脑端仿真、综合成功和时序通过不能代替真实耳机发声测试。参赛材料应分别记录编译结果、
下载结果、固定音实测和压力控制实测，不把尚未完成的上板步骤写成已验证。
