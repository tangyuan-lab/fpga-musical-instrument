"""生成独立多键事件、按键动画和和弦名称页面；屏幕多指事件能力须实物确认。"""
from collections import defaultdict
from copy import deepcopy
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont
from create_touch_piano import generate as generate_base, branch, packet, V2
from touch16_base import extend, background, geometry, NOTES, KEY_COUNT
from chord_library import PC_NAMES, QUALITIES, chord_table, lookup_code

ROOT = Path(__file__).resolve().parent / "touch_poly"


def rgb(color):
    return ((color >> 11) * 255 // 31, ((color >> 5) & 63) * 255 // 63, (color & 31) * 255 // 31)


def color565(r, g, b):
    return ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3)


def generate():
    generate_base()
    base = Path(__file__).resolve().parent / "touch"
    spec = extend(deepcopy(json.loads((base / "controls_manifest.json").read_text(encoding="utf-8"))))
    widgets = spec["widgets"]
    by_name = {widget["objname"]: widget for widget in widgets}
    colors = spec["colors_rgb565"]
    hotspots = widgets[-KEY_COUNT:]
    del widgets[-KEY_COUNT:]

    def variable(name, initial=0):
        widgets.append({"objname": name, "type": "variable", "fields": {"sta": 0, "val": initial}, "events": {}})

    for key in range(KEY_COUNT):
        variable(f"held{key}")
        variable(f"fade{key}")
    for name in ("animStep", "pcMask", "touchCount", "animBusy", "bassPc"):
        variable(name)
    variable("lastMask", -1)
    variable("lastBass", -1)
    variable("octMode")
    variable("testMode")
    widgets.append({"objname": "chordTxt", "type": "text", "fields": {
        "x": 690, "y": 45, "w": 302, "h": 36, "sta": 1, "font": 0,
        "pco": colors["cyan"], "bco": colors["panel"], "xcen": 1, "ycen": 1,
        "txt": "----", "txt_maxl": 18}, "events": {}})

    def edges(key, color):
        x,y,w,h = geometry(key)
        return [f"fill {x},{y+5},2,{h-10},{color}", f"fill {x+w-2},{y+5},2,{h-10},{color}",
                f"fill {x+3},{y+3},{w-6},2,{color}", f"fill {x+3},{y+h-5},{w-6},2,{color}"]

    def face(key, held):
        sharp = "#" in NOTES[key]
        return [f"ui{key}.bco={colors['panel' if held else 'sharp' if sharp else 'key']}",
                f"ui{key}.pco={colors['cyan' if held else 'amber' if sharp else 'ink']}", f"ref ui{key}"]

    # 保活仅表明页面逻辑仍在保持该键；硬件能否给每个触点产生独立事件另行验证。
    all_off = [packet(2, 255), "heldKey.val=-1", "touchCount.val=0", "pcMask.val=0",
               "tmAnim.en=0", 'touchTxt.txt="---"', 'chordTxt.txt="----"',
               "octMode.val=0", "testMode.val=0", 'octBtn.txt="OCT 0"', 'testBtn.txt="TEST 4"']
    for key in range(KEY_COUNT):
        all_off += [f"held{key}.val=0", f"fade{key}.val=0", *edges(key, colors["border"]), *face(key, False)]
    all_off += ["lastMask.val=-1", "lastBass.val=-1"]
    by_name["offBtn"]["events"]["codesup-"] = all_off
    old_play = by_name["playBtn"]["events"]["codesup-"]
    start = old_play.index("if(playMode.val==1)")
    by_name["playBtn"]["events"]["codesup-"] = [*all_off, *old_play[start:]]
    old_demo = by_name["demoBtn"]["events"]["codesup-"]
    start = old_demo.index("playMode.val=0")
    by_name["demoBtn"]["events"]["codesup-"] = [*all_off, *old_demo[start:]]
    timer = by_name["tm0"]["events"]["codestimer-"]
    start = timer.index("if(heldKey.val>=0)")
    depth, entered, end = 0, False, start
    for end in range(start+1, len(timer)):
        if timer[end] == "{":
            depth += 1
            entered = True
        elif timer[end] in ("}", "}else"):
            depth -= 1
            if entered and depth == 0 and timer[end] == "}":
                break
    heartbeat = []
    for key in range(KEY_COUNT):
        heartbeat += branch(f"held{key}.val==1", [packet(1, key)])
    # 当前坐标只有一组：仅用无任何触摸时的 0,0 兜底全停，不能据此辨认多指位置。
    release = 'playMode.val==0||demoMode.val==1||t0.txt=="MIDI"'
    touch_gate = branch(release, all_off, branch("tch0==0&&tch1==0", all_off, heartbeat))
    timer[start:end+1] = branch("touchCount.val>0", touch_gate)
    timer += branch("testMode.val==1", branch(release, all_off, [packet(4,1)]))
    # 八度变化不发 Note On，持续音保留相位/包络。四频测试独立于 ADC 与外部按键。
    control_gate = 'playMode.val==1&&demoMode.val==0&&t0.txt!="MIDI"'
    def performance_button(name,x,width,label,events):
        widget=deepcopy(by_name["offBtn"])
        widget["objname"]=name
        widget["fields"].update({"x":x,"y":212,"w":width,"h":38,"txt":label,"txt_maxl":8})
        widget["events"]={"codesup-":events}
        widgets.append(widget)
    octave_action=branch("octMode.val==0",[packet(3,1),"octMode.val=1",'octBtn.txt="OCT +1"'],
        branch("octMode.val==1",[packet(3,2),"octMode.val=2",'octBtn.txt="OCT -1"'],
            [packet(3,0),"octMode.val=0",'octBtn.txt="OCT 0"']))
    performance_button("octBtn",144,140,"OCT 0",branch(control_gate+'&&testMode.val==0',octave_action))
    performance_button("testBtn",300,132,"TEST 4",branch(control_gate,
        branch("testMode.val==1",all_off,[*all_off,packet(4,1),"testMode.val=1",
            'testBtn.txt="TEST ON"','chordTxt.txt="TEST Cmaj7"'])))

    recognize = ["touchCount.val=0", "pcMask.val=0", "bassPc.val=-1"]
    for key in range(KEY_COUNT):
        recognize += branch(f"held{key}.val==1", ["touchCount.val++", *branch("bassPc.val==-1", [f"bassPc.val={key%12}"])])
    for pc in range(12):
        condition = "||".join(f"held{k}.val==1" for k in range(pc,KEY_COUNT,12))
        recognize += branch(condition, [f"pcMask.val=pcMask.val+{1 << pc}"])
    lookup = ['chordTxt.txt="NOTES"', *branch("pcMask.val==0", ['chordTxt.txt="----"'])]
    for pc, name in enumerate(PC_NAMES):
        lookup += branch(f"pcMask.val=={1 << pc}", [f'chordTxt.txt="{name}"'])
    lookup += lookup_code(branch)
    recognize += branch("pcMask.val!=lastMask.val||bassPc.val!=lastBass.val", [*lookup,"lastMask.val=pcMask.val","lastBass.val=bassPc.val"])
    recognize += branch("touchCount.val>1", ["covx touchCount.val,touchTxt.txt,0,0"],
                      branch("touchCount.val==0", ['touchTxt.txt="---"']))
    # 官方 click obj,1 激活按下事件；共享字典避免在 32 个按键事件中复制大查表。
    widgets.append({"objname":"chordCalc","type":"text","hidden":True,"fields":{
        "x":0,"y":0,"w":32,"h":32,"sta":1,"font":0,"pco":colors['page'],
        "bco":colors['page'],"xcen":1,"ycen":1,"txt":"","txt_maxl":1},
        "events":{"codesdown-":recognize}})
    animate = ["animBusy.val=0"]
    for key in range(KEY_COUNT):
        # 按下时立即高亮；只运行两个过渡帧，保持期间静态亮起，松开立即恢复。
        # 50 ms 是过渡帧间隔，既不作为发音延迟，也不阻塞按下/松开事件。
        animate += branch(f"held{key}.val==1&&fade{key}.val>0", [f"fade{key}.val--",
            *branch(f"fade{key}.val>0", ["animBusy.val=1", *edges(key,colors['white'])],
                    edges(key,colors['purple' if '#' in NOTES[key] else 'cyan']))])
    animate += branch("animBusy.val==0", ["tmAnim.en=0"])
    widgets.append({"objname": "tmAnim", "type": "timer", "fields": {"tim": 50, "en": 0},
                    "events": {"codestimer-": animate}})
    for key, hotspot in enumerate(hotspots):
        hotspot["events"] = {
            "codesdown-": [f"selected.val={key}", *branch(
                'playMode.val==1&&demoMode.val==0&&t0.txt!="MIDI"&&testMode.val==0',
                [packet(1, key), f"held{key}.val=1", f"fade{key}.val=2", "tmAnim.en=1",
                 *edges(key, colors["cyan"]), *face(key,True), f'touchTxt.txt="{NOTES[key]}"', "click chordCalc,1"])],
            "codesup-": branch(f"held{key}.val==1", [packet(0, key), f"held{key}.val=0", f"fade{key}.val=0",
                *edges(key, colors["border"]), *face(key,False), "click chordCalc,1"])}
    widgets.extend(hotspots)
    hidden = [widget["objname"] for widget in widgets if widget.get("hidden")]
    spec["page_events"] = {"codesloadend-": [*[f"vis {name},0" for name in hidden], *all_off,
                                            "tm0.en=1", "tmAnim.en=0"],
                           "codesup-": all_off, "codesunload-": all_off}
    spec.update({"version": "touch16-event-animation-chords-4", "font_resource": "../v2/dashboard_ascii_32.zi",
                 "runtime_limits": "Up to four sounding FPGA voices. Screen multi-pointer events NOT verified; tch0/tch1 provide only one coordinate pair.",
                 "multi_touch_hardware_status": "unconfirmed; label reported as TJC1060X570_011 without touch suffix",
                 "animation_ms": 50, "chord_recognition": "exact pitch-class sets; bass-root preference; octave folding; /+ indicates further candidates",
                 "features": ["16 independent key event states", "immediate down/up visual response", "100ms press transition then static highlight",
                              f"{len(QUALITIES)} chord qualities across 12 roots", "ADC inputs preserved",
                              "continuous-note octave transpose", "four-frequency FPGA test mode"]})
    assert len(widgets) < 255
    ROOT.mkdir(parents=True, exist_ok=True)
    (ROOT / "controls_manifest.json").write_text(json.dumps(spec, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    (ROOT / "chord_catalog.json").write_text(json.dumps({"qualities": QUALITIES, "pitch_class_candidates": chord_table()}, ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    image = background(base / "instrument_background.png",colors,rgb)
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((680, 19, 1000, 88), radius=12, fill=rgb(colors["panel"]), outline=rgb(colors["border"]))
    font = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 13)
    draw.text((696, 24), "当前音符 / 和弦", font=font, fill=rgb(colors["muted"]))
    draw.rectangle((140, 211, 609, 249), fill=rgb(colors["page"]))
    draw.text((444, 219), "按下高亮/松开复原", font=font, fill=rgb(colors["muted"]))
    image.save(ROOT / "instrument_background.png")
    return spec


if __name__ == "__main__":
    spec = generate()
    print(f"Generated {len(spec['widgets'])} controls; animation=50ms; multi-touch hardware UNCONFIRMED")
