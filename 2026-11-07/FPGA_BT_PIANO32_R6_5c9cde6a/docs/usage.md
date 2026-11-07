# 编译、仿真与 SRAM Program

## 打开和构建

完整解压源码包，在 Gowin FPGA Designer V1.9.12.03 中打开 `workstation_r6_piano32_bt.gprj`。器件为 `GW5AST-LV138PG484AC1/I0` C 版，顶层为 `mega138_models8_top`。工程携带 97 项生产 HDL、IP、ROM 与约束。

命令行构建使用 `gw_sh build.tcl` 完成综合，再使用 `gw_sh pnr.tcl` 完成布局布线与位流生成。

## 校验源码

使用 Python 3.10+：

```powershell
python scripts/check_project.py --json
```

工具核对生产身份、149 项生产输入、工程引用、仿真清单、头文件、ROM 及发布清单。工具可以从其他工作目录通过完整路径启动。

## 功能仿真

使用 ModelSim 的 `vlib`、`vlog`、`vsim`，以及 Gowin GW5A 的 `IDE/simlib/gw5a/prim_sim.v`。通过 `MODELSIM_BIN`、`GOWIN_PRIM_SIM` 环境变量或命令行参数指定安装位置。

```powershell
python scripts/run_tests.py --test tb_closure_count
python scripts/run_tests.py --test tb_batch_screen_semantics
python scripts/run_tests.py --test tb_bt_piano32_feedback --functional-effects-ram
python scripts/run_tests.py --test tb_batch_bt_equivalence --negative-control urgent_emergency
```

`--test` 可以重复指定。`sim/test_profiles.json` 列出本版 12 项测试的依赖与 4 项反例的替换关系。其余测试台也可按名称运行。正常测试必须同时满足进程成功、测试身份匹配、正数 CHECKS、日志 PASS 且无 Error/Fatal；定向反例必须命中指定 Fatal 且无 PASS。

默认使用厂商原语模型。`--functional-effects-ram` 显式选用随包提供的效果 RAM 功能模型，其余原语仍使用厂商模型。`--timeout-seconds` 指定每个外部进程的超时秒数，默认 1800。

每次运行生成独立的 `runs/` 目录，保存 `result.json`、输入哈希、编译日志和仿真日志。退出码 0 表示所选验证符合预期，1 表示验证失败，2 表示参数或工具配置错误。

## 加载 FS

从本版 Release 下载 `R6_5c9cde6a_UserCode000063F0.fs`，按 `SHA256SUMS.txt` 校验。连接板卡与下载器，在 Gowin Programmer 中选择对应器件和 FS，使用 SRAM Program 加载。

RTL BUILD 为 `0x5c9cde6a`，FS UserCode 为 `0x000063F0`。[引脚表](pinout.csv)与工程 CST 对应；50 MHz 控制时钟、48 kHz 音频采样配置。USB／串口屏用于钢琴递进控制，115200 baud、8N1；HC-05 用于参数控制与状态回读，约 9600 baud、8N1。

Release 同时提供原始回退镜像与校验说明。
