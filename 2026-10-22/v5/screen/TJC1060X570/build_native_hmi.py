"""批量修改 HMI 页面源，刷新原生页面及容器校验；TFT 由官方编辑器编译。"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

SCREEN = Path(__file__).resolve().parent
PROJECT = SCREEN.parents[1]
sys.path.insert(0, str(PROJECT / "third_party/tjc_toolchain"))
from usarthmi.editor import _replace_hmi_entry
from usarthmi.hmi_cfs import compute_native_cfs_crc, find_native_cfs_record, parse_native_cfs_table
from usarthmi.hmi_inspect import inspect_hmi
from usarthmi.hmi_pagesafe import inspect_page_safe_status, refresh_page_safe_header
from usarthmi.page_format import parse_page_data


def native_entry(raw: bytes, name: str) -> bytes:
    # 官方 CFS 指向当前版本；文件开头的旧目录可能指向备份页面。
    record = find_native_cfs_record(parse_native_cfs_table(raw), name)
    if record is None:
        raise ValueError(f"原生目录缺少 {name}")
    return raw[record.data_offset:record.data_offset + record.length]


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def update_entry(path: Path, name: str, data: bytes) -> None:
    # 同时更新旧目录和原生 CFS 指针，避免两种读取方式得到不同数据。
    raw = path.read_bytes()
    path.write_bytes(_replace_hmi_entry(raw, inspect_hmi(path).entries, name, data))
    if native_entry(path.read_bytes(), name) != data:
        raise RuntimeError(f"原生目录更新失败：{name}")


def normalize_program(raw: bytes) -> bytes:
    # 保留全局变量、背光和上电通知的原始中文注释，去重串口初始化。
    text = raw.decode("gbk").replace("\r\r\n", "\r\n")
    lines, inserted = [], False
    for line in text.splitlines():
        if re.match(r"\s*(?:baud|bauds|recmod|bkcmd)\s*=", line):
            continue
        if re.match(r"\s*page\s+0\b", line):
            lines.extend(["//匹配 FPGA：115200、8N1、标准字符串协议，关闭执行结果回传。",
                          "bauds=115200", "recmod=0", "bkcmd=0"])
            inserted = True
        lines.append(line)
    if not inserted:
        raise ValueError("初始化脚本中没有 page 0，停止生成")
    return ("\r\n".join(lines) + "\r\n").encode("gbk")


def generate(source: Path, minimal: bool) -> dict:
    original = source.read_bytes()
    source_page = native_entry(original, "0.pa")
    if not inspect_page_safe_status(source_page).safe_ok:
        raise ValueError("模板页面校验失败，请使用官方保存的工程")
    page = parse_page_data(source_page)
    if page.hidden_gap_after_table(source_page) or page.post_block_tail(source_page):
        raise ValueError("模板含额外原生数据，当前生成器不能处理")
    if len(page.blocks) != 2 or page.blocks[1].objname != "t0":
        raise ValueError("模板必须仅有 page0 和 t0")
    prototype = page.blocks[1].clone()
    spec = json.loads((SCREEN / "design/controls_manifest.json").read_text(encoding="utf-8"))
    controls = spec["dynamic_text_controls"][:1] if minimal else spec["dynamic_text_controls"]
    page.blocks = page.blocks[:1]
    for index, control in enumerate(controls):
        block = prototype.clone()
        block.set_int("id", index + 1)
        for field in ("objname", "txt"):
            block.set_string(field, control[field])
        for field in ("x", "y", "w", "h", "sta", "font", "pco", "bco", "xcen", "ycen", "txt_maxl"):
            block.set_int(field, control[field])
        block.set_int("endx", control["x"] + control["w"] - 1)
        block.set_int("endy", control["y"] + control["h"] - 1)
        # 仅显示数据：不复制模板可能存在的触摸动作。
        block.set_event("codesdown-", [])
        block.set_event("codesup-", [])
        page.blocks.append(block)
    serialized = page.serialize()
    serialized = refresh_page_safe_header(serialized, datasize=len(serialized),
                                          datainformation_qyt=len(page.blocks))
    name = "uart_minimal" if minimal else "instrument_full"
    out = SCREEN / "generated" / name
    out.mkdir(parents=True, exist_ok=True)
    hmi = out / f"{name}.HMI"
    if hmi.resolve() == source.resolve():
        raise ValueError("输出路径不能覆盖模板")
    hmi.write_bytes(original)
    update_entry(hmi, "0.pa", serialized)
    program = normalize_program(native_entry(original, "Program.s"))
    update_entry(hmi, "Program.s", program)
    (out / "Program.s").write_text(program.decode("gbk"), encoding="utf-8")
    (out / "page0.pa").write_bytes(serialized)

    # 回读原生目录，验证位置、隐藏端点、容量和初值与源码清单一致。
    actual_raw = hmi.read_bytes()
    actual_page = native_entry(actual_raw, "0.pa")
    blocks = parse_page_data(actual_page).blocks
    for expected, block in zip(controls, blocks[1:], strict=True):
        assert block.objname == expected["objname"]
        assert block.get_field("txt").value.decode("ascii") == expected["txt"]
        for field in ("x", "y", "w", "h", "sta", "font", "pco", "bco", "txt_maxl"):
            assert int.from_bytes(block.get_field(field).value, "little") == expected[field]
        for field, end in (("endx", expected["x"] + expected["w"] - 1),
                           ("endy", expected["y"] + expected["h"] - 1)):
            assert int.from_bytes(block.get_field(field).value, "little") == end
        assert len(expected["txt"]) <= expected["txt_maxl"]
        assert 0 <= expected["x"] < expected["x"] + expected["w"] <= 1024
        assert 0 <= expected["y"] < expected["y"] + expected["h"] <= 600
    for i, a in enumerate(controls):
        for b in controls[:i]:
            assert not (a["x"] < b["x"] + b["w"] and b["x"] < a["x"] + a["w"]
                        and a["y"] < b["y"] + b["h"] and b["y"] < a["y"] + a["h"])
    resources = {}
    for resource in ("main.HMI", "0.is", "0.i", "0.zi"):
        before, after = native_entry(original, resource), native_entry(actual_raw, resource)
        assert before == after, f"资源被意外修改：{resource}"
        resources[resource] = digest(after)
    table = parse_native_cfs_table(actual_raw)
    safe = inspect_page_safe_status(actual_page)
    assert safe.safe_ok and table.trailing_crc == compute_native_cfs_crc(actual_raw)
    report = {"source": str(source), "source_sha256": digest(original), "hmi": str(hmi),
              "hmi_sha256": digest(actual_raw), "model": spec["model"],
              "controls": [c["objname"] for c in controls], "page_safe": safe.to_dict(),
              "native_cfs_crc_valid": True, "geometry_valid": True, "collisions": 0,
              "unchanged_resource_sha256": resources, "compiled": False,
              "official_editor_open_verified": False, "hardware_verified": False}
    (out / "build_manifest.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=SCREEN / "uart_minimal_manual.HMI")
    parser.add_argument("--minimal", action="store_true")
    args = parser.parse_args()
    print(json.dumps(generate(args.source.resolve(), args.minimal), ensure_ascii=False, indent=2))
