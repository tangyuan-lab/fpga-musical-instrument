# Tang Mega 60K 四声部数字音源

比赛项目：使用 FPGA 实时合成钢琴和八种鼓，通过板载 PT8211 输出音频。
主工程为 **`piano_drums_poly4_shared.gprj`**，器件为 **GW5AT-LV60PG484AC1/I0，B 版**。

## 当前状态

| 项目 | 状态 |
|---|---|
| 音色 | 17 个钢琴音、八种鼓；运行时读取模态/解析模型参数和数学表 |
| 四声部引擎 | 四个并行声部，共用四音容量；分配、混音、松键事件归属、第五音抢占已实现 |
| 板载按键 | K2 切换钢琴/鼓，K3 循环试音；尚未接入外部多键扫描器 |
| 实体四键同时演奏 | 仍需输入整合和实板并发验收 |
| 可用试听位流 | v74，USER **0x00005AA4**；用户已确认有声、干净、无颤抖 |
| 当前 RTL | 使用显式完整 FIR 系数读取；与已验证写法一致，需独立完成正式物理验收 |
| 工作时钟/输出 | 50 MHz / 48 kHz，PT8211，16 位双声道相同输出 |
| 后续余量目标 | 62.5 MHz、CLS ≤65%，尚未达到 |

**v74 是由冻结修正网表生成并完成试听的位流。** 当前 RTL 构建使用独立版本码，构建说明见下文。
已保留 v74 的位流、网表、约束、哈希和报告；本包中的板卡状态见 [BOARD_STATE.md](BOARD_STATE.md)。

## 从哪里开始

```text
piano_drums_poly4_shared.gprj  唯一默认比赛工程入口
src/poly4_shared/             当前四声部音源
src/mem/、refit_v2/等          模型参数、数学 ROM、参考核心
integration/poly4_shared/     约束、接口与回归测试
integration/keyboard_16/      16 键音高映射，扫描器尚未接入
scripts/                     校验、构建、测试、打包入口
docs/                        硬件、架构、验收、上传与归档说明
reports/v74/                 已试听版本的物理结果和实板证据
research/guitar/             未接入、未实板验收的吉他研究候选
third_party/notices/         离线参考素材来源及原授权文本
checkpoints/                 本地位流；Git 仅跟踪说明和哈希
releases/                    本地源码/固件交付包，Git 忽略生成物
build/                       新构建和测试输出，Git 忽略
```

`src/` 中小体积的原音源/参考核心用于回归和后续开发，不全部加入主工程。
实际综合文件以 `.gprj` 的 FileList 为准。历史独立工程、失败实验和大体积诊断已移到工程外归档。

## 校验和构建

需要 Python 3.10+。构建需要自行安装 Gowin，已验证工具版本为 V1.9.12.03。
工具链、厂商仿真库和许可证文件不随源码分发。

```powershell
python scripts/check_project.py
# 本地保存了 checkpoints 位流时，增加字节级核验：
python scripts/check_project.py --strict-source --check-firmware

# 指向你自己的 Gowin 安装目录，或使用 GOWIN_HOME 环境变量：
python scripts/build.py --gowin-home "你的Gowin安装目录" --phase syn
python scripts/build.py --gowin-home "你的Gowin安装目录" --phase pnr
# 单独运行更严格的余量目标：
python scripts/build.py --gowin-home "你的Gowin安装目录" --phase pnr --target margin62m5
```

默认约束为 **20 ns / 50 MHz**；原 **16 ns / 62.5 MHz** 约束单独保留。
构建在 `build/` 内冻结一份输入快照，使用新工程、禁用增量复用，写入新版本码 0x00005AB0。
不会覆盖 v74 位流，也不会自动下载或写 Flash。综合结束会检查四声部全部 **128 个 FIR 地址**。

## 回归测试

安装 Icarus Verilog，并将其可执行文件目录加入 PATH 或设置 `IVERILOG_BIN`：

```powershell
python scripts/run_tests.py --suite basic
python scripts/run_tests.py --suite smoke --gowin-home "你的Gowin安装目录"
```

`basic` 检查键号映射、整数规则和备用 I2S 数字输出；`smoke` 另外检查 FIR DSP 与共享 RAM/乘法仲裁。
另保留 `--suite engine` 作为整机诊断入口；当前该 Icarus 测试在整理前后均触发同一启动断言，未列为通过项，详见验收记录。
完整验收还包括尾音、四键实板和新位流测试。
厂商原语模型只在测试时从本机安装目录提取到 `build/`，不纳入仓库。

## 下载和资源

优先使用 `checkpoints/manifest.json` 指定的 **v74**，在 Gowin Programmer 中选择本器件、SRAM 下载。
断电后 SRAM 配置丢失；本次整理没有写 Flash，也没有重新下载板卡。
本地 `releases/v74_board_bundle_20261019.zip` 可作为 GitHub Release 附件。

| v74 最终物理资源 | 已用/总量 | 占用率 |
|---|---:|---:|
| Logic | 32452/59904 | 54.17% |
| Register | 10491/60780 | 17.26% |
| CLS | 19484/29952 | 65.05% |
| BSRAM | 77/118 | 65.25% |
| DSP | 56/118 | 47.46% |

Fmax **52.777 MHz**；50 MHz 约束下未布通、setup、hold 违例均为 **0**。
报告保留 PR1014 通用时钟布线警告。旧位流无声问题的原因尚未定位；v74 的试听结果与新构建验收分别记录。
资源结果和试听记录以本文件及 [BOARD_STATE.md](BOARD_STATE.md) 为准。

## GitHub 与后续开发

源码、ROM、必要测试和报告进入本交付包；工具链、原始录音、旧构建和大体积位流不在本目录中。
下一步为键盘事件接入、四键实板验收和时序余量优化。吉他候选处于研究阶段，Bass 尚未实现。
第三方来源和项目许可信息需要结合完整工程归档确认。
