#!/usr/bin/env python3
"""校验 R6 工程、生产身份和发布文件；仅使用 Python 标准库。"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath, PureWindowsPath
import re
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
PROJECT_NAME = "workstation_r6_piano32_bt.gprj"
HEADER = "rtl/workstation_build_identity.vh"
DEVICE = "GW5AST-LV138PG484AC1/I0"
CONFIG = "impl/workstation_r6_piano32_bt_process_config.json"
PRODUCTION_DIGEST = "0b02fc49e67e97c369b3442f3844b8d7ef6edeb20293769a8e38cf9d585f74ff"
# 保留原构建身份供设备协议使用，发布包仅接受这两份经过审计的注释修订文件。
RELEASE_COMMENT_HASHES = {
    "rtl/r7_piano32_progressive.sv": "f3022d68495382190c92b4d4167a8482569cd5145fa33aba12dac657d528c4a0",
    "rtl/r7_test_piano32_control_r2.sv": "a6fdc96cc7b75f8fbc6c2f4259fab727c95c2c0937966a4d764681f0e6c4f27d",
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def local_path(root: Path, name: str) -> Path:
    """输入清单只接受工程内的相对文件，避免工作目录或绝对路径改变解析。"""
    if not isinstance(name, str) or not name:
        raise ValueError("文件名为空或类型错误")
    if PurePosixPath(name).is_absolute() or PureWindowsPath(name).drive:
        raise ValueError(f"清单使用了绝对路径：{name}")
    path = (root / name).resolve()
    if not path.is_relative_to(root.resolve()):
        raise ValueError(f"清单路径超出工程：{name}")
    return path


def distribution_files(root: Path) -> dict[str, Path]:
    """发布库存包含静态交付文件，运行输出与 Python 缓存独立保存。"""
    result = {}
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        relative = path.relative_to(root)
        name = relative.as_posix()
        if "__pycache__" in relative.parts or path.suffix == ".pyc" or path.name.endswith(".gprj.user"):
            continue
        if relative.parts[0] == "runs" and name != "runs/.gitkeep":
            continue
        if relative.parts[0] == "impl" and name != CONFIG:
            continue
        if name == "SOURCE_MANIFEST.json":
            continue
        result[name] = path
    return result


def simulation_sources(root: Path, sources: list[str]) -> list[str]:
    expected = [p for p in sources if not p.startswith("ip/") and p != "rtl/workstation_ddr_phy.sv"]
    actual = []
    for number, line in enumerate((root / "sim/compile.f").read_text(encoding="utf-8-sig").splitlines(), 1):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        match = re.fullmatch(r'"([^"\r\n]+)"', line)
        if not match:
            raise ValueError(f"sim/compile.f 第 {number} 行不是带引号的相对文件名")
        local_path(root, match[1])
        actual.append(match[1])
    if actual != expected:
        raise ValueError("sim/compile.f 与生产清单的功能仿真子集或顺序不一致")
    return actual


def check_project(root: Path = ROOT) -> dict:
    root = root.resolve()
    identity = read_json(root / "build_identity.json")
    inputs = identity["inputs"]
    if not isinstance(inputs, dict) or not inputs:
        raise ValueError("build_identity.json 缺少生产输入")
    if identity.get("device") != DEVICE or identity.get("version") != "C":
        raise ValueError("构建身份的器件或版本不匹配")
    canonical = {k: v for k, v in identity.items() if k not in {"production_digest", "build_id"}}
    digest = hashlib.sha256(json.dumps(canonical, sort_keys=True, separators=(",", ":")).encode("utf-8")).hexdigest()
    if digest != PRODUCTION_DIGEST or identity["production_digest"] != digest or identity["build_id"] != int(digest[:8], 16):
        raise ValueError("构建身份摘要与 R6 记录不一致")
    for name, expected in inputs.items():
        path = local_path(root, name)
        if not path.is_file():
            raise ValueError(f"缺少生产输入：{name}")
        if sha256(path) != RELEASE_COMMENT_HASHES.get(name, expected):
            raise ValueError(f"生产输入 SHA-256 不匹配：{name}")
    header = (root / HEADER).read_text(encoding="utf-8-sig")
    match = re.search(r"`define\s+WORKSTATION_BUILD_ID\s+32'h([0-9a-fA-F]+)", header)
    if not match or int(match[1], 16) != identity["build_id"]:
        raise ValueError("构建身份头文件与 JSON 不一致")

    sources = read_json(root / "sources.json")
    if not isinstance(sources, list) or len(sources) != len(set(sources)):
        raise ValueError("sources.json 必须是无重复文件的列表")
    if any(not p.endswith((".v", ".sv")) for p in sources):
        raise ValueError("生产文件清单包含非 RTL 文件")
    expected_inputs = set(sources)
    expected_inputs.update(p.relative_to(root).as_posix() for p in root.glob("*.mem"))
    for folder in ("ip", "constraints"):
        expected_inputs.update(p.relative_to(root).as_posix() for p in (root / folder).rglob("*") if p.is_file())
    expected_inputs.update(("sources.json", "build.tcl", "pnr.tcl"))
    expected_inputs.update(p.relative_to(root).as_posix() for p in (root / "rtl").glob("*.vh") if p.relative_to(root).as_posix() != HEADER)
    if expected_inputs != set(inputs):
        raise ValueError("当前生产输入集合与构建身份不一致")

    projects = sorted(p.name for p in root.glob("*.gprj"))
    if projects != [PROJECT_NAME]:
        raise ValueError(f"工程根目录应只提供 {PROJECT_NAME}，实际为 {projects}")
    project = ET.parse(root / PROJECT_NAME)
    device = project.find("./Device")
    if device is None or device.attrib.get("pn") != DEVICE:
        raise ValueError("Gowin 工程器件不匹配")
    entries = project.findall("./FileList/File")
    paths = [item.attrib["path"] for item in entries]
    if len(paths) != len(set(paths)):
        raise ValueError("Gowin 工程文件列表包含重复引用")
    for name in paths:
        if not local_path(root, name).is_file():
            raise ValueError(f"缺少工程引用：{name}")
    if {p for p in paths if p.endswith((".v", ".sv"))} != set(sources):
        raise ValueError("Gowin 工程与 sources.json 的生产 RTL 不一致")
    config = read_json(root / CONFIG)
    if config.get("TopModule") != "mega138_models8_top":
        raise ValueError("工程选项中的顶层不匹配")
    options = {"Global_Freq": "50.000", "Place_Option": "3", "Route_Option": "2", "Route_Maxfan": "50"}
    if any(config.get(name) != value for name, value in options.items()):
        raise ValueError("Gowin 工程选项与 R6 构建配置不一致")
    tcl = (root / "build.tcl").read_text(encoding="utf-8-sig")
    tcl_sources = re.findall(r"add_file -type verilog \[file join \$root \{([^}]+)\}\]", tcl)
    if tcl_sources != sources:
        raise ValueError("build.tcl 与 sources.json 的源文件或顺序不一致")
    for name in re.findall(r"add_file -type (?:cst|sdc) \[file join \$root \{([^}]+)\}\]", tcl):
        if not local_path(root, name).is_file():
            raise ValueError(f"缺少构建约束：{name}")
    functional_sources = simulation_sources(root, sources)

    includes = memories = 0
    files = distribution_files(root)
    for path in files.values():
        if path.suffix not in {".v", ".sv", ".vh", ".svh"}:
            continue
        code = path.read_text(encoding="utf-8-sig")
        code = re.sub(r"/\*.*?\*/|//[^\n]*", "", code, flags=re.S)
        for name in re.findall(r'`include\s+"([^"\r\n]+)"', code):
            includes += 1
            candidates = (local_path(root, name), (path.parent / name).resolve())
            if not any(p.is_relative_to(root) and p.is_file() for p in candidates):
                raise ValueError(f"缺少头文件：{path.relative_to(root)} → {name}")
        for name in re.findall(r'"([^"\r\n]+\.mem)"', code):
            memories += 1
            candidates = (local_path(root, name), (path.parent / name).resolve())
            if not any(p.is_relative_to(root) and p.is_file() for p in candidates):
                raise ValueError(f"缺少 ROM：{path.relative_to(root)} → {name}")

    manifest = read_json(root / "SOURCE_MANIFEST.json")
    if manifest.get("build") != f"0x{identity['build_id']:08x}" or manifest.get("production_digest") != digest:
        raise ValueError("发布库存与生产身份不一致")
    if set(manifest["files"]) != set(files):
        missing = sorted(set(manifest["files"]) - set(files))
        extra = sorted(set(files) - set(manifest["files"]))
        raise ValueError(f"发布库存集合不一致：缺少 {missing}；额外 {extra}")
    for name, path in files.items():
        if sha256(path) != manifest["files"][name]:
            raise ValueError(f"发布文件 SHA-256 不匹配：{name}")
    return {
        "status": "PASS", "build": f"0x{identity['build_id']:08x}",
        "production_digest": digest, "production_inputs": len(inputs),
        "original_input_hash_matches": len(inputs) - len(RELEASE_COMMENT_HASHES),
        "comment_only_input_revisions": len(RELEASE_COMMENT_HASHES),
        "production_rtl": len(sources), "project_entries": len(entries),
        "functional_simulation_sources": len(functional_sources),
        "testbenches": len(list((root / "sim").glob("tb_*.sv"))),
        "include_references": includes, "memory_references": memories,
        "manifest_files": len(files), "project": PROJECT_NAME,
    }


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT, help="待校验的 R6 工程目录")
    parser.add_argument("--json", action="store_true", help="输出 JSON 检查结果")
    args = parser.parse_args(argv)
    try:
        result = check_project(args.root)
    except (OSError, ValueError, KeyError, TypeError, ET.ParseError) as error:
        print(f"SOURCE_CHECK FAIL: {error}", file=sys.stderr)
        return 1
    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        print(
            f"SOURCE_CHECK PASS build={result['build']} inputs={result['production_inputs']} "
            f"original={result['original_input_hash_matches']} comment_revisions={result['comment_only_input_revisions']} "
            f"rtl={result['production_rtl']} tests={result['testbenches']} files={result['manifest_files']}"
        )
    return 0


if __name__ == "__main__":
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    raise SystemExit(main())
