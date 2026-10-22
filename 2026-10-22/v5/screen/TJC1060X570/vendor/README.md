# 可选的官方模板输入

发布包已有两份可编辑HMI，可以直接用USART HMI编译。
原官方工厂演示、数据手册、Windows字体文件和本机最小页面模板未作为自编源码发布。
需要从脚本重新生成时，使用自己合法取得并经官方编辑器保存的模板：

```powershell
python scripts/prepare_screen_templates.py --minimal 路径/uart_minimal_manual.HMI --factory 路径/TJC1060X570_factory.HMI
```

脚本按`templates.lock.json`核对格式基线。字体生成使用本机Windows微软雅黑，不分发原字体文件。
本项目生成的`.zi`和`.HMI`作为屏幕工程资源保留；其字体/官方格式内容不被重新授予MIT许可。
