"""本机校谱试听：只生成电脑缓存，不参与 FPGA 传输，也不替代硬件验收。"""
from __future__ import annotations

from bisect import bisect_right
from dataclasses import dataclass
from pathlib import Path
import hashlib
import json
import os
import threading
import uuid
import wave

import numpy as np

from .music_project import FS, Note, Patch, Song


class TempoMap:
    """tick 与实际秒数双向换算，速度单位为微秒/四分音符。"""
    def __init__(self, song: Song):
        if song.ppqn <= 0 or not song.tempos or song.tempos[0][0] != 0:
            raise ValueError('速度表必须从 0 开始，PPQN 必须大于 0')
        self.ppqn = song.ppqn
        self.ticks, self.seconds, self.tempos = [], [], []
        for tick, tempo in song.tempos:
            if tick < 0 or tempo <= 0 or (self.ticks and tick <= self.ticks[-1]):
                raise ValueError('速度变化位置必须递增，速度必须大于 0')
            seconds = 0 if not self.ticks else self.seconds[-1] + (tick-self.ticks[-1])*self.tempos[-1]/(1e6*self.ppqn)
            self.ticks.append(tick); self.seconds.append(seconds); self.tempos.append(tempo)

    def to_seconds(self, tick):
        tick = max(0, tick); i = max(0, bisect_right(self.ticks, tick)-1)
        return self.seconds[i]+(tick-self.ticks[i])*self.tempos[i]/(1e6*self.ppqn)

    def to_tick(self, seconds):
        seconds = max(0, seconds); i = max(0, bisect_right(self.seconds, seconds)-1)
        return self.ticks[i]+(seconds-self.seconds[i])*1e6*self.ppqn/self.tempos[i]


@dataclass(frozen=True)
class PreviewResult:
    path: Path
    seconds: float
    sample_rate: int
    notes: int
    peak: float


def _check_cancel(cancel):
    if cancel is not None and cancel.is_set():
        raise InterruptedError('试听已取消')


def _envelope(times, held, parameters):
    attack, decay, sustain, release = parameters
    # 与设备参数使用同一物理含义；本机不模拟 FPGA 定点截位和声部分配。
    attack_s = 4095 / (max(1, attack)*FS)
    level = sustain/4095
    def on(t):
        return np.where(t < attack_s, t/attack_s,
                        np.maximum(level, 1-(t-attack_s)*max(1, decay)*FS/4095))
    release_s = 4095 / (max(1, release)*FS)
    return np.maximum(0, np.where(times < held, on(times), on(held)-(times-held)/release_s))


def render_preview(song: Song, patches: list[Patch], cache_dir=None,
                   muted=(), solo=(), sample_rate=44100, cancel: threading.Event | None=None):
    """允许未确认识谱音符试听；下发仍走 Song.validate，不会自动确认或改写原工程。

    按段落读取音色/音量/移调，另外叠加仅本机的静音与独奏。缓存键含全部演奏参数。
    最长 20 分钟，超限明确报错；不截断曲谱。WAV 为单声道 16 位，仅在本机播放。
    """
    if song.source_tracks:
        from .source_tracks import device_song
        song=device_song(song,allow_uncertain=True)
    if not song.notes: raise ValueError('没有可试听音符，请等待识谱或双击卷帘添加音符')
    if not 8000 <= sample_rate <= 96000: raise ValueError('试听采样率超出范围')
    clock = TempoMap(song)
    for n in song.notes:
        if not (0 <= n.start < n.end and 0 <= n.pitch <= 127 and 1 <= n.velocity <= 127 and 0 <= n.part < 4):
            raise ValueError(f'请先修正无效音符：{n}')
    for section in song.sections:
        if (len(section.timbres) != 4 or len(section.volumes) != 4 or
            any(not 0 <= p <= 9 for p in section.timbres) or any(not 0 <= v <= 100 for v in section.volumes)):
            raise ValueError('请先修正段落配器参数')
    seconds = clock.to_seconds(song.duration)+.35
    if seconds > 1200: raise ValueError('本机单次试听最多 20 分钟，请拆分长曲谱')
    muted, solo = set(muted), set(solo)
    # 确认识谱/改名称不改变声音，避免每次确认音符都重新生成整曲音频。
    payload = dict(version=2, ppqn=song.ppqn, tempos=song.tempos, duration=song.duration,
                   notes=[(n.start,n.end,n.pitch,n.velocity,n.part) for n in song.notes],
                   sections=[(s.start,s.end,s.timbres,s.volumes,s.mute,s.solo,s.transpose) for s in song.sections],
                   patches=[(p.waveform,p.attack,p.decay,p.sustain,p.release) for p in patches],
                   muted=sorted(muted), solo=sorted(solo), sample_rate=sample_rate)
    key = hashlib.sha256(json.dumps(payload, sort_keys=True, ensure_ascii=False).encode()).hexdigest()
    folder = Path(cache_dir or Path(__file__).resolve().parents[1]/'build/cache/preview_audio')
    folder.mkdir(parents=True, exist_ok=True); path = folder/(key+'.wav'); meta = folder/(key+'.json')
    _check_cancel(cancel)
    if path.exists() and meta.exists():
        data = json.loads(meta.read_text(encoding='utf-8'))
        return PreviewResult(path, data['seconds'], sample_rate, data['notes'], data['peak'])
    audio = np.zeros(int(np.ceil(seconds*sample_rate)), dtype=np.float32)
    count = 0
    for n in song.notes:
        _check_cancel(cancel)
        section = next((s for s in song.sections if s.start <= n.start < s.end), None)
        if n.part in muted or (solo and n.part not in solo): continue
        if section and ((section.mute >> n.part)&1 or (section.solo and not ((section.solo >> n.part)&1))): continue
        bank = section.timbres[n.part] if section else (1 if n.part == 0 else 0)
        volume = section.volumes[n.part]/100 if section else 1
        transpose = section.transpose if section else 0
        pitch = max(0, min(127, n.pitch+transpose)) if n.part != 3 else n.pitch
        params = (512, 8, 600, 64) if bank == 0 else (64, 8, 3072, 32)
        table = None
        if bank >= 2 and n.part != 3:
            if bank-2 >= len(patches): raise ValueError(f'段落使用了缺失的自定义音色 {bank}，请修改配器或导入音色')
            patch = patches[bank-2]; patch.validate()
            params = (patch.attack, patch.decay, patch.sustain, patch.release)
            table = np.array(patch.waveform, dtype=np.float32)/32768
        start_s, end_s = clock.to_seconds(n.start), clock.to_seconds(n.end)
        start = round(start_s*sample_rate); held = end_s-start_s
        release_s = min(.35, 4095/(max(1, params[3])*FS))
        end = min(len(audio), round((end_s+release_s)*sample_rate))
        freq = 440*2**((pitch-69)/12)
        # 分块生成长持续音，避免单音符产生巨大的临时数组。
        for first in range(start, end, 65536):
            _check_cancel(cancel)
            last = min(first+65536, end); t = (np.arange(first, last)-start)/sample_rate
            phase = np.remainder(t*freq, 1)
            if n.part == 3:
                # 本机鼓音仅用于节奏校对，不声称与设备鼓模型逐样本相同。
                rng = np.random.default_rng(n.start*131+n.pitch+first)
                if pitch in (35, 36): signal = np.sin(2*np.pi*(48*t+5*(1-np.exp(-28*t))))*np.exp(-14*t)
                else: signal = rng.uniform(-1, 1, len(t))*np.exp(-(35 if pitch in (42, 44, 46) else 18)*t)
                signal *= np.minimum(1, t/.001)
            else:
                if table is not None:
                    position = phase*256; index = position.astype(np.int32); weight = position-index
                    signal = table[index]*(1-weight)+table[(index+1)&255]*weight
                elif bank == 0: signal = (1-4*np.abs(phase-.5))+.25*(1-4*np.abs(np.remainder(phase*2, 1)-.5))
                else: signal = np.sin(2*np.pi*phase)+.18*np.sin(4*np.pi*phase)+.08*np.sin(6*np.pi*phase)
                signal *= _envelope(t, held, params)
            audio[first:last] += (signal*(n.velocity/127)*volume*.12).astype(np.float32)
        count += 1
    peak = float(np.max(np.abs(audio)))
    # 只在溢出时整体衰减，保留相对力度，不对静音片段增益。
    if peak > .94: audio *= .94/peak
    tmp = path.with_suffix('.'+uuid.uuid4().hex+'.tmp')
    try:
        with wave.open(str(tmp), 'wb') as stream:
            stream.setnchannels(1); stream.setsampwidth(2); stream.setframerate(sample_rate)
            for first in range(0, len(audio), 65536):
                _check_cancel(cancel)
                stream.writeframes((audio[first:first+65536]*32767).astype('<i2').tobytes())
        _check_cancel(cancel); os.replace(tmp, path)
        data = dict(seconds=seconds, notes=count, peak=peak)
        meta.write_text(json.dumps(data), encoding='utf-8')
    finally:
        tmp.unlink(missing_ok=True)
    return PreviewResult(path, seconds, sample_rate, count, peak)


def format_time(seconds):
    seconds = max(0, int(seconds)); return f'{seconds//60:02d}:{seconds%60:02d}'
