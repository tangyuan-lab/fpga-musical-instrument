"""FTB 单周期音色文件读写工具。"""

from __future__ import annotations

from dataclasses import dataclass
import struct

FTB_MAGIC = b"FTB1"
WAVETABLE_POINTS = 256


@dataclass
class Timbre:
    name: str
    waveform: list[int]
    attack: int = 32
    release: int = 16


def encode_ftb(timbre: Timbre) -> bytes:
    if len(timbre.waveform) != WAVETABLE_POINTS:
        raise ValueError("FTB wave table must contain exactly 256 points")
    if any(value < -32768 or value > 32767 for value in timbre.waveform):
        raise ValueError("FTB samples must be signed int16")
    if not 1 <= timbre.attack <= 255:
        raise ValueError("FTB attack step must be 1..255")
    if not 1 <= timbre.release <= 255:
        raise ValueError("FTB release step must be 1..255")
    name = timbre.name.encode("utf-8")[:31]
    name = name + b"\0" * (32 - len(name))
    header = struct.pack("<4sBBBB32s", FTB_MAGIC, 1, 8, timbre.attack, timbre.release, name)
    return header + struct.pack("<256h", *timbre.waveform)


def decode_ftb(data: bytes) -> Timbre:
    if len(data) != 4 + 4 + 32 + 512 or data[:4] != FTB_MAGIC:
        raise ValueError("invalid FTB file")
    _, version, points_log2, attack, release, raw_name = struct.unpack_from("<4sBBBB32s", data)
    if version != 1 or points_log2 != 8:
        raise ValueError("unsupported FTB version or table size")
    name = raw_name.split(b"\0", 1)[0].decode("utf-8", errors="replace")
    waveform = list(struct.unpack_from("<256h", data, 40))
    return Timbre(name, waveform, attack, release)
