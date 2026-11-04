"""原始轨道与设备声部的边界。导入保留来源，设备映射只修改编译副本。"""
from __future__ import annotations
import copy, hashlib, uuid
from pathlib import Path
from .music_project import Song,Note,Section,SourceTrack


def read_midi(path):
    """按原轨道／通道保留身份与控制事件；不会把channel3以后的轨道合并。"""
    import mido
    path=Path(path);midi=mido.MidiFile(path)
    if midi.type==2:raise ValueError('暂不支持异步 MIDI Type2')
    if midi.ticks_per_beat<=0:raise ValueError('暂不支持 SMPTE MIDI 时间格式')
    song=Song(name=path.stem,ppqn=midi.ticks_per_beat,source_files=[str(path.resolve())],tempos=[])
    fingerprint=hashlib.sha256(path.read_bytes()).hexdigest();events=[];track_names={};tracks={}
    for index,track in enumerate(midi.tracks):
        absolute=0;track_names[index]=f'轨道 {index+1}'
        for order,message in enumerate(track):
            absolute+=message.time
            if message.type=='track_name':track_names[index]=message.name
            events.append((absolute,index,order,message))
    programs={};held={};tempo={0:500000};meters={0:(4,4)};ending=0
    for global_order,(tick,index,order,message) in enumerate(sorted(events,key=lambda row:row[:3])):
        ending=max(ending,tick)
        if message.type=='set_tempo':tempo[tick]=message.tempo;continue
        if message.type=='time_signature':meters[tick]=(message.numerator,message.denominator);continue
        if message.type=='midi_port' and message.port:raise ValueError('暂不支持多端口MIDI，未合并不同端口的同通道音符')
        if message.type=='program_change':programs[message.channel]=message.program
        if (not message.is_meta and message.type not in ('note_on','note_off')) or message.type in ('key_signature','marker','cue_marker','lyrics','text'):
            song.source_midi_events.append(dict(tick=tick,track=index,order=global_order,meta=message.is_meta,message=message.dict()))
        if message.type not in ('note_on','note_off'):continue
        key=(message.channel,message.note);pending=held.setdefault(key,[])
        if message.type=='note_on' and message.velocity:
            identity=(index,message.channel)
            if identity not in tracks:
                identifier=uuid.uuid5(uuid.NAMESPACE_URL,f'{fingerprint}:{index}:{message.channel}').hex
                tracks[identity]=SourceTrack(identifier,track_names[index],f'midi:{index}:{message.channel}',message.channel,
                    programs.get(message.channel,0),message.channel==9)
            track=tracks[identity]
            pending.append((tick,message.velocity,track.track_id,message.channel,global_order))
        elif pending:
            start,velocity,identifier,channel,start_order=pending.pop(0)
            if tick>start:song.notes.append(Note(start,tick,message.note,velocity,3 if channel==9 else min(channel,2),track_id=identifier,source_start_order=start_order,source_end_order=global_order))
    if any(held.values()):song.issues.append('存在未配对起音，按曲尾补齐，须核对')
    for (_,pitch),pending in held.items():
        for start,velocity,identifier,channel,start_order in pending:
            song.notes.append(Note(start,max(start+1,ending),pitch,velocity,3 if channel==9 else min(channel,2),track_id=identifier,uncertain=True))
    song.notes.sort(key=lambda n:(n.start,n.end,n.track_id,n.pitch))
    song.source_tracks=list(tracks.values());song.tempos=[[tick,value] for tick,value in sorted(tempo.items())]
    song.meter_changes=[[tick,*value] for tick,value in sorted(meters.items())]
    song.numerator,song.denominator=meters[0];song.sections=[Section(end=max(song.duration,ending),mute=0)]
    song.issues.append('已保留源轨道和MIDI控制事件；下发前需明确映射设备声部')
    return song


def attach_xml_tracks(song):
    """谱面仍以原XML为准；为可听事件附上原part／staff／voice，不改写谱表。"""
    from .score_document import xml_root
    root=xml_root(song.score_document.current_xml)
    declarations={p.get('id'):p for p in root.findall('part-list/score-part')};origins={};tracks={}
    for part in root.findall('part'):
        pid=part.get('id');declaration=declarations.get(pid)
        name=declaration.findtext('part-name',pid) if declaration is not None else pid
        program=int(declaration.findtext('midi-instrument/midi-program','1'))-1 if declaration is not None else 0
        channel=int(declaration.findtext('midi-instrument/midi-channel','1'))-1 if declaration is not None else 0
        for node in part.iter('note'):
            if node.find('pitch') is None and node.find('unpitched') is None:continue
            staff=node.findtext('staff','1');voice=node.findtext('voice','1');key=f'{pid}:{staff}:{voice}'
            if key not in tracks:
                identifier=uuid.uuid5(uuid.UUID(song.resource_id),key).hex
                tracks[key]=SourceTrack(identifier,f'{name} · 谱表{staff} / 声部{voice}',key,channel,program,channel==9)
            origins[node.get('id')]=key
    for note in song.notes:
        sources=song.score_document.links.get(note.note_id,[note.note_id]);key=None
        for identifier in sources:
            key=origins.get(identifier)
            if key:break
            original=next((value for name,value in sorted(origins.items(),key=lambda row:-len(row[0] or '')) if identifier.startswith((name or '')+'-')),None)
            if original:key=original;break
        if key is None:raise ValueError(f'音符 {note.note_id} 缺少源轨道，未静默合并')
        note.track_id=tracks[key].track_id
    song.source_tracks=list(tracks.values())
    from .score_document import performance_hash
    song.score_document.performance_hash=performance_hash(song)


def device_song(song,allow_uncertain=False):
    """生成四声部设备副本，原始轨道、XML和参考音色保持独立。"""
    if not song.source_tracks:return copy.deepcopy(song)
    tracks={track.track_id:track for track in song.source_tracks}
    if len(tracks)!=len(song.source_tracks):raise ValueError('源轨道ID重复')
    missing=[track.name for track in song.source_tracks if track.device_part not in (0,1,2,3)]
    if missing:raise ValueError('请先映射源轨道到设备声部：'+'、'.join(missing))
    if song.score_document:
        from .score_document import performance_hash,require_device_assumptions
        if song.score_document.errors:raise ValueError('乐谱编译未通过：'+'；'.join(song.score_document.errors))
        if not allow_uncertain:require_device_assumptions(song.score_document)
        if song.score_document.performance_hash!=performance_hash(song):raise ValueError('谱面与编辑事件版本不一致')
    unsupported={event['message']['type'] for event in song.source_midi_events if not event.get('meta') and event['message']['type']!='program_change'}
    if unsupported:raise ValueError('源谱含尚未转换为设备演奏的控制事件：'+', '.join(sorted(unsupported))+'；已保留，不能静默丢弃')
    result=copy.deepcopy(song);result.source_tracks=[];result.source_midi_events=[];result.score_document=None
    for note in result.notes:
        if note.track_id not in tracks:raise ValueError('存在没有来源轨道的音符，请先选择源轨道')
        note.part=tracks[note.track_id].device_part
        if allow_uncertain:note.uncertain=False
    return result


def reference_midi(song,muted=(),solo=()):
    """按源轨道生成电脑参考MIDI，复制原控制事件到独立试听通道。"""
    import mido
    destinations={};tracks={t.track_id:t for t in song.source_tracks};muted=set(muted)&tracks.keys();solo=set(solo)&tracks.keys()
    if len(tracks)!=len(song.source_tracks):raise ValueError('源轨道ID重复')
    channels=iter([n for n in range(16) if n!=9]);events=[]
    for track in song.source_tracks:
        try:channel=9 if track.is_drum else next(channels)
        except StopIteration as exc:raise ValueError('参考MIDI单次最多15条独立旋律轨道；未静默丢轨') from exc
        destinations[track.track_id]=channel
        program=track.program if track.reference_override is None else track.reference_override
        if not 0<=program<=127:raise ValueError('参考乐器编号无效')
        events.append((0,-1_000_000,mido.Message('program_change',channel=channel,program=program)))
    for tick,tempo in song.tempos:events.append((tick,-2_000_000,mido.MetaMessage('set_tempo',tempo=tempo)))
    for tick,a,b in song.meter_changes or [[0,song.numerator,song.denominator]]:
        events.append((tick,-2_000_000,mido.MetaMessage('time_signature',numerator=a,denominator=b)))
    for event in song.source_midi_events:
        message=(mido.MetaMessage if event.get('meta') else mido.Message).from_dict(event['message'])
        order=event.get('order',0)*4
        if not hasattr(message,'channel'):
            events.append((event['tick'],order,message));continue
        for track in song.source_tracks:
            if message.channel!=track.channel:continue
            if message.type=='program_change' and track.reference_override is not None:continue
            events.append((event['tick'],order,message.copy(channel=destinations[track.track_id])))
    any_solo=bool(solo) or any(t.preview_solo for t in song.source_tracks)
    for note in song.notes:
        track=tracks.get(note.track_id)
        if track is None:raise ValueError('音符缺少原始轨道，未按设备声部猜测参考音色')
        if not 0<=note.start<note.end or not 0<=note.pitch<128 or not 1<=note.velocity<128:raise ValueError('请修正无效音符')
        if track.preview_muted or track.track_id in muted or any_solo and not (track.preview_solo or track.track_id in solo):continue
        if not 0<=track.reference_volume<=100:raise ValueError('源轨道参考音量应为0..100')
        velocity=round(note.velocity*track.reference_volume/100)
        if not velocity:continue
        channel=destinations[track.track_id]
        on_order=note.source_start_order*4 if note.source_start_order is not None else 2
        off_order=note.source_end_order*4 if note.source_end_order is not None else 1
        events.extend([(note.start,on_order,mido.Message('note_on',channel=channel,note=note.pitch,velocity=velocity)),
                       (note.end,off_order,mido.Message('note_off',channel=channel,note=note.pitch,velocity=0))])
    result=mido.MidiFile(type=0,ticks_per_beat=song.ppqn);track=mido.MidiTrack();result.tracks.append(track);last=0
    for tick,_,message in sorted(events,key=lambda value:value[:2]):
        track.append(message.copy(time=tick-last));last=tick
    track.append(mido.MetaMessage('end_of_track',time=max(0,song.duration-last)))
    return result
