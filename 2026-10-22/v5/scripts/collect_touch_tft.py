"""收集官方编辑器导出的数值修正版 TFT，并校验型号、尺寸和 CRC。"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import sys

PROJECT = Path(__file__).resolve().parents[1]
TOOLCHAIN = PROJECT / "third_party/tjc_toolchain"
sys.path.insert(0, str(TOOLCHAIN))
from usarthmi.tft_checksum import calculate_tft_checksum
from usarthmi.tft_toolchain import inspect_tft


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--file", type=Path, help="指定官方导出的 TFT；默认扫描官方 work 目录")
    parser.add_argument("--project", choices=['instrument_workstation','instrument_touch16','instrument_touch_press','instrument_touch_poly','instrument_touch_hexfix'],default='instrument_touch16')
    args = parser.parse_args()
    project_directory = 'instrument_workstation_fixed' if args.project == 'instrument_workstation' else args.project
    output = PROJECT / "screen/TJC1060X570/generated" / project_directory
    hmi = output / (args.project+".HMI")
    target = hmi.with_suffix(".tft")
    work = Path(os.environ["APPDATA"]) / "USART HMI/work"
    candidates = [args.file] if args.file else list(work.glob(f"*/output/{target.name}"))
    candidates = [path for path in candidates if path.is_file()]
    if not candidates:
        print(f"PENDING: official export {target.name} not found; no TFT copied.")
        return 2
    source = max(candidates, key=lambda path: path.stat().st_mtime)
    # 旧工程即使 CRC 正确也不能冒充此版；名称和时间是收集门槛，不是字节码语义证明。
    if source.stem.lower() != hmi.stem.lower() or source.stat().st_mtime < hmi.stat().st_mtime:
        raise ValueError("Wrong project name or stale TFT; compile/export the current HMI first")
    info = inspect_tft(source)
    header = info["parsed"]["Header1"]
    if info["model"] != "TJC1060X570_011" or (
        header["lcd_resolution_x"], header["lcd_resolution_y"], header["ui_orientation"]
    ) != (1024, 600, 0):
        raise ValueError("TFT model, resolution or orientation mismatch")
    raw = source.read_bytes()
    if header["file_size"] != len(raw):
        raise ValueError("TFT header size mismatch")
    stored = int.from_bytes(raw[-4:], "little")
    calculated = calculate_tft_checksum(raw, series=header["model_series"])
    if stored != calculated:
        raise ValueError("TFT CRC mismatch")
    target.write_bytes(raw)
    report = {"status": "artifact_checks_passed", "source_export": str(source.resolve()),
              "tft": str(target), "sha256": hashlib.sha256(raw).hexdigest(),
              "file_size": len(raw), "model": info["model"], "editor_version": info["editor_version"],
              "checksum_valid": True, "checksum": f"0x{stored:08X}",
              "source_binding": "project filename and timestamps only; compiled event semantics not decoded",
              "hardware_validation": "pending"}
    (output / "tft_collection.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n",
                                                encoding="utf-8")
    print(f"PASS TFT model/1024x600/CRC; {len(raw)} bytes\n{target}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
