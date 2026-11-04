"""FluidSynth 参考试听。只写电脑缓存；此模块不导入串口和设备协议。"""
from pathlib import Path
import hashlib, json, os, subprocess, tempfile, threading, wave
import mido
from .preview_audio import TempoMap,PreviewResult,_check_cancel

ROOT=Path(__file__).resolve().parents[1]
TOOLS=ROOT/'build/tools/music'

def resources(soundfont=None):
    manifest=TOOLS/'manifest.json'
    if not manifest.exists():raise ValueError('参考音色未准备：运行 python scripts/prepare_music_stack.py')
    data=json.loads(manifest.read_text(encoding='utf-8'));exe=ROOT/data['fluidsynth'];font=Path(soundfont or ROOT/data['soundfont'])
    if not exe.is_file() or not font.is_file():raise ValueError('找不到 FluidSynth 或 SoundFont，请重新准备电脑音乐组件')
    return exe,font

def presets(path):
    """读 SF2/SF3 的 phdr 目录，声音解码交给 FluidSynth。"""
    import struct
    with Path(path).open('rb') as source:
        header=source.read(12)
        if len(header)!=12 or header[:4]!=b'RIFF' or header[8:]!=b'sfbk':raise ValueError('需要有效 SF2/SF3 SoundFont')
        ending=min(Path(path).stat().st_size,8+int.from_bytes(header[4:8],'little'));block=b''
        while source.tell()+8<=ending:
            tag,length=struct.unpack('<4sI',source.read(8));start=source.tell();end=start+length
            if end>ending:raise ValueError('SoundFont 块长度无效')
            if tag==b'LIST' and length>=4 and source.read(4)==b'pdta':
                while source.tell()+8<=end:
                    child,size=struct.unpack('<4sI',source.read(8));position=source.tell()
                    if position+size>end:raise ValueError('SoundFont 目录长度无效')
                    if child==b'phdr':block=source.read(size);break
                    source.seek(position+size+(size&1))
            if block:break
            source.seek(end+(length&1))
    if not block:raise ValueError('SoundFont 缺少音色目录')
    if len(block)%38:raise ValueError('SoundFont 音色目录损坏')
    return [(bank,program,name.split(b'\0')[0].decode('latin-1')) for name,program,bank,*_ in struct.iter_unpack('<20sHHHIII',block[:-38])]

def reference_midi(song,muted=(),solo=()):
    """按相同配器规则编译参考演奏，允许待确认音符，不改确认标志。"""
    if song.source_tracks:
        from .source_tracks import reference_midi as compile_reference
        return compile_reference(song,muted,solo)
    events=[];muted,solo=set(muted),set(solo)
    for tick,tempo in song.tempos:events.append((tick,0,mido.MetaMessage('set_tempo',tempo=tempo)))
    for part,program in enumerate(song.reference_programs):
        events.append((0,0,mido.Message('program_change',channel=9 if part==3 else part,program=program)))
    for n in song.notes:
        if not (0<=n.start<n.end and 0<=n.pitch<128 and 1<=n.velocity<128 and 0<=n.part<4):raise ValueError('请修正无效音符后再试听')
        if n.part in muted or solo and n.part not in solo:continue
        section=next((s for s in song.sections if s.start<=n.start<s.end),None)
        if section and ((section.mute>>n.part)&1 or section.solo and not ((section.solo>>n.part)&1)):continue
        pitch=max(0,min(127,n.pitch+(section.transpose if section and n.part!=3 else 0)))
        level=section.volumes[n.part] if section else 100;velocity=round(n.velocity*level/100)
        if velocity<=0:continue
        channel=9 if n.part==3 else n.part
        events.extend([(n.start,2,mido.Message('note_on',channel=channel,note=pitch,velocity=max(1,min(127,velocity)))),
                       (n.end,1,mido.Message('note_off',channel=channel,note=pitch,velocity=0))])
    track=mido.MidiTrack();last=0
    for tick,_,message in sorted(events,key=lambda x:(x[0],x[1])):
        track.append(message.copy(time=tick-last));last=tick
    track.append(mido.MetaMessage('end_of_track',time=max(0,song.duration-last)))
    result=mido.MidiFile(type=0,ticks_per_beat=song.ppqn);result.tracks.append(track);return result

_font_hashes={}
def render_reference(song,patches=(),cache_dir=None,muted=(),solo=(),sample_rate=44100,cancel=None,soundfont=None):
    exe,font=resources(soundfont);clock=TempoMap(song);seconds=clock.to_seconds(song.duration)
    if not song.notes or seconds>1200:raise ValueError('参考试听需要有效音符，最长20分钟')
    stat=font.stat();stamp=(str(font.resolve()),stat.st_size,stat.st_mtime_ns)
    if stamp not in _font_hashes:_font_hashes[stamp]=hashlib.sha256(font.read_bytes()).hexdigest()
    midi=reference_midi(song,muted,solo)
    import io
    stream=io.BytesIO();midi.save(file=stream);midi_bytes=stream.getvalue()
    digest=hashlib.sha256(midi_bytes+f'FluidSynth-2.6.1:{_font_hashes[stamp]}:{sample_rate}:reference-v1'.encode()).hexdigest()
    folder=Path(cache_dir or ROOT/'build/cache/reference_audio');folder.mkdir(parents=True,exist_ok=True)
    target=folder/(digest+'.wav');_check_cancel(cancel)
    if not target.exists():
        with tempfile.TemporaryDirectory(prefix='render_',dir=folder) as directory:
            source=Path(directory)/'reference.mid';output=Path(directory)/'reference.wav';source.write_bytes(midi_bytes)
            # 不启用播放器驱动；离线渲染后沿用 Qt 的暂停、定位、循环和输出设备。
            command=[str(exe),'-ni','-R','0','-C','0','-g','0.6','-r',str(sample_rate),'-T','wav','-O','s16','-F',str(output),str(font),str(source)]
            with (Path(directory)/'render.log').open('wb') as log:
                process=subprocess.Popen(command,stdout=log,stderr=log,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
                try:
                    while process.poll() is None:
                        if cancel is not None and cancel.wait(.05):raise InterruptedError('参考试听已取消')
                        if cancel is None:
                            try:process.wait(.05)
                            except subprocess.TimeoutExpired:pass
                    if process.returncode:raise ValueError('FluidSynth 渲染失败：'+(Path(directory)/'render.log').read_text(errors='replace')[-1200:])
                    _check_cancel(cancel);os.replace(output,target)
                finally:
                    if process.poll() is None:process.terminate();process.wait(timeout=5)
    with wave.open(str(target)) as audio:duration=audio.getnframes()/audio.getframerate()
    return PreviewResult(target,duration,sample_rate,len(song.notes),0.)
