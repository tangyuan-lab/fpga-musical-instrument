# GitHub 协作规范

本规范适用于 FPGA 实时多音色合成电子乐器引擎项目。目标是保证三名成员可以并行开发、稳定集成。

## 1. 基本原则

1. 每个人使用自己的 GitHub 账号、姓名和邮箱提交，不共用账号。
2. `main` 始终保持可编译、可验证；开发成员不得直接向 `main` Push。
3. 每个任务先创建 Issue，一个功能分支只解决一个 Issue。
4. 每个 Commit 只表达一个完整、可验证的变化。
5. 每个 PR 至少由另一名成员审核，只有负责人负责合并。
6. 有真实进展时当天提交；没有成果时不使用空 Commit 制造活跃度。
7. 波形、频谱、资源报告和上板结果是开发产物的一部分，必须和代码一起记录。

开发期仓库使用个人免费账户并保持私有，GitHub 无法强制启用私有仓库分支保护，因此“禁止直接 Push main”暂由团队纪律和负责人审核执行。评审前仓库公开后，必须为 `main` 启用分支规则。

## 2. 团队角色

| 角色 | 责任 |
| --- | --- |
| 成员 A / 负责人 | 系统架构、时钟与复位、I2S、顶层集成；确认 PR 证据并执行 Merge Commit |
| 成员 B | DDS、波表、ADSR、独立复音和混音；维护对应 Testbench |
| 成员 C | 按键与交互、验证、指标、README 和演示材料 |
| PR 作者 | 完成功能、自测、说明设计原因、上传证据、响应 Review |
| 审核者 | 检查功能、接口、位宽、时钟域、复位、测试证据和文档一致性 |

不能由 PR 作者独自批准自己的变更。负责人自己的 PR 也必须由另外一名成员审核。

## 3. 标准流程

所有任务统一执行：

```text
Issue → 功能分支 → Commit → Push → Pull Request → Review → Merge Commit → Release
```

### 3.1 开始任务前创建 Issue

根据工作类型选择 Feature、Bug 或 Test 模板，填写：

- 目标和工作范围；
- 明确不包含的内容；
- 可以检查的验收条件；
- 负责人、截止时间和所属 Milestone；
- 要保存的仿真、综合、时序、频谱或上板证据。

Issue 标题使用“动作 + 结果”，例如：

```text
实现可参数化 DDS 振荡器
验证四个独立频率同时输出
修复混音累加溢出
```

### 3.2 更新主分支并创建功能分支

```powershell
git switch main
git pull --ff-only origin main
git switch -c feat/synth-dds
```

分支命名：

| 前缀 | 用途 | 示例 |
| --- | --- | --- |
| `feat/` | 新功能 | `feat/synth-dds` |
| `fix/` | 问题修复 | `fix/mixer-saturation` |
| `test/` | 测试与验证 | `test/four-voice-spectrum` |
| `docs/` | 文档和展示 | `docs/resource-report` |

使用小写英文和连字符。不要使用 `new`、`temp`、`final`、姓名缩写等无法说明任务的名称。

### 3.3 修改后检查并提交

```powershell
git status
git diff
git add rtl/audio/dds_oscillator.v
git add tb/dds_oscillator_tb.v
git diff --cached
git commit -m "feat(synth): add parameterized DDS oscillator"
```

优先指定文件执行 `git add`，新人不要习惯性使用 `git add .`。提交前确认：

- 没有混入其他任务的修改；
- 没有个人绝对路径、账号令牌或许可证；
- 没有 Gowin 缓存、临时日志和大型实现目录；
- RTL、Testbench 和文档描述一致；
- 必要验证已经完成。

Commit 标题格式：

```text
类型(模块): 简洁说明完成的结果
```

合格示例：

```text
feat(audio): add 48 kHz I2S transmitter
feat(envelope): implement ADSR state machine
test(polyphony): verify four independent frequencies
fix(mixer): add signed saturation protection
docs(metrics): record 8-voice resource usage
```

禁止使用：

```text
update
改了一下
final
123
```

### 3.4 推送并创建 PR

```powershell
git push -u origin feat/synth-dds
```

在 GitHub 点击 `Compare & pull request`，确认：

- Base 分支为 `main`；
- Compare 分支为自己的功能分支；
- 标题说明模块和结果；
- 正文完整填写 PR 模板；
- 使用 `Closes #编号` 关联 Issue；
- 指定至少一名其他成员审核；
- 附上波形、频谱、报告或上板证据。

Review 后继续修改时，不新建第二个 PR；在原分支继续 Commit 并执行：

```powershell
git push
```

## 4. PR 验收条件

### 功能

- 满足关联 Issue 的验收条件。
- 没有未说明的范围扩展。
- 失败路径和已知限制已记录。

### RTL 与接口

- 端口方向、名称、单位和有效条件明确。
- 有符号数据使用显式 `signed`，符号扩展正确。
- 乘法、累加和混音中间位宽足够，溢出策略明确。
- 跨时钟域信号经过同步或握手处理。
- 同步或异步复位策略与系统约定一致。
- 参数边界不会产生零位宽、非法切片或计数溢出。

### 音频与复音

- 采样率、位深、声道和 I2S 对齐方式明确。
- 每个有效复音具备独立相位、频率和包络控制。
- 不把同一声音的谐波当作多个复音。
- 混音有明确的位宽增长、缩放和饱和处理。

### 验证

- Testbench 能复现测试条件。
- 仿真波形标注关键信号、单位和预期值。
- 上板结果注明板卡、器件、Gowin 版本和 Commit。
- 资源与时序变化使用同一参数、约束和 Commit 比较。
- README、架构文档和指标表已同步更新。

## 5. 主分支更新与冲突处理

PR 合并前，如果 `main` 已更新，在自己的功能分支执行：

```powershell
git fetch origin
git rebase origin/main
```

出现冲突时：

1. 打开冲突文件，找到 `<<<<<<<`、`=======`、`>>>>>>>`。
2. 理解两边修改目的，人工决定最终内容，不能盲目选择一侧。
3. 删除冲突标记并重新验证。
4. 标记已解决并继续：

```powershell
git add <冲突文件>
git rebase --continue
```

如果无法判断：

```powershell
git rebase --abort
```

然后由模块负责人和另一位修改者共同处理。已经 Push 过的个人功能分支完成 Rebase 后，只允许：

```powershell
git push --force-with-lease
```

严禁对 `main` 使用 `--force` 或 `--force-with-lease`，严禁使用裸 `git push --force`。

## 6. Review、合并与清理

审核者需要：

1. 阅读关联 Issue 和验收条件；
2. 检查 Files changed，确认没有无关文件；
3. 检查接口、位宽、符号、时钟域和复位；
4. 打开验证证据，确认能支持结论；
5. 对问题提出具体修改意见；
6. 修改完成后重新检查并 Approve。

负责人在审核和验证通过后选择 `Create a merge commit`，不使用 Squash 或 Rebase merge。合并后成员执行：

```powershell
git switch main
git pull --ff-only origin main
git branch -d feat/synth-dds
```

远程功能分支由 GitHub 自动删除。只有确实完成验收的 Issue 才能关闭；未完成内容应保留为已知问题或拆出新的 Issue。

## 7. 验证证据保存规范

| 证据 | 建议位置 | 必须包含 |
| --- | --- | --- |
| 仿真波形 | `docs/progress/日期-主题/` | Commit、信号名、时间单位、结论 |
| 频谱图 | `docs/progress/日期-主题/` | 采样率、FFT 长度、目标频率、结论 |
| 资源报告摘要 | `docs/metrics/` | Gowin 版本、器件、参数、LUT/FF/DSP/BRAM |
| 时序报告摘要 | `docs/metrics/` | 时钟约束、最高频率、最差余量 |
| 上板照片 | `docs/progress/日期-主题/` | 板卡、连接方式和测试场景 |
| 演示视频 | GitHub Release | 版本、Commit、操作步骤和已知问题 |

截图和报告使用可理解的文件名，例如：

```text
2026-09-20_dds-440hz_waveform.png
2026-09-24_four-voice_spectrum.png
2026-09-25_8voice_resource-summary.md
```

不要只贴图片。图片旁必须有文字说明“测试什么、使用什么配置、看到了什么、是否通过”。

## 8. 自动生成文件与大文件

不得提交：

- Gowin 自动生成的缓存、临时目录和本机数据库；
- 临时日志、崩溃转储和编辑器配置；
- 第三方工具许可证和账号凭据；
- 带用户名的本机绝对路径；
- 未压缩的长视频和重复生成的完整实现目录。

需要保留的综合、布局布线和时序结论，应整理成小型 Markdown 摘要放入 `docs/metrics/`。位流和长视频放在 GitHub Release，并在 README 或进度表中链接。

## 9. Release 规范

两周阶段至少发布：

- `v0.1-single-voice`：Day 8 单音闭环；
- `v0.2-polyphony`：Day 14 多复音冲刺。

Release 说明包含：

```text
本版本完成：
演示方式：
硬件和工具版本：
采样率、位深和复音数：
资源及时序结果：
验证证据：
已知问题：
下一版本目标：
```

## 10. 公开仓库前检查

1. 删除令牌、许可证、个人路径和隐私内容。
2. 检查参考工程、波表和第三方代码的来源及许可。
3. README 首屏展示最新成果、架构、进度和核心指标。
4. 进度表链接到真实 Issue、PR 和 Release。
5. 在 `Settings → Rules → Rulesets` 为 `main` 设置：必须 PR、至少一人批准、必须解决对话、禁止强推、禁止删除、禁止随意绕过。
6. 从干净 Clone 按 README 重新编译，确认工程可复现。
