# 复现 V2 字库

`build_dashboard_font.py` 使用本机 Consolas 与已验证的 ZI V6/GB2312 头结构，生成按顺序排列的 95 个 ASCII 字符。字格为 16×32 像素，采用三位抗锯齿；`4095` 的宽度为 64 像素。

从项目根目录运行，选择新的输出路径：

```powershell
python screen/TJC1060X570/design/build_dashboard_font.py --out build/font-repro/dashboard_ascii_32.zi --preview
```

脚本默认使用 `C:/Windows/Fonts/consola.ttf`，依赖 Pillow 和项目现有 `third_party/tjc_toolchain`。输出旁保存 JSON 检查结果；`--preview` 保存由最终 ZI 字形回读生成的 PNG。**所有输出均拒绝覆盖已有文件，不会修改当前屏幕工程或既有字体。**

已验证字体 SHA256：

```text
513d06ee5d5ac8ffa651ccc6fe0b0185767f4ff2833c2fd48c2098b3aa3df4f4
```

JSON 中 `exact_reproduction=true` 表示完全复现。若字体文件或 Pillow/FreeType 渲染版本改变，二进制结果可能不同；请比较 JSON 中的源字体 SHA 和版本。回读校验通过仅证明字库结构与字形编码正确，新增或不同结果仍需由官方编辑器验证。
