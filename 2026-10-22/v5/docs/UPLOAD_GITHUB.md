# 上传GitHub

上传解压后的仓库内容；ZIP可另作为Release附件。不要把原工作目录的build/.tools一起上传。

1. 在自己的GitHub账号创建一个空仓库。
2. 在本目录打开终端：

```powershell
git init -b main
git add .
git commit -m "Initial FPGA music workstation V5 source snapshot"
git remote add origin https://github.com/YOUR_ACCOUNT/YOUR_REPOSITORY.git
git push -u origin main
```

将YOUR_ACCOUNT/YOUR_REPOSITORY换为自己的地址。Git提示身份未配置时，用自己的姓名/邮箱配置当前仓库。
使用GitHub Desktop也可将本目录加入仓库后提交、发布。

完整性文件：`SOURCE_MANIFEST.json`记录源码摘要，`RELEASE_CHECKS.json`记录干净副本检查；并不代表题目全部实物要求已完成。
