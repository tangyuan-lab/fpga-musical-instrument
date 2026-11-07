#!/usr/bin/env python3
"""使用 ModelSim 运行 R6 测试台，绑定源码、模型、工具及结构化完成记录。"""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
import uuid

from check_project import ROOT, check_project, read_json, sha256, simulation_sources


class RunFailure(RuntimeError):
    pass


def positive_seconds(value: str) -> int:
    number = int(value)
    if number < 1:
        raise argparse.ArgumentTypeError("超时秒数必须大于零")
    return number


def simulation_argument(value: str) -> str:
    name = value.partition("=")[0]
    if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", name) or name == "RESULT":
        raise argparse.ArgumentTypeError("仿真参数格式为 NAME 或 NAME=VALUE，RESULT 由工具分配")
    return "+" + value


def find_tools(directory: str | None) -> dict[str, Path]:
    folder = Path(directory).expanduser().resolve() if directory else None
    result = {}
    for name in ("vlib", "vlog", "vsim"):
        if folder:
            choices = [folder / (name + ".exe"), folder / name]
            path = next((p for p in choices if p.is_file()), None)
        else:
            value = shutil.which(name)
            path = Path(value).resolve() if value else None
        if path is None:
            raise ValueError(f"找不到 {name}：请设置 --modelsim-bin、MODELSIM_BIN 或 PATH")
        result[name] = path
    return result


def find_primitive(value: str | None) -> Path:
    if not value and os.environ.get("GOWIN_HOME"):
        value = str(Path(os.environ["GOWIN_HOME"]) / "IDE/simlib/gw5a/prim_sim.v")
    if not value:
        raise ValueError("请用 --gowin-prim-sim、GOWIN_PRIM_SIM 或 GOWIN_HOME 指定本机 GW5A 原语模型")
    path = Path(value).expanduser().resolve()
    if not path.is_file():
        raise ValueError(f"厂商原语模型不存在：{path}")
    return path


def find_ini(tools: dict[str, Path], value: str | None) -> Path:
    if value:
        path = Path(value).expanduser().resolve()
        if not path.is_file():
            raise ValueError(f"ModelSim 配置不存在：{path}")
        return path
    folder = tools["vsim"].parent
    for path in (folder.parent / "modelsim.ini", folder / "modelsim.ini"):
        if path.is_file():
            return path
    raise ValueError("找不到 modelsim.ini，请用 --modelsim-ini 指定")


def assess_result(test: str, completion: str, log: str) -> dict:
    """进程退出码之外，校验测试身份、有效检查数和日志；防止假 PASS。"""
    values = {}
    for line in completion.splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            if key in values:
                raise RunFailure(f"完成记录含重复字段：{key}")
            values[key] = value.strip()
    if values.get("STATUS") != "PASS" or values.get("TEST") != test:
        raise RunFailure("缺少匹配测试台的 STATUS=PASS 完成记录")
    count = values.get("CHECKS", "")
    if not re.fullmatch(r"[1-9][0-9]*", count):
        raise RunFailure("完成记录缺少正数 CHECKS")
    if not re.search(r"\bPASS\s+" + re.escape(test) + r"\b", log):
        raise RunFailure("仿真日志缺少对应测试台的 PASS 标记")
    if re.search(r"\bFAIL\b|\*\*\s+(?:Error|Fatal):", log, re.IGNORECASE):
        raise RunFailure("仿真日志包含 FAIL、Error 或 Fatal")
    return {"status": "PASS", "test": test, "checks": int(count)}


def run_step(label: str, command: list[str], output: Path, timeout: int, steps: list[dict], expected_fatal: str | None = None) -> str:
    logfile = output / (label + ".log")
    record = {"stage": label, "command": command, "log": logfile.name, "timeout_seconds": timeout}
    steps.append(record)
    started = time.monotonic()
    flags = getattr(subprocess, "CREATE_NO_WINDOW", 0) if os.name == "nt" else 0
    with logfile.open("wb") as handle:
        process = subprocess.Popen(command, cwd=ROOT, stdout=handle, stderr=subprocess.STDOUT, creationflags=flags)
        record["pid"] = process.pid
        try:
            record["exit_code"] = process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            record["timed_out"] = True
            # 只结束本工具启动的超时进程树，避免遗留仿真子进程。
            if os.name == "nt":
                subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, creationflags=flags)
            if process.poll() is None:
                process.kill()
            process.wait()
            record["exit_code"] = process.returncode
        finally:
            record["elapsed_seconds"] = round(time.monotonic() - started, 3)
    record["log_sha256"] = sha256(logfile)
    text = logfile.read_text(encoding="utf-8", errors="replace")
    if record.get("timed_out"):
        raise RunFailure(f"{label} 超过 {timeout} 秒，已结束本次进程")
    if expected_fatal:
        if not re.search(r"\*\*\s+Fatal:[^\r\n]*" + re.escape(expected_fatal), text) or re.search(r"\bPASS\s+tb_", text):
            raise RunFailure("定向反例未命中指定断言，或出现非预期 PASS")
        if record["exit_code"] not in (0, 1, 2, 3):
            raise RunFailure("定向反例进程异常退出")
        return text
    if record["exit_code"] != 0:
        raise RunFailure(f"{label} 退出码为 {record['exit_code']}，见 {logfile.name}")
    if re.search(r"\*\*\s+(?:Error|Fatal):", text, re.IGNORECASE):
        raise RunFailure(f"{label} 日志含 Error/Fatal，见 {logfile.name}")
    return text


def execute_test(test: str, args, tools: dict[str, Path], primitive: Path, ini_source: Path, check: dict) -> dict:
    # 缩短运行目录名，兼容旧版 ModelSim 的 Windows 路径长度限制。
    tag = datetime.now(timezone.utc).strftime("%m%d%H%M%S") + "_" + uuid.uuid4().hex[:6]
    output = ROOT / "runs" / tag
    run_path = output.relative_to(ROOT)
    output.mkdir(parents=True, exist_ok=False)
    result = {
        "schema": 1, "test": test, "build": check["build"],
        "production_digest": check["production_digest"], "passed": False,
        "release_manifest_sha256": sha256(ROOT / "SOURCE_MANIFEST.json"),
        "ram_model": "functional_effects_ram" if args.functional_effects_ram else "vendor_primitive",
        "scope": "RTL functional simulation", "steps": [],
        "plusargs": args.plusarg,
        "started_at": datetime.now(timezone.utc).isoformat(),
        "tools": {name: {"sha256": sha256(path), "executable": path.name} for name, path in tools.items()},
        "primitive_sha256": sha256(primitive), "modelsim_ini_sha256": sha256(ini_source),
    }
    print("RUN_DIR " + str(output), flush=True)
    try:
        sources = read_json(ROOT / "sources.json")
        compiled = simulation_sources(ROOT, sources)
        if args.functional_effects_ram:
            compiled = ["sim/sample_ram_functional.sv" if p == "sample_ram.sv" else p for p in compiled]
        profiles = read_json(ROOT / "sim/test_profiles.json")
        selected = list(compiled) + profiles["tests"].get(test, [f"sim/{test}.sv"])
        negative = profiles["negative_controls"].get(args.negative_control) if args.negative_control else None
        if negative:
            if negative["test"] != test:
                raise ValueError("定向反例与测试台不匹配")
            selected = [negative["source"] if name == negative["replaces"] else name for name in selected]
            result["negative_control"] = args.negative_control
            result["expected_assertion"] = negative["target"]
        # 加入递归 include、所有 ROM 及构建身份，记录实际仿真的输入闭包。
        bound = set(selected) | {"sim/compile.f", "build_identity.json", "rtl/workstation_build_identity.vh"}
        bound.update(p.relative_to(ROOT).as_posix() for p in ROOT.glob("*.mem"))
        bound.update(p.relative_to(ROOT).as_posix() for p in (ROOT / "sim").glob("*.mem"))
        pending = list(bound)
        while pending:
            name = pending.pop()
            path = ROOT / name
            if path.suffix not in {".v", ".sv", ".vh", ".svh"}:
                continue
            code = re.sub(r"/\*.*?\*/|//[^\n]*", "", path.read_text(encoding="utf-8-sig"), flags=re.S)
            for included in re.findall(r'`include\s+"([^"\r\n]+)"', code):
                candidate = next((p for p in (ROOT / included, path.parent / included) if p.is_file()), None)
                if candidate is None or not candidate.resolve().is_relative_to(ROOT):
                    raise RunFailure(f"无法绑定头文件：{included}")
                relative = candidate.resolve().relative_to(ROOT).as_posix()
                if relative not in bound:
                    bound.add(relative)
                    pending.append(relative)
        hashes = {name: sha256(ROOT / name) for name in sorted(bound)}
        (output / "source_hashes.json").write_text(json.dumps(hashes, indent=2) + "\n", encoding="utf-8", newline="\n")
        result["source_hashes"] = "source_hashes.json"

        library = (run_path / "work").as_posix()
        ini = output / "modelsim.ini"
        ini_option = (run_path / ini.name).as_posix()
        ini_text = ini_source.read_text(encoding="utf-8-sig", errors="replace")
        if re.search(r"(?m)^work\s*=.*$", ini_text):
            ini_text = re.sub(r"(?m)^work\s*=.*$", "work = " + library, ini_text)
        else:
            ini_text = ini_text.replace("[Library]", "[Library]\nwork = " + library, 1)
        ini.write_text(ini_text, encoding="utf-8", newline="\n")
        filelist = output / "compile.f"
        filelist.write_text("".join(f'"{name}"\n' for name in selected), encoding="utf-8", newline="\n")
        run_step("library", [str(tools["vlib"]), library], output, args.timeout_seconds, result["steps"])
        run_step("primitives", [str(tools["vlog"]), "-modelsimini", ini_option, "-work", "work", "-sv", str(primitive)], output, args.timeout_seconds, result["steps"])
        run_step("compile", [str(tools["vlog"]), "-modelsimini", ini_option, "-work", "work", "-sv", "-f", (run_path / filelist.name).as_posix()], output, args.timeout_seconds, result["steps"])
        completion = output / "sim_completed.txt"
        script = output / "run.do"
        script.write_text("onerror {quit -code 2 -f}\nonbreak {quit -code 3 -f}\nrun -all\nquit -code 0 -f\n", encoding="utf-8", newline="\n")
        # 旧版 vsim 对含空格的 -modelsimini 路径会重复转义，内部参数统一使用工程相对路径。
        log = run_step("simulation", [
            str(tools["vsim"]), "-c", "-modelsimini", ini_option, "-lib", "work",
            "-l", (run_path / "transcript.log").as_posix(), "-do", (run_path / script.name).as_posix(),
            test, "+RESULT=" + (run_path / completion.name).as_posix(), *args.plusarg,
        ], output, args.timeout_seconds, result["steps"], expected_fatal=negative["target"] if negative else None)
        if negative:
            if completion.exists():
                raise RunFailure("定向反例产生了正常测试完成记录")
            result.update(passed=True, expected_failure_observed=True)
        else:
            proof = assess_result(test, completion.read_text(encoding="utf-8-sig") if completion.is_file() else "", log)
            result.update(passed=True, checks=proof["checks"], completion_sha256=sha256(completion))
    except (OSError, ValueError, RunFailure) as error:
        result["error"] = str(error)
    finally:
        result["finished_at"] = datetime.now(timezone.utc).isoformat()
        (output / "result.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"RESULT {'PASS' if result['passed'] else 'FAIL'} {test}: {output / 'result.json'}", flush=True)
    if not result["passed"]:
        print(result.get("error", "测试失败"), file=sys.stderr, flush=True)
    return result


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--negative-control", choices=["urgent_emergency", "screen_semantic", "generation_identity", "pcm"], help="用隔离的故障注入源码验证指定断言")
    parser.add_argument("--test", action="append", required=True, help="sim/ 下的测试台模块名，可重复指定")
    parser.add_argument("--modelsim-bin", default=os.environ.get("MODELSIM_BIN"), help="ModelSim 可执行文件目录；也可通过 PATH 查找")
    parser.add_argument("--modelsim-ini", default=os.environ.get("MODELSIM_INI"), help="可选的 ModelSim 基础配置")
    parser.add_argument("--gowin-prim-sim", default=os.environ.get("GOWIN_PRIM_SIM"), help="GW5A prim_sim.v 文件路径")
    parser.add_argument("--functional-effects-ram", action="store_true", help="显式采用等时序效果 RAM 功能模型")
    parser.add_argument("--plusarg", action="append", type=simulation_argument, default=[], help="传入测试台的 NAME 或 NAME=VALUE，可重复指定")
    parser.add_argument("--timeout-seconds", type=positive_seconds, default=1800, help="每个编译或仿真进程的超时秒数，默认 1800")
    args = parser.parse_args(argv)
    try:
        for name in args.test:
            if not re.fullmatch(r"tb_[A-Za-z0-9_]+", name) or not (ROOT / "sim" / (name + ".sv")).is_file():
                raise ValueError(f"测试台不存在或名称不合法：{name}")
        tools = find_tools(args.modelsim_bin)
        primitive = find_primitive(args.gowin_prim_sim)
        ini = find_ini(tools, args.modelsim_ini)
        check = check_project()
    except (OSError, ValueError, KeyError, TypeError, SyntaxError) as error:
        print(f"TEST_SETUP FAIL: {error}", file=sys.stderr)
        return 2
    for test in args.test:
        if not execute_test(test, args, tools, primitive, ini, check)["passed"]:
            return 1
    return 0


if __name__ == "__main__":
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    raise SystemExit(main())
