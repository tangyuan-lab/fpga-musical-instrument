"""经USB转TTL直连C18/C19，读取工作站压力状态并选择性发送持续测试音。"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import sys
import time

import serial
from serial.tools import list_ports

END = b'\xff\xff\xff'
MODE_NAMES = {0: '首页', 1: '鼓点', 2: '弹琴', 3: '混音', 4: '实体键设置'}


def command(op: int, value: int) -> bytes:
    """C19五字节控制帧：A5 5A OP VALUE (FF xor OP xor VALUE)，不用于COM15。"""
    if not 0 <= op <= 255 or not 0 <= value <= 255:
        raise ValueError('操作码和参数必须在0..255')
    return bytes((0xA5, 0x5A, op, value, 0xFF ^ op ^ value))


class Telemetry:
    def __init__(self) -> None:
        self.buffer = bytearray()
        self.values: dict[str, int] = {}
        self.minimum: dict[str, int] = {}
        self.maximum: dict[str, int] = {}
        self.frames = 0

    def feed(self, data: bytes) -> None:
        self.buffer.extend(data)
        while END in self.buffer:
            frame, _, tail = self.buffer.partition(END)
            self.buffer = bytearray(tail)
            match = re.search(rb'(rx[A-Za-z0-9]+)\.val=(\d+)$', frame)
            if not match:
                continue  # 刚打开端口可能截到半条命令。
            name = match[1].decode('ascii')
            value = int(match[2])
            self.values[name] = value
            self.minimum[name] = min(self.minimum.get(name, value), value)
            self.maximum[name] = max(self.maximum.get(name, value), value)
            self.frames += 1
        if len(self.buffer) > 8192:
            self.buffer.clear()  # 噪声或错误波特率不应无限占用内存。


def receive(port: serial.Serial, telemetry: Telemetry) -> None:
    telemetry.feed(port.read(port.in_waiting or 1))


def run(args: argparse.Namespace) -> int:
    info = next((p for p in list_ports.comports() if p.device.upper() == args.port.upper()), None)
    if info is None:
        raise ValueError(f'{args.port}不在当前串口列表中')
    # FT2232双通道是板载JTAG/USB文件协议，禁止向它发屏幕控制帧。
    if info.vid == 0x0403 and info.pid == 0x6010:
        raise ValueError('请选择独立USB转TTL端口；不能使用板载COM14/COM15')
    telemetry = Telemetry()
    with serial.Serial(args.port, 115200, timeout=0.05, write_timeout=1) as port:
        port.reset_input_buffer()
        if args.piano or args.tone_seconds:
            port.write(command(2, 255) + command(5, 2))
            deadline = time.monotonic() + 3
            while time.monotonic() < deadline and telemetry.values.get('rxMode') != 2:
                receive(port, telemetry)
            if telemetry.values.get('rxMode') != 2:
                raise TimeoutError('未收到弹琴模式回传，请检查RXD→C18、TXD→C19及共地')
        if args.tone_seconds:
            # 测试音使用屏幕音源，跳过MCP采样；150ms保活，断线后FPGA自行超时停音。
            print(f'发送四音测试，持续{args.tone_seconds:g}秒；此阶段不依赖压力传感器。', flush=True)
            port.write(command(8, 0) + command(9, 80))
            end = time.monotonic() + args.tone_seconds
            next_keepalive = 0.0
            try:
                while time.monotonic() < end:
                    now = time.monotonic()
                    if now >= next_keepalive:
                        port.write(command(4, 1)); next_keepalive = now + 0.15
                    receive(port, telemetry)
            finally:
                port.write(command(4, 0) + command(2, 255))
            print('测试音已停止，保留弹琴模式。', flush=True)
        print(f'读取压力{args.seconds:g}秒，请按压并松开实体键。', flush=True)
        end = time.monotonic() + args.seconds
        next_print = 0.0
        while time.monotonic() < end:
            receive(port, telemetry)
            now = time.monotonic()
            if now >= next_print and telemetry.frames:
                p = [telemetry.values.get(f'rxP{k}') for k in range(16)]
                mode = telemetry.values.get('rxMode')
                flags = telemetry.values.get('rxFlags', 0)
                print(f'模式={MODE_NAMES.get(mode, mode)} 音频就绪={bool(flags & 16)} '
                      f'音符={telemetry.values.get("rxKeys", 0):04X} 压力={p}', flush=True)
                next_print = now + 0.5
    missing = [k for k in range(16) if f'rxP{k}' not in telemetry.values]
    report = {'port': args.port, 'baud': 115200, 'frames': telemetry.frames,
              'values': telemetry.values,
              'pressure_min': [telemetry.minimum.get(f'rxP{k}') for k in range(16)],
              'pressure_max': [telemetry.maximum.get(f'rxP{k}') for k in range(16)],
              'missing_pressure_channels': missing, 'tone_requested_seconds': args.tone_seconds}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(f'记录已保存：{args.out.resolve()}', flush=True)
    if missing:
        raise TimeoutError('没有收到完整16路压力状态，优先检查TTL接线及波特率')
    return 0


def main() -> int:
    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf-8')
        sys.stderr.reconfigure(encoding='utf-8')
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', required=True)
    parser.add_argument('--seconds', type=float, default=8)
    parser.add_argument('--piano', action='store_true', help='先停音并直接切到弹琴模式')
    parser.add_argument('--tone-seconds', type=float, default=0, help='先切弹琴并发送四音测试')
    parser.add_argument('--out', type=Path, default=Path('build/workstation_pressure_probe.json'))
    args = parser.parse_args()
    if not 0 < args.seconds <= 120 or not 0 <= args.tone_seconds <= 30:
        parser.error('读取时间应为0..120秒（不含0）；测试音应为0..30秒')
    try:
        return run(args)
    except (OSError, ValueError, TimeoutError, serial.SerialException) as error:
        print(f'诊断未完成：{error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
