# GitHub 仓库首次上线指南

本指南由仓库负责人执行一次。当前本地仓库已经包含两条历史：

```text
main
└─ docs(readme): initialize project overview

docs/setup-collaboration
└─ docs(repo): add collaboration workflow and templates
```

协作文档位于 `docs/setup-collaboration`，应通过第一条 Pull Request 合并到 `main`，从项目开始就留下真实的协作记录。

## 1. 在 GitHub 创建空仓库

1. 登录 GitHub，点击右上角 `+`，选择 `New repository`。
2. Owner 选择负责人自己的账号。
3. Repository name 填写 `fpga-musical-instrument`。
4. Description 填写：

   ```text
   FPGA-based real-time polyphonic musical instrument engine
   ```

5. Visibility 选择 `Private`。
6. **不要勾选** Add a README file、Add .gitignore 或 Choose a license。本地仓库已经包含这些需要的文件，再次初始化会产生两套不相关历史。
7. 点击 `Create repository`。

## 2. 连接并推送本地仓库

在 PowerShell 中进入本地仓库：

```powershell
Set-Location -LiteralPath "<本地仓库目录>\fpga-musical-instrument"
```

将命令中的 `<负责人GitHub用户名>` 替换为仓库 Owner：

```powershell
git remote add origin https://github.com/<负责人GitHub用户名>/fpga-musical-instrument.git
git remote -v
git push -u origin main
git push -u origin docs/setup-collaboration
```

第一次 Push 时，Git Credential Manager 可能打开浏览器要求登录 GitHub。只在 GitHub 官方登录页面完成操作，不把密码或验证码写入仓库、Issue 或聊天记录。

如果误填远程地址，在任何 Push 之前执行：

```powershell
git remote set-url origin https://github.com/<正确用户名>/fpga-musical-instrument.git
git remote -v
```

## 3. 创建第一条 Pull Request

Push 完成后进入 GitHub 仓库：

1. 点击 `Compare & pull request`；如果没有提示，进入 `Pull requests → New pull request`。
2. Base 选择 `main`。
3. Compare 选择 `docs/setup-collaboration`。
4. 标题填写：

   ```text
   docs(repo): 建立团队协作规范和模板
   ```

5. 第一条 PR 创建时，模板还没有合并到 `main`，因此手动填写：

   ```markdown
   ## 本次完成
   - 新增团队 GitHub 协作规范
   - 新增 Feature、Bug、Test 三种 Issue 模板
   - 新增 Pull Request 模板
   - 新增开发进度和 FPGA 资源扩展记录模板

   ## 设计原因
   - 统一三名成员的分支、提交、审核和验证流程
   - 保存真实连续的开发记录，便于评委快速阅读

   ## 验证方法
   - 检查所有内部 Markdown 链接
   - 检查 Issue 模板 Front Matter
   - 执行 git diff --check 和 git fsck --full

   ## 验证结果
   - 检查通过，本地工作区干净

   ## 已知问题
   - GitHub 免费账户的私有仓库不能强制执行分支保护，开发期由负责人唯一合并
   ```

6. 指定另一名成员为 Reviewer。
7. 等待审核意见；修改时继续在 `docs/setup-collaboration` 分支 Commit 和 Push。
8. 审核通过后，负责人选择 `Create a merge commit`。

## 4. 邀请两名成员

1. 打开 `Settings → Collaborators`。
2. 点击 `Add people`。
3. 分别搜索两名成员的 GitHub 用户名并发送邀请。
4. 请成员确认邀请邮件或 GitHub 通知。
5. 成员接受后，各自在自己的电脑执行 Clone 和身份检查。

成员首次配置：

```powershell
git --version
git config --global user.name "自己的 GitHub 名称"
git config --global user.email "GitHub 绑定邮箱"
git clone https://github.com/<负责人GitHub用户名>/fpga-musical-instrument.git
cd fpga-musical-instrument
git remote -v
git status
```

三人不能共用同一个 Git 身份。

## 5. 配置 Pull Request 合并方式

进入 `Settings → General → Pull Requests`：

1. 保留 `Allow merge commits`。
2. 关闭 `Allow squash merging`。
3. 关闭 `Allow rebase merging`。
4. 开启 `Automatically delete head branches`。

由于开发期是 GitHub 免费账户下的私有仓库，分支保护无法强制执行。团队暂时执行：

- 除负责人外，成员不直接 Push `main`；
- 负责人也通过 PR 提交自己的功能；
- 每个 PR 至少一人 Review；
- 只有负责人点击 Merge；
- 禁止对 `main` Force Push。

## 6. 建立 Milestone 和 Label

在 `Issues → Milestones` 创建：

| Milestone | 用途 |
| --- | --- |
| `Week 1` | Git、Verilog、Gowin、I2S、DDS、ADSR 学习与单音准备 |
| `Week 2` | 单音闭环、ADSR、4 复音、频谱、资源和演示整理 |

在 `Issues → Labels` 创建或确认：

| Label | 用途 |
| --- | --- |
| `feature` | 新功能 |
| `bug` | 可复现问题 |
| `test` | 仿真、综合、频谱或上板验证 |
| `documentation` | 文档和展示 |
| `hardware` | 板卡、引脚、音频接口等硬件相关工作 |
| `blocked` | 存在明确阻塞条件 |
| `needs-review` | 等待另一名成员审核 |

## 7. 验证模板已经生效

第一条 PR 合并后检查：

1. 进入 `Issues → New issue`，确认出现功能开发、问题报告、测试与验证三种模板。
2. 新建测试 PR，确认正文自动出现 PR 模板。
3. 检查仓库 `Insights → Network` 或 Commit 历史，确认 Merge Commit 和功能 Commit 都被保留。
4. 从 README 点击协作规范、进度和资源表，确认内部链接全部有效。

## 8. 三人完成协作练习

每名成员分别：

1. 使用 Documentation 或 Feature 模板创建练习 Issue。
2. 建立 `docs/git-practice-姓名拼音` 分支。
3. 新建自己的练习文档。
4. Commit 并 Push。
5. 创建 PR 并关联 Issue。
6. 由另一名成员留下 Review 意见。
7. 修改完成后由负责人 Merge Commit 合并。

三个人都独立完成一次，才算协作机制验收通过。

## 9. 评审前公开并保护 main

公开前先检查敏感信息、第三方许可和复现步骤。确认无误后将仓库改为 Public，再在 `Settings → Rules → Rulesets` 为 `main` 创建规则：

- Require a pull request before merging；
- Require one approval；
- Require conversation resolution；
- 禁止 Force Push；
- 禁止删除 `main`；
- 不允许管理员随意绕过。

最后使用未参与开发的干净目录重新 Clone，按照 README 完成一次编译和验证。
