"""可保存的乐谱文档：MusicXML 是谱面源，Partitura 负责符号时间轴，设备只接收编译结果。"""
from __future__ import annotations
from dataclasses import dataclass, field
from fractions import Fraction
from pathlib import Path
import copy, hashlib, io, math, uuid, zipfile
import xml.etree.ElementTree as ET
PITCH_SPELLINGS=[('C',0),('C',1),('D',0),('E',-1),('E',0),('F',0),('F',1),('G',0),('A',-1),('A',0),('B',-1),('B',0)]


def read_xml(path):
    path=Path(path)
    if path.suffix.lower()=='.mxl':
        with zipfile.ZipFile(path) as package:
            if sum(x.file_size for x in package.infolist())>30_000_000:raise ValueError('MusicXML 解压大小超限')
            container=ET.fromstring(package.read('META-INF/container.xml'))
            name=next(x.attrib['full-path'] for x in container.iter() if x.tag.endswith('rootfile'))
            return package.read(name).decode('utf-8-sig')
    return path.read_text(encoding='utf-8-sig')


def xml_root(text):
    root=ET.fromstring(text)
    for item in root.iter():item.tag=item.tag.split('}')[-1]
    if root.tag!='score-partwise':raise ValueError('需要 MusicXML score-partwise 格式')
    return root


def _text(parent,name,text,**attrs):
    element=ET.SubElement(parent,name,attrs);element.text=str(text);return element


def _fraction(value):
    # quarter_map 返回浮点；仅接受能恢复为有限音乐分数的值，不能截断 tick。
    value=float(value);result=Fraction(value).limit_denominator(1_000_000)
    if abs(float(result)-value)>1e-9:raise ValueError('谱面时值无法精确表示，请在 MuseScore 校正')
    return result


@dataclass
class ScoreDocument:
    original_xml: str = ''
    initial_xml: str = ''
    current_xml: str = ''
    revision: int = 1
    reconstructed: bool = False
    mapping: dict[str,int] = field(default_factory=dict)
    links: dict[str,list[str]] = field(default_factory=dict)
    warnings: list[str] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)
    performance_hash: str = ''
    measure_grid: list[list[str]] = field(default_factory=list)
    notation_schema: int = 1
    review_items: list[dict] = field(default_factory=list)
    source_measures: list[dict] = field(default_factory=list)
    reviewed_measures: dict[str,str] = field(default_factory=dict)
    confirmed_assumptions: dict = field(default_factory=dict)

    @classmethod
    def from_file(cls,path):
        raw=read_xml(path);root=xml_root(raw)
        if root.find('part-list') is None:
            listing=ET.Element('part-list');root.insert(0,listing)
            for i,part in enumerate(root.findall('part')):
                pid=part.get('id',f'P{i+1}');part.set('id',pid)
                _text(ET.SubElement(listing,'score-part',id=pid),'part-name',pid)
        used_ids={note.get('id') for note in root.iter('note') if note.get('id')}
        if len(used_ids)!=sum(bool(note.get('id')) for note in root.iter('note')):
            raise ValueError('MusicXML 音符 ID 重复，请在 MuseScore 重新导出，避免覆盖音符')
        for pi,part in enumerate(root.findall('part')):
            if not part.get('id'):part.set('id',f'P{pi+1}')
            for i,note in enumerate(part.iter('note')):
                if not note.get('id'):
                    identifier=f'{part.get("id")}_n{i}'
                    while identifier in used_ids:identifier+='x'
                    note.set('id',identifier);used_ids.add(identifier)
        current=ET.tostring(root,encoding='unicode');mapping={}
        # 自有四逻辑声部的中文名称在MuseScore往返后仍明确标识角色；不把第五条未知轨道静默丢弃。
        roles=('主旋律','和弦','低音','鼓')
        for declaration in root.findall('part-list/score-part'):
            name=declaration.findtext('part-name','');pid=declaration.get('id');part=next((p for p in root.findall('part') if p.get('id')==pid),None)
            if name in roles and part is not None:
                for note in part.iter('note'):mapping[f'{pid}:{note.findtext("staff","1")}:{note.findtext("voice","1")}']=roles.index(name)
        return cls(raw,current,current,mapping=mapping)

    def structure(self):
        """供属性面板使用；原 XML 保留所有尚未编辑的记号。"""
        root=xml_root(self.current_xml)
        return {tag:[dict(x.attrib,text=''.join(x.itertext()).strip()) for x in root.iter(tag)]
                for tag in ('measure','clef','key','time','rest','time-modification','tie','direction')}

    def compile(self,name='曲谱',uncertain=False,device_constraints=True):
        try:import partitura
        except ImportError as exc:raise ValueError('缺少 Partitura 乐谱解析组件，请运行 python scripts/prepare_music_stack.py --install-python') from exc
        from partitura import score as symbols
        from .music_project import Song,Note,Section
        root=xml_root(self.current_xml);self.errors=[];self.warnings=[]
        from .score_audit import audit
        self.review_items,self.source_measures,dynamics=audit(root)
        self.errors.extend(x['message']+'（'+x['part']+' 第'+x['measure']+'小节）' for x in self.review_items if x['severity']=='error')
        self.warnings.extend(x['message'] for x in self.review_items if x['severity']=='question')
        self.errors.extend(_audit_xml(root))
        # 会改变音高/节奏的记号必须显式处理。装饰音/跳转暂交给外部校谱，不能静默消失。
        for tag in ('grace','transpose','ornaments','glissando','slide','tremolo'):
            if root.find('.//'+tag) is not None:self.errors.append(f'暂不支持 {tag} 的设备编译，请先在 MuseScore 展开为实际音符')
        for sound in root.iter('sound'):
            if any(k in sound.attrib for k in ('dacapo','dalsegno','tocoda','fine')):
                self.errors.append('存在跳转记号，请先在 MuseScore 展开播放顺序')
        with _quiet_partitura():
            parsed=partitura.load_musicxml(io.BytesIO(ET.tostring(root)),force_note_ids='keep',quiet=True)
        if not parsed.parts or not any(part.notes for part in parsed.parts):raise ValueError('MusicXML 没有可读取音符，请检查 part-list 与乐谱结构')
        records=[];tempo={Fraction(0):500000};signatures=[];self.links={};explicit=set(self.mapping)
        parts=[];unfolded_parts=set()
        for part in parsed.parts:
            has_repeat=any(True for _ in part.iter_all(symbols.Repeat))
            if has_repeat:
                part=symbols.unfold_part_maximal(part,update_ids=True)
                unfolded_parts.add(len(parts))
                self.warnings.append('已按反复记号展开设备播放顺序；编辑反复内音符请使用 MuseScore')
            parts.append(part)
        # Partitura把弱起放在负的四分音符位置；统一平移全部谱表与速度，保留弱起休止。
        # 不能逐轨按首个有声音符归零，否则会抹掉左手/低音的入拍时间差。
        origin=min([Fraction(0)]+[_fraction(p.quarter_map(p.first_point.t)) for p in parts if p.first_point is not None])
        grids=[]
        for p in parts:
            grids.append([[str(_fraction(p.quarter_map(m.start.t))-origin),str(_fraction(p.quarter_map(m.end.t))-origin),str(m.name if m.name is not None else m.number)]
                          for m in p.iter_all(symbols.Measure) if m.start is not None and m.end is not None])
        self.measure_grid=max(grids,key=len,default=[])
        for pi,part in enumerate(parts):
            for obj in part.iter_all(symbols.Tempo):tempo[_fraction(part.quarter_map(obj.start.t))-origin]=obj.microseconds_per_quarter
            for obj in part.iter_all(symbols.TimeSignature):signatures.append((_fraction(part.quarter_map(obj.start.t))-origin,obj.beats,obj.beat_type))
            staff_set={n.staff or 1 for n in part.notes};first_voice=next((n.voice or 1 for n in part.notes if (n.staff or 1)==1),1)
            for note in part.notes_tied:
                start=_fraction(part.quarter_map(note.start.t))-origin;end=_fraction(part.quarter_map(note.start.t+note.duration_tied))-origin
                if start<0 or end<=start:self.errors.append(f'{note.id} 起止时值无效');continue
                key=f'{part.id}:{note.staff or 1}:{note.voice or 1}'
                default=(2 if (note.staff or 1)!=1 else 0 if (note.voice or 1)==first_voice else 1) if len(staff_set)>1 else min(pi,2)
                assigned=self.mapping.get(key,default)
                if pi<3:self.mapping.setdefault(key,default)
                if device_constraints and pi>=3 and key not in explicit:self.errors.append(f'声部 {key} 需要明确映射到设备声部')
                if assigned not in range(4):self.errors.append(f'声部 {key} 映射无效');continue
                chain=[];item=note
                while item is not None:
                    chain.append(item.id);item=item.tie_next
                identifier=note.id
                self.links[identifier]=chain
                original_id=identifier.rsplit('-',1)[0] if pi in unfolded_parts else identifier
                records.append((start,end,note.midi_pitch,dynamics.get(identifier,dynamics.get(original_id,100)),assigned,identifier))
        ppqn=480
        for a,b,*_ in records:ppqn=math.lcm(ppqn,a.denominator,b.denominator)
        for t in tempo:ppqn=math.lcm(ppqn,t.denominator)
        for a,b,_ in self.measure_grid:ppqn=math.lcm(ppqn,Fraction(a).denominator,Fraction(b).denominator)
        if ppqn>32767:raise ValueError(f'精确 PPQN={ppqn} 超出设备范围，未量化或截断曲谱')
        song=Song(name=name,ppqn=ppqn,tempos=[[int(t*ppqn),v] for t,v in sorted(tempo.items())],score_document=self)
        if signatures:
            _,song.numerator,song.denominator=min(signatures)
            song.meter_changes=[[int(t*ppqn),a,b] for t,a,b in sorted(set(signatures))]
        occupied={};moved=0;compiled={}
        for start,end,pitch,velocity,part,identifier in sorted(records,key=lambda x:(x[0],x[1],x[5])):
            a,b=int(start*ppqn),int(end*ppqn)
            # 设备每逻辑声部/音高只能挂起一个音符；保留同音叠置，不截短原音符。
            chosen=next((p for p in [part]+[p for p in (0,1,2) if p!=part and part!=3] if occupied.get((p,pitch),0)<=a),None) if device_constraints else part
            if chosen is None:chosen=part;self.errors.append(f'{identifier} 同音叠置超过设备声部表达能力')
            changed=chosen!=part;moved+=changed;occupied[chosen,pitch]=max(occupied.get((chosen,pitch),0),b)
            compiled[identifier]=Note(a,b,pitch,velocity,chosen,uncertain=uncertain or changed,note_id=identifier)
        song.notes=[compiled[r[5]] for r in records]
        if moved:self.warnings.append(f'{moved} 个同音叠置分配到空闲声部，请确认配器')
        song.sections=[Section(end=song.duration,timbres=[0,0,0,0],volumes=[100]*4)]
        song.issues=list(dict.fromkeys(self.errors+self.warnings));self.performance_hash=performance_hash(song)
        return song

    def sync(self,before,after):
        """轻量编辑直接改节点；只有重记谱文档允许重建，导入原谱的结构修改交给外部编辑。"""
        old={n.note_id:n for n in before.notes};new={n.note_id:n for n in after.notes}
        rhythm=old.keys()!=new.keys() or any((n.start,n.end,n.part,n.track_id)!=(old[k].start,old[k].end,old[k].part,old[k].track_id) for k,n in new.items() if k in old)
        if rhythm:
            if not self.reconstructed:
                raise ValueError('为保留原谱调号、谱表与连音，节奏或声部结构修改请导出到 MuseScore；当前不会整曲重记谱覆盖原稿')
            replacement=from_song(after);self.current_xml=replacement.current_xml;self.links=replacement.links;self.mapping=replacement.mapping;self.measure_grid=[];self.reconstructed=True;self.notation_schema=replacement.notation_schema
        else:
            root=xml_root(self.current_xml);nodes={n.get('id'):n for n in root.iter('note')}
            for key,n in new.items():
                previous=old.get(key)
                if not previous or (n.pitch,n.velocity)==(previous.pitch,previous.velocity):continue
                for source in self.links.get(key,[key]):
                    node=nodes.get(source)
                    if node is None:raise ValueError('乐谱音符映射已变化，请重新导入校正版')
                    node.set('dynamics',str(n.velocity/0.9));pitch=node.find('pitch')
                    if pitch is not None and n.pitch!=previous.pitch:
                        _write_pitch(pitch,n.pitch)
                        accidental=node.find('accidental')
                        if accidental is not None:node.remove(accidental)
                        _accidental(node,PITCH_SPELLINGS[n.pitch%12][1])
            self.current_xml=ET.tostring(root,encoding='unicode')
        self.revision+=1;self.performance_hash=performance_hash(after)


class _quiet_partitura:
    def __enter__(self):
        import warnings
        self.context=warnings.catch_warnings();self.context.__enter__();warnings.simplefilter('ignore');return self
    def __exit__(self,*args):return self.context.__exit__(*args)


def _audit_xml(root):
    """导入前验证小节与延音。只在编译副本拆开不连续延音，保存稿保留原记号供校正。"""
    issues=[]
    for part in root.findall('part'):
        divisions=1;numerator,denominator=4,4;cursor=Fraction(0);held={}
        for measure in part.findall('measure'):
            beginning=cursor;end=cursor;previous=cursor
            for item in measure:
                if item.tag=='attributes':
                    divisions=int(item.findtext('divisions',str(divisions)))
                    numerator=int(item.findtext('time/beats',str(numerator)));denominator=int(item.findtext('time/beat-type',str(denominator)))
                    if divisions<=0:raise ValueError('MusicXML divisions 必须大于0')
                elif item.tag=='direction':
                    met=item.find('direction-type/metronome')
                    if met is not None and item.find('sound') is None:
                        length={'whole':4,'half':2,'quarter':1,'eighth':.5,'16th':.25}.get(met.findtext('beat-unit'))
                        bpm=met.findtext('per-minute')
                        if length and bpm:
                            factor=sum(.5**i for i in range(len(met.findall('beat-unit-dot'))+1))
                            ET.SubElement(item,'sound',tempo=str(float(bpm)*length*factor))
                elif item.tag in ('backup','forward'):
                    cursor+=Fraction(item.findtext('duration','0'))/divisions*(-1 if item.tag=='backup' else 1)
                elif item.tag=='note':
                    duration=Fraction(item.findtext('duration','0'))/divisions;start=previous if item.find('chord') is not None else cursor
                    pitch=item.find('pitch')
                    if pitch is not None:
                        key=(item.findtext('voice','1'),item.findtext('staff','1'),ET.tostring(pitch))
                        ties={t.get('type'):t for t in item.findall('tie')}
                        if 'stop' in ties and key in held and held[key][1]!=start:
                            issues.append(f'第{measure.get("number","?")}小节延音不连续，请校正')
                            item.remove(ties['stop']);prior=held[key][0]
                            for t in list(prior.findall('tie')):
                                if t.get('type')=='start':prior.remove(t)
                        if 'start' in ties:held[key]=(item,start+duration)
                        elif 'stop' in ties:held.pop(key,None)
                    if item.find('chord') is None:previous=start;cursor+=duration
                    end=max(end,start+duration)
            if end-beginning>Fraction(numerator*4,denominator) and measure.get('implicit')!='yes':issues.append(f'第{measure.get("number","?")}小节超出拍号，请校正连音或声部起点')
            cursor=end
    return issues


def require_device_assumptions(document):
    if not document.review_items and not document.reconstructed:
        from .score_audit import audit
        document.review_items,document.source_measures,_=audit(xml_root(document.current_xml))
    missing=[i['message'] for i in document.review_items if i['code'] in ('missing_tempo','missing_meter') and not document.confirmed_assumptions.get(i['code'])]
    if missing:raise ValueError('下发前请补齐或明确确认速度／拍号：'+'；'.join(dict.fromkeys(missing)))


def performance_hash(song):
    import json
    data=[song.ppqn,song.tempos,[(n.note_id,n.start,n.end,n.pitch,n.velocity,n.part) for n in song.notes]]
    if song.source_tracks:data.extend([[n.track_id for n in song.notes],song.meter_changes])
    return hashlib.sha256(json.dumps(data,sort_keys=True).encode()).hexdigest()


def _write_pitch(parent,midi):
    for child in list(parent):parent.remove(child)
    step,alter=PITCH_SPELLINGS[midi%12]
    _text(parent,'step',step)
    if alter:_text(parent,'alter',alter)
    _text(parent,'octave',midi//12-1)


def _accidental(note,alter):
    # MusicXML的pitch/alter决定发声音高，accidental决定印出的记号，两者必须同步。
    element=ET.Element('accidental');element.text={-1:'flat',0:'natural',1:'sharp'}[alter]
    after={'pitch','duration','tie','voice','type','dot'};index=0
    for i,child in enumerate(note):
        if child.tag in after:index=i+1
    note.insert(index,element)


def _duration(parent,ticks,ppqn):
    """写入二进制时值；连音组的精确比例由调用者统一提供，不能逐音猜比例。"""
    value=Fraction(ticks,ppqn)
    types=[('whole',4),('half',2),('quarter',1),('eighth',Fraction(1,2)),('16th',Fraction(1,4)),('32nd',Fraction(1,8)),('64th',Fraction(1,16)),('128th',Fraction(1,32)),('256th',Fraction(1,64)),('512th',Fraction(1,128)),('1024th',Fraction(1,256))]
    for kind,length in types:
        for dots,factor in ((0,Fraction(1)),(1,Fraction(3,2)),(2,Fraction(7,4))):
            if value==length*factor:
                _text(parent,'type',kind)
                for _ in range(dots):ET.SubElement(parent,'dot')
                return
    raise ValueError('重新记谱需要超过1024分音符的网格，请在MuseScore校正；未量化或截断')


def _beat_pieces(entries,left,right,ppqn):
    """按拍生成精确时值，连音组内使用同一比例；切片只新增延音，不改原音符。"""
    # 单个任意时值不能可靠地反推出原谱连音组。仅对重新记谱使用此网格，
    # 一拍内所有起止点的最小公分母决定组大小，避免不同的任意比例挤出小节。
    points=sorted({left,right}|{max(left,n.start) for n in entries}|{min(right,n.end) for n in entries})
    denominator=1
    for point in points:denominator=math.lcm(denominator,Fraction(point-left,ppqn).denominator)
    normal=1<<(denominator.bit_length()-1)
    tuplet=denominator!=normal
    result=[]
    for start,end in zip(points,points[1:]):
        if start==end:continue
        source=next((n for n in entries if n.start<=start and n.end>=end),None)
        units=Fraction((end-start)*denominator,ppqn)
        if units.denominator!=1:raise ValueError('重新记谱网格无法精确表示音符，未量化或截断')
        remaining=int(units);cursor=start
        while remaining:
            count=1<<(remaining.bit_length()-1)
            ending=cursor+Fraction(count*ppqn,denominator)
            result.append((source,cursor,ending,count,denominator,normal,tuplet))
            cursor=ending;remaining-=count
    return result


def _tuplet_mark(notations,kind,actual,normal):
    mark=ET.SubElement(notations,'tuplet',type=kind,number='1')
    if kind=='start':
        mark.set('bracket','yes')
        unit={1:'quarter',2:'eighth',4:'16th',8:'32nd',16:'64th',32:'128th',64:'256th',128:'512th',256:'1024th'}.get(normal)
        if unit is None:raise ValueError('重新记谱需要超过1024分音符的网格，请在MuseScore校正')
        for tag,count in (('tuplet-actual',actual),('tuplet-normal',normal)):
            item=ET.SubElement(mark,tag);_text(item,'tuplet-number',count);_text(item,'tuplet-type',unit)


def from_song(song):
    """旧工程/卷帘重新记谱。原有书面结构未知，界面必须标注“重新记谱”。"""
    root=ET.Element('score-partwise',version='4.0');work=ET.SubElement(root,'work');_text(work,'work-title',song.name)
    parts=ET.SubElement(root,'part-list');bar_value=Fraction(song.ppqn*4*song.numerator,song.denominator)
    if bar_value.denominator!=1 or bar_value<=0:raise ValueError('原PPQN无法精确表示小节长度，未量化或截断曲谱')
    bar=int(bar_value)
    markers=song.bar_markers() if song.meter_changes else [(i*bar,str(i+1)) for i in range(max(1,math.ceil(song.duration/bar))+1)]
    measures=list(zip(markers,markers[1:]));links={};mapping={}
    # 按时间区间分配可复用的记谱voice；每谱表最多4声部，额外复音使用额外谱表。
    # 同一voice每小节只输出一次，避免逐音填满休止导致MuseScore把小节判为超长。
    for part_index in range(len(song.source_tracks) or 4):
        source_track=song.source_tracks[part_index] if song.source_tracks else None
        pid=f'P{part_index+1}';declaration=ET.SubElement(parts,'score-part',id=pid);_text(declaration,'part-name',source_track.name if source_track else ('主旋律','和弦','低音','鼓')[part_index])
        part=ET.SubElement(root,'part',id=pid)
        entries=[n for n in song.notes if n.track_id==source_track.track_id] if source_track else [n for n in song.notes if n.part==part_index]
        ends=[];assigned={}
        for n in sorted(entries,key=lambda item:(item.start,item.end,item.note_id)):
            voice=next((i for i,end in enumerate(ends) if end<=n.start),len(ends))
            if voice==len(ends):ends.append(n.end)
            else:ends[voice]=n.end
            assigned[n.note_id]=voice+1
        staff_count=max(1,math.ceil(len(ends)/4))
        for voice in range(1,max(1,len(ends))+1):mapping[f'{pid}:{(voice-1)//4+1}:{voice}']=source_track.device_part if source_track and source_track.device_part is not None else min(part_index,2) if source_track else part_index
        meter=(song.numerator,song.denominator)
        for mi,((left,label),(right,_)) in enumerate(measures):
            bar=right-left;measure=ET.SubElement(part,'measure',number=str(mi+1))
            meter_change=next(((a,b) for tick,a,b in song.meter_changes if tick==left),None)
            if meter_change:meter=meter_change
            if mi==0:
                attributes=ET.SubElement(measure,'attributes');_text(attributes,'divisions',song.ppqn)
                time=ET.SubElement(attributes,'time');_text(time,'beats',meter[0]);_text(time,'beat-type',meter[1])
                if staff_count>1:_text(attributes,'staves',staff_count)
                for staff in range(1,staff_count+1):
                    use_bass=sorted(n.pitch for n in entries)[len(entries)//2]<60 if source_track and entries else part_index==2
                    clef=ET.SubElement(attributes,'clef',number=str(staff));_text(clef,'sign','F' if use_bass else 'G');_text(clef,'line',4 if use_bass else 2)
            elif meter_change:
                attributes=ET.SubElement(measure,'attributes');time=ET.SubElement(attributes,'time');_text(time,'beats',meter[0]);_text(time,'beat-type',meter[1])
            if part_index==0:
                for tick,tempo in song.tempos:
                    if left<=tick<right:
                        direction=ET.SubElement(measure,'direction');dt=ET.SubElement(direction,'direction-type');met=ET.SubElement(dt,'metronome')
                        _text(met,'beat-unit','quarter');_text(met,'per-minute',60_000_000/tempo);_text(direction,'offset',tick-left)
                        ET.SubElement(direction,'sound',tempo=str(60_000_000/tempo))
            sounding=[n for n in entries if n.start<right and n.end>left]
            accidentals={};printed={}
            for n in sorted(sounding,key=lambda item:(item.start,item.pitch,item.note_id)):
                if n.start<left:continue
                step,alter=PITCH_SPELLINGS[n.pitch%12];key=((assigned[n.note_id]-1)//4,step,n.pitch//12)
                if accidentals.get(key,0)!=alter:printed[n.note_id]=alter
                accidentals[key]=alter
            voices=sorted({assigned[n.note_id] for n in sounding})
            for staff in range(staff_count):
                if not any((v-1)//4==staff for v in voices):voices.append(staff*4+1)
            voices.sort()
            for order,voice in enumerate(voices):
                if order>0:
                    backup=ET.SubElement(measure,'backup');_text(backup,'duration',bar)
                staff=(voice-1)//4+1
                selected=sorted((n for n in sounding if assigned[n.note_id]==voice),key=lambda item:item.start)
                if not selected:
                    node=ET.SubElement(measure,'note');ET.SubElement(node,'rest',measure='yes');_text(node,'duration',bar);_text(node,'voice',voice)
                    if staff_count>1:_text(node,'staff',staff)
                    continue
                for beat in range(left,right,song.ppqn):
                    end_beat=min(right,beat+song.ppqn)
                    group=_beat_pieces([n for n in selected if n.start<end_beat and n.end>beat],beat,end_beat,song.ppqn)
                    for index,(n,start,end,count,actual,normal,tuplet) in enumerate(group):
                        node=ET.SubElement(measure,'note')
                        if n is None:ET.SubElement(node,'rest')
                        else:
                            identifier=f'{n.note_id}_s{mi}_{len(links.get(n.note_id,[]))}'
                            links.setdefault(n.note_id,[]).append(identifier);node.set('id',identifier);node.set('dynamics',str(n.velocity/.9))
                            _write_pitch(ET.SubElement(node,'pitch'),n.pitch)
                        length=end-start
                        if length.denominator!=1:raise ValueError('记谱切片无法用原PPQN表示，未量化或截断')
                        _text(node,'duration',int(length))
                        if n is not None:
                            if start>n.start:ET.SubElement(node,'tie',type='stop')
                            if end<n.end:ET.SubElement(node,'tie',type='start')
                        _text(node,'voice',voice);_duration(node,count,normal)
                        if n is not None and start==n.start and n.note_id in printed:_accidental(node,printed[n.note_id])
                        if tuplet:
                            modification=ET.SubElement(node,'time-modification');_text(modification,'actual-notes',actual);_text(modification,'normal-notes',normal)
                        if staff_count>1:_text(node,'staff',staff)
                        if tuplet or n is not None and (start>n.start or end<n.end):
                            notation=ET.SubElement(node,'notations')
                            if n is not None:
                                if start>n.start:ET.SubElement(notation,'tied',type='stop')
                                if end<n.end:ET.SubElement(notation,'tied',type='start')
                            if tuplet and index==0:_tuplet_mark(notation,'start',actual,normal)
                            if tuplet and index==len(group)-1:_tuplet_mark(notation,'stop',actual,normal)
    text=ET.tostring(root,encoding='unicode')
    return ScoreDocument(initial_xml=text,current_xml=text,reconstructed=True,links=links,mapping=mapping,performance_hash=performance_hash(song),notation_schema=3)


def ensure_document(song):
    if song.score_document is None:song.score_document=from_song(song)
    if song.score_document.performance_hash!=performance_hash(song):
        raise ValueError('谱面与音符版本不一致，请先完成乐谱同步')
    if song.score_document.reconstructed and song.score_document.notation_schema<3:
        previous=song.score_document;current=from_song(song)
        current.original_xml=previous.original_xml;current.initial_xml=previous.initial_xml;current.revision=previous.revision+1
        song.score_document=current
    return song.score_document


def sync_song(before,after):
    if before.score_document is None:after.score_document=from_song(after)
    else:
        after.score_document=copy.deepcopy(before.score_document);after.score_document.sync(before,after)


def render_pages(document,width=2000,height=2800):
    try:import verovio
    except ImportError as exc:raise ValueError('缺少 Verovio 五线谱组件，请运行 python scripts/prepare_music_stack.py --install-python') from exc
    # 每个后台实例显式加载随包字体，避免先在主线程导入后后台排版缺字库。
    from importlib.resources import files
    toolkit=verovio.toolkit(False)
    if not toolkit.setResourcePath(str(files('verovio')/'data')):raise ValueError('Verovio 字体资源不可用，请修复音乐组件安装')
    toolkit.setOptions({'pageWidth':width,'pageHeight':height,'scale':40,'svgViewBox':True,'xmlIdChecksum':True})
    if not toolkit.loadData(document.current_xml):raise ValueError('五线谱排版失败：'+toolkit.getLog())
    return [qt_svg(toolkit.renderToSVG(i+1)) for i in range(toolkit.getPageCount())]


def qt_svg(source):
    """Qt SVG 对无尺寸的嵌套 svg 支持不完整，转换成等价缩放组，保留音符ID与矢量字形。"""
    ns='http://www.w3.org/2000/svg';ET.register_namespace('',ns);ET.register_namespace('xlink','http://www.w3.org/1999/xlink')
    root=ET.fromstring(source);outer=list(map(float,root.get('viewBox').split()))
    for node in list(root):
        if node.tag==f'{{{ns}}}svg' and node.get('viewBox'):
            inner=list(map(float,node.attrib.pop('viewBox').split()));node.tag=f'{{{ns}}}g'
            node.set('transform',f'scale({outer[2]/inner[2]} {outer[3]/inner[3]}) translate({-inner[0]} {-inner[1]})')
    return ET.tostring(root,encoding='unicode')


def difference(before,after):
    from collections import Counter
    def keys(song):return Counter((Fraction(n.start,song.ppqn),Fraction(n.end,song.ppqn),n.pitch,n.velocity,n.part) for n in song.notes)
    a,b=keys(before),keys(after)
    return f'原稿 {len(before.notes)} 音符 → 校正版 {len(after.notes)} 音符；新增/变化 {sum((b-a).values())}，删除/变化 {sum((a-b).values())}；速度表'+('相同' if before.tempos==after.tempos and before.ppqn==after.ppqn else '已变化')


def retain_arrangement(before,after):
    """外部校谱只替换乐谱；按四分音符位置保留配器，尾段随新曲长缩放，不能偷偷量化。"""
    after.reference_programs=list(before.reference_programs)
    previous_tracks={t.source_key:t for t in before.source_tracks};identities={}
    for track in after.source_tracks:
        previous=previous_tracks.get(track.source_key);old=track.track_id
        track.track_id=previous.track_id if previous else uuid.uuid5(uuid.UUID(before.resource_id),track.source_key).hex
        identities[old]=track.track_id
        if previous:
            for name in ('device_part','reference_override','preview_muted','preview_solo','reference_volume'):setattr(track,name,getattr(previous,name))
    for note in after.notes:
        if note.track_id in identities:note.track_id=identities[note.track_id]
    if after.score_document:after.score_document.performance_hash=performance_hash(after)
    if not before.sections:return
    ending=after.duration;sections=[]
    for source in before.sections:
        start=Fraction(source.start*after.ppqn,before.ppqn)
        end=Fraction(source.end*after.ppqn,before.ppqn)
        if start.denominator!=1 or end.denominator!=1:
            raise ValueError('校正版 PPQN 无法精确表示原段落边界，请先调整段落位置后导回')
        if start>=ending:break
        section=copy.deepcopy(source);section.start=int(start);section.end=min(int(end),ending);sections.append(section)
    if sections:
        sections[-1].end=ending;after.sections=sections
