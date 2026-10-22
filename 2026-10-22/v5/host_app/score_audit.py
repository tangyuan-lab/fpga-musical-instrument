"""MusicXML结构审计。按源小节身份定位，不能把错误的累计时长当作原谱坐标。"""
from fractions import Fraction as F
import hashlib,json,copy
import xml.etree.ElementTree as ET

TYPES={'maxima':32,'long':16,'breve':8,'whole':4,'half':2,'quarter':1,
       'eighth':F(1,2),'16th':F(1,4),'32nd':F(1,8),'64th':F(1,16),'128th':F(1,32),'256th':F(1,64),'512th':F(1,128),'1024th':F(1,256)}
DYNAMICS={'pppp':12,'ppp':24,'pp':36,'p':49,'mp':64,'mf':80,'f':96,'ff':112,'fff':124,'ffff':127}


def measure_fingerprint(measure,entry_divisions,context):
    # divisions只是计量单位。局部精确编辑改变全谱单位时，不使其他小节的核对凭据失效。
    canonical=copy.deepcopy(measure);divisions=entry_divisions
    for child in list(canonical):
        if child.tag=='attributes':
            units=child.find('divisions')
            if units is not None:divisions=int(units.text);child.remove(units)
            if not list(child) and not child.attrib:canonical.remove(child);continue
        for node in child.iter():
            if node.tag in ('duration','offset'):node.text=str(F(node.text)/divisions)
    for node in canonical.iter():
        if node.text is not None and not node.text.strip():node.text=None
        node.tail=None
    return hashlib.sha256(json.dumps(context,sort_keys=True).encode()+ET.tostring(canonical)).hexdigest()


def written_duration(note):
    kind=note.findtext('type');base=TYPES.get(kind)
    if base is None:return None
    return F(base)*sum((F(1,2**i) for i in range(len(note.findall('dot'))+1)),F(0))


def audit(root):
    issues=[];measures=[];velocities={};seen=set()
    def issue(code,part,measure,message,node=None,severity='error'):
        identifier=f'{part}:{measure}:{node.get("id", "") if node is not None else ""}:{code}'
        issues.append(dict(id=identifier,code=code,part=part,measure=str(measure),note_id=node.get('id','') if node is not None else '',message=message,severity=severity))
    has_tempo=any('tempo' in s.attrib for s in root.iter('sound')) or root.find('.//metronome') is not None
    if not has_tempo:issue('missing_tempo','*','1','未识别到速度；电脑暂按120 BPM试听，请确认原谱速度',severity='question')
    for part in root.findall('part'):
        pid=part.get('id','?');divisions=1;meter=F(4);nominal=F(0);held={};levels={};clefs={};keys={};first=True;meter_known=False
        level_events=[];note_levels=[];page=0
        for mi,measure in enumerate(part.findall('measure')):
            label=measure.get('number',str(mi+1));cursor=F(0);ending=F(0);previous=None;context=dict(clefs=dict(clefs),keys=dict(keys),meter=str(meter));entry_divisions=divisions
            if mi and any(p.get('new-page')=='yes' for p in measure.findall('print')):page+=1
            for item in measure:
                if item.tag=='attributes':
                    if item.find('divisions') is not None:divisions=int(item.findtext('divisions'))
                    if divisions<=0:raise ValueError('MusicXML divisions 必须大于0')
                    for c in item.findall('clef'):clefs[c.get('number','1')]=ET.tostring(c,encoding='unicode')
                    for k in item.findall('key'):keys[k.get('number','*')]=ET.tostring(k,encoding='unicode')
                    t=item.find('time')
                    if t is not None:
                        meter_known=True
                        beats=t.findall('beats');units=t.findall('beat-type')
                        if len(beats)!=len(units):issue('invalid_meter',pid,label,'拍号分子分母不配对')
                        else:meter=sum((sum(F(v) for v in a.text.split('+'))*4/F(b.text) for a,b in zip(beats,units)),F(0))
                elif item.tag in ('backup','forward'):
                    delta=F(item.findtext('duration','0'))/divisions
                    if delta<0:issue('negative_duration',pid,label,'回退／前进时值为负')
                    cursor+=delta*(-1 if item.tag=='backup' else 1)
                    if cursor<0:issue('negative_backup',pid,label,'声部回退超出小节开头')
                    ending=max(ending,cursor);previous=None
                elif item.tag=='direction':
                    sound=item.find('sound');staff=item.findtext('staff','*')
                    value=None
                    if sound is not None and sound.get('dynamics') is not None:value=round(float(sound.get('dynamics'))*.9)
                    elif item.find('direction-type/dynamics') is not None:
                        mark=item.find('direction-type/dynamics');value=next((DYNAMICS[c.tag] for c in mark if c.tag in DYNAMICS),None)
                    if value is not None:level_events.append((nominal+cursor+F(item.findtext('offset','0'))/divisions,staff,max(1,min(127,value))))
                elif item.tag=='note':
                    identifier=item.get('id','');voice=item.findtext('voice','1');staff=item.findtext('staff','1')
                    if identifier and identifier in seen:issue('duplicate_note_id',pid,label,'音符ID重复',item)
                    seen.add(identifier)
                    chord=item.find('chord') is not None;grace=item.find('grace') is not None
                    start=previous[0] if chord and previous is not None else cursor
                    if chord and (previous is None or previous[1]!=voice or previous[2]):issue('invalid_chord',pid,label,'和弦音没有同声部的前置音符，或前置项为休止',item)
                    duration=F(item.findtext('duration','0'))/divisions
                    if duration<=0 and not grace:issue('zero_duration',pid,label,'音符／休止缺少正时值',item)
                    expected=written_duration(item);tm=item.find('time-modification')
                    if tm is not None:
                        a=F(tm.findtext('actual-notes','0'));b=F(tm.findtext('normal-notes','0'))
                        if a<=0 or b<=0:issue('invalid_tuplet',pid,label,'连音比例必须为正',item)
                        elif expected is not None:expected*=b/a
                    full_rest=item.find('rest') is not None and item.find('rest').get('measure')=='yes'
                    if expected is not None and not grace and not full_rest and expected!=duration:
                        issue('duration_mismatch',pid,label,f'记谱时值与演奏时值不一致：{expected} / {duration}拍',item)
                    pitch=item.find('pitch')
                    if pitch is not None:
                        semitone={'C':0,'D':2,'E':4,'F':5,'G':7,'A':9,'B':11}.get(pitch.findtext('step'))
                        if semitone is not None:
                            midi=(int(pitch.findtext('octave','4'))+1)*12+semitone+F(pitch.findtext('alter','0'));key=(voice,midi)
                            ties={t.get('type') for t in item.findall('tie')}
                            if 'stop' in ties:
                                if key not in held:issue('orphan_tie_stop',pid,label,'延音终点没有对应起点',item)
                                elif held[key][0]!=nominal+start:issue('discontinuous_tie',pid,label,'延音链时间不连续',item)
                            if 'start' in ties:held[key]=(nominal+start+duration,label,item)
                            elif 'stop' in ties:held.pop(key,None)
                    note_levels.append((identifier,nominal+start,staff,item.get('dynamics')))
                    if grace and not any(k in item.find('grace').attrib for k in ('make-time','steal-time-following','steal-time-previous')):
                        issue('grace_timing',pid,label,'装饰音缺少明确播放时值，请局部试听并确认借时规则',item,'question')
                    if not chord:previous=(start,voice,item.find('rest') is not None);cursor=start+duration
                    ending=max(ending,start+duration)
            implicit=measure.get('implicit')=='yes'
            if first and not meter_known:issue('missing_meter',pid,label,'未识别到拍号，请确认',severity='question')
            if meter_known and ending>meter:issue('overfull',pid,label,f'小节超拍：{ending}拍，拍号要求{meter}拍')
            elif meter_known and ending<meter and not implicit:issue('underfull',pid,label,f'小节欠拍：{ending}拍，拍号要求{meter}拍')
            digest=measure_fingerprint(measure,entry_divisions,context)
            measures.append(dict(id=f'{pid}:{label}:{mi}',part=pid,measure=label,index=mi,page=page,start=str(nominal),length=str(meter),actual_length=str(ending),implicit=implicit,content_hash=digest))
            nominal+=ending if implicit else meter;first=False
        for (_,pitch),(_,label,node) in held.items():issue('orphan_tie_start',pid,label,'延音起点没有对应终点',node)
        for identifier,start,staff,override in note_levels:
            values=[(time,i,value) for i,(time,s,value) in enumerate(level_events) if time<=start and s in ('*',staff)]
            velocities[identifier]=max(1,min(127,round(float(override)*.9))) if override is not None else max(values)[2] if values else 100
    return issues,measures,velocities
