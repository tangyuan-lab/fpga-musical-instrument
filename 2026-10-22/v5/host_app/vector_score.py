"""MuseScore/Leland 双谱表矢量 PDF 校谱。

读取真实 SMuFL 音头、谱号、附点、符干/符梁、连音括号与延音曲线，不从声音推测音符。
仅接受能完整覆盖音头、能闭合各小节的矢量谱；扫描图片仍交给 Audiveris，并保留待确认标记。
几何坐标为 PDF point；输出 Note.box 统一换算为 180 dpi 原谱预览像素。
"""
from pathlib import Path
from fractions import Fraction
import collections
import math
import re
import pymupdf
from .music_project import Song, Note, Section

def extract(page):
 chars=[]
 for block in page.get_text('rawdict')['blocks']:
  for line in block.get('lines',[]):
   for span in line['spans']:
    for char in span['chars']:
     chars.append(dict(c=ord(char['c']),text=char['c'],x=char['origin'][0],y=char['origin'][1],size=span['size'],font=span['font'],box=char['bbox']))
 heads=[dict(c,idx=i) for i,c in enumerate(chars) if c['c'] in (0xe0a2,0xe0a3,0xe0a4)]
 paths=page.get_drawings();systems={}
 for d in paths:
  if not .75<(d['width'] or 0)<1.2:continue
  r=d['rect']
  if r.width<.1 and r.height>30:
   key=round(r.y0,1);s=systems.setdefault(key,dict(tops=[r.y0+.273,r.y1],bars=[]));s['bars'].append(r.x0)
 systems=sorted(systems.values(),key=lambda s:s['tops'][0])
 for s in systems:s['bars']=sorted(set(round(x,3) for x in s['bars']))
 space=4.96063
 ledger=[d['rect'] for d in paths if .7<(d['width'] or 0)<.85 and d['rect'].height<.1 and 6<d['rect'].width<20]
 for h in heads:
  options=[]
  column_lines=[r.y0 for r in ledger if r.x0-1<h['x']+3<r.x1+1]
  for si,s in enumerate(systems):
   for st,top in enumerate(s['tops']):
    bottom=top+4*space; edge=top if h['y']<top else bottom
    outside=max(top-h['y'],h['y']-bottom,0);sign=-1 if h['y']<top else 1
    missing=sum(not any(abs(y-(edge+sign*k*space))<.2 for y in column_lines) for k in range(1,math.floor((outside+.1)/space)+1))
    distance=abs((h['y']-top)/(space/2)-round((h['y']-top)/(space/2)))*space/2
    options.append((missing*20+distance*3+outside*.005,si,st,missing,distance))
  cost,si,st,missing,error=min(options);h['system']=si;h['staff']=st;h['ledger_missing']=missing;h['grid_error']=error
 clefs=[]
 for c in chars:
  if c['c'] not in (0xe050,0xe062):continue
  sign='G' if c['c']==0xe050 else 'F'
  options=[(abs(c['y']-(top+(3 if sign=='G' else 1)*space)),si,st) for si,s in enumerate(systems) for st,top in enumerate(s['tops'])]
  distance,si,st=min(options);clefs.append(dict(c,system=si,staff=st,sign=sign))
 events=[];assigned=collections.Counter()
 for pi,d in enumerate(paths):
  r=d['rect']
  if not (.4<(d['width'] or 0)<.6 and r.width<.1 and r.height>7 and len(d['items'])==1):continue
  x=r.x0
  for direction in ('up','down'):
   tip=r.y0 if direction=='up' else r.y1;attach=r.y1 if direction=='up' else r.y0
   base=x-6.20 if direction=='up' else x-.248
   end_heads=[h for h in heads if abs(h['x']-base)<.6 and abs(h['y']-(attach+(.794 if direction=='up' else -.837)))<.6]
   if not end_heads:continue
   attached=[h for h in heads if min(abs(h['x']-base),abs(h['x']-base-(5.953 if direction=='up' else -5.953)))<.6 and r.y0-.9<=h['y']<=r.y1+.9 and abs(h['y']-tip)>6]
   si,st=collections.Counter((h['system'],h['staff']) for h in attached).most_common(1)[0][0];s=systems[si]
   if not s['bars'][0]<=base<=s['bars'][-1]:continue
   beams=[]
   beam_centers=[]
   for bi,b in enumerate(paths):
    rr=b['rect']
    if b['fill'] and 1<rr.height<18 and rr.width>3 and len(b['items'])==4 and all(it[0]=='l' for it in b['items']):
     if rr.x0-.3<=x<=rr.x1+.3 and abs((rr.y0+rr.y1)/2-tip)<14:
      intersections=[]
      for line in b['items']:
       a,z=line[1],line[2]
       if abs(a.x-z.x)>.1 and min(a.x,z.x)-.3<=x<=max(a.x,z.x)+.3:intersections.append(a.y+(z.y-a.y)*(x-a.x)/(z.x-a.x))
      if intersections:beam_centers.append(sum(intersections)/len(intersections))
   if any(abs(y-tip)<1.4 for y in beam_centers):
    beams=[y for y in beam_centers if -.5<=(y-tip)*(1 if direction=='up' else -1)<13]
   flags=[c for c in chars if 0xe240<=c['c']<=0xe24f and abs(c['x']-(x-.248))<.6 and abs(c['y']-tip)<.6]
   beam_count=max(len(beams),max([(f['c']-0xe240)//2+1 for f in flags]+[0]))
   duration=2 if any(h['c']==0xe0a3 for h in attached) else 4 if any(h['c']==0xe0a2 for h in attached) else 1/(2**beam_count)
   max_x=max(h['x'] for h in attached)
   dots=[c for c in chars if c['c']==0xe1e7 and max_x+7<c['x']<max_x+(19 if any(h['c']==0xe0a3 for h in attached) else 13) and min(abs(c['y']-h['y']) for h in attached)<2.6]
   if dots:duration*=1.5
   event=dict(x=base,stem_x=x,system=si,staff=st,direction=direction,heads=attached,duration=duration,beams=beam_count,dots=bool(dots),tip=tip)
   for h in attached:assigned[h['idx']]+=1
   events.append(event)
 for c in chars:
  if not 0xe4e3<=c['c']<=0xe4eb:continue
  opts=[(abs(c['y']-(top+2*space)),si,st) for si,s in enumerate(systems) for st,top in enumerate(s['tops'])]
  _,si,st=min(opts)
  duration={0xe4e3:3,0xe4e4:2,0xe4e5:1,0xe4e6:.5,0xe4e7:.25,0xe4e8:.125,0xe4e9:.0625}.get(c['c'],1)
  events.append(dict(x=c['x'],system=si,staff=st,heads=[],duration=duration,rest=True,c=c['c'],y=c['y'],direction='up' if c['y']<systems[si]['tops'][st]+2*space else 'down'))
 # 元素使用原始矢量坐标；括号左右线段和中间数字共同界定连音范围。
 tuplets=[]
 for c in chars:
  if not (c['text'].isdigit() and 8.8<c['size']<9.2 and 'Italic' in c['font']):continue
  number=int(c['text'])
  if number not in (3,5,6,7,9):continue
  candidates=[d for d in paths if len(d['items'])==2 and all(i[0]=='l' for i in d['items']) and d['rect'].width>1 and d['rect'].height>1 and abs(d['rect'].y1-c['y'])<18]
  left=min([d for d in candidates if d['rect'].x1<=c['x']+1],key=lambda d:abs(d['rect'].x1-c['x']),default=None)
  right=min([d for d in candidates if d['rect'].x0>=c['x']+3],key=lambda d:abs(d['rect'].x0-c['x']-5),default=None)
  factor={3:2/3,5:4/5,6:4/6,7:4/7,9:8/9}[number]
  if left and right and abs(left['rect'].x1-c['x'])<=10 and abs(right['rect'].x0-c['x']-5)<=10:
   ranges=[(left['rect'].x0,right['rect'].x1)]
  else:
   ranges=[(b['rect'].x0,b['rect'].x1) for b in paths if b['fill'] and len(b['items'])==4 and all(i[0]=='l' for i in b['items']) and 1<b['rect'].height<18 and b['rect'].width>15 and b['rect'].x0<c['x']+3<b['rect'].x1 and abs((b['rect'].y0+b['rect'].y1)/2-c['y'])<20]
  choices=[]
  for x0,x1 in ranges:
   near=[e for e in events if x0-1<=e.get('stem_x',e['x']+.25 if e.get('rest') else e['x']+6.2)<=x1+1 and abs(e.get('tip',e.get('y',999))-c['y'])<100]
   for si,st in set((e['system'],e['staff']) for e in near):
    for di in ('up','down','all'):
     selected=[e for e in near if e['system']==si and e['staff']==st and (di=='all' or e['direction']==di)]
     if len(selected)<2:continue
     bars=systems[si]['bars'];a=max((x for x in bars if x<x0+3),default=bars[0]);b=min((x for x in bars if x>x1-3),default=bars[-1])
     lane=[e for e in events if e['system']==si and e['staff']==st and a<e['x']<b and (di=='all' or e['direction']==di)]
     total=sum(e['duration'] for e in lane)+sum(e['duration'] for e in selected)*(factor-1)
     score=abs(total-3)*100+sum(abs(e.get('tip',e.get('y',999))-c['y']) for e in selected)/len(selected)*.001
     choices.append((score,si,st,di,x0,x1,selected))
  if not choices:continue
  score,si,st,direction,x0,x1,selected=min(choices,key=lambda a:a[0])
  if score>1:continue
  for e in selected:e['duration']*=factor;e['tuplet']=number
  tuplets.append(dict(number=number,x0=x0,x1=x1,system=si,staff=st,direction=direction))
 for s in systems:s['bars']=sorted(set(round(x,3) for x in s['bars']))
 return dict(events=events,systems=systems,heads=heads,clefs=clefs,chars=chars,tuplets=tuplets,assigned=assigned,paths=paths)


def _fraction(value):return Fraction(value).limit_denominator(23040)


def _lane(events, beats):
 """省略的静音声部不产生音频；只有唯一能闭合的小节休止子集才参与定时。"""
 notes=[e for e in events if e['heads']];rests=[e for e in events if not e['heads']]
 wanted=beats-sum((_fraction(e['duration']) for e in notes),Fraction())
 choices=[]
 for mask in range(1<<len(rests)):
  chosen=[e for i,e in enumerate(rests) if (mask>>i)&1]
  if sum((_fraction(e['duration']) for e in chosen),Fraction())==wanted:choices.append(chosen)
 if len(choices)==1:return sorted(notes+choices[0],key=lambda e:e['x'])
 return None


def _schedule(data, beats):
 records=[];bar_number=0;inferred=[]
 for page_number,page in enumerate(data):
  if any(page['assigned'][h['idx']]!=1 or h['ledger_missing'] or h['grid_error']>.1 for h in page['heads']):
   raise ValueError('矢量音头归属或加线存在歧义，不能作为自动校正版')
  for system_number,system in enumerate(page['systems']):
   for left,right in zip(system['bars'],system['bars'][1:]):
    bar_number+=1;bar_start=(bar_number-1)*beats;unsolved=[];anchors=[]
    for staff in (0,1):
     events=sorted([e for e in page['events'] if e['system']==system_number and e['staff']==staff and left<e['x']<right],key=lambda e:e['x'])
     lanes={d:[e for e in events if e['direction']==d] for d in ('up','down')}
     # 单声部的符干随音高改变方向，不能把两个方向错误地都从小节起点播放。
     if sum((_fraction(e['duration']) for e in events),Fraction())==beats:
      groups=[events]
     else:groups=[_lane(lanes[d],beats) for d in ('up','down')]
     for lane_index,group in enumerate(groups):
      if group is None:
       unsolved.append((staff,lanes[('up','down')[lane_index]]));continue
      cursor=bar_start
      for event in group:
       event['start']=cursor;event['end']=cursor+_fraction(event['duration']);event['bar']=bar_number
       if not event.get('rest') or event.get('c')!=0xe4e3:anchors.append((event['x'],cursor-bar_start))
       if event['heads']:records.append((page_number,system_number,staff,event))
       cursor=event['end']
      if cursor!=bar_start+beats:raise ValueError(f'第{bar_number}小节定时未闭合')
    for staff,events in unsolved:
     notes=[e for e in events if e['heads']]
     if not notes:continue
     # 无声部开头休止的单个持续音：只接受“曲尾对齐”且横坐标与独立声部锚点相符。
     if len(notes)!=1:raise ValueError(f'第{bar_number}小节声部时值有歧义')
     event=notes[0];start=beats-_fraction(event['duration'])
     if start<0:raise ValueError(f'第{bar_number}小节音符超过拍号')
     before=[(x,t) for x,t in anchors if t<=start];after=[(x,t) for x,t in anchors if t>=start]
     if not before or not after:raise ValueError(f'第{bar_number}小节缺少独立定位锚点')
     x0,t0=max(before,key=lambda a:a[1]);x1,t1=min(after,key=lambda a:a[1])
     expected=x0 if t0==t1 else x0+float((start-t0)/(t1-t0))*(x1-x0)
     if abs(expected-event['x'])>7:raise ValueError(f'第{bar_number}小节省略休止位置无法确认')
     event['start']=bar_start+start;event['end']=bar_start+beats;event['bar']=bar_number
     records.append((page_number,system_number,staff,event));inferred.append(bar_number)
 return records,bar_number,inferred


def _degree(y,top,sign,space=4.96063):
 return (30 if sign=='G' else 18)+round((top+4*space-y)/(space/2))


def _clef(page,system,staff,x):
 clefs=[c for c in page['clefs'] if c['system']==system and c['staff']==staff and c['x']<=x+1]
 if not clefs:raise ValueError('矢量谱缺少可定位的谱号')
 return max(clefs,key=lambda c:c['x'])['sign']


def _pitches(data,records):
 for pi,page in enumerate(data):
  for si,system in enumerate(page['systems']):
   for staff,top in enumerate(system['tops']):
    heads=sorted([h for h in page['heads'] if h['system']==si and h['staff']==staff],key=lambda h:h['x'])
    if not heads:continue
    first=min(h['x'] for h in heads);first_clef=_clef(page,si,staff,first)
    accidentals=[c for c in page['chars'] if c['c'] in (0xe260,0xe261,0xe262) and abs(c['y']-(top+10))<70]
    signature=[c for c in accidentals if c['x']<first-12 and c['x']>system['bars'][0]]
    key={}
    for c in signature:
     # 调号必须落在当前谱表的五线附近，不能误用另一谱表的临时变音。
     if top-5<c['y']<top+25:key[_degree(c['y'],top,first_clef)%7]={0xe260:-1,0xe261:0,0xe262:1}[c['c']]
    for left,right in zip(system['bars'],system['bars'][1:]):
     group=[h for h in heads if left<h['x']<right];changes=[]
     for c in accidentals:
      if c in signature:continue
      targets=[h for h in group if .5<h['x']-c['x']<24 and abs(h['y']-c['y'])<.2]
      if targets:
       head=min(targets,key=lambda h:h['x']);sign=_clef(page,si,staff,head['x'])
       changes.append((head['x'],_degree(head['y'],top,sign),{0xe260:-1,0xe261:0,0xe262:1}[c['c']]))
     for h in group:
      degree=_degree(h['y'],top,_clef(page,si,staff,h['x']));alter=key.get(degree%7,0)
      for x,d,a in sorted(changes):
       if x<=h['x']+.6 and d==degree:alter=a
      h['degree']=degree;h['explicit_accidental']=any(abs(x-h['x'])<.7 and d==degree for x,d,a in changes)
      h['pitch']=12*(degree//7+1)+(0,2,4,5,7,9,11)[degree%7]+alter
      if not 0<=h['pitch']<=127:raise ValueError('矢量谱音高超出MIDI范围')


def _tie_heads(data,records):
 """只合并有实际曲线、同音高且时间连续的音头；普通连奏弧线不改变起音。"""
 lookup={};segments=[]
 for pi,si,staff,event in records:
  for head in event['heads']:
   segment=dict(head=head,page=pi,system=si,staff=staff,start=event['start'],end=event['end'],
                bar=event['bar'],direction=event['direction'])
   lookup[pi,head['idx']]=len(segments);segments.append(segment)
 parents=list(range(len(segments)));outgoing=set();incoming=set();links=[]
 def root(i):
  while parents[i]!=i:parents[i]=parents[parents[i]];i=parents[i]
  return i
 def union(a,b):
  a,b=root(a),root(b)
  if a==b:return False
  parents[b]=a;return True
 def compatible(sa,sb):
  a,b=sa['head'],sb['head']
  return a['degree']==b['degree'] and (a['pitch']==b['pitch'] or not b['explicit_accidental'])
 def connect(ia,ib):
  # 跨小节的延音保留前一个音的临时变音，不回落为新小节调号音。
  segments[ib]['head']['pitch']=segments[ia]['head']['pitch']
  if union(ia,ib):links.append((ia,ib))
 for pi,page in enumerate(data):
  here=[(i,s) for i,s in enumerate(segments) if s['page']==pi]
  for path in page['paths']:
   items=path['items']
   if not path['fill'] or len(items)!=2 or any(it[0]!='c' for it in items):continue
   first,last=items[0][1],items[0][4]
   if last.x<first.x:first,last=last,first
   def near(point,side):
    found=[]
    for index,s in here:
     h=s['head'];dx=point.x-h['x'];dy=abs(abs(point.y-h['y'])-3.62)
     if (-1<dx<10 and dy<1.3):found.append((abs(dx-3.5)+dy*3,index,s))
    return sorted(found,key=lambda a:a[0])
   a,b=near(first,'left'),near(last,'right')
   matches=[(qa+qb,ia,ib) for qa,ia,sa in a for qb,ib,sb in b if ia!=ib and compatible(sa,sb) and sa['end']==sb['start']]
   if matches:
    _,ia,ib=min(matches);connect(ia,ib);continue
   # 换行/翻页的延音线在页边截成两段；之后仍以同音和精确时间邻接复核。
   if a and not b:
    _,i,s=a[0];edge=page['systems'][s['system']]['bars'][-1]
    if last.x>edge-8:outgoing.add(i)
   if b and not a:
    _,i,s=b[0];edge=page['systems'][s['system']]['bars'][0]
    if first.x<edge+10:incoming.add(i)
 for a in outgoing:
  sa=segments[a]
  candidates=[b for b in incoming if compatible(sa,segments[b]) and segments[b]['staff']==sa['staff'] and segments[b]['start']==sa['end']]
  if len(candidates)==1:connect(a,candidates[0])
 groups=collections.defaultdict(list)
 for i,s in enumerate(segments):groups[root(i)].append(s)
 return list(groups.values()),len(links),segments


def recognize_vector_pdf(path, audit=None):
 """不适用的文件返回 None；匹配到的矢量谱若有歧义则报错，不把错误结果称为校正版。"""
 path=Path(path)
 if path.suffix.lower()!='.pdf':return None
 try:document=pymupdf.open(path)
 except Exception:return None
 with document:
  if 'MuseScore' not in (document.metadata.get('creator') or ''):return None
  if not all(any('Leland' in f[3] for f in page.get_fonts()) for page in document):return None
  data=[extract(page) for page in document]
  if not data or any(not p['systems'] for p in data):return None
  first_top=data[0]['systems'][0]['tops'][0]
  digits=[c for c in data[0]['chars'] if 0xe080<=c['c']<=0xe089 and first_top<c['y']<first_top+20]
  if len(digits)<2:return None
  first=sorted(digits,key=lambda c:(c['x'],c['y']))[:2];first.sort(key=lambda c:c['y'])
  numerator,denominator=[c['c']-0xe080 for c in first]
  if numerator!=3 or denominator!=4:raise ValueError('当前矢量校谱只验收了3/4双谱表，请使用MusicXML或人工校正')
  beats=Fraction(3);records,bars,inferred=_schedule(data,beats);_pitches(data,records)
  groups,ties,segments=_tie_heads(data,records)
  ppqn=480
  for _,_,_,e in records:
   ppqn=math.lcm(ppqn,e['start'].denominator,e['end'].denominator)
  if ppqn>32767:raise ValueError('矢量谱连音精度超出设备PPQN范围')
  # 读取印在谱面的四分音符速度，不能用默认120代替漏识别的158。
  tempo_symbols=[c for c in data[0]['chars'] if c['c']==0xeca5]
  tempo=None
  for c in tempo_symbols:
   text=''.join(t['text'] for t in sorted(data[0]['chars'],key=lambda t:t['x']) if c['x']<t['x']<c['x']+70 and abs(t['y']-c['y'])<1 and t['c']<128)
   match=re.search(r'=\s*(\d+)',text)
   if match:tempo=int(match[1]);break
  if not tempo:raise ValueError('矢量谱未找到可确认的速度标记')
  song=Song(name=path.stem,ppqn=ppqn,numerator=numerator,denominator=denominator,tempos=[[0,round(60_000_000/tempo)]],source_files=[str(path.resolve())])
  for group in groups:
   s=min(group,key=lambda s:s['start']);head=s['head'];box=head['box']
   song.notes.append(Note(int(min(s['start'] for s in group)*ppqn),int(max(s['end'] for s in group)*ppqn),head['pitch'],
                          velocity=88 if s['staff']==0 else 74,part=2 if s['staff']==1 else 0,
                          page=s['page'],box=[(head['x']-1)*2.5,(head['y']-3.2)*2.5,8.5*2.5,6.4*2.5],uncertain=True))
  song.notes.sort(key=lambda n:(n.start,n.part,n.pitch));song.sections=[Section(end=int(bars*beats*ppqn),timbres=[0,0,0,0])]
  occupied={};rerouted=0
  for n in song.notes:
   choices=[n.part]+[p for p in (0,1,2) if p!=n.part]
   free=next((p for p in choices if occupied.get((p,n.pitch),0)<=n.start),None)
   if free is None:raise ValueError('同音重叠超过设备可表达的三个旋律声部，需人工分轨')
   if free!=n.part:rerouted+=1;n.part=free
   occupied[n.part,n.pitch]=n.end
  song.issues=[f'矢量校谱：{len(data)}页/{bars}小节/{sum(len(p["heads"]) for p in data)}音头，合并{ties}条同音延音；速度={tempo} BPM',
               '钢琴谱默认同音色；右手→旋律、左手→低音；试听后仍需人工确认']
  if rerouted:song.issues.append(f'{rerouted}个同音重叠分配到空闲声部，未改变音高和时值')
  if inferred:song.issues.append('省略休止定位需复核：第'+','.join(map(str,inferred))+'小节')
  report=dict(pages=len(data),bars=bars,heads=sum(len(p['heads']) for p in data),notes=len(song.notes),ties=ties,tempo=tempo,ppqn=ppqn,
              inferred_bars=inferred,tuplets=[dict(page=i+1,**t) for i,p in enumerate(data) for t in p['tuplets']],
              events=[dict(page=pi+1,system=si,staff=st,bar=e['bar'],x=e['x'],start=str(e['start']),end=str(e['end']),pitches=[h['pitch'] for h in e['heads']]) for pi,si,st,e in records])
  if audit is not None:audit.update(report)
  return song

