"""上位机第一版命令行入口。"""

from __future__ import annotations

import argparse
from pathlib import Path
import sys
import time

import serial
from serial.tools import list_ports

from .serial_link import FpgaSerialLink, list_serial_ports
from .timbre_file import decode_ftb


def main() -> int:
    parser = argparse.ArgumentParser(description="Tang Mega 60K FPGA 电子乐器上位机")
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("ports", help="列出串口")
    scan = sub.add_parser(
        "scan-ping",
        help="依次尝试所有可见串口，找到能返回 FPGA ACK 的端口",
    )
    scan.add_argument(
        "--include-all",
        action="store_true",
        help="也尝试其他串口及 FT2232 通道 A（默认跳过板载 JTAG 通道）",
    )
    diag = sub.add_parser("listen-diag", help="读取 UART 诊断位流周期发送的原始字符串")
    diag.add_argument("--port", required=True, help="通常是 FT2232 通道 B，例如 COM15")
    diag.add_argument("--seconds", type=float, default=3.0)
    diag.add_argument(
        "--probe-rx", action="store_true",
        help="读取时发送一个 X；观察诊断位流的 LED1 是否翻转",
    )
    ping = sub.add_parser("ping", help="发送 PING 并检查 FPGA ACK")
    ping.add_argument("--port", required=True)
    send = sub.add_parser("send-midi", help="上传完整 MIDI Type 0 文件；使用 play 命令开始播放")
    send.add_argument("--port", required=True)
    send.add_argument("file", type=Path)
    send.add_argument("--timbre", type=int, choices=(0, 1, 2), default=0)
    send.add_argument("--play", action="store_true", help="上传成功后立即播放")
    stop = sub.add_parser("stop", help="停止 FPGA 播放")
    stop.add_argument("--port", required=True)
    play = sub.add_parser("play", help="播放 FPGA 中已经接收的 MIDI 文件")
    play.add_argument("--port", required=True)
    play.add_argument("--timbre", type=int, choices=(0, 1, 2), default=0)
    status = sub.add_parser("status", help="读取 FPGA 文件、解析器、声部和音色状态")
    status.add_argument("--port", required=True)
    ftb = sub.add_parser("upload-ftb", help="上传单周期 FTB 音色波表")
    ftb.add_argument("--port", required=True)
    ftb.add_argument("file", type=Path)

    args = parser.parse_args()
    if args.command == "ports":
        for name, description in list_serial_ports():
            print(f"{name}\t{description}")
        return 0

    if args.command == "scan-ping":
        # 该板 FT2232 通道 A 是 JTAG，B 才是 FPGA UART。历史实测向 A 写入后
        # JTAG 曾暂时无法打开，因此默认只探测 B。include-all 可显式覆盖此限制。
        candidates = []
        for port in list_ports.comports():
            description = port.description or ""
            serial_number = (port.serial_number or "").upper()
            is_jtag_a = (
                port.vid == 0x0403 and port.pid == 0x6010 and serial_number.endswith("A")
            )
            if args.include_all or (
                ("USB Serial" in description or "FTDI" in description) and not is_jtag_a
            ):
                candidates.append((port.device, description))
        if not candidates:
            print("没有找到可尝试的串口", file=sys.stderr)
            return 1
        for name, description in candidates:
            print(f"尝试 {name} ({description}) ...", flush=True)
            try:
                with FpgaSerialLink(name) as link:
                    nonce = link.ping()
                print(f"FOUND {name} ACK nonce=0x{nonce:08X}")
                return 0
            except (OSError, RuntimeError, TimeoutError, ValueError) as exc:
                print(f"  无响应：{exc}")
        print("没有端口返回 FPGA ACK。请确认已烧录 uart_ping_echo_sram.fs。", file=sys.stderr)
        return 1

    if args.command == "listen-diag":
        if args.seconds <= 0:
            print("error: --seconds 必须大于 0", file=sys.stderr)
            return 1
        try:
            # 固定字符串诊断不使用二进制帧协议，直接读取 115200/8N1 原始字节。
            with serial.Serial(args.port, 115200, timeout=0.1) as port:
                port.reset_input_buffer()
                if args.probe_rx:
                    port.write(b"X")
                    port.flush()
                    print("已发送 X；请观察 PMOD0 LED1 是否翻转", flush=True)
                deadline = time.monotonic() + args.seconds
                received = bytearray()
                while time.monotonic() < deadline:
                    received.extend(port.read(port.in_waiting or 1))
                    if b"UART_LINK_OK\r\n" in received:
                        print(f"收到诊断字符串：{bytes(received)!r}")
                        return 0
                print(f"未收到诊断字符串；原始数据：{bytes(received)!r}", file=sys.stderr)
                return 1
        except (OSError, serial.SerialException) as exc:
            print(f"error: {exc}", file=sys.stderr)
            return 1

    try:
        with FpgaSerialLink(args.port) as link:
            if args.command == "ping":
                nonce = link.ping()
                print(f"ACK nonce=0x{nonce:08X}")
            elif args.command == "send-midi":
                data = args.file.read_bytes()
                link.ping()
                link.send_midi_file(data, timbre_id=args.timbre, start_play=args.play)
                if args.play:
                    print(f"uploaded {len(data)} bytes and requested PLAY")
                else:
                    print(f"uploaded {len(data)} bytes; use the play command to start")
            elif args.command == "stop":
                link.stop()
                print("STOP acknowledged")
            elif args.command == "play":
                link.play(args.timbre)
                print("PLAY acknowledged")
            elif args.command == "upload-ftb":
                data = args.file.read_bytes()
                decode_ftb(data)
                link.ping()
                link.upload_ftb(data)
                print(f"uploaded {len(data)} byte FTB wavetable")
            elif args.command == "status":
                values = link.status()
                print(" ".join(f"{key}={value}" for key, value in values.items()))
    except (OSError, RuntimeError, TimeoutError, ValueError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
