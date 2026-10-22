# 2026-10-22 实测记录

本次在发布目录执行；两个原始目录未修改。原项目内日期和历史报告继续保留。

| 项目 | 实测结果 | 范围 |
| --- | --- | --- |
| 发布来源 | handoff 248 + V5 522 = 770 个来源文件 | 另附发布说明、库存清单与本次证据 |
| 工程引用 | 19 个 `.gprj` 全部引用存在 | 只验证路径，不代表综合通过 |
| V5 原始清单 | 收录时 521/521 哈希匹配 | 归档属性调整后同步更新清单；原清单保留在发布根目录 |
| handoff 严格源码检查 | 通过：26 工程输入、29 参数文件、0 生产源码变化 | `python scripts/check_project.py --strict-source`；不含固件核对 |
| handoff 主工程编译 | ModelSim 10.6d：24 个 RTL，0 errors / 0 warnings | `vlog -sv`；未做完整整机 elaboration/综合 |
| handoff 基础仿真 | 键盘映射、整数规则、I2S 三项通过 | ModelSim 执行已有 testbench，见下文修订 |
| V5 主机测试 | 114 项：113 通过、1 跳过，无失败或错误 | `python -m unittest discover -s tests -q`；实音源可选用例跳过 |
| V5 界面布局 | 6/6 通过 | 1366×768、1920×1080；缩放 1/1.25/1.5；离屏验证 |
| V5 RTL 脚本 | 受工具依赖阻断 | `test_workstation_v2.py`、`test_midi_tracks.py`、`test_track_audio.py` 缺 Icarus (`iverilog`/`vvp`)；未取得仿真通过证据 |
| Gowin 综合/PNR、时序、整机上板 | 本次未执行 | 仍待配齐工具及硬件验收 |

## 缺依赖测试的处理

系统 Python 初测缺 PySide6、Partitura，89 个已发现用例报告 1 failure、22 errors、1 skipped。隔离环境补装两者后，114 项中仍有 Verovio 缺失引发的 1 error、1 failure。再补装 Verovio 后，**完整重跑 114 项得到 OK (skipped=1)**。这些中间失败未被当成产品功能缺陷，也未被隐藏成通过。

依赖安装在系统临时目录的独立 venv（继承已有系统包）内。新增 PySide6 6.11.1、Partitura 1.9.0、Verovio 6.3.0；完整实测环境见 `verification_logs/python_environment.txt`。本次不是在全部锁定版本的全新环境中验收，用户复现请按 `v5/requirements.txt` 安装。

Icarus 未安装导致三项 RTL 脚本无法开始仿真；这与“发布包缺源码”不同。工程文件路径和来源哈希已分别检查，但不能据此宣称三项仿真已通过。

## I2S 测试修订

原 `handoff/sim/tb_i2s_tx_16.sv` 直接 `@(posedge frame_tick)` 计数。`frame_tick` 是组合时钟使能，ModelSim 的 delta-cycle 瞬态会重复触发事件：计数 400 次时只完成 199 帧，复现 `lost I2S frames`。

本批把两处等待改为在 `posedge clk` 采样 `frame_tick`，与生产 RTL 对时钟使能的用法一致。原来的 WS、位延迟、双声道采样和补零断言均保留，重跑通过；生产 `i2s_tx_16.v` 未改。原始目录仍保留原测试，发布库存记录了原/新哈希。

复现三个基础用例：

```powershell
.\run_basic_modelsim.ps1 -ModelSimBin 'D:/modeltech64_10.6d/win64'
```

脚本检查 PASS、Fatal/Error 和进程状态，避免 ModelSim 遇到 `$fatal` 仍返回 0 而被误判。

## Git 字节一致性

V5 原文件多采用 CRLF；原 `.gitattributes` 会转换多数文本行尾，导致原始 SHA 清单在 Git 发布后失效。本批在两个项目的属性末尾添加 `* -text`，只控制此快照的 Git 行尾转换，并同步更新 `SOURCE_MANIFEST.json` 中属性文件的哈希及总字节数。保留 `v5_SOURCE_MANIFEST.original.json` 供来源对照。

`INVENTORY.json` 记录 770 个来源路径、发布哈希及四处修订的原哈希。本次日志集中于 `verification_logs/`；历史 `RELEASE_CHECKS.json` 不作为今日通过依据。

Git 索引已核对 770 个来源文件的字节哈希；另用 Git 实际检出复核，避免 Windows `core.autocrlf` 改变未显式指定行尾的工程与许可文件。
