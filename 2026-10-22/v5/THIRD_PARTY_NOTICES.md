# 第三方来源

- 自编代码沿用根目录MIT许可。
- `third_party/tjc_toolchain/usarthmi`：YXerer668及贡献者，MIT；原LICENSE随包保留。来源：https://github.com/YXerer668/tjc-usart-hmi-toolchain 。实际快照文件摘要进入SOURCE_MANIFEST.json。
- `rtl/video/gowin_dvi_ip/DVI_TX_Top.v`：Sipeed官方cam_dvi，固定提交及Apache-2.0原声明见同目录README和LICENSES；Gowin原文件声明保留。
- PySide6/Qt、Verovio、Partitura、FluidSynth、GeneralUser GS、Audiveris、converter21/music21、Transcoda均通过各自准备脚本或包管理器获取，未把它们的安装器/模型/音源作为MIT源码打包。准备音乐组件的脚本保留组件许可。
- 屏幕HMI/ZI/图片属于工程资源，使用官方格式与本机字体生成；不重新许可官方模板或字体。
- 旧USB Host诊断用到授权范围未确认的外部示例固件，不在本次仓库中；当前MCP3208、UART屏、电脑工作站与V2主工程均不依赖它。
