"""生成上板联调用的小型 MIDI Type 0 与 FTB 单周期音色文件。"""

from __future__ import annotations

import math
from pathlib import Path
import struct
import sys

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from host_app.timbre_file import Timbre, encode_ftb  # noqa: E402

PPQN = 480


def vlq(value: int) -> bytes:
    """把非负整数编码为 MIDI 可变长度数。"""

    if value < 0 or value > 0x0FFFFFFF:
        raise ValueError("MIDI VLQ value is out of range")
    encoded = bytearray((value & 0x7F,))
    value >>= 7
    while value:
        encoded.insert(0, 0x80 | (value & 0x7F))
        value >>= 7
    return bytes(encoded)


def midi_file(track: bytes, ppqn: int = PPQN) -> bytes:
    """给轨道事件加上标准 MIDI Type 0 文件头。"""

    header = b"MThd" + struct.pack(">IHHH", 6, 0, 1, ppqn)
    return header + b"MTrk" + struct.pack(">I", len(track)) + track


def tempo_event(delta: int, microseconds_per_quarter: int) -> bytes:
    return vlq(delta) + b"\xFF\x51\x03" + microseconds_per_quarter.to_bytes(3, "big")


def note_on(delta: int, note: int, velocity: int) -> bytes:
    return vlq(delta) + bytes((0x90, note, velocity))


def note_off(delta: int, note: int) -> bytes:
    return vlq(delta) + bytes((0x80, note, 0))


def end_of_track(delta: int = 0) -> bytes:
    return vlq(delta) + b"\xFF\x2F\x00"


def make_single_note() -> bytes:
    track = tempo_event(0, 500_000)
    track += note_on(0, 60, 88)
    track += note_off(PPQN, 60)
    track += end_of_track()
    return midi_file(track)


def make_long_note() -> bytes:
    """C4 持续 10 秒，便于观察播放状态并听测耳机输出。"""

    track = tempo_event(0, 500_000)
    track += note_on(0, 60, 88)
    track += note_off(PPQN * 20, 60)
    track += end_of_track()
    return midi_file(track)


def make_four_voice_chords() -> bytes:
    """依次演奏 Cmaj7、Fmaj7、G7、Am7，验证四声部并行。"""

    chords = (
        (60, 64, 67, 71),
        (53, 57, 60, 64),
        (55, 59, 62, 65),
        (57, 60, 64, 67),
    )
    track = bytearray(tempo_event(0, 600_000))
    for chord in chords:
        for note in chord:
            track.extend(note_on(0, note, 78))
        for index, note in enumerate(chord):
            track.extend(note_off(PPQN if index == 0 else 0, note))
    track.extend(end_of_track())
    return midi_file(bytes(track))


def make_tempo_change_scale() -> bytes:
    """前四个音 120 BPM，后四个音 180 BPM，验证 Tempo 变化。"""

    notes = (60, 62, 64, 65, 67, 69, 71, 72)
    track = bytearray(tempo_event(0, 500_000))
    for index, note in enumerate(notes):
        track.extend(note_on(0, note, 84))
        track.extend(note_off(PPQN // 2, note))
        if index == 3:
            track.extend(tempo_event(0, 333_333))
    track.extend(end_of_track())
    return midi_file(bytes(track))


def make_soft_sine() -> bytes:
    waveform = [round(24_000 * math.sin(2 * math.pi * index / 256)) for index in range(256)]
    return encode_ftb(Timbre("Soft Sine", waveform, attack=24, release=12))


def make_bright_harmonic() -> bytes:
    raw = []
    for index in range(256):
        phase = 2 * math.pi * index / 256
        raw.append(math.sin(phase) + 0.50 * math.sin(2 * phase) + 0.25 * math.sin(3 * phase))
    peak = max(abs(value) for value in raw)
    waveform = [round(28_000 * value / peak) for value in raw]
    return encode_ftb(Timbre("Bright Harmonic", waveform, attack=36, release=18))


def generate_assets(output_root: Path) -> list[Path]:
    midi_dir = output_root / "midi"
    timbre_dir = output_root / "timbres"
    midi_dir.mkdir(parents=True, exist_ok=True)
    timbre_dir.mkdir(parents=True, exist_ok=True)
    assets = {
        midi_dir / "01_single_note.mid": make_single_note(),
        midi_dir / "02_four_voice_chords.mid": make_four_voice_chords(),
        midi_dir / "03_tempo_change_scale.mid": make_tempo_change_scale(),
        midi_dir / "04_long_note_10s.mid": make_long_note(),
        timbre_dir / "soft_sine.ftb": make_soft_sine(),
        timbre_dir / "bright_harmonic.ftb": make_bright_harmonic(),
    }
    for path, data in assets.items():
        path.write_bytes(data)
    return list(assets)


def main() -> None:
    paths = generate_assets(ROOT / "examples")
    for path in paths:
        print(f"generated {path.relative_to(ROOT)} ({path.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
