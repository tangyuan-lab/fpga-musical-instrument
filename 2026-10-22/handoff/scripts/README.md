# 日常入口

- `check_project.py`：依赖、参数、FIR写法与可选源码/位流哈希检查。
- `build.py`：新建快照运行综合/布局布线；默认50 MHz，可选62.5 MHz；不下载板卡。
- `run_tests.py`：现有数字回归，厂商模型只在本机提取到 build。
- `check_shared_fir_sign.py`：对指定综合网表核对4×32个FIR系数地址。
- `package_release.py`：导出干净源码包或已试听v74附件，不执行上传。

旧拟合、失败实验、诊断下载与清理脚本均在工程外原目录归档中，不作为新工程入口。
`run_tests.py --suite engine` 是尚未通过的可选诊断，当前在整理前后均触发启动断言；默认推荐 basic/smoke，不将此项包装成已验证回归。

工具路径优先级：命令行、环境变量、本机忽略文件 `.local/tools.json`。
该本机文件可设置 `gowin_home` 与 `iverilog_bin`；不会进入 Git 或源码 ZIP。
