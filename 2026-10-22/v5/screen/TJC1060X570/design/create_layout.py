"""Create a USART HMI layout manifest and an SVG preview; no HMI/TFT output."""

from pathlib import Path
import csv
import html
import json


ROOT = Path(__file__).resolve().parent
WIDTH, HEIGHT = 1024, 600
NOTES = ["C4", "C#4", "D4", "D#4", "E4", "F4", "F#4", "G4", "G#4", "A4", "A#4", "B4", "C5"]


def rgb565(rgb):
    r, g, b = [int(rgb[i:i + 2], 16) for i in (1, 3, 5)]
    return ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3)


def rgb888(value):
    r, g, b = (value >> 11) & 31, (value >> 5) & 63, value & 31
    return f"#{(r * 255 + 15) // 31:02x}{(g * 255 + 31) // 63:02x}{(b * 255 + 15) // 31:02x}"


COLORS = {
    "page": rgb565("#0f172a"),
    "panel": rgb565("#1e293b"),
    "accidental_panel": rgb565("#111827"),
    "text": rgb565("#f8fafc"),
    "muted": rgb565("#94a3b8"),
    "cyan": rgb565("#38bdf8"),
    "gold": rgb565("#fbbf24"),
    "border": rgb565("#334155"),
}


def text_control(name, x, y, w, h, initial, capacity, foreground="text", background="page", dynamic=False, meaning=""):
    return {
        "objname": name,
        "type": "Text",
        "x": x, "y": y, "w": w, "h": h,
        "txt_maxl": capacity,
        "font": 0,
        "sta": 1,
        "pco": COLORS[foreground],
        "bco": COLORS[background],
        "xcen": 1 if dynamic or name.startswith("note") else 0,
        "ycen": 1,
        "txt": initial,
        "dynamic": dynamic,
        "meaning": meaning,
    }


dynamic = [
    text_control("t0", 48, 140, 270, 50, "----", 4, "cyan", "panel", True, "模式：LIVE / MIDI"),
    text_control("t1", 366, 140, 270, 50, "-", 1, "gold", "panel", True, "活动键数量，单个十六进制字符；A=10、B=11、C=12、D=13"),
    text_control("t2", 684, 140, 270, 50, "-----", 5, "text", "panel", True, "状态：WAIT / READY / PLAY"),
]
static = [
    text_control("title", 32, 24, 650, 48, "PRESSURE INSTRUMENT", 19),
    text_control("uartInfo", 748, 24, 244, 48, "UART 115200", 11, "muted"),
    text_control("labelMode", 48, 98, 270, 40, "MODE", 4, "muted", "panel"),
    text_control("labelActive", 366, 98, 270, 40, "ACTIVE (HEX)", 12, "muted", "panel"),
    text_control("labelState", 684, 98, 270, 40, "STATE", 5, "muted", "panel"),
    text_control("labelPressure", 32, 220, 600, 42, "PRESSURE (HEX 000-FFF)", 22, "muted"),
    text_control("labelKeys", 700, 220, 292, 42, "13 KEYS / 12-BIT", 16, "muted"),
    text_control("footer", 32, 532, 960, 40, "PRESS A KEY TO SEE ITS HEX VALUE CHANGE", 40, "muted"),
]
panels = [
    {"x": x, "y": 94, "w": 302, "h": 110, "bco": COLORS["panel"]}
    for x in (32, 350, 668)
]
for key, note in enumerate(NOTES):
    background = "accidental_panel" if "#" in note else "panel"
    x = 32 + key * 74
    panels.append({"x": x, "y": 270, "w": 68, "h": 234, "bco": COLORS[background]})
    static.append(text_control(f"note{key}", x + 2, 278, 64, 42, note, len(note), "text", background))
    dynamic.append(text_control(f"t{key + 3}", x + 2, 358, 64, 56, "---", 3, "cyan", background, True,
                                f"第 {key + 1} 键 {note} 压力，12 位值，三个大写十六进制字符 000..FFF"))

manifest = {
    "artifact_kind": "USART HMI layout source only; NOT an .HMI project or .TFT binary",
    "model": "TJC1060X570_011",
    "orientation": "landscape",
    "page": {"name": "page0", "id": 0, "width": WIDTH, "height": HEIGHT, "bco": COLORS["page"]},
    "font0": {
        "id": 0,
        "encoding": "ASCII",
        "height_px": 32,
        "recommended_width_px": 16,
        "required_characters": " !\"#()-/0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_",
        "note": "在 USART HMI 字库生成器中创建并添加 ASCII 字库，确保添加后的编号为 0。预览字体仅为浏览器等宽字体，不代表已经生成屏幕字库。",
    },
    "uart": {"baud": 115200, "data_bits": 8, "parity": "none", "stop_bits": 1, "terminator_hex": "FF FF FF"},
    "fpga_wiring": {"C18": "FPGA TX -> screen RX", "C19": "FPGA RX <- screen TX", "ground": "common GND"},
    "colors_rgb565": COLORS,
    "dynamic_text_controls": dynamic,
    "static_text_controls": static,
    "background_panels": panels,
    "initialization_before_page0": ["bauds=115200", "recmod=0", "bkcmd=3", "page 0"],
    "touch_events": "empty",
    "acceptance": {
        "after_screen_download_only": "应看到此新页面；动态控件仍为 ----、-、-----、---，只证明屏幕页面更新。",
        "after_fpga_uart_first_frame": "t0 自动出现 LIVE 或 MIDI，t1 为单个十六进制字符，t2 为 WAIT/READY/PLAY，t3..t15 变为三个十六进制字符。",
        "live_key_test": "LIVE 模式下按压、松开一个键，对应压力值应随之变化。校准、传感器和模式配置会影响实际数值，不能要求空载必为 000。",
        "refresh": "首帧约等待 1 秒；后续每整帧发送完等待 100 毫秒，总周期约 120 毫秒。",
        "not_proven": "新页面出现本身不证明 UART、声音、MIDI 上传或触摸控制已验证。",
    },
}

for control in dynamic + static:
    assert 0 <= control["x"] and 0 <= control["y"]
    assert control["x"] + control["w"] <= WIDTH
    assert control["y"] + control["h"] <= HEIGHT
    assert len(control["txt"]) <= control["txt_maxl"]
assert [c["objname"] for c in dynamic] == [f"t{i}" for i in range(16)]

(ROOT / "controls_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
columns = ["objname", "type", "x", "y", "w", "h", "txt_maxl", "font", "sta", "pco", "bco", "xcen", "ycen", "txt", "meaning"]
with (ROOT / "dynamic_controls.csv").open("w", encoding="utf-8-sig", newline="") as stream:
    writer = csv.DictWriter(stream, fieldnames=columns, extrasaction="ignore")
    writer.writeheader()
    writer.writerows(dynamic)

svg = [
    '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="600" viewBox="0 0 1024 600" role="img" aria-labelledby="title description">',
    '<title id="title">Pressure instrument serial screen layout preview</title>',
    '<desc id="description">Layout source preview only. All sixteen FPGA fields show placeholders before UART data arrives.</desc>',
    f'<rect width="1024" height="600" fill="{rgb888(COLORS["page"])}"/>',
]
for panel in panels:
    svg.append(f'<rect x="{panel["x"]}" y="{panel["y"]}" width="{panel["w"]}" height="{panel["h"]}" fill="{rgb888(panel["bco"])}"/>')
for control in static + dynamic:
    anchor = "middle" if control["xcen"] else "start"
    x = control["x"] + (control["w"] / 2 if control["xcen"] else 0)
    y = control["y"] + control["h"] / 2
    svg.append(f'<text data-objname="{control["objname"]}" x="{x:g}" y="{y:g}" fill="{rgb888(control["pco"])}" font-family="Consolas, Liberation Mono, monospace" font-size="32" text-anchor="{anchor}" dominant-baseline="middle">{html.escape(control["txt"])}</text>')
svg.append('</svg>')
(ROOT / "pressure_instrument_preview.svg").write_text("\n".join(svg) + "\n", encoding="utf-8")

(ROOT / "README.md").write_text("""# TJC1060X570_011 乐器页面布局源

这是 1024×600 横屏页面的布局清单与静态 SVG 预览。**这些文件不是 `.HMI` 工程或 `.TFT` 下载文件，也没有安装或下载到屏幕。**

## 文件

- `controls_manifest.json`：页面尺寸、RGB565 颜色、16 个 FPGA 输出 Text 控件、静态标签及背景矩形。
- `dynamic_controls.csv`：可以在表格软件中查看的 16 个输出控件属性。
- `pressure_instrument_preview.svg`：全部输出字段尚未接收到数据时的布局预览。
- `pressure_instrument_preview.png`：由 SVG 渲染的同一布局预览，可直接查看；仍然不是屏幕下载文件。
- `create_layout.py`：重新生成上述布局文件的脚本。

## USART HMI 创建要求

1. 选择 TJC1060X570_011（1024×600），横屏，新建 `page0`。
2. 生成 ASCII 32 像素字库并添加为 `font=0`。确保大写英文字母、数字、`#`、`-`、`/` 和括号可用；选择字符宽度约 16 像素的等宽字体。
3. 按清单建立 **Text** 控件 `t0`～`t15`。输出名称和 `txt_maxl` 必须匹配清单，不能使用 Number 控件代替。
4. 上方三项依次为模式、活动键数和状态；下方 13 项从左到右对应 C4、C#4、D4、D#4、E4、F4、F#4、G4、G#4、A4、A#4、B4、C5。
5. 静态标签与背景矩形只用于布局。可以按清单创建，也可以制成单张背景图；`t0`～`t15` 必须保留为真实 Text 控件。
6. 使用项目现有 `program.s` 初始化，115200、8N1，`recmod=0`。触摸事件暂时留空。
7. 编译为 `.TFT`，按屏幕下载流程更新后，才能替换屏内原有工程。

## 如何判断现象正确

- **先看页面**：屏上应出现 `PRESSURE INSTRUMENT`、三个状态区域和 13 个音名。如果仍是别人旧页面，说明还没有把新屏幕工程下载进去。
- **再看 UART**：页面初值为 `----`、`-`、`-----` 和 `---`。FPGA 数据到达后，模式出现 `LIVE` 或 `MIDI`、状态出现 `WAIT`/`READY`/`PLAY`、压力变成三个十六进制字符。这个变化证明屏幕接受并执行了 FPGA 文本命令。
- **最后按键**：在 `LIVE` 模式，按压和松开一个压力键，对应音名下方的值应改变。不要把空载值必须为 `000` 当作条件，校准和传感器状态会影响数值。
- 活动键数为一位十六进制：`A`=10、`B`=11、`C`=12、`D`=13；压力为 `000`～`FFF`。
- 首帧前约等待 1 秒，之后约每 120 毫秒刷新一轮。

页面更新和 UART 文本更新分别验证不同步骤；这些现象不单独证明音频、MIDI 上传或触摸功能已通过实物验证。
""", encoding="utf-8")

print(f"Created {len(dynamic)} dynamic Text controls and {len(static)} static Text labels.")
for name in ("controls_manifest.json", "dynamic_controls.csv", "pressure_instrument_preview.svg", "README.md"):
    print(ROOT / name)
