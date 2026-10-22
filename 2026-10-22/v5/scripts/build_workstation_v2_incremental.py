"""运行独立 V2 增量候选；只生成验收报告，不发布位流、不烧录设备。

先验证综合缓存，再冻结输入。任何源码变化、工具报错、时序或引脚不符都会
阻止 PASS；原有构建目录和 ready-to-program 目录不会被写入。
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import html
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time


ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "build/gowin/instrument_workstation_v2"
DEFAULT_OUTPUT = ROOT / "build/gowin/instrument_workstation_v2_inc0"
REFERENCE = ROOT / "build/baselines/v2_incremental_reference/prior_routed.pr"
REFERENCE_SHA = "ECFBDA1B5FA793590103D639FB00EFC0DC194210DCE58ADD5A5D829A2D017C61"
TOOL = Path(os.environ.get("GOWIN_SH","C:/Gowin/Gowin_V1.9.12.03_x64/IDE/bin/gw_sh.exe"))
NAME = "instrument_workstation_v2"


def sha(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest().upper()


def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def save_json(path: Path, value) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def source_paths() -> list[Path]:
    # 包含未参与该顶层的 RTL，保持与既有综合缓存的保守绑定规则一致。
    paths = {p.resolve() for p in (ROOT / "rtl").rglob("*")
             if p.is_file() and p.suffix.lower() in {".v", ".sv", ".inc"}}
    paths.update(p.resolve() for p in (ROOT / "gowin").rglob("*")
                 if p.is_file() and p.suffix.lower() in {".cst", ".sdc"})
    paths.update(p.resolve() for p in (ROOT / "config").rglob("*") if p.is_file())
    paths.update((ROOT / p).resolve() for p in [
        "gowin/build_instrument_workstation_v2.tcl",
        "gowin/build_instrument_workstation_v2_syn.tcl",
        "gowin/build_instrument_workstation_v2_pnr.tcl",
        "scripts/prepare_workstation_v2.py", "scripts/verify_workstation_pinout.py",
        "scripts/build_workstation_v2.ps1", "scripts/build_workstation_v2_incremental.py",
    ])
    return sorted(paths, key=lambda p: str(p).casefold())


def verify_cache() -> tuple[dict[str, str], Path, dict]:
    cache_path = BASE / "synthesis_cache.json"
    cache = read_json(cache_path)
    netlist = BASE / f"impl/gwsynthesis/{NAME}.vg"
    if sha(netlist) != cache["netlist"].upper():
        raise ValueError("综合缓存网表 SHA256 不匹配")
    expected = {Path(p).resolve(): value.upper() for p, value in cache["sources"].items()}
    rtl = {p.resolve() for p in (ROOT / "rtl").rglob("*")
           if p.is_file() and p.suffix.lower() in {".v", ".sv", ".inc"}}
    cached_rtl = {p for p in expected if p.suffix.lower() in {".v", ".sv", ".inc"}}
    if rtl != cached_rtl:
        raise ValueError("当前 RTL 文件集合与综合缓存不一致")
    for path, digest in expected.items():
        if not path.is_file() or sha(path) != digest:
            raise ValueError(f"综合缓存过期：{path}")
    if sha(REFERENCE) != REFERENCE_SHA:
        raise ValueError("冻结的旧完整布线参考文件 SHA256 不匹配")
    paths = source_paths() + [cache_path.resolve(), netlist.resolve(), REFERENCE.resolve(),
                              TOOL.resolve(), (TOOL.parent / "gowin.dll").resolve()]
    hashes = {str(p): sha(p) for p in paths}
    return hashes, netlist, cache


def changed_inputs(hashes: dict[str, str]) -> list[str]:
    changed = [name for name, digest in hashes.items()
               if not Path(name).is_file() or sha(Path(name)) != digest]
    # 已有文件的删除由上面的哈希检查覆盖；这里也禁止构建期间新增源码或约束。
    changed.extend(str(p) for p in source_paths() if str(p) not in hashes)
    return sorted(set(changed))


def tcl_path(path: Path) -> str:
    value = path.resolve().as_posix()
    if "{" in value or "}" in value or "\n" in value:
        raise ValueError(f"路径无法安全写入 Tcl：{path}")
    return "{" + value + "}"


def timing_result(text: str) -> dict[str, int]:
    result = {}
    for kind in ("Setup", "Hold"):
        match = re.search(rf"Numbers of {kind} Violated Endpoints</td>\s*<td>\s*(\d+)\s*</td>", text)
        if not match:
            raise ValueError(f"时序报告缺少 {kind} 违例数量")
        result[kind.lower()] = int(match.group(1))
    return result


def pin_result(text: str) -> dict:
    rows = {}
    for row in re.findall(r"<tr[^>]*>(.*?)</tr>", text, re.S | re.I):
        cells = [html.unescape(re.sub(r"<[^>]*>", "", c)).strip()
                 for c in re.findall(r"<td[^>]*>(.*?)</td>", row, re.S | re.I)]
        if cells:
            rows[cells[0]] = cells
    expected = {
        "mcp0_sclk": ("AA19", "out"), "mcp0_miso": ("AA20", "in"),
        "mcp0_mosi": ("AB21", "out"), "mcp0_cs_n": ("Y21", "out"),
        "mcp1_sclk": ("AB20", "out"), "mcp1_miso": ("AA21", "in"),
        "mcp1_mosi": ("AB22", "out"), "mcp1_cs_n": ("Y22", "out"),
        "uart_tx_o": ("U15", "out"), "uart_rx_i": ("V14", "in"),
        "screen_tx_o": ("C18", "out"), "screen_rx_i": ("C19", "in"),
        "hp_bck": ("T21", "out"), "hp_ws": ("U21", "out"), "hp_din": ("P16", "out"),
    }
    actual = {}
    for name, (pin, direction) in expected.items():
        cells = rows.get(name, [])
        if len(cells) < 8:
            raise ValueError(f"实际引脚报告缺少 {name}")
        value = (cells[2].split("/")[0], cells[4], cells[7])
        if value != (pin, direction, "LVCMOS33"):
            raise ValueError(f"{name} 引脚/方向/电平不符：{value}")
        actual[name] = {"pin": pin, "direction": direction, "io_type": "LVCMOS33"}
    return actual


def incremental_evidence(text: str) -> dict:
    lines = [line.strip() for line in text.splitlines()
             if re.search(r"increment|matching|matched|PA2135|CT2019|CT2020|fallback", line, re.I)]
    percentages = [float(m.group(1)) for m in re.finditer(
        r"(?:matching|matched)[^\r\n%]*?\(?\s*([\d.]+)\s*%", text, re.I)]
    fallback = bool(re.search(r"PA2135|less than the threshold|ignore incremental|default .{0,25}flow will be run", text, re.I))
    return {"matching_percentages": percentages, "fallback_detected": fallback,
            "incremental_confirmed": False if fallback else (True if percentages else None),
            "evidence_lines": lines,
            "note": "匹配率未打印时不推测百分比；以保留的工具日志为准。"}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--mode", choices=("pnr", "full"), default="pnr", help="full使用缓存网表正常放置布线，不加载旧路由")
    parser.add_argument("--check-only", action="store_true", help="只核对缓存和参考文件，不创建候选目录、不启动工具")
    args = parser.parse_args()
    hashes, netlist, cache = verify_cache()
    if args.check_only:
        print(f"PASS cache/reference checks; netlist={cache['netlist']}; bound_files={len(hashes)}", flush=True)
        return 0
    output = args.output.resolve()
    if not output.is_relative_to((ROOT / "build/gowin").resolve()) or output in {BASE.resolve(), ROOT}:
        raise ValueError("候选输出目录必须位于 build/gowin 内，且不能等于原构建目录")
    # 拒绝复用旧目录，防止旧时序报告或旧位流混入本轮验收。
    output.mkdir(parents=True, exist_ok=False)
    inputs = output / "inputs"
    inputs.mkdir()
    snapshots = {}
    for original in [netlist, ROOT / f"gowin/{NAME}.cst", ROOT / f"gowin/{NAME}.sdc"]:
        snapshot = inputs / original.name
        shutil.copyfile(original, snapshot)
        if sha(snapshot) != hashes[str(original.resolve())]:
            raise ValueError(f"输入复制期间发生变化：{original}")
        snapshots[original.suffix] = snapshot
    tcl = output / "candidate.tcl"
    options = [
        ("top_module", "instrument_workstation_v2_top"), ("output_base_name", NAME),
        ("synthesis_tool", "gowinsynthesis"), ("verilog_std", "sysv2017"),
        ("global_freq", "50.000"), ("cst_warn_to_error", "1"),
        ("use_cpu_as_gpio", "1"), ("use_jtag_as_gpio", "0"), ("vccx", "1.8"),
        ("route_option", "0"), ("timing_driven", "1"), ("correct_hold_violation", "1"),
    ]
    lines = [f"cd {tcl_path(output)}", "set_device GW5AT-LV60PG484AC1/I0 -device_version B",
             f"add_file -type netlist {tcl_path(snapshots['.vg'])}",
             f"add_file -type cst {tcl_path(snapshots['.cst'])}",
             f"add_file -type sdc {tcl_path(snapshots['.sdc'])}"]
    lines += [f"set_option -{name} {value}" for name, value in options]
    if args.mode == "pnr":
        lines += [f"set_option -inc_pnr {tcl_path(REFERENCE)}"]
    lines += ["run pnr"]
    tcl.write_text("\n".join(lines) + "\n", encoding="utf-8")
    hashes.update({str(p): sha(p) for p in [*snapshots.values(), tcl]})
    save_json(output / "frozen_inputs.json", hashes)
    changed = changed_inputs(hashes)
    if changed:
        raise ValueError(f"工具启动前输入发生变化：{changed}")
    log = output / "candidate.log"
    started = time.time_ns()
    report = {"passed": False, "status": "RUNNING", "output": str(output),
              "started_utc": datetime.now(timezone.utc).isoformat(), "route_option": 0,
              "implementation_mode": args.mode,
              "reference": str(REFERENCE) if args.mode == "pnr" else None,
              "reference_sha256": REFERENCE_SHA if args.mode == "pnr" else None,
              "netlist_sha256": cache["netlist"], "log": str(log),
              "frozen_inputs": str(output / "frozen_inputs.json"),
              "publication": "独立候选；不发布 ready-to-program，不烧录"}
    report_path = output / "candidate_report.json"
    save_json(report_path, report)
    try:
        # CREATE_NO_WINDOW 只隐藏命令行工具窗口，stdout/stderr 仍完整写入日志。
        flags = subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0
        with log.open("w", encoding="utf-8", buffering=1) as stream:
            process = subprocess.Popen([str(TOOL), str(tcl)], cwd=output,
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                encoding="utf-8", errors="replace", creationflags=flags)
            report["tool_pid"] = process.pid
            save_json(report_path, report)
            print(f"START incremental candidate PID={process.pid}; log={log}", flush=True)
            assert process.stdout is not None
            for line in process.stdout:
                stream.write(line)
                print(line, end="", flush=True)
            result = process.wait()
        report["returncode"] = result
        tool_log = log.read_text(encoding="utf-8")
        report["incremental"] = incremental_evidence(tool_log)
        if result != 0 or re.search(r"\bERROR\s*\(", tool_log, re.I):
            raise ValueError(f"Gowin 失败，返回码 {result}")
        if re.search(r"(?:\b[1-9]\d*\s+unrouted\b|can't route|cannot route|failed to route|routing failed)", tool_log, re.I):
            raise ValueError("工具报告存在未布通网络")
        if "Placement and routing completed" not in tool_log or "Bitstream generation completed" not in tool_log:
            raise ValueError("工具未确认布局布线和位流生成完成")
        pnr = output / "impl/pnr"
        artifacts = {name: pnr / (NAME + suffix) for name, suffix in [
            ("bitstream", ".fs"), ("timing", "_tr_content.html"),
            ("pinout", ".pin.html"), ("implementation", ".rpt.txt")]}
        for name, path in artifacts.items():
            if not path.is_file() or path.stat().st_size == 0 or path.stat().st_mtime_ns < started:
                raise ValueError(f"缺少本轮新鲜产物：{name} {path}")
        implementation = artifacts["implementation"].read_text(encoding="utf-8", errors="replace")
        if re.search(r"\bERROR\s*\(|\b[1-9]\d*\s+unrouted\b", implementation, re.I):
            raise ValueError("实现报告包含错误或未布通网络")
        report["timing"] = timing_result(artifacts["timing"].read_text(encoding="utf-8"))
        report["pins"] = pin_result(artifacts["pinout"].read_text(encoding="utf-8"))
        report["artifacts"] = {name: {"path": str(path), "sha256": sha(path),
                                      "mtime_ns": path.stat().st_mtime_ns}
                               for name, path in artifacts.items()}
        if any(report["timing"].values()):
            raise ValueError(f"时序不通过：{report['timing']}")
        report["passed"] = True
        report["status"] = "PASS"
    except Exception as error:
        report["status"] = "FAIL"
        report["error"] = str(error)
    finally:
        changed = changed_inputs(hashes)
        report["changed_inputs"] = changed
        if changed:
            report.update(passed=False, status="FAIL", error="构建期间输入发生变化")
        report["finished_utc"] = datetime.now(timezone.utc).isoformat()
        if log.is_file():
            report["incremental"] = incremental_evidence(log.read_text(encoding="utf-8"))
        save_json(report_path, report)
    print(f"{report['status']} independent candidate: {report_path}", flush=True)
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    try:
        raise SystemExit(main())
    except (OSError, ValueError, KeyError) as error:
        print(f"FAIL incremental candidate: {error}", file=sys.stderr)
        raise SystemExit(1)
