# GitHub 上传约定

本目录是源码仓库入口。`.gitignore` 已排除工具、原始录音、位流、压缩包、旧诊断、仿真缓存和构建产物。
不要直接把上一级工程归档上传，也不要将 `.tools/`、Gowin 安装目录、厂商模型或许可证文件加入 Git。

```powershell
python scripts/check_project.py
python scripts/run_tests.py --suite basic
git status --short
git add .
git diff --cached --stat
```

检查待提交内容后，自行使用 GitHub Desktop 或创建仓库后按 GitHub 提示提交、关联远程、推送。
本次整理未设置虚构仓库地址、作者身份或访问令牌，也未自动提交/推送。

本地可运行 `python scripts/package_release.py source` 生成干净源码 ZIP，
运行 `python scripts/package_release.py v74` 生成已试听版本的固件/网表附件。
后者适合放在 GitHub Release；源码包已排除它。不要把重新综合的 0x5AB0 标成已试听 v74。

GitHub 对大文件有限制，生成物宜作为 Release 附件：
[官方大文件说明](https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-large-files-on-github)。

作者尚未指定原创代码的开源许可证，本次不擅自赋予 MIT/GPL 等授权。
第三方素材来源与原始授权文本在 `third_party/`，不能被项目未来的许可证覆盖。
选定项目许可后再添加根 `LICENSE`；公开源码与授予开源许可的区别见
[GitHub 官方说明](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository)。
