# PR 描述草稿

## 关联 Issue

Closes #7

## 本次完成

这是项目从 Day01 开始的第 4 个开发日成果，记录钢琴近似音色从初版到最终音量调整的迭代过程。

- 加入由起音、主体和尾音三张谐波表合成的钢琴近似音色；
- 根据试听反馈提亮高次谐波，并对波表进行 RMS 归一化；
- 记录琴槌噪声方案的试听结果和撤回决定；
- 调整最终输出音量，并定位板上颤音、空闲噪音等待查问题；
- 整理对应顶层、ROM、testbench、仿真脚本和试听证据；
- 更新 Day04 README 和进度记录。

## 设计原因

起音、主体和尾音使用不同周期谐波表，声部按音频帧连续混合三段频谱。后续迭代调整高次谐波和 RMS 归一化，并将音色结构与输出幅度分开验证。

## 接口、位宽或时钟变化

无 Day03 输入和 PT8211 接口变化。新增钢琴声部使用既有音频帧节拍、力度和相位接口。

## 验证方法

在以下目录分别执行：

```powershell
vsim -c -do run_timbre_v1.do
vsim -c -do run_timbre_bright.do
vsim -c -do run_volume_final.do
vsim -c -do run_hammer_withdrawn.do
```

## 验证结果

四个入口均输出 `PASS: piano attack/decay, velocity, four audition notes, unclipped PT8211 stereo`。

## 资源与时序变化

Gowin 综合数据来自本日各版本的工程记录，分别写在对应 README 中；本地 ModelSim 环境未重新运行 Gowin 综合。

## 已知问题

板上颤音来源、主观音色、空闲噪音和最终音量仍需硬件试听确认。

## 审核清单

- [x] 已完成 ModelSim 验证
- [x] 已检查版本源码、ROM 和 testbench 对应关系
- [x] 已清理 Gowin 缓存、临时日志和位流
- [x] 已更新 README 和阶段进度
- [x] 已关联 Issue #7
- [ ] 已指定其他成员审核

