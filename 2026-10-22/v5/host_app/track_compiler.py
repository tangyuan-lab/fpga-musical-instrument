"""源轨道编译候选：16个归属、16个共享通道；未接入旧四声部上传路径。

每轨按同音重叠深度占用若干静态MIDI通道，各通道共享归属、角色和混音值。
这里生成完整Type0文件，仍由FPGA解析绝对起止时间；不下发PCM或实时逐音符流。
"""
from __future__ import annotations

import copy
import io
import math
import struct
import uuid
from dataclasses import asdict, dataclass

from .device_v2 import display_name
from .music_project import PARTS, Song
from .source_tracks import device_song

TRACK_FORMAT = 1
MAX_OWNERS = 16
MAX_CHANNELS = 16
UNITY = 32768


def gain_q15(db):
    db = float(db)
    if not math.isfinite(db) or not -120 <= db <= 6:
        raise ValueError('轨道音量范围为静音至+6 dB')
    return 0 if db <= -90 else round(UNITY * 10 ** (db / 20))


@dataclass(frozen=True)
class Owner:
    index: int
    track_id: str
    name: str
    role: int
    gain: int
    mute: bool
    solo: bool
    legacy_velocity: int = 100


@dataclass(frozen=True)
class TrackCompilation:
    midi: bytes
    owners: tuple[Owner, ...]
    channel_owners: tuple[int, ...]  # FF表示未使用；channel9也按此映射，不猜测鼓轨。
    note_channels: dict[str, int]
    peak_notes: int
    peak_melodic_notes: int
    peak_tick: int
    duration: int
    sections: bytes

    def metadata(self):
        """候选资源WSMX/1。发布前须与MIDI和配器一起校验，旧位流不能接收。"""
        # 16字节头、16字节静态通道表，每轨56字节；尾部无可变长度字段。
        data = bytearray(struct.pack('<4sBBBBII', b'WSMX', TRACK_FORMAT, len(self.owners),
                                     sum(o != 255 for o in self.channel_owners), 0,
                                     len(self.note_channels), self.duration))
        data.extend(self.channel_owners)
        for owner in self.owners:
            data.extend(struct.pack('<16s32sHBBBBH', uuid.UUID(owner.track_id).bytes,
                                    display_name(owner.name), owner.gain, owner.role,
                                    owner.mute, owner.solo, owner.legacy_velocity, 0))
        return bytes(data)

    def report(self):
        return dict(format=TRACK_FORMAT, owners=[asdict(o) for o in self.owners],
                    channels=list(self.channel_owners), notes=len(self.note_channels),
                    peak_notes=self.peak_notes, peak_melodic_notes=self.peak_melodic_notes, peak_tick=self.peak_tick,
                    midi_bytes=len(self.midi), metadata_bytes=len(self.metadata()),
                    duration=self.duration, integrated_firmware=False)


def decode_metadata(data):
    """严格检查候选元数据，供协议/RTL一致性测试；不发布目录。"""
    if len(data) < 32:
        raise ValueError('轨道资源长度不足')
    magic, version, count, lanes, reserved, notes, duration = struct.unpack_from('<4sBBBBII', data)
    if magic != b'WSMX' or version != TRACK_FORMAT or reserved or not 1 <= count <= MAX_OWNERS:
        raise ValueError('轨道资源头无效')
    if len(data) != 32 + count * 56 or not 1 <= lanes <= MAX_CHANNELS or not 1 <= notes <= 2048:
        raise ValueError('轨道资源容量或长度错误')
    channels = tuple(data[16:32])
    if any(o != 255 and o >= count for o in channels) or sum(o != 255 for o in channels) != lanes:
        raise ValueError('通道归属表无效')
    owners = []
    for i in range(count):
        identifier, name, gain, role, mute, solo, legacy, unused = struct.unpack_from('<16s32sHBBBBH', data, 32 + i * 56)
        if role > 3 or mute > 1 or solo > 1 or legacy > 100 or gain > gain_q15(6) or unused:
            raise ValueError('轨道参数超出范围')
        if i not in channels:
            raise ValueError('源轨道没有播放通道')
        owners.append(Owner(i, str(uuid.UUID(bytes=identifier)),
                            name.split(b'\0')[0].decode('gb2312'), role, gain, bool(mute), bool(solo), legacy))
    if len({o.track_id for o in owners}) != count:
        raise ValueError('源轨道ID重复')
    return owners, channels, notes, duration


def _legacy_owners(song):
    mix = song.track_mix
    return [Owner(i, str(uuid.uuid5(uuid.UUID(song.resource_id), f'part:{i}')), PARTS[i], i,
                  gain_q15(mix.get(f'part:{i}', {}).get('db', 0)),
                  bool(mix.get(f'part:{i}', {}).get('mute', False)),
                  bool(mix.get(f'part:{i}', {}).get('solo', False))) for i in range(4)]


def compile_tracks(song: Song, *, allow_uncertain=False):
    """先校验再编译。容量报错不会修改工程、裁音符或量化时间。

    每轨首通道固定，额外通道只解决同轨同音高的重叠；不同音高能共享通道。
    对所有轨静态预留通道，因此控制器/尾音不会因通道重用串到别的轨道。
    """
    import mido
    if song.source_tracks:
        timeline = device_song(song, allow_uncertain=allow_uncertain)
        owners = []
        for index, track in enumerate(song.source_tracks):
            if not isinstance(track.reference_volume, int) or not 0 <= track.reference_volume <= 100:
                raise ValueError(f'{track.name} 的兼容力度参数应为0～100')
            owners.append(Owner(index, track.track_id, track.name, track.device_part,
                                gain_q15(track.gain_db), bool(track.preview_muted),
                                bool(track.preview_solo), track.reference_volume))
        note_owners = {n.note_id: next((o.index for o in owners if o.track_id == n.track_id), -1) for n in song.notes}
    else:
        timeline = copy.deepcopy(song)
        if allow_uncertain:
            for note in timeline.notes:note.uncertain = False
        owners = _legacy_owners(song)
        note_owners = {n.note_id: n.part for n in song.notes}
    # 与旧上传路径共享容量/音符/段落/谱面校验，只把同音重叠交给下面的通道分配。
    timeline._validate_timeline(independent_channels=True)
    if len(owners) > MAX_OWNERS:
        raise ValueError(f'设备最多16个源轨道，当前{len(owners)}个；电脑工程仍完整保留')
    if len(note_owners) != len(song.notes) or any(not n.note_id for n in song.notes):
        raise ValueError('音符ID重复或为空，无法分配独立通道')
    try:
        ids = [uuid.UUID(o.track_id) for o in owners]
    except ValueError as exc:
        raise ValueError('设备源轨道ID必须为UUID') from exc
    if len(set(ids)) != len(owners):raise ValueError('源轨道ID重复')
    if any(i < 0 or i >= len(owners) for i in note_owners.values()):
        raise ValueError('音符缺少源轨道归属')

    # 为每个音高做区间着色；同一轨道不同音高复用同一组lane。
    local_lanes = {}; counts = [1] * len(owners); triggers = {}
    endings = {}
    for note in sorted(song.notes, key=lambda n: (n.start, n.end, n.note_id)):
        owner = note_owners[note.note_id]
        occupied = endings.setdefault((owner, note.pitch), [])
        lane = next((i for i, end in enumerate(occupied) if end <= note.start), len(occupied))
        if lane == len(occupied):occupied.append(note.end)
        else:occupied[lane] = note.end
        local_lanes[note.note_id] = lane
        if lane + 1 > counts[owner]:
            counts[owner] = lane + 1; triggers[owner] = (note.start, note.end, note.pitch)
    if sum(counts) > MAX_CHANNELS:
        details = []
        for owner in owners:
            at = triggers.get(owner.index)
            interval = f'，tick {at[0]}～{at[1]}，音高{at[2]}' if at else ''
            details.append(f'{owner.name}需{counts[owner.index]}通道{interval}')
        raise ValueError(f'共需{sum(counts)}个通道，设备只有16个：' + '；'.join(details))
    channel_owners = []; offsets = []
    for owner in owners:
        offsets.append(len(channel_owners));channel_owners.extend([owner.index] * counts[owner.index])
    channel_owners.extend([255] * (16 - len(channel_owners)))
    channels = {identifier: offsets[note_owners[identifier]] + lane for identifier, lane in local_lanes.items()}

    events = []
    for tick, tempo in timeline.tempos:events.append((tick, 0, mido.MetaMessage('set_tempo', tempo=tempo)))
    for tick, a, b in timeline.meter_changes or [[0, timeline.numerator, timeline.denominator]]:
        if tick < 0 or a < 1 or a > 255 or b not in (1, 2, 4, 8, 16, 32, 64, 128):
            raise ValueError('设备拍号表无效')
        events.append((tick, 0, mido.MetaMessage('time_signature', numerator=a, denominator=b)))
    peak = 0; peak_tick = 0; active = 0; boundaries = []; melody_boundaries = []
    for note in timeline.notes:
        channel = channels[note.note_id]
        # 兼容旧工程的力度缩放保存在元数据；MIDI仍保留原始力度。
        events.extend([(note.start, 2, mido.Message('note_on', channel=channel, note=note.pitch, velocity=note.velocity)),
                       (note.end, 1, mido.Message('note_off', channel=channel, note=note.pitch, velocity=0))])
        boundaries.extend([(note.start, 1), (note.end, -1)])
        section = next(s for s in timeline.sections if s.start <= note.start < s.end)
        if note.part != 3 or section.timbres[3] >= 2:
            melody_boundaries.extend([(note.start, 1), (note.end, -1)])
    for tick, delta in sorted(boundaries):
        active += delta
        peak = max(peak, active)
    active = 0; peak_melody = 0
    for tick, delta in sorted(melody_boundaries):
        active += delta
        if active > peak_melody:peak_melody = active;peak_tick = tick
    if peak_melody > 28:
        raise ValueError(f'tick {peak_tick} 同时有{peak_melody}个乐谱旋律音符；设备需为实时演奏保留4个旋律声部，请调整配器')
    output = mido.MidiFile(type=0, ticks_per_beat=timeline.ppqn);track=mido.MidiTrack();output.tracks.append(track);last=0
    for tick, _, message in sorted(events, key=lambda row: row[:2]):
        # 标准SMF的delta为28位；大间隔必须明确报错，不能写入硬件无法解析的VLQ。
        if tick - last > 0x0fffffff:raise ValueError('事件间隔超出MIDI四字节VLQ范围')
        track.append(message.copy(time=tick-last));last=tick
    if timeline.duration - last > 0x0fffffff:raise ValueError('曲尾间隔超出MIDI四字节VLQ范围')
    track.append(mido.MetaMessage('end_of_track', time=timeline.duration-last))
    stream=io.BytesIO();output.save(file=stream)
    if len(stream.getvalue()) > 65536:raise ValueError('当前歌曲原始MIDI超过共享64KiB缓存')
    sections = b''.join(struct.pack('<II4B4BBBBbHH', s.start, s.end, *s.timbres, *s.volumes,
                                   s.mute, s.solo, s.live_timbre, s.transpose, 0, 0) for s in timeline.sections)
    result = TrackCompilation(stream.getvalue(), tuple(owners), tuple(channel_owners), channels,
                              peak, peak_melody, peak_tick, timeline.duration, sections)
    decode_metadata(result.metadata())
    return result


def capacity_text(compilation):
    lines = ['16轨候选编译检查通过（尚未接入当前固件上传路径）',
             '待确认内容仅供检查；下发仍须通过校谱确认与固件能力校验。',
             f'源轨：{len(compilation.owners)}/16；共享通道：{sum(o != 255 for o in compilation.channel_owners)}/16',
             f'音符：{len(compilation.note_channels)}/2048；同时旋律音：{compilation.peak_melodic_notes}/28（另留4个实时声部）',
             f'MIDI：{len(compilation.midi)}字节；独立轨道元数据：{len(compilation.metadata())}字节', '']
    for owner in compilation.owners:
        channels = '、'.join(str(i+1) for i, value in enumerate(compilation.channel_owners) if value == owner.index)
        db = '静音' if not owner.gain else f'{20*math.log10(owner.gain/UNITY):.1f} dB'
        lines.append(f'{owner.name} → {PARTS[owner.role]}；通道{channels}；{db}'
                     + ('；静音开启' if owner.mute else '') + ('；独奏开启' if owner.solo else ''))
    return '\n'.join(lines)
