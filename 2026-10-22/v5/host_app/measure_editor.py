"""局部MusicXML编辑：只重排选中小节的游标，不由演奏事件重建整首谱。"""
from __future__ import annotations
from fractions import Fraction as F
import copy,math,uuid
import xml.etree.ElementTree as ET
from .score_audit import TYPES,written_duration
from .score_document import xml_root,_write_pitch,_accidental


def measure_data(document,part_id,index):
    root=xml_root(document.current_xml);part=next(p for p in root.findall('part') if p.get('id')==part_id)
    div=1;meter=F(4);target=part.findall('measure')[index]
    for measure in part.findall('measure')[:index+1]:
        for attrs in measure.findall('attributes'):
            div=int(attrs.findtext('divisions',str(div)))
            if attrs.find('time') is not None:meter=sum((sum(F(n) for n in a.text.split('+'))*4/F(b.text) for a,b in zip(attrs.findall('time/beats'),attrs.findall('time/beat-type'))),F(0))
    # 本小节中途改变divisions时逐项解释；前面的属性只用来确定入口上下文。
    div=1
    for measure in part.findall('measure')[:index]:
        for attrs in measure.findall('attributes'):div=int(attrs.findtext('divisions',str(div)))
    cursor=F(0);previous=F(0);rows=[];other=[]
    for order,node in enumerate(target):
        if node.tag=='attributes':div=int(node.findtext('divisions',str(div)));other.append((cursor,order,copy.deepcopy(node)))
        elif node.tag in ('backup','forward'):cursor+=F(node.findtext('duration','0'))/div*(-1 if node.tag=='backup' else 1)
        elif node.tag=='note':
            chord=node.find('chord') is not None;start=previous if chord else cursor;duration=F(node.findtext('duration','0'))/div
            pitch=node.find('pitch');midi=None
            if pitch is not None:midi=12*(int(pitch.findtext('octave','4'))+1)+{'C':0,'D':2,'E':4,'F':5,'G':7,'A':9,'B':11}[pitch.findtext('step')]+int(pitch.findtext('alter','0'))
            rows.append(dict(id=node.get('id','n'+uuid.uuid4().hex),start=str(start),duration=str(duration),pitch=midi,
                staff=node.findtext('staff','1'),voice=node.findtext('voice','1'),type=node.findtext('type','quarter'),dots=len(node.findall('dot')),
                actual=int(node.findtext('time-modification/actual-notes','1')),normal=int(node.findtext('time-modification/normal-notes','1')),
                tie_start=any(t.get('type')=='start' for t in node.findall('tie')),tie_stop=any(t.get('type')=='stop' for t in node.findall('tie')),
                grace=node.find('grace') is not None,chord=chord,node=copy.deepcopy(node),order=order))
            rows[-1]['tuplet_start']=any(t.get('type')=='start' for t in node.findall('notations/tuplet'))
            rows[-1]['tuplet_stop']=any(t.get('type')=='stop' for t in node.findall('notations/tuplet'))
            if not chord:previous=start;cursor=start+duration
        elif node.tag=='direction':
            offset=F(node.findtext('offset','0'))/div;other.append((cursor+offset,order,copy.deepcopy(node)))
        else:other.append((cursor,order,copy.deepcopy(node)))
    return dict(root=root,part=part,measure=target,rows=rows,other=other,meter=meter,part_id=part_id,index=index)


def _set(parent,name,value):
    node=parent.find(name)
    if node is None:node=ET.SubElement(parent,name)
    node.text=str(value);return node


def set_measure_tempo(document,part_id,index,bpm):
    bpm=F(bpm)
    if not 4<=bpm<=1000:raise ValueError('速度范围为4～1000 BPM（四分音符每分钟）')
    model=measure_data(document,part_id,index);measure=model['measure']
    # 保留同一direction中的力度/文字，仅替换本小节起点的旧速度。
    original_children=list(measure)
    for position,order,_ in model['other']:
        node=original_children[order]
        if position==0 and node.tag=='direction':
            sound=node.find('sound')
            if sound is not None:sound.attrib.pop('tempo',None)
            for kind in node.findall('direction-type'):
                for mark in list(kind.findall('metronome')):kind.remove(mark)
                if not list(kind):node.remove(kind)
            if sound is not None and not sound.attrib and not list(sound):node.remove(sound)
            if node.find('direction-type') is None and node.find('sound') is None:measure.remove(node)
    direction=ET.Element('direction');kind=ET.SubElement(direction,'direction-type');metronome=ET.SubElement(kind,'metronome')
    _set(metronome,'beat-unit','quarter');_set(metronome,'per-minute',float(bpm));ET.SubElement(direction,'sound',tempo=str(float(bpm)))
    # 回写后按新的单位和游标插入；下一次compile读取同一份XML中的速度。
    document.current_xml=ET.tostring(model['root'],encoding='unicode')
    rows=model['rows'];return apply_measure(document,part_id,index,rows,[(F(0),direction)])


def set_measure_meter(document,part_id,index,beats,unit):
    beats,unit=int(beats),int(unit)
    if not 1<=beats<=32 or unit not in (1,2,4,8,16,32):raise ValueError('拍号分子范围1～32，分母为1/2/4/8/16/32')
    model=measure_data(document,part_id,index);children=list(model['measure'])
    for position,order,_ in model['other']:
        node=children[order]
        if position==0 and node.tag=='attributes':
            for time in list(node.findall('time')):node.remove(time)
    attrs=ET.Element('attributes');time=ET.SubElement(attrs,'time');_set(time,'beats',beats);_set(time,'beat-type',unit)
    document.current_xml=ET.tostring(model['root'],encoding='unicode')
    return apply_measure(document,part_id,index,model['rows'],[(F(0),attrs)])


def _change_attributes(document,part_id,index,position,tag,replacement,number=None):
    """只替换目标位置的记谱上下文；音符使用绝对音高，不随谱号/调号偷偷移调。"""
    position=F(position);candidate=copy.deepcopy(document);model=measure_data(candidate,part_id,index)
    if not 0<=position<=model['meter']:raise ValueError('记号位置应在本小节内，单位为四分音符')
    children=list(model['measure'])
    for at,order,_ in model['other']:
        node=children[order]
        if at==position and node.tag=='attributes':
            for item in list(node.findall(tag)):
                if number is None or item.get('number','1')==str(number):node.remove(item)
    attributes=ET.Element('attributes');attributes.append(replacement)
    candidate.current_xml=ET.tostring(model['root'],encoding='unicode')
    apply_measure(candidate,part_id,index,model['rows'],[(position,attributes)])
    # 校验和精确时值换算成功后才提交，失败时原文档保持可继续编辑。
    document.current_xml=candidate.current_xml;document.revision=candidate.revision
    document.reviewed_measures=candidate.reviewed_measures
    return document


def set_measure_clef(document,part_id,index,staff,sign,line,octave=0,position=0):
    staff,line,octave=int(staff),int(line),int(octave)
    if not 1<=staff<=128 or sign not in ('G','F','C') or not 1<=line<=5 or not -2<=octave<=2:
        raise ValueError('谱表1～128；谱号G/F/C；线号1～5；八度变化-2～2')
    clef=ET.Element('clef',number=str(staff));_set(clef,'sign',sign);_set(clef,'line',line)
    if octave:_set(clef,'clef-octave-change',octave)
    return _change_attributes(document,part_id,index,position,'clef',clef,staff)


def set_measure_key(document,part_id,index,fifths,position=0,mode=None):
    fifths=int(fifths)
    if not -7<=fifths<=7:raise ValueError('调号升降数范围为-7～7；负数为降号')
    if mode is not None and mode not in ('major','minor','dorian','phrygian','lydian','mixolydian','aeolian','ionian','locrian','none'):
        raise ValueError('调式无效')
    if mode is None:
        # 保留原调式；此入口设置当前乐器的全部谱表，明确替换该位置的分谱表调号。
        root=xml_root(document.current_xml);part=next(p for p in root.findall('part') if p.get('id')==part_id)
        model=measure_data(document,part_id,index)
        keys=[k for m in part.findall('measure')[:index] for k in m.findall('attributes/key')]
        keys.extend(k for at,_,a in model['other'] if at<=F(position) and a.tag=='attributes' for k in a.findall('key'))
        if keys:mode=keys[-1].findtext('mode')
    key=ET.Element('key');_set(key,'fifths',fifths)
    if mode is not None:_set(key,'mode',mode)
    return _change_attributes(document,part_id,index,position,'key',key)


def apply_measure(document,part_id,index,rows,changes=()):
    model=measure_data(document,part_id,index);root=model['root'];measure=model['measure'];other=model['other']
    # 统一整份XML的divisions只是精确单位换算，保留音高/谱号/连音/节点ID及其他小节结构。
    divisions=1
    for n in root.iter('divisions'):divisions=math.lcm(divisions,int(n.text))
    for row in rows:
        for key in ('start','duration'):divisions=math.lcm(divisions,F(row[key]).denominator)
    for time,_,_ in other:divisions=math.lcm(divisions,time.denominator)
    for time,node in changes:divisions=math.lcm(divisions,F(time).denominator)
    if divisions>1_000_000:raise ValueError('小节精确时值单位过大，请检查连音比例')
    for part in root.findall('part'):
        old_div=1
        for m in part.findall('measure'):
            for node in m:
                if node.tag=='attributes':
                    old_div=int(node.findtext('divisions',str(old_div)))
                    if node.find('divisions') is not None:node.find('divisions').text=str(divisions)
                for value in node.findall('duration')+node.findall('offset'):
                    scaled=F(value.text)*divisions/old_div
                    if scaled.denominator!=1:raise ValueError('原XML时值不能精确换算')
                    value.text=str(int(scaled))
        first=part.find('measure')
        if first is not None:
            attrs=first.find('attributes')
            if attrs is None:attrs=ET.Element('attributes');first.insert(0,attrs)
            _set(attrs,'divisions',divisions)
    old_nodes={row['id']:row for row in model['rows']};events=[]
    for order,row in enumerate(rows):
        start=F(row['start']);duration=F(row['duration'])
        if start<0 or duration<0 or duration==0 and not row.get('grace'):raise ValueError('音符起点不能为负，普通音符时长必须为正')
        old=old_nodes.get(row['id']);node=copy.deepcopy(old['node']) if old else ET.Element('note')
        node.set('id',row['id'])
        for tag in ('chord','duration','voice','type','dot','time-modification','staff','tie','grace'):
            for item in list(node.findall(tag)):node.remove(item)
        pitch=node.find('pitch');rest=node.find('rest')
        if row.get('pitch') is None:
            if pitch is not None:node.remove(pitch)
            if rest is None:node.insert(0,ET.Element('rest'))
        else:
            value=int(row['pitch'])
            if not 0<=value<=127:raise ValueError('音高必须为0..127')
            if rest is not None:node.remove(rest)
            if pitch is None:pitch=ET.Element('pitch');node.insert(0,pitch)
            if old is None or old['pitch']!=value:
                _write_pitch(pitch,value)
                for accidental in list(node.findall('accidental')):node.remove(accidental)
                _accidental(node,int(pitch.findtext('alter','0')))
        if row.get('grace'):node.insert(0,ET.Element('grace'))
        else:_set(node,'duration',int(duration*divisions))
        _set(node,'voice',row['voice']);_set(node,'type',row['type'])
        for _ in range(int(row['dots'])):ET.SubElement(node,'dot')
        actual,normal=int(row['actual']),int(row['normal'])
        if actual<=0 or normal<=0:raise ValueError('连音比例必须为正整数')
        if actual!=normal:
            tm=ET.SubElement(node,'time-modification');_set(tm,'actual-notes',actual);_set(tm,'normal-notes',normal)
        _set(node,'staff',row['staff']);notations=node.find('notations')
        if notations is not None:
            for tied in list(notations.findall('tied')):notations.remove(tied)
            for tuplet in list(notations.findall('tuplet')):notations.remove(tuplet)
        for mark in ('start','stop'):
            if row.get('tuplet_'+mark):
                if notations is None:notations=ET.SubElement(node,'notations')
                tuplet=ET.SubElement(notations,'tuplet',type=mark,number='1')
                if mark=='start':
                    tuplet.set('bracket','yes')
                    for tag,value in (('tuplet-actual',actual),('tuplet-normal',normal)):_set(ET.SubElement(tuplet,tag),'tuplet-number',value)
        for name in ('stop','start'):
            if row.get('tie_'+name):
                ET.SubElement(node,'tie',type=name)
                if notations is None:notations=ET.SubElement(node,'notations')
                ET.SubElement(notations,'tied',type=name)
        order_map={tag:n for n,tag in enumerate(('grace','cue','chord','pitch','rest','unpitched','duration','tie','instrument','footnote','level','voice','type','dot','accidental','time-modification','stem','notehead','staff','beam','notations','lyric','play','listen'))}
        node[:]=sorted(node,key=lambda child:order_map.get(child.tag,99))
        events.append((start,order,row,node,duration))
    groups={}
    for start,order,row,node,duration in events:groups.setdefault((start,str(row['voice'])),[]).append((order,row,node,duration))
    output=[]
    for (start,voice),items in groups.items():
        items.sort(key=lambda item:item[0]);nodes=[]
        for n,(_,row,node,duration) in enumerate(items):
            if n:
                if row['pitch'] is None or items[0][1]['pitch'] is None:raise ValueError('同一声部同一位置不能同时含休止与音符')
                node.insert(0,ET.Element('chord'))
            nodes.append(node)
        output.append((start,10,items[0][0],nodes,items[0][3]))
    ending_nodes=[]
    for time,order,node in other:
        if node.tag=='barline':ending_nodes.append(node);continue
        if node.tag=='attributes' and node.find('divisions') is not None:node.find('divisions').text=str(divisions)
        if node.tag=='direction':
            for offset in list(node.findall('offset')):node.remove(offset)
            sound=node.find('sound')
            if sound is not None:
                for offset in list(sound.findall('offset')):sound.remove(offset)
        output.append((time,0,order,[node],F(0)))
    for order,(time,node) in enumerate(changes):output.append((F(time),1,order,[copy.deepcopy(node)],F(0)))
    for child in list(measure):measure.remove(child)
    cursor=F(0)
    for time,_,_,nodes,duration in sorted(output,key=lambda e:e[:3]):
        if time!=cursor:
            move=ET.SubElement(measure,'forward' if time>cursor else 'backup');_set(move,'duration',int(abs(time-cursor)*divisions))
        for node in nodes:measure.append(node)
        cursor=time+duration
    ending=max([F(r['start'])+F(r['duration']) for r in rows]+[F(0)])
    if cursor<ending:
        move=ET.SubElement(measure,'forward');_set(move,'duration',int((ending-cursor)*divisions))
    for node in ending_nodes:measure.append(node)
    document.current_xml=ET.tostring(root,encoding='unicode');document.revision+=1
    document.reviewed_measures={key:value for key,value in document.reviewed_measures.items() if not key.startswith(part_id+':'+measure.get('number','')+':')}
    return document


def recompile_song(before,document):
    from .source_tracks import attach_xml_tracks
    from .score_document import retain_arrangement,performance_hash
    result=document.compile(before.name,uncertain=True,device_constraints=False);result.resource_id=before.resource_id
    result.source_files=list(before.source_files);result.recognition=copy.deepcopy(before.recognition)
    if before.source_tracks:
        attach_xml_tracks(result);old={t.source_key:t for t in before.source_tracks}
        for track in result.source_tracks:
            if track.source_key in old:
                prior=old[track.source_key]
                for key in ('name','device_part','reference_override','preview_muted','preview_solo','reference_volume','gain_db'):setattr(track,key,getattr(prior,key))
    retain_arrangement(before,result);result.revision=before.revision+1;result.track_mix=copy.deepcopy(before.track_mix)
    from .score_review import snapshot
    old_bars=snapshot(before.score_document)[1] if before.score_document else []
    _,new_bars,note_bars,_=snapshot(document)
    previous_hash={m['id']:m['content_hash'] for m in old_bars}
    unchanged={m['id'] for m in new_bars if previous_hash.get(m['id'])==m['content_hash']}
    previous={n.note_id:n for n in before.notes}
    for n in result.notes:
        old=previous.get(n.note_id)
        linked_bars={note_bars.get(identifier) for identifier in document.links.get(n.note_id,[n.note_id])}
        # 音高不变也可能改过谱号/调号/连音记法。相关源小节变化后不能沿用旧确认。
        if old and linked_bars and None not in linked_bars and linked_bars.issubset(unchanged) and \
            (F(old.start,before.ppqn),F(old.end,before.ppqn),old.pitch,old.velocity)==(F(n.start,result.ppqn),F(n.end,result.ppqn),n.pitch,n.velocity):n.uncertain=old.uncertain
    result.score_document.performance_hash=performance_hash(result);return result
