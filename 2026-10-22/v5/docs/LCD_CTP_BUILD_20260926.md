# LCD + CTP 构建记录（2026-09-26）

目标工程：`gowin/lcd_ctp_test.gprj`  
顶层模块：`lcd_ctp_test_top`  
器件：`GW5AT-LV60PG484AC1/I0`，Device Version B

## 构建结果

- 综合、布局布线、时序分析和位流生成均完成。
- Setup violated endpoints：`0`。
- Hold violated endpoints：`0`。
- Setup/Hold TNS：均为 `0.000`。
- 生成文件：`build/ready-to-program/lcd_ctp_test_sram.fs`。
- 文件大小：`17,312,519` 字节。
- SHA256（最新一次 21:36 构建）：

  ```text
  CFA5ACC21851F27999E65E2938D5F66CC075C2BDDEFD35B9D2E3148ED71373EC
  ```

`device.cfg` 已确认将 `SSPI`、`I2C` 和 `CPU` 复用功能释放为普通 GPIO，供 J5 LCD 数据及时序信号使用。构建中仍可能看到 `PR1014`，它表示 `sys_clk` 使用普通布线资源；本次静态时序报告没有 Setup/Hold 违例。

## 烧录文件

在 Gowin Programmer 中选择：

```text
.\build\ready-to-program\lcd_ctp_test_sram.fs
```

下载类型使用 `SRAM Program`。烧录前先接好 J5 LCD 排线和 J6 CTP 排线，屏幕使用独立稳定的 5 V 供电。

## 预期现象

1. 上电并烧录后，LCD 显示红、黄、绿、青、蓝、紫六段彩条。
2. GT911/GT9271 初始化成功时，PMOD0 的 LED7 点亮。
3. 手指触摸时，LED6 点亮，画面出现白色十字。
4. CTP 没有响应时，LED5 点亮；先检查 J6 排线方向、3.3 V/GND 和控制器型号。

## 尚未确认的内容

该记录只证明 Gowin 工程可以生成合法位流，尚未代替真实板卡验收。实际 LCD 分辨率/极性、J5 复用信号是否与底板外设争用、GT911 地址和触摸坐标方向，都需要烧录后观察确认。
