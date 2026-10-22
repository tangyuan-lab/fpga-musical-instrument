"""直接生成第二版串口屏 HMI 源；TFT 仍由官方 USART HMI 编译。"""
from __future__ import annotations

import argparse
from io import BytesIO
import json
from pathlib import Path
import re
import sys

from PIL import Image

SCREEN = Path(__file__).resolve().parent
PROJECT = SCREEN.parents[1]
sys.path.insert(0, str(PROJECT / "third_party/tjc_toolchain"))
from build_native_hmi import digest, native_entry, normalize_program, update_entry
from usarthmi.hmi_cfs import compute_native_cfs_crc, parse_native_cfs_table
from usarthmi.hmi_pagesafe import inspect_page_safe_status, refresh_page_safe_header
from usarthmi.page_format import parse_page_data
from usarthmi.tft_images import compile_hmi_picture_resource
from usarthmi.zi_font import ZiFont


PAGE_EVENTS = {"codesload-", "codesloadend-", "codesdown-", "codesup-", "codesunload-"}
WIDGET_EVENTS = {"codesdown-", "codesup-", "codestimer-", "codesslide-"}
VISUAL_TYPES = {"text", "progress", "hotspot"}


def clear_events(block) -> None:
    # 工厂模板有演示逻辑，必须完全移除，防止引用不存在的页面和资源。
    # 保留官方事件槽及顺序，只清空其中的语句。
    prefixes = [token.rsplit("-", 1)[0] + "-" for token in block.event_tokens
                if re.fullmatch(r"codes[A-Za-z]+-\d+", token)]
    for prefix in dict.fromkeys(prefixes):
        block.set_event(prefix, [])


def apply_events(block, events: dict, allowed: set[str]) -> None:
    for prefix, lines in events.items():
        if prefix not in allowed or not isinstance(lines, list) or any(not isinstance(line, str) for line in lines):
            raise ValueError(f"无效事件：{block.objname}.{prefix}")
        block.set_event(prefix, lines)


def set_field(block, name: str, value) -> None:
    field = block.get_field(name)
    if field is None:
        raise ValueError(f"模板未定义属性：{block.objname}.{name}")
    if isinstance(value, str):
        if name not in {"objname", "txt"}:
            raise ValueError(f"属性不是字符串：{block.objname}.{name}")
        block.set_string(name, value, encoding="gbk")
        return
    if not isinstance(value, int):
        raise ValueError(f"属性必须为整数：{block.objname}.{name}")
    width = len(field.value)
    # val 是有符号 32 位数；原生字段仍保存其小端补码。
    if value < 0 and name == "val" and width == 4:
        if value < -0x80000000:
            raise ValueError(f"数值超出 int32：{block.objname}.{name}")
        value &= 0xFFFFFFFF
    if value < 0 or value >= (1 << (width * 8)):
        raise ValueError(f"属性超出 {width} 字节容量：{block.objname}.{name}={value}")
    block.set_int(name, value, width=width)


def block_int(block, name: str) -> int:
    field = block.get_field(name)
    if field is None:
        raise ValueError(f"缺少属性：{block.objname}.{name}")
    return int.from_bytes(field.value, "little")


def find_prototype(raw: bytes, page_name: str, type_code: str):
    page = parse_page_data(native_entry(raw, page_name))
    return next(block.clone() for block in page.blocks if block.type_code == type_code)


def generate(manifest_path: Path, output_path: Path, source_path: Path, factory_path: Path) -> dict:
    spec = json.loads(manifest_path.read_text(encoding="utf-8"))
    original, factory = source_path.read_bytes(), factory_path.read_bytes()
    original_page = native_entry(original, "0.pa")
    if not inspect_page_safe_status(original_page).safe_ok:
        raise ValueError("模板页面校验失败，请使用官方保存的工程")
    page = parse_page_data(original_page)
    if page.hidden_gap_after_table(original_page) or page.post_block_tail(original_page):
        raise ValueError("模板存在额外原生数据，停止以免丢失内容")
    if len(page.blocks) != 2 or page.blocks[1].objname != "t0":
        raise ValueError("模板必须仅包含 page0 和 t0")
    prototypes = {
        "text": page.blocks[1].clone(),
        "timer": find_prototype(factory, "13.pa", "3"),
        "variable": find_prototype(factory, "17.pa", "4"),
        "progress": find_prototype(factory, "13.pa", "j"),
        "hotspot": find_prototype(factory, "17.pa", "m"),
    }
    widgets = spec["widgets"]
    if len(widgets) > 254:
        raise ValueError("控件数量超出单字节 ID 范围")
    names = [widget["objname"] for widget in widgets]
    required=spec.get('legacy_text_controls',16)
    if not isinstance(required,int) or not 1<=required<=16:raise ValueError('协议文本控件数量无效')
    if names[:required] != [f"t{index}" for index in range(required)]:
        raise ValueError("前 16 个控件必须是 FPGA 协议 t0..t15")
    if len(set(names)) != len(names) or "page0" in names:
        raise ValueError("控件名称重复或与页面名冲突")
    width, height = spec["page"]["width"], spec["page"]["height"]
    if (width, height) != (1024, 600):
        raise ValueError("当前模板只支持 1024×600 横屏")

    page.blocks = page.blocks[:1]
    page.blocks[0].set_string("objname", "page0")
    page.blocks[0].set_int("sta", 2)
    page.blocks[0].set_int("pic", 0)
    clear_events(page.blocks[0])
    apply_events(page.blocks[0], spec.get("page_events", {}), PAGE_EVENTS)
    for index, widget in enumerate(widgets, 1):
        kind, name = widget["type"], widget["objname"]
        if kind not in prototypes or not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]{0,13}", name):
            raise ValueError(f"不支持的控件：{kind}/{name}")
        if index <= required and kind != "text":
            raise ValueError("FPGA t0..t15 必须保留文本类型")
        block = prototypes[kind].clone()
        block.set_string("objname", name)
        block.set_int("id", index, width=1)
        clear_events(block)
        # 模板的外部字库和图片编号不能带入新工程。
        if block.get_field("font"):
            block.set_int("font", 0)
        for field in ("pic", "picc", "bpic", "ppic"):
            if block.get_field(field):
                block.set_int(field, 65535)
        if block.get_field("lockobj"):
            block.set_int("lockobj", 0)
        for field, value in widget.get("fields", {}).items():
            if field in {"id", "objname", "type"}:
                raise ValueError(f"身份属性不能由清单覆盖：{name}.{field}")
            set_field(block, field, value)
        if kind in VISUAL_TYPES:
            x, y, w, h = (block_int(block, field) for field in ("x", "y", "w", "h"))
            if not (0 <= x < x + w <= width and 0 <= y < y + h <= height):
                raise ValueError(f"控件越界：{name}")
            block.set_int("endx", x + w - 1, width=2)
            block.set_int("endy", y + h - 1, width=2)
        if block.get_field("font") and block_int(block, "font") != 0:
            raise ValueError(f"仅保留 font0：{name}")
        if block.get_field("txt"):
            if len(block.get_field("txt").value) > block_int(block, "txt_maxl"):
                raise ValueError(f"初始字符串超出容量：{name}")
        if kind == "progress" and block_int(block, "val") > 100:
            raise ValueError(f"进度条值超出 0..100：{name}")
        if kind == "timer" and not 50 <= block_int(block, "tim") <= 65535:
            raise ValueError(f"定时器周期超出 50..65535 ms：{name}")
        apply_events(block, widget.get("events", {}), WIDGET_EVENTS)
        page.blocks.append(block)

    serialized = page.serialize()
    serialized = refresh_page_safe_header(serialized, datasize=len(serialized), datainformation_qyt=len(page.blocks))
    background = manifest_path.parent / "instrument_background.png"
    with Image.open(background) as image:
        if image.size != (width, height):
            raise ValueError("背景图片尺寸必须等于页面尺寸")
    picture_info, picture_data, source_data = compile_hmi_picture_resource(background, 0)
    if output_path.resolve() == source_path.resolve():
        raise ValueError("输出不能覆盖原始模板")
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_bytes(original)
    update_entry(output_path, "0.pa", serialized)
    program = normalize_program(native_entry(original, "Program.s"))
    update_entry(output_path, "Program.s", program)
    update_entry(output_path, "0.i", picture_data)
    update_entry(output_path, "0.is", source_data)
    font_path = manifest_path.parent / spec["font_resource"] if spec.get("font_resource") else None
    font_data = font_path.read_bytes() if font_path else native_entry(original, "0.zi")
    parsed_font = ZiFont.from_bytes(font_data)
    if parsed_font.character_height != 32 or parsed_font.measure_text("4095")[0] > 64:
        raise ValueError("数字字库必须为 32 像素高，四位十进制数必须能放进 64 像素")
    for char in " !\"#()-/0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_":
        if ord(char) not in parsed_font.glyphs:
            raise ValueError(f"字库缺少协议字符：{char!r}")
    if font_path:
        update_entry(output_path, "0.zi", font_data)

    # 回读实际 CFS 指向的数据；旧目录只作为兼容镜像，不作为验证依据。
    actual = output_path.read_bytes()
    actual_page = native_entry(actual, "0.pa")
    blocks = parse_page_data(actual_page).blocks
    if [block.objname for block in blocks] != ["page0", *names]:
        raise RuntimeError("控件回读顺序错误")
    if [block_int(block, "id") for block in blocks] != list(range(len(blocks))):
        raise RuntimeError("控件 ID 回读错误")
    for expected, block in zip(widgets, blocks[1:], strict=True):
        for field, value in expected.get("fields", {}).items():
            actual_field = block.get_field(field).value
            expected_field = value.encode("gbk") if isinstance(value, str) else (value & ((1 << (len(actual_field) * 8)) - 1)).to_bytes(len(actual_field), "little")
            if actual_field != expected_field:
                raise RuntimeError(f"属性回读不符：{block.objname}.{field}")
    if native_entry(actual, "0.i") != picture_data or native_entry(actual, "0.is") != source_data:
        raise RuntimeError("背景资源回读错误")
    # 编码后的 JPEG 允许补齐高度至 16 的倍数，逻辑页面保持 1024×600。
    block_offset = int.from_bytes(picture_data[8:12], "little")
    with Image.open(BytesIO(picture_data[block_offset + 20:])) as compiled_image:
        compiled_dimensions = compiled_image.size
        compiled_image.verify()
    preserved = {}
    for name in ("main.HMI",):
        before, after = native_entry(original, name), native_entry(actual, name)
        if before != after:
            raise RuntimeError(f"型号或字体资源被修改：{name}")
        preserved[name] = digest(after)
    if native_entry(actual, "0.zi") != font_data:
        raise RuntimeError("字库资源回读错误")
    safe = inspect_page_safe_status(actual_page)
    table = parse_native_cfs_table(actual)
    if not safe.safe_ok or table.trailing_crc != compute_native_cfs_crc(actual):
        raise RuntimeError("页面或原生 CFS 校验失败")
    report = {
        "source": str(source_path), "source_sha256": digest(original),
        "factory_prototypes": str(factory_path), "factory_sha256": digest(factory),
        "manifest": str(manifest_path), "hmi": str(output_path), "hmi_sha256": digest(actual),
        "model": spec.get("model", "TJC1060X570_011"),
        "controls": names, "object_count": len(blocks), "page_safe": safe.to_dict(),
        "native_cfs_crc_valid": True, "geometry_valid": True,
        "preserved_resource_sha256": preserved,
        "font": {"source": str(font_path) if font_path else "original font0",
                 "sha256": digest(font_data), "name": parsed_font.font_name,
                 "height": parsed_font.character_height, "glyphs": parsed_font.character_count,
                 "four_digit_width": parsed_font.measure_text("4095")[0]},
        "picture": picture_info.to_dict(), "compiled_picture_dimensions": compiled_dimensions,
        "compiled": False, "official_editor_compile_status": "pending",
        "hardware_validation_status": "pending",
    }
    (output_path.parent / "page0.pa").write_bytes(actual_page)
    (output_path.parent / "Program.s").write_text(program.decode("gbk"), encoding="utf-8")
    (output_path.parent / "build_manifest.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=SCREEN / "design/v2/controls_manifest.json")
    parser.add_argument("--source", type=Path, default=SCREEN / "uart_minimal_manual.HMI")
    parser.add_argument("--factory", type=Path, default=SCREEN / "vendor/TJC1060X570_factory.HMI")
    parser.add_argument("--output", type=Path, default=SCREEN / "generated/instrument_v2/instrument_v2.HMI")
    args = parser.parse_args()
    print(json.dumps(generate(args.manifest.resolve(), args.output.resolve(), args.source.resolve(), args.factory.resolve()), ensure_ascii=False, indent=2))
