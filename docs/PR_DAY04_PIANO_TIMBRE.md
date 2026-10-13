# PR 描述草稿

## 关联 Issue

Closes #<创建 Issue 后填写编号>

## 本次完成

这是项目从 Day01 开始的第 4 个开发日成果，包含三个连续阶段：音色合成、音色提亮和音量与硬件问题定位。

- 加入来源 阶段一 的三段谐波表钢琴近似音色；
- 加入来源 阶段二 的提亮音色 v2；
- 保留来源 阶段三 撤回琴槌噪声版作为对照；
- 加入来源 阶段四～阶段五 的最终音量调整版；
- 整理对应顶层、ROM、testbench、仿真脚本和试听证据；
- 更新 Day04 阶段 README 和进度记录。

## 设计原因

起音、主体和尾音使用不同周期谐波表，声部按音频帧连续混合三段频谱。来源 阶段二 调整高次谐波和 RMS 归一化，来源 阶段三～阶段五 将音色结构与幅度调整分开验证。

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

来源 阶段一～阶段五 的 Gowin 综合数据来自来源工程记录，分别写在对应 README 中；本地 ModelSim 环境未重新运行 Gowin 综合。

## 已知问题

板上颤音来源、主观音色、空闲噪音和最终音量仍需硬件试听确认。

## 审核清单

- [x] 已完成 ModelSim 验证
- [x] 已检查版本源码、ROM 和 testbench 对应关系
- [x] 已清理 Gowin 缓存、临时日志和位流
- [x] 已更新 README 和阶段进度
- [ ] 已填写真实 Issue 编号
- [ ] 已指定其他成员审核

