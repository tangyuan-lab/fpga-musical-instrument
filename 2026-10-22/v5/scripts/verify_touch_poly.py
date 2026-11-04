"""代码验证多键事件、和弦识别、动画与 HMI 回读；不声称实物支持多点触摸。"""
import contextlib
import io
import json
from pathlib import Path
import sys
import time

from verify_touch_screen import SCREEN, PROJECT, EventModel, build_hmi, validate_saved_events, verify_rtl
from create_touch_poly import generate, chord_table, rgb, KEY_COUNT, QUALITIES
from chord_library import display_label, PC_NAMES
from touch16_base import geometry
from PIL import Image, ImageDraw


def validate(spec):
    count = 0

    def check(condition, message):
        nonlocal count
        if not condition:
            raise AssertionError(message)
        count += 1

    model = EventModel(spec)
    v = model.values
    check(v["tmAnim.en"] == 0, "Idle animation timer disabled")
    v.update({"t0.txt": "LIVE", "t1.txt": "0", "t2.txt": "READY", "tch0": 40, "tch1": 300})
    for command,label in ((1,'OCT +1'),(2,'OCT -1'),(0,'OCT 0')):
        model.run('octBtn','codesup-')
        check(v['octMode.val']==command and v['octBtn.txt']==label,'Octave control state')
        check(model.packets[-1][2:4]==bytes([3,command]),'Octave UART command')
    model.run('testBtn','codesup-')
    check(v['testMode.val']==1 and model.packets[-1][2:4]==bytes([4,1]),'TEST enters four-voice mode')
    model.packets.clear()
    model.run('key0','codesdown-')
    check(not model.packets,'TEST blocks live touch notes')
    model.run()
    check(model.packets[-1][2:4]==bytes([4,1]),'TEST heartbeat')
    model.run('testBtn','codesup-')
    check(v['testMode.val']==0 and model.packets[-1][2:4]==bytes([2,255]),'TEST stop sends all-off')
    model.packets.clear()
    for key in range(KEY_COUNT):
        v[f"t{key+3}.txt"] = "FFF"
    model.run()
    check(all(v[f"cur{k}.val"] == 4095 and v[f"j{k}.val"] == 100 for k in range(KEY_COUNT)), "FFF regression")
    model.run("unitBtn", "codesup-")
    model.run()
    check(all(v[f"ui{k}.txt"] == "4095" for k in range(KEY_COUNT)), "DEC regression")
    for raw,n in [('E',14),('F',15),('10',16)]:
        v['t1.txt']=raw
        model.run()
        check(v['activeTxt.txt']==str(n), '16-key active count display')

    def down(key):
        model.run(f"key{key}", "codesdown-")

    def up(key):
        model.run(f"key{key}", "codesup-")

    def animate():
        model.run("tmAnim")

    def off():
        model.run("offBtn", "codesup-")

    for key in (0, 4, 7):
        down(key)
    animate()
    check(v["chordTxt.txt"] == "C" and v["touchCount.val"] == 3, "C major")
    check(model.packets[-3:] == [bytes.fromhex(x) for x in ("A5 5A 01 00 FE", "A5 5A 01 04 FA", "A5 5A 01 07 F9")], "Independent key ON")
    model.packets.clear()
    model.run()
    check([packet[3] for packet in model.packets] == [0, 4, 7], "Three-key heartbeats")
    down(11)
    animate()
    check(v["chordTxt.txt"] == "Cmaj7" and v["touchCount.val"] == 4, "C major seventh")
    up(4)
    animate()
    check(v["held0.val"] == v["held7.val"] == v["held11.val"] == 1 and v["held4.val"] == 0, "Independent key OFF")
    off()
    for mask, names in chord_table().items():
        for key in range(12):
            if mask & (1 << key):
                down(key)
        animate()
        bass = PC_NAMES[min(key for key in range(12) if mask & (1 << key))]
        check(v["chordTxt.txt"] == display_label(names,bass), f"Chord mask {mask:03X}")
        off()
    for key in (4, 7, 12):
        down(key)
    animate()
    check(v["chordTxt.txt"] == "C", "Octave folding / inversion")
    down(0)
    check(v["tmAnim.en"] == 1, "Press starts animation")
    animate()
    check(v["chordTxt.txt"] == "C" and v["touchCount.val"] == 4, "Duplicate pitch class")
    off()
    for key in (0, 1, 2):
        down(key)
    animate()
    check(v["chordTxt.txt"] == "NOTES", "Unknown note set is not mislabeled")
    off()
    animate()
    check(v["chordTxt.txt"] == "----", "Empty note set")

    # 独立指定复杂音组，确保常见扩展/变音名称未被遗漏。
    for keys,name in [((0,4,7,9),'C6'),((0,3,6,9),'Cdim7'),((0,1,4,7,10),'C7b9'),
                      ((0,2,4,7,10),'C9'),((0,2,3,5,7,10),'Cm11'),
                      ((0,2,4,5,7,9,10),'C13'),((0,3,7,11),'CmMaj7')]:
        off()
        for key in keys: down(key)
        check(name in v['chordTxt.txt'],f'Common family {name}')
    off()
    for key in range(13,KEY_COUNT):
        down(key)
        check(v['chordTxt.txt']==PC_NAMES[key%12], f'New key {key} octave folding')
        up(key)
    frames = []
    model.draws.clear()
    down(0)
    check(v['chordTxt.txt']=='C' and v['ui0.bco']==spec['colors_rgb565']['panel'], 'Immediate down feedback without timer tick')
    frames.append(list(model.draws))
    for level in (1,0):
        model.draws.clear()
        animate()
        check(v['fade0.val']==level, 'Press transition progresses')
        frames.append(list(model.draws))
    check(v['tmAnim.en']==0 and v['held0.val']==1,'Hold remains static after short transition')
    model.draws.clear()
    up(0)
    frames.append(list(model.draws))
    check(v['held0.val']==0 and v['fade0.val']==0 and v['ui0.bco']==spec['colors_rgb565']['key'], 'Immediate release feedback')
    for field, value in (("playMode.val", 0), ("demoMode.val", 1), ("t0.txt", "MIDI")):
        previous = v[field]
        down(0)
        down(4)
        animate()
        v[field] = value
        model.run()
        check(all(v[f"held{k}.val"] == 0 for k in range(KEY_COUNT)), f"Mode releases all: {field}")
        model.packets.clear()
        down(7)
        check(not model.packets, f"Mode blocks ON: {field}")
        v[field] = previous
    down(0)
    down(4)
    animate()
    v.update({"tch0": 0, "tch1": 0})
    model.run()
    check(all(v[f"held{k}.val"] == 0 for k in range(KEY_COUNT)), "No-touch global release")
    inputs = {f"t{k}.txt": v[f"t{k}.txt"] for k in range(KEY_COUNT+3)}
    model.run("demoBtn", "codesup-")
    for _ in range(16*KEY_COUNT):
        animate()
        model.run()
    check(all(v[key] == value for key, value in inputs.items()), "DEMO input isolation")
    return count, frames


def save_preview(spec, frames, output):
    # 从实际执行所得 fill 指令渲染，预览只证明动画源有变化，不等同于屏幕帧率验证。
    background = Image.open(SCREEN / "design/touch_poly/instrument_background.png").convert("RGB")
    from usarthmi.zi_font import ZiFont
    font = ZiFont(SCREEN / "design/v2/dashboard_ascii_32.zi")
    for widget in spec["widgets"]:
        if widget["type"] != "text" or widget.get("hidden"):
            continue
        f = widget["fields"]
        ImageDraw.Draw(background).rectangle((f["x"], f["y"], f["x"]+f["w"]-1, f["y"]+f["h"]-1), fill=rgb(f["bco"]))
        glyph = font.render_text(f["txt"], rgb(f["pco"]))
        background.paste(glyph, (f["x"]+(f["w"]-glyph.width)//2, f["y"]+(f["h"]-glyph.height)//2), glyph)
    images = []
    for commands in frames:
        image = background.copy()
        draw = ImageDraw.Draw(image)
        for command in commands:
            if command.startswith("fill "):
                x, y, width, height, color = map(int, command[5:].split(","))
                draw.rectangle((x, y, x+width-1, y+height-1), fill=rgb(color))
        images.append(image)
    images[0].save(output / "animation_preview.gif", save_all=True, append_images=images[1:], duration=50, loop=0)


def main():
    started = time.perf_counter()
    output = SCREEN / "generated/instrument_touch16"
    report_path = PROJECT / "build/tests/touch_poly_verification.json"
    report = {"status": "failed", "hardware_multi_touch": "unconfirmed", "official_compile": "pending"}
    try:
        with contextlib.redirect_stdout(io.StringIO()):
            spec = generate()
        checks, frames = validate(spec)
        build = build_hmi(SCREEN / "design/touch_poly/controls_manifest.json", output / "instrument_touch16.HMI",
                          SCREEN / "uart_minimal_manual.HMI", SCREEN / "vendor/TJC1060X570_factory.HMI")
        events = validate_saved_events(spec, Path(build["hmi"]))
        save_preview(spec, frames, output)
        rtl = verify_rtl()
        report.update({"status": "passed", "source_assertions": checks, "native_events_checked": events,
                       "native_cfs_crc_valid": build["native_cfs_crc_valid"], "hmi_sha256": build["hmi_sha256"],
                       "hmi": build["hmi"], "rtl_passed": rtl, "animation_preview": str(output / "animation_preview.gif"),
                       "voice_limit": 4, "key_count":KEY_COUNT,"chord_qualities":len(QUALITIES),"chord_masks": len(chord_table())})
    except Exception as error:
        report["error"] = f"{type(error).__name__}: {error}"
        raise
    finally:
        report["elapsed_seconds"] = round(time.perf_counter()-started, 2)
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    print(f"PASS {checks} page checks; {events} saved events; {len(rtl)} RTL tests; {report['elapsed_seconds']}s")
    print(f"HMI: {build['hmi']}\nMulti-finger hardware events UNCONFIRMED; official TFT compile pending")


if __name__ == "__main__":
    main()
