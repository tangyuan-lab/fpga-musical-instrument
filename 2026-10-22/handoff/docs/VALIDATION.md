# 验证范围

## v74 历史物理与板上结果

工具 V1.9.12.03，器件 GW5AT-60B，50 MHz 运行约束；全量 PnR 用时 409.625 秒。
资源和时序原报告在 `reports/v74/`。Fmax 52.777 MHz，未布通/setup/hold 均为 0。
PRIMARY、LW 均报告 8/8，PR1014 警告仍存在。

实板 USER 0x00005AA4；用户确认有声、干净、无颤抖。这是主观试听通过，不等于全部 PCM、力度、尾音及四键硬件测试已经完成。
完整 62.5 MHz 余量和 CLS≤65% 目标尚未达到；CLS 65.05%。

`reports/v74/rtl_fir_sign_128.json` 是整理前修正 RTL 的综合后检查。
`prior_rtl_real_keys_result.json` 是此前完整 RTL 上电、消抖、长空闲后按键的仿真结果。
这些 JSON 引用的旧原始日志和测试程序保存在工程外归档；不能把孤立 JSON 当作本轮重新执行的结果。

## 整理后校验

`scripts/check_project.py` 检查主工程依赖、ROM 路径、所有冻结参数哈希和 FIR 读取写法。
`--strict-source` 另外核对本次整理冻结的源码与约束；`--check-firmware` 核对本地三个位流。

新测试与综合输出放到 `build/`，最终整理摘要在 `reports/cleanup_20261019/summary.json`。
回归套件范围、运行命令见根 README。轻量测试不替代器件最终布局布线，也不作完整尾音声明。

下一轮验收：四键同时触发、独立松键、第五键抢占及旧键松开不误关新音；混合音色与同库参数竞争；
完整音色/力度/变调/尾音对照；重新配置和上电的可复现性；严格余量目标。

## 整理时发现的诊断限制

`--suite engine` 的新增 Icarus 短帧整机入口在 190 ns 触发
`Drum parameter owners overlapped a retained-bank capture`。用整理前原源码和整理后源码运行同一测试，
结果一致，因此没有证据将它归因于目录迁移或相对 ROM 路径。
这项测试不标通过，也不据此反向否定用户已确认的 v74 音频；启动初始化/仿真环境与整机状态需要后续单独检查。
现有8项 smoke 回归与之分别报告。此次整理不改音源状态机来掩盖该断言。
