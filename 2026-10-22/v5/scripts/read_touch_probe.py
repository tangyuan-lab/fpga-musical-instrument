"""监听 Tang Mega 60K USB 触摸探针的串口枚举信息。"""

from __future__ import annotations

import argparse
import threading
import time

import serial
from serial.tools import list_ports


def candidate_ports(requested: list[str]) -> list[str]:
    if requested:
        return requested

    devices: list[str] = []
    for port in list_ports.comports():
        is_ftdi_2232 = port.vid == 0x0403 and port.pid == 0x6010
        if is_ftdi_2232 or "USB Serial Port" in (port.description or ""):
            devices.append(port.device)
    return devices


def listen(port_name: str, stop: threading.Event) -> None:
    try:
        with serial.Serial(port_name, 115200, timeout=0.2) as port:
            port.dtr = False
            port.rts = False
            print(f"[{port_name}] Opened at 115200/8N1.", flush=True)
            pending = bytearray()
            while not stop.is_set():
                data = port.read(port.in_waiting or 1)
                if not data:
                    continue
                pending.extend(data)
                if len(pending) > 4096 and b"\n" not in pending:
                    pending.clear()
                while b"\n" in pending:
                    raw_line, _, pending = pending.partition(b"\n")
                    raw_line = raw_line.rstrip(b"\r")
                    if raw_line:
                        printable = sum(byte == 9 or 32 <= byte < 127 for byte in raw_line)
                        if printable * 4 >= len(raw_line) * 3:
                            line = raw_line.decode("ascii", errors="replace")
                            print(f"[{port_name}] {line}", flush=True)
    except serial.SerialException as exc:
        print(f"[{port_name}] Cannot open: {exc}", flush=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("ports", nargs="*", help="可选，例如 COM14 COM15")
    parser.add_argument("--seconds", type=int, default=90, help="监听时间，默认 90 秒")
    args = parser.parse_args()

    ports = candidate_ports(args.ports)
    if not ports:
        print("No FTDI serial ports found. Check the board USB-C connection.")
        return 1

    print("Unplug and reconnect the touch USB cable to USB-A2 now.")
    stop = threading.Event()
    threads = [threading.Thread(target=listen, args=(name, stop), daemon=True) for name in ports]
    for thread in threads:
        thread.start()

    try:
        time.sleep(max(1, args.seconds))
    except KeyboardInterrupt:
        pass
    finally:
        stop.set()
        for thread in threads:
            thread.join(timeout=1)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
