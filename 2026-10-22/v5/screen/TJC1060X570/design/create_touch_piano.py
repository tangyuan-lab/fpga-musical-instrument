"""生成独立触摸演奏页面源，保留 V2 监控输入，不修改原 V2 工程。"""
from __future__ import annotations

from copy import deepcopy
import hashlib
import json
from pathlib import Path
import re
import sys

from PIL import Image, ImageDraw, ImageFont
from hex12_parser import decode_hex12

DESIGN = Path(__file__).resolve().parent
ROOT = DESIGN / "touch"
V2 = DESIGN / "v2"
PROJECT = DESIGN.parents[2]
NOTES = ["C4", "C#4", "D4", "D#4", "E4", "F4", "F#4", "G4", "G#4", "A4", "A#4", "B4", "C5"]


def branch(condition, yes, no=None):
    lines = [f"if({condition})", "{", *yes, "}"]
    if no is not None:
        lines[-1] = "}else"
        lines += ["{", *no, "}"]
    return lines


def packet(operation, key):
    data = [0xA5, 0x5A, operation, key]
    checksum = data[0] ^ data[1] ^ data[2] ^ data[3]
    return "printh " + " ".join(f"{byte:02X}" for byte in [*data, checksum])


def generate():
    original = json.loads((V2 / "controls_manifest.json").read_text(encoding="utf-8"))
    spec = deepcopy(original)
    widgets = spec["widgets"]
    by_name = {widget["objname"]: widget for widget in widgets}
    colors = spec["colors_rgb565"]

    def variable(name, value=0, text=None):
        fields = {"sta": 0, "val": value} if text is None else {"sta": 1, "txt": text, "txt_maxl": 3}
        widget = {"objname": name, "type": "variable", "fields": fields, "events": {}}
        widgets.append(widget)
        by_name[name] = widget

    def text(name, x, y, w, h, initial, capacity, foreground="cyan"):
        widget = {"objname": name, "type": "text", "fields": {
            "x": x, "y": y, "w": w, "h": h, "sta": 1, "font": 0,
            "pco": colors[foreground], "bco": colors["panel"], "xcen": 1, "ycen": 1,
            "txt": initial, "txt_maxl": capacity}, "events": {}}
        widgets.append(widget)
        by_name[name] = widget

    if "hexDigit" not in by_name:
        variable("hexDigit", text="0")

    variable("playMode", 1)
    variable("heldKey", -1)
    variable("sourceTxt", text="---")
    for key in range(13):
        variable(f"sim{key}", text="000")
    text("playBtn", 676, 536, 84, 34, "PLAY", 4)
    text("offBtn", 774, 536, 120, 34, "ALL OFF", 7, "amber")
    text("touchTxt", 500, 536, 112, 34, "---", 3)
    by_name["demoBtn"]["fields"].update({"x": 908, "y": 536, "w": 80, "h": 34})

    def stripe(key, held=False):
        # 顶部色条位于文字与压力条以外，触摸高亮不会伪造压力读数。
        x = 49 + key * 74
        color = colors["purple"] if held else colors["amber" if "#" in NOTES[key] else "cyan"]
        return f"fill {x},271,34,3,{color}"

    def release_held():
        lines = []
        for key in range(13):
            lines += branch(f"heldKey.val=={key}", [packet(0, key), stripe(key)])
        return [*lines, "heldKey.val=-1", 'touchTxt.txt="---"']

    def all_off():
        return [packet(2, 255), "heldKey.val=-1", 'touchTxt.txt="---"',
                *[stripe(key) for key in range(13)]]

    # 屏幕本地演奏开关不改变 FPGA 的 LIVE/MIDI 模式。
    by_name["playBtn"]["events"]["codesup-"] = [*all_off(), *branch(
        "playMode.val==1", ["playMode.val=0", 'playBtn.txt="MON"', f"playBtn.pco={colors['muted']}"],
        branch("demoMode.val==0", ["playMode.val=1", 'playBtn.txt="PLAY"', f"playBtn.pco={colors['cyan']}"]))]
    by_name["offBtn"]["events"]["codesup-"] = all_off()
    # DEMO 使用 sim0..sim12 的独立假数据，绝不写入真实 UART t0..t15。
    demo_start = ["demoMode.val=1", "demoStep.val=0", "demoKey.val=0", 'demoBtn.txt="STOP"',
                  f"demoBtn.pco={colors['amber']}"]
    demo_stop = ["demoMode.val=0", 'demoBtn.txt="DEMO"', f"demoBtn.pco={colors['cyan']}"]
    clear_peak = [line for key in range(13) for line in
                  (f"cur{key}.val=0", f"peak{key}.val=0", f'peakHex{key}.txt="000"')]
    by_name["demoBtn"]["events"]["codesup-"] = [*all_off(), "playMode.val=0", 'playBtn.txt="MON"',
        f"playBtn.pco={colors['muted']}", *clear_peak, *branch("demoMode.val==0", demo_start, demo_stop)]
    # RESET 与屏幕当前选用的数据源一致；它不触发 ADC 或 FPGA 校准。
    reset = []
    for key in range(13):
        reset += [f"peak{key}.val=cur{key}.val", *branch("demoMode.val==1",
                  [f"peakHex{key}.txt=sim{key}.txt"], [f"peakHex{key}.txt=t{key+3}.txt"])]
    by_name["clearBtn"]["events"]["codesup-"] = reset

    timer = []
    demo_values = ["000", "080", "180", "380", "700", "A00", "FFF", "D00",
                   "900", "500", "280", "180", "080", "020", "000", "000"]
    demo = [*[f'sim{key}.txt="000"' for key in range(13)]]
    for step, value in enumerate(demo_values):
        demo += branch(f"demoStep.val=={step}", [f'demoValue.txt="{value}"'])
    for key in range(13):
        demo += branch(f"demoKey.val=={key}", [f"sim{key}.txt=demoValue.txt"])
    demo += ["demoStep.val++", *branch("demoStep.val>=16", ["demoStep.val=0", "demoKey.val++"]),
             *branch("demoKey.val>=13", ["demoKey.val=0"])]
    timer += branch("demoMode.val==1", demo)

    # tch0/tch1 是实时坐标：无触摸时均为 0；在定时器读取可以兜住移出后松开。
    # 弹起事件内坐标可能未更新，因此 codesup 只直接释放，不依赖坐标。
    release_reason = 'playMode.val==0||demoMode.val==1||t0.txt=="MIDI"'
    heartbeat = []
    for key in range(13):
        x = 32 + key * 74
        inside = f"tch0>={x}&&tch0<{x+68}&&tch1>=270&&tch1<484"
        heartbeat += branch(f"heldKey.val=={key}", branch(inside,
            [packet(1, key), stripe(key, True)],
            [packet(0, key), stripe(key), "heldKey.val=-1", 'touchTxt.txt="---"']))
    # 分开判断模式和坐标，避免依赖混合 &&/|| 的运算优先级。
    timer += branch("heldKey.val>=0", branch(release_reason, release_held(),
                    branch("tch0==0&&tch1==0", release_held(), heartbeat)))

    active = branch('t1.txt=="A"', ['activeTxt.txt="10"'],
             branch('t1.txt=="B"', ['activeTxt.txt="11"'],
             branch('t1.txt=="C"', ['activeTxt.txt="12"'],
             branch('t1.txt=="D"', ['activeTxt.txt="13"'], ['activeTxt.txt=t1.txt']))))
    demo_status = ['modeTxt.txt="DEMO"', 'stateTxt.txt="DEMO"',
                   *branch('demoValue.txt=="000"', ['activeTxt.txt="0"'], ['activeTxt.txt="1"'])]
    timer += branch("demoMode.val==1", demo_status, ['modeTxt.txt=t0.txt', 'stateTxt.txt=t2.txt', *active])
    for key in range(13):
        timer += branch("demoMode.val==1", [f"sourceTxt.txt=sim{key}.txt"], [f"sourceTxt.txt=t{key+3}.txt"])
        valid = []
        valid += branch(f"cur{key}.val>=peak{key}.val", [f"peak{key}.val=cur{key}.val", f"peakHex{key}.txt=sourceTxt.txt"])
        valid += branch("holdMode.val==1", [f"sys0=peak{key}.val"], [f"sys0=cur{key}.val"])
        valid += branch("unitMode.val==1", [f"covx sys0,ui{key}.txt,0,0"],
                        branch("holdMode.val==1", [f"ui{key}.txt=peakHex{key}.txt"], [f"ui{key}.txt=sourceTxt.txt"]))
        valid += ["sys0=sys0*100", "sys0=sys0/4095", f"j{key}.val=sys0"]
        valid += branch(f"selected.val=={key}", [f'detailNote.txt="{NOTES[key]}"',
                        f"covx cur{key}.val,detailNow.txt,0,0", f"covx peak{key}.val,detailPeak.txt,0,0"])
        invalid = [f'ui{key}.txt="---"', f"j{key}.val=0", *branch(f"selected.val=={key}",
                   [f'detailNote.txt="{NOTES[key]}"', 'detailNow.txt="---"', 'detailPeak.txt="---"'])]
        parsed = decode_hex12("sourceTxt.txt", f"cur{key}.val") + branch("sys2==3", valid, invalid)
        timer += ["strlen sourceTxt.txt,sys2", *branch("sys2==3", branch('sourceTxt.txt!="---"', parsed, invalid), invalid)]
    timer += branch('modeTxt.txt=="MIDI"', [f"modeTxt.pco={colors['purple']}"], [f"modeTxt.pco={colors['cyan']}"])
    timer += branch('stateTxt.txt=="WAIT"', [f"stateTxt.pco={colors['muted']}"], [f"stateTxt.pco={colors['cyan']}"])
    timer += ["ref modeTxt", "ref stateTxt"]
    by_name["tm0"]["fields"].update({"tim": 150, "en": 1})
    by_name["tm0"]["events"]["codestimer-"] = timer

    # 热点最后追加：覆盖整张琴键卡片，处于压力条和文字控件之上。
    # m 原型来自同型号官方工厂工程 17.pa m0，由通用 HMI builder 克隆。
    for key in range(13):
        x = 32 + key * 74
        down = [f"selected.val={key}", *branch('playMode.val==1&&demoMode.val==0&&t0.txt!="MIDI"',
            [*release_held(), f"heldKey.val={key}", packet(1, key), stripe(key, True), f'touchTxt.txt="{NOTES[key]}"'])]
        up = branch(f"heldKey.val=={key}", [packet(0, key), stripe(key), "heldKey.val=-1", 'touchTxt.txt="---"'])
        widgets.append({"objname": f"key{key}", "type": "hotspot", "fields": {
            "x": x, "y": 270, "w": 68, "h": 214, "vscope": 0, "drag": 0, "sendkey": 0},
            "events": {"codesdown-": down, "codesup-": up}})

    hidden = [widget["objname"] for widget in widgets if widget.get("hidden")]
    spec.update({"version": "touch-1", "font_resource": "../v2/dashboard_ascii_32.zi",
        "page_events": {"codesloadend-": [*[f"vis {name},0" for name in hidden], *all_off(), "tm0.en=1"],
                        "codesup-": all_off(), "codesunload-": all_off()},
        "features": ["13 full-card touch piano hotspots", "fixed-volume press/release playback", "150ms held heartbeat",
                     "PLAY/MON local gate", "ALL OFF", "real UART pressure monitoring", "separate local DEMO data"],
        "runtime_limits": "One tracked touch note; LIVE only; moving outside the original key releases without glissando. Pressure fields remain ADC inputs.",
        "touch_protocol": {"framing": "A5 5A OP KEY CHECK", "checksum": "XOR of the first 4 bytes",
            "operations": {"01": "note on/held heartbeat", "00": "note off", "02": "all off, KEY=FF"},
            "key_range": [0, 12], "note_order": NOTES, "heartbeat_ms": 150,
            "fixed_velocity": "Configured by FPGA; touch does not write ADC pressure values.",
            "official_coordinate_doc": "http://wiki.tjc1688.com/variables/tch0-tch3.html",
            "official_touch_event_doc": "http://wiki.tjc1688.com/start/ide_introduce/ide_introduce8.html",
            "official_printh_doc": "http://wiki.tjc1688.com/commands/printh.html"}})

    # 源码静态检查：协议与真实 UART 输入边界、热点层级和所有位置。
    assert [widget["objname"] for widget in widgets[:16]] == [f"t{i}" for i in range(16)]
    assert [widget["objname"] for widget in widgets[-13:]] == [f"key{i}" for i in range(13)]
    assert len({widget["objname"] for widget in widgets}) == len(widgets) and len(widgets) < 255
    event_lines = [line for widget in widgets for lines in widget.get("events", {}).values() for line in lines]
    event_lines += [line for lines in spec["page_events"].values() for line in lines]
    packets = []
    for line in event_lines:
        assert not re.match(r"^t(?:[0-9]|1[0-5])\.txt=", line), f"真实 UART 输入被本地覆盖：{line}"
        if line.startswith("printh "):
            assert re.fullmatch(r"printh (?:[0-9A-F]{2} ){4}[0-9A-F]{2}", line)
            data = bytes.fromhex(line[7:])
            assert len(data) == 5 and data[:2] == b"\xA5\x5A"
            assert data[4] == data[0] ^ data[1] ^ data[2] ^ data[3]
            assert (data[2] in (0, 1) and data[3] in range(13)) or data[2:4] == b"\x02\xFF"
            packets.append(line)
    assert packet(1, 0) == "printh A5 5A 01 00 FE"
    assert packet(0, 0) == "printh A5 5A 00 00 FF"
    assert packet(2, 255) == "printh A5 5A 02 FF 02"
    for widget in widgets:
        if widget["type"] in ("text", "progress", "hotspot"):
            fields = widget["fields"]
            assert 0 <= fields["x"] < fields["x"] + fields["w"] <= 1024
            assert 0 <= fields["y"] < fields["y"] + fields["h"] <= 600
    ROOT.mkdir(parents=True, exist_ok=True)
    (ROOT / "controls_manifest.json").write_text(json.dumps(spec, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (ROOT / "timer.txt").write_text("\n".join(timer) + "\n", encoding="utf-8")

    background = Image.open(V2 / "instrument_background.png").convert("RGB")
    draw = ImageDraw.Draw(background)

    def rgb(value):
        return ((value >> 11) * 255 // 31, ((value >> 5) & 63) * 255 // 63, (value & 31) * 255 // 31)

    def label(x, y, value, size=14, fg="muted", bold=False):
        font_path = Path("C:/Windows/Fonts") / ("msyhbd.ttc" if bold else "msyh.ttc")
        draw.text((x, y), value, font=ImageFont.truetype(str(font_path), size), fill=rgb(colors[fg]))

    draw.rectangle((28, 18, 670, 84), fill=rgb(colors["page"]))
    label(32, 24, "触摸键盘合成器", 30, "white", True)
    label(33, 67, "固定力度触摸演奏 · 实际压力数据独立显示", 13)
    draw.rectangle((28, 207, 600, 252), fill=rgb(colors["page"]))
    label(32, 214, "触摸琴键", 20, "white", True)
    label(140, 218, "按住发声，松手停音；滑出原键停止", 14)
    draw.rectangle((491, 516, 638, 576), fill=rgb(colors["panel"]))
    label(502, 520, "正在触摸", 12)
    draw.rectangle((668, 510, 1000, 592), fill=rgb(colors["page"]))
    draw.rounded_rectangle((672, 512, 991, 579), radius=12, fill=rgb(colors["panel"]),
                           outline=rgb(colors["border"]), width=1)
    label(684, 516, "演奏开关 / 全部停止 / 本地演示", 12)
    background.save(ROOT / "instrument_background.png")

    sys.path.insert(0, str(PROJECT / "third_party/tjc_toolchain"))
    from usarthmi.zi_font import ZiFont
    font = ZiFont(V2 / "dashboard_ascii_32.zi")
    for widget in widgets:
        if widget["type"] != "text" or widget.get("hidden"):
            continue
        fields = widget["fields"]
        draw.rectangle((fields["x"], fields["y"], fields["x"] + fields["w"] - 1,
                        fields["y"] + fields["h"] - 1), fill=rgb(fields["bco"]))
        glyph = font.render_text(fields["txt"], rgb(fields["pco"]))
        background.paste(glyph, (round(fields["x"] + (fields["w"] - glyph.width) / 2),
                                round(fields["y"] + (fields["h"] - glyph.height) / 2)), glyph)
    background.save(ROOT / "preview_idle.png")
    held_preview = background.copy()
    held_draw = ImageDraw.Draw(held_preview)
    held_draw.rectangle((49, 271, 82, 273), fill=rgb(colors["purple"]))
    held_draw.rectangle((500, 536, 611, 569), fill=rgb(colors["panel"]))
    glyph = font.render_text("C4", rgb(colors["cyan"]))
    held_preview.paste(glyph, (round(500 + (112 - glyph.width) / 2), 537), glyph)
    held_preview.save(ROOT / "preview_touch.png")
    report = {"source": str(Path(__file__).resolve()), "controls": len(widgets), "hotspots": 13,
              "highest_layer_hotspots": True, "uart_input_writes": 0,
              "packet_commands_checked": len(packets), "unique_packet_commands": sorted(set(packets)),
              "geometry_valid": True, "heartbeat_ms": 150, "single_touch_note": True,
              "font_sha256": hashlib.sha256((V2 / "dashboard_ascii_32.zi").read_bytes()).hexdigest(),
              "official_compile_status": "pending", "hardware_status": "pending"}
    (ROOT / "source_checks.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return report


if __name__ == "__main__":
    print(json.dumps(generate(), ensure_ascii=False, indent=2))
