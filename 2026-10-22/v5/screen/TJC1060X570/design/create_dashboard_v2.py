"""生成新版乐器背景、控件清单及屏幕本地脚本，不更改 FPGA UART 协议。"""
from pathlib import Path
import json
import sys
from PIL import Image, ImageDraw, ImageFont
from hex12_parser import decode_hex12

ROOT = Path(__file__).resolve().parent / "v2"
ROOT.mkdir(parents=True, exist_ok=True)
NOTES = ["C4", "C#4", "D4", "D#4", "E4", "F4", "F#4", "G4", "G#4", "A4", "A#4", "B4", "C5"]


def color(hex_color):
    rgb = tuple(int(hex_color[i:i+2], 16) for i in (1, 3, 5))
    return ((rgb[0] >> 3) << 11) | ((rgb[1] >> 2) << 5) | (rgb[2] >> 3)


def pixel(value):
    return ((value >> 11) * 255 // 31, ((value >> 5) & 63) * 255 // 63, (value & 31) * 255 // 31)


C = {name: color(code) for name, code in {
    "page": "#10141c", "panel": "#1b2330", "border": "#303b4c",
    "white": "#f3f2eb", "muted": "#93a3b7", "cyan": "#52d7bd",
    "amber": "#eebf73", "purple": "#bba7f5", "key": "#e9e7df",
    "ink": "#263440", "sharp": "#222c3b", "track": "#c6cbc6",
    "sharp_track": "#364358",
}.items()}
widgets = []


def text(name, x, y, w, h, value, capacity, fg="white", bg="panel", up=None, hidden=False):
    widget = {"objname": name, "type": "text", "hidden": hidden,
              "fields": {"x": x, "y": y, "w": w, "h": h, "sta": 1, "font": 0,
                         "pco": C[fg], "bco": C[bg], "xcen": 1, "ycen": 1,
                         "txt": value, "txt_maxl": capacity}, "events": {}}
    if up:
        widget["events"]["codesup-"] = up
    widgets.append(widget)
    return widget


def variable(name, value=0, string=None):
    fields = {"val": value, "sta": 0} if string is None else {"sta": 1, "txt": string, "txt_maxl": 3}
    widgets.append({"objname": name, "type": "variable", "fields": fields, "events": {}})


def branch(condition, yes, no=None):
    result = [f"if({condition})", "{", *yes, "}"]
    if no is not None:
        # 官方编译器要求 }else 同行，普通 C 风格的换行 else 会被当作指令。
        result[-1] = "}else"
        result += ["{", *no, "}"]
    return result


# UART 输入名称和容量保持不变；派生数值另用 ui0..ui12，避免被 FPGA 覆盖。
text("t0", 50, 129, 266, 40, "----", 4, "cyan", hidden=True)
text("t1", 370, 129, 266, 40, "-", 1, "amber", hidden=True)
text("t2", 690, 129, 266, 40, "WAIT", 5, hidden=True)
for k, note in enumerate(NOTES):
    sharp = "#" in note
    text(f"t{k+3}", 34+k*74, 438, 64, 36, "---", 3,
         "amber" if sharp else "ink", "sharp" if sharp else "key", hidden=True)

text("modeTxt", 50, 129, 266, 40, "----", 4, "cyan")
text("stateTxt", 690, 129, 266, 40, "WAIT", 5)
text("activeTxt", 370, 129, 266, 40, "-", 2, "amber")
for name in ("unitMode", "holdMode", "selected", "demoMode", "demoStep", "demoKey"):
    variable(name)
for k in range(13):
    variable(f"cur{k}")
    variable(f"peak{k}")

unit_event = branch("unitMode.val==0", ["unitMode.val=1", 'unitBtn.txt="DEC"'],
                    ["unitMode.val=0", 'unitBtn.txt="HEX"'])
hold_event = branch("holdMode.val==0", ["holdMode.val=1", 'holdBtn.txt="HOLD"', f"holdBtn.pco={C['amber']}"],
                    ["holdMode.val=0", 'holdBtn.txt="PEAK"', f"holdBtn.pco={C['muted']}"])
clear_event = [line for k in range(13) for line in
               (f"peak{k}.val=cur{k}.val", f"peakHex{k}.txt=t{k+3}.txt")]
demo_event = branch("demoMode.val==0", ["demoMode.val=1", "demoStep.val=0", "demoKey.val=0",
                                       'demoBtn.txt="STOP"', f"demoBtn.pco={C['amber']}"],
                    ["demoMode.val=0", 'demoBtn.txt="DEMO"', f"demoBtn.pco={C['cyan']}",
                     't0.txt="----"', 't1.txt="-"', 't2.txt="WAIT"',
                     *[f't{k+3}.txt="---"' for k in range(13)],
                     *[f"cur{k}.val=0" for k in range(13)],
                     *[f"peak{k}.val=0" for k in range(13)]])
text("unitBtn", 618, 212, 102, 38, "HEX", 4, "cyan", up=unit_event)
text("holdBtn", 744, 212, 102, 38, "PEAK", 4, "muted", up=hold_event)
text("clearBtn", 870, 212, 114, 38, "RESET", 5, "muted", up=clear_event)
for k, note in enumerate(NOTES):
    sharp = "#" in note
    event = [f"selected.val={k}"]
    text(f"ui{k}", 34+k*74, 438, 64, 36, "---", 4,
         "amber" if sharp else "ink", "sharp" if sharp else "key", up=event)
    widgets.append({"objname": f"j{k}", "type": "progress", "fields": {
        "x": 56+k*74, "y": 326, "w": 20, "h": 94, "sta": 0, "val": 0,
        "pco": C["amber" if sharp else "cyan"], "bco": C["sharp_track" if sharp else "track"],
        "dez": 1, "dis": 0}, "events": {"codesup-": event}})
text("detailNote", 62, 536, 80, 34, "C4", 3, "cyan")
text("detailNow", 211, 536, 94, 34, "---", 4)
text("detailPeak", 365, 536, 94, 34, "---", 4, "amber")
text("demoBtn", 704, 523, 112, 42, "DEMO", 4, "cyan", up=demo_event)
variable("demoValue", string="000")
variable("hexDigit", string="0")
for k in range(13):
    variable(f"peakHex{k}", string="000")

# 控件触摸用于本地观察，不发送播放、音色或 MIDI 命令。
# DEMO 明确标识为模拟数据；退出后恢复占位符，等下一帧真实 UART 数据。
timer = []
demo_values = ["000", "080", "180", "380", "700", "A00", "FFF", "D00",
               "900", "500", "280", "180", "080", "020", "000", "000"]
demo_script = ['t0.txt="DEMO"', 't2.txt="DEMO"', 't1.txt="1"',
               *[f't{k+3}.txt="000"' for k in range(13)]]
for step, value in enumerate(demo_values):
    demo_script += branch(f"demoStep.val=={step}", [f'demoValue.txt="{value}"'])
for k in range(13):
    demo_script += branch(f"demoKey.val=={k}", [f"t{k+3}.txt=demoValue.txt"])
demo_script += branch('demoValue.txt=="000"', ['t1.txt="0"'])
demo_script += ["demoStep.val++"] + branch("demoStep.val>=16", ["demoStep.val=0", "demoKey.val++"])
demo_script += branch("demoKey.val>=13", ["demoKey.val=0"])
timer += branch("demoMode.val==1", demo_script)
timer += branch("demoMode.val==1", ['modeTxt.txt="DEMO"', 'stateTxt.txt="DEMO"'],
                ['modeTxt.txt=t0.txt', 'stateTxt.txt=t2.txt'])

timer += branch('t1.txt=="A"', ['activeTxt.txt="10"'],
                branch('t1.txt=="B"', ['activeTxt.txt="11"'],
                       branch('t1.txt=="C"', ['activeTxt.txt="12"'],
                              branch('t1.txt=="D"', ['activeTxt.txt="13"'], ['activeTxt.txt=t1.txt']))))
for k in range(13):
    valid = []
    valid += branch(f"cur{k}.val>=peak{k}.val", [f"peak{k}.val=cur{k}.val", f"peakHex{k}.txt=t{k+3}.txt"])
    valid += branch("holdMode.val==1", [f"sys0=peak{k}.val"], [f"sys0=cur{k}.val"])
    valid += branch("unitMode.val==1", [f"covx sys0,ui{k}.txt,0,0"],
                    branch("holdMode.val==1", [f"ui{k}.txt=peakHex{k}.txt"], [f"ui{k}.txt=t{k+3}.txt"]))
    valid += ["sys0=sys0*100", "sys0=sys0/4095", f"j{k}.val=sys0"]
    valid += branch(f"selected.val=={k}", [f'detailNote.txt="{NOTES[k]}"',
        f"covx cur{k}.val,detailNow.txt,0,0", f"covx peak{k}.val,detailPeak.txt,0,0"])
    invalid = [f'ui{k}.txt="---"', f"j{k}.val=0"]
    invalid += branch(f"selected.val=={k}", [f'detailNote.txt="{NOTES[k]}"',
        'detailNow.txt="---"', 'detailPeak.txt="---"'])
    timer += [f"strlen t{k+3}.txt,sys2"]
    parsed = decode_hex12(f"t{k+3}.txt", f"cur{k}.val") + branch("sys2==3", valid, invalid)
    timer += branch("sys2==3", branch(f't{k+3}.txt!="---"', parsed, invalid), invalid)
timer += branch('modeTxt.txt=="MIDI"', [f"modeTxt.pco={C['purple']}"], [f"modeTxt.pco={C['cyan']}"])
timer += branch('stateTxt.txt=="WAIT"', [f"stateTxt.pco={C['muted']}"], [f"stateTxt.pco={C['cyan']}"])
timer += ["ref modeTxt", "ref stateTxt"]
widgets.append({"objname": "tm0", "type": "timer", "fields": {"tim": 150, "en": 1},
                "events": {"codestimer-": timer}})

hidden = [w["objname"] for w in widgets if w.get("hidden")]
manifest = {"model": "TJC1060X570_011", "version": 2,
            "font_resource": "dashboard_ascii_32.zi",
            "page": {"name": "page0", "width": 1024, "height": 600},
            "colors_rgb565": C, "widgets": widgets,
            "page_events": {"codesloadend-": [*[f"vis {name},0" for name in hidden], "tm0.en=1"]},
            "features": ["13 pressure meters", "decimal active count", "HEX/DEC view", "peak hold/reset",
                         "tap value or meter for detail", "explicit local DEMO mode"],
            "runtime_limits": "page0 only; local touch does not control FPGA playback or timbre",
            "uart": {"baud": 115200, "terminator_hex": "FF FF FF", "inputs": [f"t{i}" for i in range(16)]}}
(ROOT / "controls_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
(ROOT / "timer.txt").write_text("\n".join(timer)+"\n", encoding="utf-8")

# 中文标签烘焙到背景；动态数字使用新版 ASCII font0，已通过官方编辑器编译，待实物验证。
SCALE = 2
image = Image.new("RGB", (1024*SCALE, 600*SCALE), pixel(C["page"]))
draw = ImageDraw.Draw(image)


def font(size, bold=False, mono=False):
    name = "consolab.ttf" if mono and bold else "consola.ttf" if mono else "msyhbd.ttc" if bold else "msyh.ttc"
    return ImageFont.truetype(str(Path("C:/Windows/Fonts")/name), size*SCALE)


def label(x, y, value, size=18, fg="muted", bold=False, anchor="la", mono=False):
    draw.text((x*SCALE, y*SCALE), value, font=font(size, bold, mono), fill=pixel(C[fg]), anchor=anchor)


def rect(x, y, w, h, fg, radius=0, border=None):
    box = (x*SCALE, y*SCALE, (x+w-1)*SCALE, (y+h-1)*SCALE)
    if radius:
        draw.rounded_rectangle(box, radius*SCALE, fill=pixel(C[fg]), outline=pixel(C[border]) if border else None, width=SCALE)
    else:
        draw.rectangle(box, fill=pixel(C[fg]))


label(32, 24, "压力键合成器", 30, "white", True)
label(33, 65, "PRESSURE / PERFORMANCE", 13, "muted", mono=True)
rect(824, 29, 168, 38, "panel", 19, "border")
label(908, 37, "13 KEYS  ·  C4—C5", 14, "cyan", anchor="ma")
for x, title, subtitle in ((32, "演奏模式", "LIVE / MIDI"), (352, "活动键数", "0 — 13"), (672, "系统状态", "WAIT / READY / PLAY")):
    rect(x, 96, 304, 94, "panel", 12, "border")
    label(x+18, 106, title, 17)
    label(x+282, 110, subtitle, 11, anchor="ra", mono=True)
label(32, 213, "键位压力", 20, "white", True)
label(137, 217, "轻触数值或压力条，查看通道详情", 14)
for x, w in ((610, 118), (736, 118), (862, 130)):
    rect(x, 208, w, 44, "panel", 9, "border")
for k, note in enumerate(NOTES):
    x = 32+k*74
    sharp = "#" in note
    bg = "sharp" if sharp else "key"
    rect(x, 270, 68, 214, bg, 10, "border" if sharp else None)
    rect(x+17, 271, 34, 3, "amber" if sharp else "cyan")
    label(x+9, 283, f"{k+1:02d}", 10, "muted" if sharp else "ink", mono=True)
    label(x+34, 298, note, 20, "white" if sharp else "ink", True, "ma", mono=True)
    rect(x+24, 326, 20, 94, "sharp_track" if sharp else "track")
rect(32, 512, 618, 68, "panel", 12, "border")
label(53, 520, "所选音符", 12)
label(213, 520, "当前 / 4095", 12)
label(367, 520, "峰值 / 4095", 12)
label(502, 522, "观察显示", 12)
label(502, 549, "触摸不触发演奏", 11)
rect(682, 512, 156, 68, "panel", 12, "border")
label(878, 522, "显示单位", 12)
label(878, 548, "HEX / DEC", 16, "white", mono=True)
background = image.resize((1024, 600), Image.Resampling.LANCZOS)
background.save(ROOT / "instrument_background.png")


def preview(values=None, mode="----", state="WAIT", active="-", demo=False):
    canvas = background.copy()
    d = ImageDraw.Draw(canvas)
    sys.path.insert(0, str(ROOT.parents[3] / "third_party/tjc_toolchain"))
    from usarthmi.zi_font import ZiFont
    dynamic_font = ZiFont(ROOT / "dashboard_ascii_32.zi")
    for w in widgets:
        if w["type"] != "text" or w.get("hidden"):
            continue
        f = w["fields"]
        value = f["txt"]
        name = w["objname"]
        value = {"modeTxt": mode, "stateTxt": state, "activeTxt": active}.get(name, value)
        if values is not None and name.startswith("ui"):
            value = f"{values[int(name[2:])]:03X}"
        if values is not None:
            value = {"detailNow": str(values[0]), "detailPeak": str(values[0])}.get(name, value)
        if demo and name == "demoBtn":
            value = "STOP"
        d.rectangle((f['x'], f['y'], f['x']+f['w']-1, f['y']+f['h']-1), fill=pixel(f['bco']))
        glyphs = dynamic_font.render_text(value, pixel(f['pco']))
        canvas.paste(glyphs, (round(f['x']+(f['w']-glyphs.width)/2),
                            round(f['y']+(f['h']-glyphs.height)/2)), glyphs)
    if values is not None:
        for k, v in enumerate(values):
            height = round(v*94/4095)
            if height:
                x = 56+k*74
                d.rectangle((x, 420-height, x+19, 419), fill=pixel(C['amber' if '#' in NOTES[k] else 'cyan']))
    return canvas


preview().save(ROOT / "preview_idle.png")
preview([0x700, 0, 0xFFF, 0, 0x280, 0x500, 0, 0xB00, 0, 0x080, 0, 0x300, 0],
        "LIVE", "PLAY", "8").save(ROOT / "preview_live.png")
print(f"Generated {len(widgets)} controls, {len(timer)} timer lines; background and previews at {ROOT}")
