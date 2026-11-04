"""歌曲工程与设备资源编译；本机校谱试听另走 preview_audio，不进入设备传输链路。"""
from __future__ import annotations
from dataclasses import dataclass, field, asdict
from pathlib import Path
from fractions import Fraction
import hashlib, io, json, math, struct, uuid, wave, zipfile
import xml.etree.ElementTree as ET

FS = 50_000_000 / 1024
PARTS = ('主旋律', '和弦', '低音', '鼓')

@dataclass
class Note:
    start: int
    end: int
    pitch: int
    velocity: int = 100
    part: int = 0
    page: int = 0
    box: list[float] = field(default_factory=list)
    uncertain: bool = False
    note_id: str = field(default_factory=lambda:'n'+uuid.uuid4().hex)
    track_id: str = ''
    source_start_order: int | None = None
    source_end_order: int | None = None

@dataclass
class SourceTrack:
    """原始轨道身份；device_part 只用于下发，参考乐器不作为设备音色传输。"""
    track_id: str
    name: str
    source_key: str = ''
    channel: int = 0
    program: int = 0
    is_drum: bool = False
    device_part: int | None = None
    reference_override: int | None = None
    preview_muted: bool = False
    preview_solo: bool = False
    reference_volume: int = 100
    gain_db: float = 0.0

@dataclass
class Section:
    name: str = '全曲'
    start: int = 0
    end: int = 1920
    timbres: list[int] = field(default_factory=lambda:[1,0,0,0])
    volumes: list[int] = field(default_factory=lambda:[100,72,80,72])
    mute: int = 0
    solo: int = 0
    live_timbre: int = 0
    transpose: int = 0

@dataclass
class Song:
    name: str = '新曲谱'
    resource_id: str = field(default_factory=lambda:str(uuid.uuid4()))
    revision: int = 1
    ppqn: int = 480
    numerator: int = 4
    denominator: int = 4
    tempos: list[list[int]] = field(default_factory=lambda:[[0,500000]])
    notes: list[Note] = field(default_factory=list)
    sections: list[Section] = field(default_factory=list)
    source_files: list[str] = field(default_factory=list)
    issues: list[str] = field(default_factory=list)
    score_document: object | None = None
    reference_programs: list[int] = field(default_factory=lambda:[0,0,0,0])
    source_tracks: list[SourceTrack] = field(default_factory=list)
    source_midi_events: list[dict] = field(default_factory=list)
    meter_changes: list[list[int]] = field(default_factory=list)
    track_mix: dict = field(default_factory=dict)
    recognition: dict = field(default_factory=dict)
    @property
    def duration(self):return max([n.end for n in self.notes]+[s.end for s in self.sections]+[self.ppqn*4])
    def bar_markers(self):
        grid=getattr(self.score_document,'measure_grid',None)
        if grid:
            return [(int(Fraction(a)*self.ppqn),label) for a,_,label in grid]+[(int(Fraction(grid[-1][1])*self.ppqn),'')]
        if self.meter_changes:
            changes=sorted(self.meter_changes);position=0;number=1;result=[];index=0
            if changes[0][0]!=0:raise ValueError('拍号表必须从曲首开始')
            while position<self.duration:
                while index+1<len(changes) and changes[index+1][0]<=position:index+=1
                _,numerator,denominator=changes[index];length=Fraction(self.ppqn*4*numerator,denominator)
                if length.denominator!=1 or length<=0:raise ValueError('拍号无法用当前PPQN精确表示')
                result.append((position,str(number)));number+=1
                following=changes[index+1][0] if index+1<len(changes) else self.duration+int(length)
                position=min(position+int(length),following)
            return result+[(position,'')]
        length=max(1,self.ppqn*4*self.numerator//self.denominator)
        return [(tick,str(i+1)) for i,tick in enumerate(range(0,self.duration+length,length))]
    def validate(self):
        if self.source_tracks:
            from .source_tracks import device_song
            device_song(self).validate();return
        self._validate_timeline()
    def _validate_timeline(self, *, independent_channels=False):
        """共用容量和配器校验；新编译器须先分配独立通道才允许同音重叠。"""
        if len(self.reference_programs)!=4 or any(not isinstance(p,int) or not 0<=p<=127 for p in self.reference_programs):
            raise ValueError('参考乐器必须是四个0..127的GM编号')
        if self.score_document is not None:
            from .score_document import performance_hash,require_device_assumptions
            if self.score_document.errors:raise ValueError('乐谱编译未通过：'+'；'.join(self.score_document.errors))
            require_device_assumptions(self.score_document)
            if self.score_document.performance_hash!=performance_hash(self):raise ValueError('谱面与演奏数据版本不一致，请先完成校谱同步')
        if not self.notes:raise ValueError('曲谱还没有可播放音符，请先识谱或录入')
        if not 1<=self.ppqn<=32767:raise ValueError('PPQN必须为1..32767')
        if len(self.notes)>2048:raise ValueError('当前歌曲超过2048音符，不能下发；可拆成多首')
        if len(self.tempos)>64:raise ValueError('超过64个速度变化')
        if not self.tempos or self.tempos[0][0]!=0 or any(not 1<=tempo<=0xffffff or not 0<=tick<=0xffffffff for tick,tempo in self.tempos):raise ValueError('速度表必须从0开始，速度值为1..16777215微秒/四分音符')
        if any(a[0]>=b[0] for a,b in zip(self.tempos,self.tempos[1:])):raise ValueError('速度变化位置必须严格递增')
        for n in self.notes:
            if not(0<=n.start<n.end<=0xffffffff and 0<=n.pitch<=127 and 1<=n.velocity<=127 and 0<=n.part<4):
                raise ValueError(f'无效音符：{n}')
            if n.uncertain:raise ValueError('存在未确认的识谱音符，请先校正')
        # 当前MIDI硬件每个“声部×音高”只跟踪一个起音；重复叠音不能静默截断。
        previous_end={}
        for n in sorted(self.notes,key=lambda item:(item.start,item.end)):
            key=(n.part,n.pitch)
            if not independent_channels and n.start<previous_end.get(key,0):
                raise ValueError(f'声部{n.part}音高{n.pitch}存在重叠音符，请调整起止tick或分配到不同声部')
            previous_end[key]=n.end
        if not self.sections:self.sections=[Section(end=self.duration)]
        if len(self.sections)>32:raise ValueError('每首最多32个段落')
        previous=0
        for s in self.sections:
            if s.start!=previous or s.end<=s.start:raise ValueError('段落必须连续且不重叠，从0开始')
            if len(s.timbres)!=4 or len(s.volumes)!=4 or any(not 0<=x<10 for x in s.timbres):raise ValueError('声部音色编号无效')
            if any(not 0<=x<=100 for x in s.volumes) or not 0<=s.live_timbre<10 or not -24<=s.transpose<=24:raise ValueError('配器参数无效')
            previous=s.end
        if previous<max([n.end for n in self.notes]+[0]):raise ValueError('段落未覆盖全部音符')
        if any(not 0<=s.mute<=15 or not 0<=s.solo<=15 for s in self.sections):raise ValueError('静音和独奏掩码超出4声部范围')
    def midi(self):
        if self.source_tracks:
            from .source_tracks import device_song
            return device_song(self).midi()
        import mido
        self.validate();events=[]
        for tick,numerator,denominator in self.meter_changes or [[0,self.numerator,self.denominator]]:
            events.append((tick,0,mido.MetaMessage('time_signature',numerator=numerator,denominator=denominator)))
        for tick,tempo in self.tempos:events.append((tick,0,mido.MetaMessage('set_tempo',tempo=tempo)))
        for n in self.notes:
            ch=9 if n.part==3 else n.part
            events.extend([(n.start,2,mido.Message('note_on',channel=ch,note=n.pitch,velocity=n.velocity)),
                           (n.end,1,mido.Message('note_off',channel=ch,note=n.pitch,velocity=0))])
        track=mido.MidiTrack();last=0
        for tick,_,msg in sorted(events,key=lambda v:(v[0],v[1])):
            track.append(msg.copy(time=tick-last));last=tick
        track.append(mido.MetaMessage('end_of_track',time=max(0,self.duration-last)))
        midi=mido.MidiFile(type=0,ticks_per_beat=self.ppqn);midi.tracks.append(track)
        stream=io.BytesIO();midi.save(file=stream);return stream.getvalue()
    def arrangement(self):
        if self.source_tracks:
            from .source_tracks import device_song
            return device_song(self).arrangement()
        self.validate();data=bytearray()
        for s in self.sections:
            data.extend(struct.pack('<II4B4BBBBbHH',s.start,s.end,*s.timbres,*s.volumes,s.mute,s.solo,s.live_timbre,s.transpose,0,0))
        return bytes(data)

@dataclass
class Patch:
    name: str = '新音色'
    resource_id: str = field(default_factory=lambda:str(uuid.uuid4()))
    revision: int = 1
    waveform: list[int] = field(default_factory=lambda:[round(24000*math.sin(2*math.pi*i/256)) for i in range(256)])
    attack: int = 64
    decay: int = 8
    sustain: int = 3072
    release: int = 32
    def validate(self):
        if len(self.waveform)!=256 or any(not -32768<=x<=32767 for x in self.waveform):raise ValueError('音色必须为256点有符号16位波表')
        if not all(1<=x<=4095 for x in (self.attack,self.decay,self.release)) or not 0<=self.sustain<=4095:raise ValueError('ADSR参数超出12位范围')
    def binary(self):self.validate();return struct.pack('<256h',*self.waveform)

@dataclass
class MusicProject:
    name: str = '我的演奏工程'
    songs: list[Song] = field(default_factory=list)
    patches: list[Patch] = field(default_factory=list)
    publication_versions: dict[str,int] = field(default_factory=dict)
    mix_scene: dict = field(default_factory=dict)
    editor_drafts: dict = field(default_factory=dict)
    def validate(self):
        if len(self.songs)>4 or len(self.patches)>8:raise ValueError('设备容量为4首曲谱、8个自定义音色')
        pages=0
        for s in self.songs:s.validate();pages+=(len(s.midi())+4095)//4096
        if pages>16:raise ValueError('曲谱占用超过共享64KiB缓存（4KiB分配页）')
        for p in self.patches:p.validate()
        for s in self.songs:
            for section in s.sections:
                if any(t>=2+len(self.patches) for t in section.timbres+[section.live_timbre]):raise ValueError('配器引用了工程中不存在的音色，请先导入对应音色')
        identities=[x.resource_id for x in self.songs+self.patches]
        if len(set(identities))!=len(identities):raise ValueError('工程存在重复资源ID')
    def save(self,path):
        # 保存不要求已完成校正，允许保留未确认音符；资源依赖嵌入ZIP，移动工程不丢原谱。
        target=Path(path);temp=target.with_suffix(target.suffix+'.tmp');data=asdict(self)
        with zipfile.ZipFile(temp,'w',zipfile.ZIP_DEFLATED) as z:
            for si,song in enumerate(data['songs']):
                embedded=[]
                for pi,source in enumerate(song['source_files']):
                    p=Path(source)
                    if p.is_file():
                        name=f'sources/{si}/{pi}{p.suffix.lower()}';z.write(p,name);embedded.append(name)
                    else:raise ValueError(f'原谱文件不存在：{p}')
                song['source_files']=embedded
            z.writestr('project.json',json.dumps({'format':5,'project':data},ensure_ascii=False))
        temp.replace(target)
    @classmethod
    def load(cls,path,cache=None):
        target=Path(path);cache=Path(cache or target.parent/'.fpgamusic_sources')/hashlib.sha256(target.read_bytes()).hexdigest()[:16]
        with zipfile.ZipFile(target) as z:
            if sum(i.file_size for i in z.infolist())>100_000_000:raise ValueError('工程解压大小超限')
            raw=json.loads(z.read('project.json'))
            if raw['format'] not in (2,3,4,5):raise ValueError('不支持的工程版本')
            data=raw['project'];songs=[]
            for s in data['songs']:
                sources=[]
                for name in s['source_files']:
                    dest=(cache/name).resolve()
                    if not dest.is_relative_to(cache.resolve()):raise ValueError('工程内文件路径无效')
                    dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(z.read(name));sources.append(str(dest))
                from .score_document import ScoreDocument,from_song,ensure_document
                s['source_files']=sources;s['notes']=[Note(**n) for n in s['notes']];s['sections']=[Section(**n) for n in s['sections']]
                s['source_tracks']=[SourceTrack(**n) for n in s.get('source_tracks',[])]
                if s.get('score_document'):s['score_document']=ScoreDocument(**s['score_document'])
                song=Song(**s)
                if song.score_document is None and song.notes:song.score_document=from_song(song)
                elif song.score_document and song.score_document.reconstructed and song.score_document.notation_schema<3:ensure_document(song)
                songs.append(song)
            return cls(data['name'],songs,[Patch(**p) for p in data['patches']],
                       data.get('publication_versions',{}),data.get('mix_scene',{}),data.get('editor_drafts',{}))

def import_midi(path,preserve_tracks=False):
    if preserve_tracks:
        from .source_tracks import read_midi
        return read_midi(path)
    import mido
    f=mido.MidiFile(path);song=Song(name=Path(path).stem,ppqn=f.ticks_per_beat,tempos=[]);absolute=0;held={}
    if f.type==2:raise ValueError('暂不支持异步MIDI Type2')
    for msg in mido.merge_tracks(f.tracks):
        absolute+=msg.time
        if msg.type=='set_tempo':song.tempos.append([absolute,msg.tempo])
        elif msg.type=='time_signature':song.numerator=msg.numerator;song.denominator=msg.denominator
        elif msg.type in ('note_on','note_off'):
            key=(msg.channel,msg.note);stack=held.setdefault(key,[])
            if msg.type=='note_on' and msg.velocity:stack.append((absolute,msg.velocity))
            elif stack:
                start,vel=stack.pop(0)
                if absolute>start:song.notes.append(Note(start,absolute,msg.note,vel,3 if msg.channel==9 else min(msg.channel,2)))
    if any(held.values()):song.issues.append('存在未配对的起音，已按曲尾补齐')
    for (ch,n),values in held.items():
        for start,vel in values:song.notes.append(Note(start,max(start+1,absolute),n,vel,3 if ch==9 else min(ch,2)))
    song.tempos=[list(item) for item in sorted(dict(song.tempos).items())]
    if not song.tempos or song.tempos[0][0]!=0:song.tempos.insert(0,[0,500000])
    song.sections=[Section(end=song.duration,mute=0)];return song

def import_musicxml(path,part_mapping=None,preserve_tracks=False):
    from .score_document import ScoreDocument
    document=ScoreDocument.from_file(path)
    if part_mapping:document.mapping={f'{p}:{s}:{v}':value for (p,s,v),value in part_mapping.items()}
    song=document.compile(Path(path).stem,device_constraints=not preserve_tracks);song.source_files=[str(Path(path).resolve())]
    if preserve_tracks:
        from .source_tracks import attach_xml_tracks
        attach_xml_tracks(song)
    return song

def _legacy_import_musicxml(path,part_mapping=None):
    p=Path(path)
    if p.suffix.lower()=='.mxl':
        with zipfile.ZipFile(p) as z:
            container=ET.fromstring(z.read('META-INF/container.xml'))
            rootfile=next(e.attrib['full-path'] for e in container.iter() if e.tag.endswith('rootfile'))
            root=ET.fromstring(z.read(rootfile))
    else:root=ET.parse(p).getroot()
    # 去掉命名空间，保留XML自身的声部/小节/时间关系。
    for e in root.iter():e.tag=e.tag.split('}')[-1]
    if root.tag!='score-partwise':raise ValueError('需要MusicXML score-partwise格式')
    song=Song(name=p.stem);pitches={'C':0,'D':2,'E':4,'F':5,'G':7,'A':9,'B':11}
    for pi,part in enumerate(root.findall('part')):
        cursor=0;divisions=1;previous=0;ties={}
        pitched=[el for el in part.iter('note') if el.find('pitch') is not None]
        multistaff=any(el.findtext('staff','1')!='1' for el in pitched)
        primary_voice=next((el.findtext('voice','1') for el in pitched if el.findtext('staff','1')=='1'),'1')
        if multistaff:song.issues.append(f'{part.attrib.get("id",pi)}默认分轨：首谱表主声部→旋律，其余声部→和弦，下谱表→低音，请核对配器')
        for measure in part.findall('measure'):
            measure_start=cursor;measure_end=cursor
            for el in measure:
                if el.tag=='attributes':
                    divisions=int(el.findtext('divisions',str(divisions)))
                    song.numerator=int(el.findtext('time/beats',str(song.numerator)));song.denominator=int(el.findtext('time/beat-type',str(song.denominator)))
                elif el.tag=='direction':
                    sound=el.find('sound')
                    if sound is not None and 'tempo' in sound.attrib:
                        song.tempos.append([cursor,round(60_000_000/float(sound.attrib['tempo']))])
                    elif el.find('direction-type/metronome') is not None:
                        metronome=el.find('direction-type/metronome');bpm=metronome.findtext('per-minute')
                        unit={'whole':4,'half':2,'quarter':1,'eighth':.5,'16th':.25}.get(metronome.findtext('beat-unit'))
                        if bpm and unit:
                            unit*=sum(.5**i for i in range(len(metronome.findall('beat-unit-dot'))+1))
                            song.tempos.append([cursor,round(60_000_000/(float(bpm)*unit))])
                elif el.tag in ('backup','forward'):
                    duration=int(Fraction(el.findtext('duration','0'))*song.ppqn/divisions)
                    cursor+=duration*(-1 if el.tag=='backup' else 1)
                elif el.tag=='note':
                    duration=int(Fraction(el.findtext('duration','0'))*song.ppqn/divisions)
                    chord=el.find('chord') is not None;start=previous if chord else cursor
                    pitch=el.find('pitch')
                    if pitch is not None and duration:
                        n=12*(int(pitch.findtext('octave'))+1)+pitches[pitch.findtext('step')]+int(pitch.findtext('alter','0'))
                        types={t.attrib.get('type') for t in el.findall('tie')};key=(el.findtext('voice','1'),n)
                        if 'stop' in types and key in ties and ties[key].end==start:ties[key].end=start+duration
                        else:
                            if 'stop' in types and key in ties:
                                song.issues.append(f'第{measure.get("number","?")}小节延音不连续，未跨空隙拉长音符')
                            staff=el.findtext('staff','1');voice=el.findtext('voice','1')
                            assigned=(2 if staff!='1' else 0 if voice==primary_voice else 1) if multistaff else min(pi,2)
                            if part_mapping:assigned=part_mapping.get((part.attrib.get('id',str(pi)),staff,voice),assigned)
                            if assigned not in (0,1,2):raise ValueError('MusicXML旋律声部映射必须为0、1或2')
                            item=Note(start,start+duration,n,100,assigned);song.notes.append(item)
                            if 'start' in types:ties[key]=item
                        if 'stop' in types and 'start' not in types:ties.pop(key,None)
                    if not chord:previous=start;cursor+=duration
                    measure_end=max(measure_end,start+duration)
            expected=song.ppqn*song.numerator*4//song.denominator
            if measure_end-measure_start>expected and measure.get('implicit')!='yes':
                song.issues.append(f'第{measure.get("number","?")}小节超出拍号：{measure_end-measure_start}/{expected} tick，需校正连音或声部起点')
            cursor=measure_end
    # MIDI文件每通道/音高只有一个挂起音符。只给冲突同音寻找空闲旋律声部，保留音高和完整时值。
    occupied={};moved=0;unresolved=0
    for note in sorted(song.notes,key=lambda item:(item.start,item.end)):
        candidates=[note.part]+[p for p in (0,1,2) if p!=note.part]
        available=next((p for p in candidates if occupied.get((p,note.pitch),0)<=note.start),None)
        if available is None:unresolved+=1;note.uncertain=True
        else:
            if available!=note.part:moved+=1;note.part=available;note.uncertain=True
        occupied[note.part,note.pitch]=max(occupied.get((note.part,note.pitch),0),note.end)
    if moved:song.issues.append(f'{moved}个同音重叠音符已分配到空闲声部，请确认配器；音高及时值保留')
    if unresolved:song.issues.append(f'{unresolved}个同音重叠超过3个旋律声部，需要人工调整；未删除音符')
    song.tempos=sorted(dict(song.tempos).items());song.sections=[Section(end=song.duration,mute=0)];return song

def import_patch(path,start=0,end=None):
    p=Path(path)
    if p.suffix.lower()=='.ftb':
        from .timbre_file import decode_ftb
        t=decode_ftb(p.read_bytes());return Patch(name=t.name or p.stem,waveform=t.waveform,attack=t.attack,release=t.release)
    with wave.open(str(p),'rb') as w:
        channels=w.getnchannels();width=w.getsampwidth();count=w.getnframes();raw=w.readframes(count)
        if w.getcomptype()!='NONE' or width not in (1,2,3,4):raise ValueError('需要未压缩PCM WAV')
    stop=count if end is None else end
    if not 0<=start<stop<=count:raise ValueError('单周期选择范围无效')
    if end is None and count>4096:raise ValueError('WAV超过4096采样点，请先在波形编辑器明确选择一个周期')
    values=[]
    for frame in range(start,stop):
        value=0
        for channel in range(channels):
            offset=(frame*channels+channel)*width;b=raw[offset:offset+width]
            value+=(b[0]-128) if width==1 else int.from_bytes(b,'little',signed=True)
        values.append(value/channels)
    if len(values)<8:raise ValueError('单周期至少8个采样点')
    dc=sum(values)/len(values);peak=max(abs(x-dc) for x in values)
    if peak==0:raise ValueError('波形没有交流信号')
    result=[]
    for i in range(256):
        pos=i*len(values)/256;j=int(pos);frac=pos-j
        result.append(round(((values[j]-dc)*(1-frac)+(values[(j+1)%len(values)]-dc)*frac)*30000/peak))
    return Patch(name=p.stem,waveform=result)

def generate_accompaniment(song,chords):
    """依据用户确认的和弦生成简单三轨；不会从单旋律擅自推断和声。"""
    quality={'':(0,4,7),'m':(0,3,7),'7':(0,4,7,10),'maj7':(0,4,7,11),'m7':(0,3,7,10)}
    roots={'C':0,'C#':1,'Db':1,'D':2,'D#':3,'Eb':3,'E':4,'F':5,'F#':6,'Gb':6,'G':7,'G#':8,'Ab':8,'A':9,'A#':10,'Bb':10,'B':11}
    import re
    if len(song.meter_changes)>1:raise ValueError('变拍曲谱请分段编写伴奏，当前不会按固定拍号覆盖原轨道')
    if song.ppqn%8:raise ValueError('当前PPQN不能精确表示鼓点网格，未截断时值')
    if song.source_tracks:
        previous={t.track_id for t in song.source_tracks if t.source_key.startswith('generated:')}
        updated_tracks=[t for t in song.source_tracks if t.track_id not in previous]
        output=[n for n in song.notes if n.track_id not in previous];created={}
        for part,name,program in ((1,'生成和弦',0),(2,'生成低音',32),(3,'生成鼓点',0)):
            track=SourceTrack(uuid.uuid4().hex,name,f'generated:{part}',-1,program,part==3,part);updated_tracks.append(track);created[part]=track.track_id
    else:output=[n for n in song.notes if n.part==0];created={}
    bar=song.ppqn*4*song.numerator//song.denominator
    for measure,label in enumerate(chords):
        match=re.fullmatch(r'([A-G](?:#|b)?)(maj7|m7|m|7)?',label.strip())
        if not match:raise ValueError(f'和弦暂不支持：{label}')
        root=roots[match[1]];start=measure*bar
        for n in quality[match[2] or '']:output.append(Note(start,start+bar,48+root+n,70,1,track_id=created.get(1,'')))
        for beat in range(song.numerator):
            tick=start+beat*song.ppqn*4//song.denominator
            output.append(Note(tick,tick+song.ppqn//2,36+root,85,2,track_id=created.get(2,'')))
            output.append(Note(tick,tick+song.ppqn//8,36 if beat%2==0 else 38,95,3,track_id=created.get(3,'')))
    if song.source_tracks:song.source_tracks=updated_tracks
    song.notes=output;song.revision+=1;song.sections=[Section(end=song.duration)]
