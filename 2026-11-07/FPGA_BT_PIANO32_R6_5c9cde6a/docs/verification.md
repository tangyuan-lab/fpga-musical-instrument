# R6 0x5c9cde6a 验证与实现记录

本页索引本版功能仿真、定向反例、原生综合、布局布线、静态时序与上板功能结果。完整报告和原始过程记录随 [Release 验证资料 ZIP](https://github.com/tangyuan-lab/fpga-musical-instrument/releases/download/r6-5c9cde6a/R6_5c9cde6a_verification.zip) 收录。

## 构建与产物

| 项目 | 标识 |
| --- | --- |
| RTL BUILD | `0x5c9cde6a` |
| 生产输入摘要 | `5c9cde6a2fa66c22ba28e5fa556aa05c5acddbf4016990d6330a89a4e922feb0` |
| 生产输入 | 149 项，原构建与发布文件通过哈希清单及注释修订映射关联 |
| 生产 HDL | 97 项 |
| FS UserCode | `0x000063F0` |
| FS SHA-256 | `68b3fbac7a1f86badd6b6ba2d7a90b0d5715356de8a1afb893717fcb9eae1757` |

## 上板功能测试

本版已完成上板功能测试，运行正常。[测试记录](board_test.md)关联日期、构建与 FS 标识。

## 原始功能仿真

原始记录日期为 2026-11-07。12 项通过记录逐项核对测试名、PASS、正数 CHECKS 与日志哈希；测试输入中的生产 HDL 与本版一致。测试配置、工具参数与原始输入在验证附件 `evidence/current12_functional_evidence.zip` 中保存。

| 测试台 | 有效检查数 |
| --- | ---: |
| `tb_closure_count` | 198,756 |
| `tb_closure_touch` | 131,155 |
| `tb_batch_screen_semantics` | 16,393 |
| `tb_batch_bt_equivalence` | 3,200 |
| `tb_batch_deadlines` | 9 |
| `tb_batch_render_equivalence` | 28 |
| `tb_r7_bluetooth_uart` | 134 |
| `tb_r7_bluetooth_ownership` | 59 |
| `tb_bt_piano32_feedback` | 19 |
| `tb_bt_piano32_top` | 4,641 |
| `tb_bt_piano32_screen` | 4,709 |
| `tb_r7_features_uart` | 41 |

顶层测试记录 196 个音频帧、186 个非零混音帧。测试参数与本次发布工具执行结果分别保存，便于按各自配置复现。

## 原始定向反例

4 项故障注入均命中指定断言，且未出现 PASS。原始故障源码、日志与哈希随功能验证附件保留；本版仿真入口提供对应选项。

| 反例 | 测试台 | 指定断言 |
| --- | --- | --- |
| `urgent_emergency` | `tb_batch_bt_equivalence` | `BT_SEQUENCE_PUBLIC_MISMATCH` |
| `screen_semantic` | `tb_batch_screen_semantics` | `BATCH_SCREEN_CANCEL_MISMATCH` |
| `generation_identity` | `tb_batch_render_equivalence` | `distributed raw identity differs from indexed reference` |
| `pcm` | `tb_batch_render_equivalence` | `render PCM/finished/generation mismatch` |

## 原生综合与布局布线

Gowin V1.9.12.03，目标 `GW5AST-LV138PG484AC1/I0` C 版，顶层 `mega138_models8_top`。综合与布局布线进程均自然退出 0，布局布线日志记录四阶段 routing 和 bitstream generation 完成。

附件 `evidence/native_source_run/` 保存 `syn.log`、`pnr.log`、实际选项、源运行对应索引、综合报告与完整时序报告。`evidence/native_cli_open_save/` 保存两次原生工程打开与导出结果；原始审核材料完整保留在 `evidence/control/`。

| 检查 | 报告路径条目数 | 负 slack 条目数 | 最差 slack |
| --- | ---: | ---: | ---: |
| Setup | 36,102 | 0 | +0.029 ns |
| Hold | 12,002 | 0 | +0.133 ns |
| Recovery | 9,937 | 0 | +4.036 ns |
| Removal | 9,937 | 0 | +0.256 ns |

系统时钟约束 50 MHz，系统时钟域报告 Fmax 50.072 MHz。完整时序报告为原始 `workstation_nodrum_ddr.tr`，通过附件哈希索引核对。

## 本次发布整理

149 项生产输入中 147 项与原包逐字节一致，2 项各修订一行模块职责注释。原始构建身份对应 FS，交付文件以发布清单及注释修订映射核对。工程入口与配置同步改名，仿真清单使用相对路径，补齐当前测试台、参考模型和定向反例。

本次运行结果随验证附件 `publication_runs/` 保存，输入哈希、模型选择、有效检查数和各阶段退出码在每次运行的 `result.json` 中记录。[源码清单](../SOURCE_MANIFEST.json)与[来源清单](../PACKAGING_ORIGIN.json)提供文件对应关系。
