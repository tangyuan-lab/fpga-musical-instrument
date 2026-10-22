"""一条命令生成、验证触摸页面和两项 RTL 回归；不操作窗口、不连接串口。

页面事件在有限指令模型中执行，不能替代官方编译或实物验证。
遇到模型未支持的语法直接失败，禁止把未知指令当作验证通过。
"""
from __future__ import annotations

import argparse
import contextlib
import hashlib
import io
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

PROJECT = Path(__file__).resolve().parents[1]
SCREEN = PROJECT / "screen/TJC1060X570"
sys.path.insert(0, str(SCREEN / "design"))
sys.path.insert(0, str(SCREEN))
from create_touch_piano import generate as generate_source
from hex12_parser import decode_hex12
from build_dashboard_hmi import generate as build_hmi


class EventModel:
    """执行本项目实际事件源码的受限模型；绘图只记录，不模拟屏幕渲染。"""

    def __init__(self, spec):
        self.values = {"sys0": 0, "sys1": 0, "sys2": 0, "tch0": 0, "tch1": 0}
        self.packets = []
        self.draws = []
        self.codes = {}
        for widget in spec["widgets"]:
            for field, value in widget["fields"].items():
                self.values[f'{widget["objname"]}.{field}'] = value
            for event, lines in widget.get("events", {}).items():
                self.codes[widget["objname"], event] = self.compile(lines)
        for event, lines in spec["page_events"].items():
            self.codes["page0", event] = self.compile(lines)

    @staticmethod
    def expression(source):
        # 保留字符串内容；当前生成器每条算式只有一个运算符，避免与 TJC 优先级不同。
        pattern = r'"[^"\n]*"|[A-Za-z_]\w*(?:\.\w+)?|\d+|==|!=|>=|<=|&&|\|\||[+*/<>()-]'
        tokens = re.findall(pattern, source)
        if re.sub(pattern, "", source).strip():
            raise ValueError(f"Unsupported expression: {source}")
        operators = sum(token in ("+", "*", "/", "-") for token in tokens)
        if operators > 1:
            raise ValueError(f"Ambiguous arithmetic precedence: {source}")
        result = []
        for token in tokens:
            if re.fullmatch(r"[A-Za-z_]\w*(?:\.\w+)?", token):
                token = f"v[{token!r}]"
            else:
                token = {"&&": " and ", "||": " or ", "/": "//"}.get(token, token)
            result.append(token)
        return "".join(result)

    @classmethod
    def compile(cls, lines):
        output, indent = [], 0
        for source in lines:
            source = source.strip()
            if source == "{":
                indent += 1
                continue
            if source in ("}", "}else"):
                indent -= 1
                if indent < 0:
                    raise ValueError("Unbalanced event braces")
                if source == "}else":
                    output.append("    " * indent + "else:")
                continue
            if source.startswith("if(") and source.endswith(")"):
                code = f"if {cls.expression(source[3:-1])}:"
            elif source.startswith("printh "):
                data = bytes.fromhex(source[7:])
                code = f"packets.append({data!r})"
            elif match := re.fullmatch(r"click ([A-Za-z_]\w*),([01])", source):
                event = "codesdown-" if match[2] == "1" else "codesup-"
                code = f"click({match[1]!r},{event!r})"
            elif source.startswith(("strlen ", "substr ", "covx ")):
                command, arguments = source.split(" ", 1)
                parts = arguments.split(",")
                if command == "strlen" and len(parts) == 2:
                    code = f"v[{parts[1]!r}]=len({cls.expression(parts[0])})"
                elif command == "substr" and len(parts) == 4:
                    start, length = map(int, parts[2:])
                    code = f"v[{parts[1]!r}]={cls.expression(parts[0])}[{start}:{start+length}]"
                elif command == "covx" and len(parts) == 4 and parts[2:] == ["0", "0"]:
                    code = f"v[{parts[1]!r}]=str({cls.expression(parts[0])})"
                else:
                    raise ValueError(f"Unsupported command: {source}")
            elif source.startswith("fill "):
                arguments = source[5:].split(",")
                if len(arguments) != 5:
                    raise ValueError(f"Unsupported drawing: {source}")
                rendered = "+','+".join(f"str({cls.expression(arg)})" for arg in arguments)
                code = f"draws.append('fill '+{rendered})"
            elif source.startswith(("vis ", "ref ")):
                code = f"draws.append({source!r})"
            elif match := re.fullmatch(r"([A-Za-z_]\w*(?:\.\w+)?)(\+\+|--)", source):
                code = f"v[{match[1]!r}]+={1 if match[2] == '++' else -1}"
            elif match := re.fullmatch(r"([A-Za-z_]\w*(?:\.\w+)?)=(.+)", source):
                code = f"v[{match[1]!r}]={cls.expression(match[2])}"
            else:
                raise ValueError(f"Unsupported event line: {source}")
            output.append("    " * indent + code)
        if indent:
            raise ValueError("Unbalanced event braces")
        return compile("\n".join(output), "<TJC event model>", "exec")

    def run(self, name="tm0", event="codestimer-"):
        self.execute(self.codes[name, event])

    def execute(self, code):
        exec(code, {"__builtins__": {}, "len": len, "str": str, "click": self.run},
             {"v": self.values, "packets": self.packets, "draws": self.draws})


def validate(spec):
    checks = 0

    def require(condition, message):
        nonlocal checks
        if not condition:
            raise AssertionError(message)
        checks += 1

    model = EventModel(spec)
    v = model.values
    parser = model.compile(decode_hex12("sourceTxt.txt", "cur0.val"))
    for value in range(4096):
        v["sourceTxt.txt"] = f"{value:03X}"
        model.execute(parser)
        require(v["cur0.val"] == value and v["sys2"] == 3, f"HEX decode {value:03X}")
    for malformed in ("---", "0G0", "?FF", "FF?", "fff"):
        v["sourceTxt.txt"] = malformed
        model.execute(parser)
        require(v["sys2"] != 3, f"Invalid HEX accepted: {malformed}")

    v.update({"t0.txt": "LIVE", "t1.txt": "D", "t2.txt": "READY"})
    for key in range(13):
        v[f"t{key+3}.txt"] = "FFF"
    model.run()
    require(v["activeTxt.txt"] == "13", "Active D -> 13")
    for key in range(13):
        require(v[f"cur{key}.val"] == 4095 and v[f"j{key}.val"] == 100
                and v[f"ui{key}.txt"] == "FFF", f"Full scale channel {key}")
    model.run("unitBtn", "codesup-")
    model.run()
    require(all(v[f"ui{k}.txt"] == "4095" for k in range(13)), "Decimal full scale")
    v["t3.txt"] = "100"
    model.run("holdBtn", "codesup-")
    model.run()
    require(v["ui0.txt"] == "4095" and v["cur0.val"] == 256, "Peak hold on decline")
    model.run("clearBtn", "codesup-")
    model.run()
    require(v["ui0.txt"] == "256" and v["peak0.val"] == 256, "Peak reset")
    for invalid in ("---", "FF", "0G0", "FFFF"):
        v["t3.txt"] = invalid
        model.run()
        require(v["ui0.txt"] == "---" and v["j0.val"] == 0, "Invalid pressure display")

    def expected(op, key):
        return bytes((0xA5, 0x5A, op, key, 0xA5 ^ 0x5A ^ op ^ key))

    model.packets.clear()
    model.run("page0", "codesloadend-")
    require(model.packets == [expected(2, 255)], "Startup all off")
    for key in range(13):
        model.packets.clear()
        v.update({"tch0": 40 + 74 * key, "tch1": 300})
        model.run(f"key{key}", "codesdown-")
        model.run()
        model.run(f"key{key}", "codesup-")
        require(model.packets == [expected(1, key), expected(1, key), expected(0, key)],
                f"Key {key} press/heartbeat/release")
        require(v["heldKey.val"] == -1, f"Key {key} release state")
    for position in ((0, 0), (31, 300), (100, 300), (40, 269), (40, 484)):
        model.run("key0", "codesdown-")
        model.packets.clear()
        v["tch0"], v["tch1"] = position
        model.run()
        require(model.packets == [expected(0, 0)] and v["heldKey.val"] == -1,
                f"Touch outside card releases: {position}")
    for key, value in (("playMode.val", 0), ("demoMode.val", 1), ("t0.txt", "MIDI")):
        previous = v[key]
        model.run("key0", "codesdown-")
        v[key] = value
        model.packets.clear()
        model.run()
        require(model.packets == [expected(0, 0)], f"Mode change releases: {key}")
        model.packets.clear()
        model.run("key12", "codesdown-")
        require(not model.packets and v["selected.val"] == 12, f"Mode blocks note: {key}")
        v[key] = previous
    model.run("key0", "codesdown-")
    model.packets.clear()
    model.run("offBtn", "codesup-")
    require(model.packets == [expected(2, 255)] and v["heldKey.val"] == -1, "All off")
    inputs = {f"t{k}.txt": v[f"t{k}.txt"] for k in range(16)}
    model.run("demoBtn", "codesup-")
    for _ in range(16 * 13):
        model.run()
    require(all(v[key] == value for key, value in inputs.items()), "DEMO preserves UART input")
    require(v["modeTxt.txt"] == "DEMO" and v["demoKey.val"] == 0, "DEMO complete cycle")
    return checks


def validate_saved_events(spec, hmi_path):
    """回读 HMI 中真正写入的事件，防止只验证清单而遗漏序列化错误。"""
    from build_native_hmi import native_entry
    from usarthmi.page_format import parse_page_data, _parse_event_specs
    # 生成器以GBK保存事件；部分中文GBK恰好也能被UTF-8解码，必须明确指定。
    page = parse_page_data(native_entry(hmi_path.read_bytes(), "0.pa"),event_encoding="gbk")
    expected = {widget["objname"]: widget.get("events", {}) for widget in spec["widgets"]}
    expected["page0"] = spec["page_events"]
    count = 0
    for block in page.blocks:
        actual = {name.rsplit("-", 1)[0] + "-": lines
                  for name, lines in _parse_event_specs(block.event_tokens) if lines}
        wanted = {name: lines for name, lines in expected[block.objname].items() if lines}
        if actual != wanted:
            raise AssertionError(f"Native event mismatch: {block.objname}")
        count += len(wanted)
    return count


def verify_rtl():
    from run_tests import TESTS, TOOLS
    logs_dir = PROJECT / "build/tests"
    logs_dir.mkdir(parents=True, exist_ok=True)
    passed = []
    environment = os.environ.copy()
    environment["PATH"] = str(TOOLS) + os.pathsep + environment.get("PATH", "")
    for name in ("tb_screen_touch_keys_rx", "tb_screen_touch_audio_path"):
        binary = logs_dir / f"{name}.vvp"
        commands = [
            [str(TOOLS / "iverilog.exe"), "-g2012", "-s", name, "-o", str(binary),
             *[str(PROJECT / source) for source in TESTS[name]], str(PROJECT / f"tests/{name}.sv")],
            [str(TOOLS / "vvp.exe"), str(binary)]]
        logs = []
        for command in commands:
            result = subprocess.run(command, cwd=PROJECT, env=environment, capture_output=True, text=True,
                                    encoding="utf-8", errors="replace", timeout=90)
            logs.append(result.stdout + result.stderr)
            (logs_dir / f"{name}.log").write_text("\n".join(logs), encoding="utf-8")
            if result.returncode:
                raise RuntimeError(f"RTL failed: {name}; see {logs_dir / (name + '.log')}")
        if f"PASS {name}" not in logs[-1]:
            raise RuntimeError(f"Missing RTL PASS: {name}")
        passed.append(name)
    return passed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--skip-rtl", action="store_true", help="只改页面时跳过耗时的 RTL 仿真")
    args = parser.parse_args()
    started = time.perf_counter()
    output = SCREEN / "generated/instrument_touch_hexfix"
    report_path = PROJECT / "build/tests/touch_screen_verification.json"
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report = {"status": "failed", "scope": "source event model + native HMI integrity + optional RTL",
              "official_compile": "pending", "hardware_validation": "pending"}
    try:
        with contextlib.redirect_stdout(io.StringIO()):
            generate_source()
        manifest = SCREEN / "design/touch/controls_manifest.json"
        spec = json.loads(manifest.read_text(encoding="utf-8"))
        report["source_assertions"] = validate(spec)
        build = build_hmi(manifest, output / "instrument_touch_hexfix.HMI",
                          SCREEN / "uart_minimal_manual.HMI", SCREEN / "vendor/TJC1060X570_factory.HMI")
        report["native_events_checked"] = validate_saved_events(spec, Path(build["hmi"]))
        report.update({"native_hmi": build["hmi"], "hmi_sha256": build["hmi_sha256"],
                       "native_cfs_crc_valid": build["native_cfs_crc_valid"],
                       "page_safe": build["page_safe"], "geometry_valid": build["geometry_valid"],
                       "object_count": build["object_count"],
                       "manifest_sha256": hashlib.sha256(manifest.read_bytes()).hexdigest()})
        report["rtl_passed"] = [] if args.skip_rtl else verify_rtl()
        report["rtl_skipped"] = args.skip_rtl
        report["status"] = "passed"
    except Exception as error:
        report["error"] = f"{type(error).__name__}: {error}"
        raise
    finally:
        report["elapsed_seconds"] = round(time.perf_counter() - started, 2)
        report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"PASS {report['source_assertions']} source assertions; {len(report['rtl_passed'])} RTL tests; "
          f"{report['native_events_checked']} native events + HMI integrity OK; {report['elapsed_seconds']}s")
    print(f"Report: {report_path}")
    print(f"HMI: {report['native_hmi']} (official compile pending; no new TFT)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
