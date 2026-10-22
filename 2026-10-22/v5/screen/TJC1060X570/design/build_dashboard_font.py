"""复现 V2 仪表页的 Consolas ASCII 字库；默认拒绝覆盖现有文件。"""
from __future__ import annotations

import argparse
import hashlib
from importlib.metadata import version
import json
from pathlib import Path
import struct
import sys

from PIL import Image, ImageDraw, ImageFont

DESIGN = Path(__file__).resolve().parent
PROJECT = DESIGN.parents[2]
sys.path.insert(0, str(PROJECT / "third_party/tjc_toolchain"))
from usarthmi.zi_font import ZiFont

EXPECTED_SHA256 = "513d06ee5d5ac8ffa651ccc6fe0b0185767f4ff2833c2fd48c2098b3aa3df4f4"
REFERENCE_FONT_SHA256 = "c6e6ce8119fdd47ec6a5449a08e2d2ad7f41ea03143aae193068ed9fa58eaebc"
# 原先成功加载的 instrument_ascii_32.zi 的 44 字节头。
# 保留官方 V6、GB2312、95 字符与子集字段；只更新名称和数据长度。
OFFICIAL_HEADER = bytes.fromhex(
    "04ff000a02000020a1f7a1fe5f000000061900006b1e00002c000000"
    "ff000101130000005f00000000000000"
)
NAME = b"Dashboard_Consolas32"
ENCODING = b"gb2312"
CELL_WIDTH, CELL_HEIGHT, FONT_SIZE = 16, 32, 29
FIRST_CODEPOINT, LAST_CODEPOINT = 32, 126


def sha256(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def compress_glyph(shades: list[int]) -> bytes:
    """按 ZI V5/V6 的 3 位透明度格式编码，优先压缩透明/不透明连续像素。"""
    data = bytearray([3])
    index = 0
    while index < len(shades):
        current = shades[index]
        if current in (0, 7):
            count = 1
            while (index + count < len(shades)
                   and shades[index + count] == current and count < 31):
                count += 1
            data.append((0x20 if current == 7 else 0) | count)
            index += count
        elif index + 1 < len(shades) and shades[index + 1] in range(1, 7):
            data.append(0xC0 | (current << 3) | shades[index + 1])
            index += 2
        else:
            # mode=2、透明像素数=0，再写一个灰度像素。
            data.append(0x80 | current)
            index += 1
    return bytes(data)


def generate(font_path: Path) -> tuple[bytes, dict]:
    font = ImageFont.truetype(str(font_path), FONT_SIZE)
    glyphs, expected_masks = [], {}
    for codepoint in range(FIRST_CODEPOINT, LAST_CODEPOINT + 1):
        mask = Image.new("L", (CELL_WIDTH, CELL_HEIGHT), 0)
        ImageDraw.Draw(mask).text((0, 2), chr(codepoint), font=font, fill=255)
        # 对应当时的 Pillow 渲染与量化，保留 0..7 的三位透明度。
        shades = [min(7, (int(pixel) * 7 + 127) // 255) for pixel in mask.getdata()]
        glyphs.append((codepoint, compress_glyph(shades)))
        expected_masks[codepoint] = bytes(
            0 if pixel == 0 else 255 if pixel == 7 else pixel * 36 for pixel in shades
        )

    descriptor = NAME + ENCODING
    header = bytearray(OFFICIAL_HEADER)
    header[0x11], header[0x20] = len(descriptor), len(NAME)
    character_count = LAST_CODEPOINT - FIRST_CODEPOINT + 1
    table_size = character_count * 10
    payload_length = sum(len(data) for _, data in glyphs)
    struct.pack_into("<I", header, 0x14, len(descriptor) + table_size + payload_length)

    index_table, data_offset = bytearray(), table_size
    for codepoint, data in glyphs:
        # 数据偏移相对字符表起点，按单字节对齐；字形宽 16，无额外左右留白。
        index_table.extend(struct.pack("<HBBB", codepoint, CELL_WIDTH, 0, 0)
                           + data_offset.to_bytes(3, "little")
                           + len(data).to_bytes(2, "little"))
        data_offset += len(data)
    raw = bytes(header) + descriptor + bytes(index_table) + b"".join(data for _, data in glyphs)

    # 回读的是最终二进制字形，而不是原始 TrueType 字体预览。
    actual = ZiFont.from_bytes(raw)
    assert actual.version == 6 and actual.codepage == 2
    assert actual.character_count == 95 and actual.character_height == CELL_HEIGHT
    assert list(actual.glyphs) == list(range(FIRST_CODEPOINT, LAST_CODEPOINT + 1))
    assert all(glyph.total_width == CELL_WIDTH for glyph in actual.glyphs.values())
    for codepoint, expected in expected_masks.items():
        assert actual._glyph_mask(codepoint).tobytes() == expected, f"字形回读错误：{codepoint}"
    assert actual.measure_text("4095") == (64, 32)

    result_hash = sha256(raw)
    metadata = {
        "sha256": result_hash, "expected_sha256": EXPECTED_SHA256,
        "exact_reproduction": result_hash == EXPECTED_SHA256,
        "format": "ZI v6", "codepage": "GB2312 with ASCII-only95glyphs", "codepage_id": 2,
        "font_family": "Consolas", "source_font": str(font_path.resolve()),
        "source_font_sha256": sha256(font_path.read_bytes()),
        "reference_source_font_sha256": REFERENCE_FONT_SHA256,
        "pillow_version": version("Pillow"), "font_size_px": FONT_SIZE,
        "cell_width_px": CELL_WIDTH, "cell_height_px": CELL_HEIGHT,
        "offset_xy": [0, 2], "antialias_bit_depth": 3,
        "ascii_codepoints": {"start": FIRST_CODEPOINT, "end": LAST_CODEPOINT, "count": 95, "ordered": True},
        "glyph_mask_roundtrip_equal": True, "measure_4095_px": [64, 32],
        "size_bytes": len(raw), "official_header_reference_bytes44": OFFICIAL_HEADER.hex(),
    }
    if result_hash != EXPECTED_SHA256:
        metadata["difference_note"] = (
            "结果与已验证文件不同；请比较 Consolas 源字体 SHA 和 Pillow/FreeType 版本。"
            "字体渲染实现或源字体更新可能改变字形压缩数据，本脚本不会修改既有字体。"
        )
    return raw, metadata


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True, help="新文件输出路径；已存在则停止")
    parser.add_argument("--font", type=Path, default=Path("C:/Windows/Fonts/consola.ttf"))
    parser.add_argument("--preview", action="store_true", help="在输出旁保存最终 ZI 字形 PNG 预览")
    args = parser.parse_args()
    output = args.out.resolve()
    metadata_path = output.with_suffix(".json")
    preview_path = output.with_name(output.stem + "_preview.png")
    for target in [output, metadata_path, *([preview_path] if args.preview else [])]:
        if target.exists():
            parser.error(f"拒绝覆盖已有文件：{target}")
    raw, metadata = generate(args.font.resolve())
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(raw)
    metadata["output"] = str(output)
    if args.preview:
        zi = ZiFont.from_bytes(raw)
        preview = Image.new("RGB", (560, 236), "#0b1622")
        samples = ["LIVE MIDI READY WAIT PLAY", "0123456789  ABCDEF", "000  7FF  FFF  4095",
                   "C4 C#4 D4 D#4 E4 F4 C5", "---  ----  - / %"]
        for row, text in enumerate(samples):
            glyph_image = zi.render_text(text, (218, 245, 242))
            preview.paste(glyph_image, (24, 20 + 40 * row), glyph_image)
        preview.save(preview_path)
        metadata["real_glyph_preview"] = str(preview_path)
    metadata_path.write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(metadata, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
