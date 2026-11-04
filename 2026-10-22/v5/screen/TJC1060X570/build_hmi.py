"""从已保存的官方模板批量生成页面，调用本机官方编译器；不操作串口。"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys

SCREEN = Path(__file__).resolve().parent
PROJECT = SCREEN.parents[1]
TOOLCHAIN = PROJECT / "third_party/tjc_toolchain"
sys.path.insert(0, str(TOOLCHAIN))

from tools.official_gui_host_select import run_probe
from usarthmi.editor import _replace_hmi_entry
from usarthmi.hmi_inspect import inspect_hmi
from usarthmi.page_format import parse_page_data
from usarthmi.tft_checksum import inspect_tft_checksum
from usarthmi.tft_toolchain import inspect_tft


def entry_data(path: Path, name: str) -> bytes:
    entry = next(e for e in inspect_hmi(path).entries if e.name == name)
    return path.read_bytes()[entry.data_offset:entry.data_offset + entry.length]


def build(full: bool, install: Path, prepare_only: bool = False) -> dict:
    if prepare_only:
        raise RuntimeError("离线页面写入与 USART HMI 1.68.1 不兼容，已停用。请打开 uart_minimal_manual.HMI，在官方编辑器内修改、保存和编译。")
    name = "instrument_full" if full else "uart_minimal"
    out = SCREEN / "generated" / name
    out.mkdir(parents=True, exist_ok=True)
    hmi, tft = out / f"{name}.HMI", out / f"{name}.TFT"
    seed = SCREEN / "vendor/instrument_display_seed.HMI"
    if not seed.is_file():
        raise FileNotFoundError(f"先保存并关闭官方编辑器，保留原始模板：{seed}")
    shutil.copy2(seed, hmi)

    # 保留模板的全局变量、背光和上电通知；仅替换 UART 初始化设置。
    program = entry_data(hmi, "Program.s").decode("gbk")
    lines = []
    for line in program.splitlines():
        stripped = line.strip()
        if stripped.startswith(("baud=", "bauds=")):
            lines.append("bauds=115200//匹配 FPGA：115200、8N1，保存上电波特率")
        elif stripped.startswith("bkcmd="):
            continue
        elif stripped.startswith("page "):
            lines.append("bkcmd=0//显示专用；最小页面中不存在的控件不产生错误回包")
            lines.append(line)
        else:
            lines.append(line)
    program = "\r\n".join(lines) + "\r\n"
    inspection = inspect_hmi(hmi)
    hmi.write_bytes(_replace_hmi_entry(hmi.read_bytes(), inspection.entries,
                                      "Program.s", program.encode("gbk")))
    (out / "Program.s").write_text(program, encoding="utf-8")

    manifest = json.loads((SCREEN / "design/controls_manifest.json").read_text(encoding="utf-8"))
    controls = manifest["dynamic_text_controls"] if full else manifest["dynamic_text_controls"][:1]
    macro = ["select-page\t0\t0.pa"]
    for index, control in enumerate(controls):
        macro.append("select-object\t1" if index == 0 else "create-control\ttext")
        # 宽高先设置，坐标后设置；同时明确写入隐藏端点以避免触摸矩形残留。
        for field in ("objname", "sta", "w", "h", "x", "y", "font", "pco", "bco",
                      "xcen", "ycen", "txt_maxl", "txt"):
            macro.append(f"patch-field\t{field}\t{control[field]}")
        macro.extend((f"patch-field\tendx\t{control['x'] + control['w'] - 1}",
                      f"patch-field\tendy\t{control['y'] + control['h'] - 1}"))
    macro.extend(("save", "dump-page", f"compile\t{tft}"))
    (out / "actions.tsv").write_text("\n".join(macro) + "\n", encoding="utf-8")
    if prepare_only:
        page = parse_page_data(entry_data(hmi, "0.pa"))
        prototype = next(b for b in page.blocks if b.objname == "t0")
        for index, control in enumerate(controls):
            block = prototype if index == 0 else prototype.clone()
            block.set_int("id", index + 1)
            for field, value in control.items():
                if field in ("objname", "txt"):
                    block.set_string(field, value)
                elif field in ("x", "y", "w", "h", "font", "sta", "pco", "bco", "xcen", "ycen", "txt_maxl"):
                    block.set_int(field, value)
            block.set_int("endx", control["x"] + control["w"] - 1)
            block.set_int("endy", control["y"] + control["h"] - 1)
            if index:
                page.blocks.append(block)
        inspection = inspect_hmi(hmi)
        hmi.write_bytes(_replace_hmi_entry(hmi.read_bytes(), inspection.entries, "0.pa", page.serialize()))
        return {"hmi": str(hmi), "control_count": len(controls), "compiled": False,
                "next_step": "官方编辑器打开、保存并编译；需验证原生格式读取"}
    # 官方文件不修改，运行副本放在项目目录；构建结果必须以编译报告为准。
    os.environ["USARTHMI_HEADLESS_RUNTIME_ROOT"] = str(PROJECT / "build/tools/tjc-runtime")
    result = run_probe(hmi_path=hmi, page_index=0, page_resource="0.pa", object_index=1,
                       report_path=out / "official_compile.json", macro_lines=macro,
                       compile_output_path=tft, force_save=True, force_page_dump=True,
                       install_dir=install)
    (out / "host_result.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    report = result.get("report_json") or {}
    if report.get("status") != "ok" or report.get("saved_project") != 1 or report.get("managed_compile_ok") != 1:
        raise RuntimeError(f"官方编译未通过，查看 {out / 'host_result.json'}：{report.get('error')}")
    actual_program = entry_data(hmi, "Program.s").decode("gbk")
    for command in ("bauds=115200", "recmod=0", "bkcmd=0"):
        if command not in actual_program:
            raise RuntimeError(f"官方保存后初始化命令丢失：{command}")
    page = parse_page_data(entry_data(hmi, "0.pa"))
    actual = {b.objname: b for b in page.blocks}
    mismatches = []
    rectangles = []
    for expected in controls:
        block = actual.get(expected["objname"])
        if block is None:
            raise RuntimeError(f"官方保存后控件丢失：{expected['objname']}")
        for key in ("x", "y", "w", "h", "font", "sta", "pco", "bco", "txt_maxl"):
            value = int.from_bytes(block.get_field(key).value, "little")
            if value != expected[key]:
                mismatches.append([expected["objname"], key, value, expected[key]])
        for key, value in (("endx", expected["x"] + expected["w"] - 1),
                           ("endy", expected["y"] + expected["h"] - 1)):
            if int.from_bytes(block.get_field(key).value, "little") != value:
                mismatches.append([expected["objname"], key])
        if block.get_field("txt").value.decode("ascii") != expected["txt"]:
            mismatches.append([expected["objname"], "txt"])
        rectangles.append((expected["x"], expected["y"], expected["w"], expected["h"]))
    collisions = []
    for i, (x, y, w, h) in enumerate(rectangles):
        if x < 0 or y < 0 or x + w > 1024 or y + h > 600:
            mismatches.append([i, "out_of_bounds"])
        for j, (x2, y2, w2, h2) in enumerate(rectangles[:i]):
            if x < x2 + w2 and x2 < x + w and y < y2 + h2 and y2 < y + h:
                collisions.append([j, i])
    checksum = inspect_tft_checksum(tft)
    evidence = {"model": manifest["model"], "hmi": str(hmi), "tft": str(tft),
                "control_count": len(controls), "geometry_mismatches": mismatches,
                "control_collisions": collisions, "checksum": checksum,
                "tft_inspection": inspect_tft(tft),
                "sha256": hashlib.sha256(tft.read_bytes()).hexdigest(),
                "hardware_verified": False, "uploaded": False}
    (out / "build_manifest.json").write_text(json.dumps(evidence, ensure_ascii=False, indent=2), encoding="utf-8")
    if mismatches or collisions or not checksum["valid"]:
        raise RuntimeError(f"构建校验未通过，查看 {out / 'build_manifest.json'}")
    return {k: evidence[k] for k in ("hmi", "tft", "control_count", "sha256", "hardware_verified")}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--full", action="store_true", help="完整页面；建议最小页面实物验证通过后使用")
    parser.add_argument("--prepare-only", action="store_true", help="只生成 HMI，使用官方编辑器编译")
    parser.add_argument("--install-dir", type=Path, default=Path(r"C:\Program Files (x86)\USART HMI"))
    args = parser.parse_args()
    print(json.dumps(build(args.full, args.install_dir, args.prepare_only), ensure_ascii=False, indent=2))
