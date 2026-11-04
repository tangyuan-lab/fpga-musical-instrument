# V2 FPGA 位流发布：2026-10-17

## 发布文件

`build/ready-to-program/instrument_workstation_v2_sram.fs`

SHA256：`C286B9BC0D9A366C9E320227ADD06964BC6B198E124A629CB5969B8CC3BE1FD7`

相邻的`.sha256`、`.sources.json`和`.build.json`保存摘要、冻结输入及实际验收结果。

## 构建验收

- GW5AT-60B，GW5AT-LV60PG484AC1/I0，Gowin V1.9.12.03。
- 完整布通，系统时钟50MHz；Setup违例0、Hold违例0。
- 实际STA系统Fmax50.147MHz，最差Setup裕量+0.059ns。
- 15个ADC/UART/I2S实际引脚、输入输出方向和LVCMOS33核对通过。
- 输入源码、网表、约束及工具摘要在构建前后保持一致。
- 实际PnR：LUT28426、寄存器20220、BSRAM95/118、CLS24649/29952。
- 本轮完整PnR耗时6分5秒，含布线3分17秒。

最终候选及报告：`build/gowin/instrument_workstation_v2_maps_local/`。

## 本轮时序修复

实时键扫描拆为映射快照、移调和差异检测三级；实体键配置服务增加一拍请求锁存，按常量bank/key本地写入。整组恢复默认仍在同拍完成，`map_changed`与实际提交同拍，ACK等待覆盖新增20ns。V2服务独立维护，生成器不再覆盖其实现。

保持32个独立旋律声部、16实体压力键及原接线。配置提交、原子恢复、上下文、按钮优先级、复位及命令确认测试通过。完整顶层数字延迟六用例通过：实体最大3.573690ms、UART最大0.496790ms。32声部、4实体键、两效果器、ADC/SPI、USB及屏幕UART并发测试通过。

这些是RTL与编译证据；不包含FSR模拟响应、屏幕触摸扫描、DAC/功放和整机模拟延迟验收。

## 接线与实物状态

| 功能 | 引脚 |
| --- | --- |
| ADC0 SCLK/MISO/MOSI/CS | AA19 / AA20 / AB21 / Y21 |
| ADC1 SCLK/MISO/MOSI/CS | AB20 / AA21 / AB22 / Y22 |
| 屏幕TX/RX | C18 / C19 |
| USB UART TX/RX | U15 / V14 |
| 标准I2S BCLK/WS/DATA | T21 / U21 / P16 |

本轮未烧录板卡或Flash。已验证可发声的旧工作位流保留，SHA256仍为`35B8F988F4809A539552D622944BF57C9B823EF31A3CE6347C669AE1EB997FA2`。

V2使用标准Philips I2S，48.828125kHz、32位声道时隙、16位有效音频，需要外部标准I2S DAC；不以板载PT8211右对齐接口作V2音频验收。官方屏幕TFT及整机实测仍待完成。
