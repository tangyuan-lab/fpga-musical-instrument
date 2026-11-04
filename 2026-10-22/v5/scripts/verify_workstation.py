"""执行生成的 HMI 事件代码、回读原生页面，验证模式/映射/编排/和弦/EEPROM。"""
from pathlib import Path
import sys,re,json,argparse
ROOT=Path(__file__).resolve().parents[1]
SCREEN=ROOT/'screen/TJC1060X570'
sys.path.insert(0,str(SCREEN/'design'));sys.path.insert(0,str(SCREEN))
from create_workstation import generate,MAGIC
from verify_touch_screen import EventModel,validate_saved_events
from build_dashboard_hmi import generate as build_hmi
from chord_library import chord_table,display_label,PC_NAMES
from workstation_zh import display_label_zh
from workstation_theme import WHITES,SHARPS,geometry,drum_geometry,C
from PIL import Image,ImageDraw,ImageFont
from usarthmi.zi_font import ZiFont

class WorkstationModel(EventModel):
    @staticmethod
    def expression(source):
        # 扩展旧事件模型的官方整数位运算；其余仍执行实际源码，不另写一套UI逻辑。
        pattern=r'"[^"\n]*"|[A-Za-z_]\w*(?:\.\w+)?|\d+|==|!=|>=|<=|&&|\|\||<<|>>|[+*/<>()&|^-]'
        tokens=re.findall(pattern,source)
        if re.sub(pattern,'',source).strip():raise ValueError(source)
        result=[]
        for t in tokens:
            if re.fullmatch(r'[A-Za-z_]\w*(?:\.\w+)?',t):t=f'v[{t!r}]'
            else:t={'&&':' and ','||':' or ','/':'//'}.get(t,t)
            result.append(t)
        return ''.join(result)
    @classmethod
    def compile(cls,lines):
        expanded=[]
        for line in lines:
            if line.startswith('prints '):
                attr,length=line[7:].split(',');expanded.append(f'_emit {attr},{length}')
            elif line.startswith(('wepo ','repo ')):expanded.append('_memory '+line)
            elif line=='pic 0,0,0':expanded.append('_picture')
            else:expanded.append(line)
        # 使用父模型的控制流生成器，对新增语句临时转换成隐藏事件调用。
        output=[];indent=0
        for line in expanded:
            if line=='{':indent+=1;continue
            if line in ('}','}else'):
                indent-=1
                if line=='}else':output.append('    '*indent+'else:')
                continue
            if line.startswith('if('):code=f'if {cls.expression(line[3:-1])}:'
            elif line.startswith('printh '):code=f'raw({bytes.fromhex(line[7:])!r})'
            elif line.startswith('_emit '):
                attr,n=line[6:].split(',');code=f'emit({cls.expression(attr)},{int(n)})'
            elif line.startswith('_memory '):
                command,args=line[8:].split(' ',1);attr,address=args.split(',')
                code=f'memory({command!r},{attr!r},{cls.expression(address)},{cls.expression(attr) if command=="wepo" else "None"})'
            elif line=='_picture':code='picture()'
            else:
                single=super().compile([line]);code=f'exec_one({len(cls.snippets)})';cls.snippets.append(single)
            output.append('    '*indent+code)
        if indent:raise ValueError('unbalanced event')
        return compile('\n'.join(output),'<workstation HMI>','exec')
    snippets=[]
    def __init__(self,spec):
        self.eeprom={};self.wire=bytearray();self.pending=bytearray();super().__init__(spec)
    def execute(self,code):
        def raw(data):
            self.wire.extend(data);self.pending.extend(data)
            while len(self.pending)>=5:
                p=bytes(self.pending[:5])
                if p[:2]==b'\xa5\x5a' and p[4]==(255^p[2]^p[3]):self.packets.append(p);del self.pending[:5]
                else:del self.pending[0]
        def emit(value,n):raw((value&0xffffffff).to_bytes(4,'little')[:n])
        def memory(command,attr,address,value):
            if command=='wepo':self.eeprom[address]=value
            else:self.values[attr]=self.eeprom.get(address,-1)
        def one(index):super(WorkstationModel,self).execute(self.snippets[index])
        def picture():self.draws.append('pic 0,0,0')
        exec(code,{'__builtins__':{},'emit':emit,'raw':raw,'memory':memory,'exec_one':one,'picture':picture},{'v':self.values})

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out',type=Path,default=SCREEN/'generated/instrument_workstation_fixed/instrument_workstation.HMI')
    args=parser.parse_args()
    spec=generate();m=WorkstationModel(spec);v=m.values;checks=0
    def check(ok,label):
        nonlocal checks
        if not ok:raise AssertionError(label)
        checks+=1
    for widget in spec['widgets']:
        if widget['type']=='timer':check(50<=widget['fields']['tim']<=65535,'official timer interval bounds')
    check(next(w['fields']['tim'] for w in spec['widgets'] if w['objname']=='tmRestore')==50,'restore timer is 50ms')
    m.run('page0','codesloadend-');check(v['viewMode.val']==0,'home startup')
    v['tmRestore.en']=0
    for mode in range(1,5):
        m.run(f'menu{mode}','codesup-');check(v['viewMode.val']==mode,'menu selection')
        check(any(p[2:4]==bytes([5,mode]) for p in m.packets),'mode command')
        check('vis homeBtn,1' in m.draws,'manual return is visible in every mode')
        v.update({'seqView.val':int(mode==1),'held4.val':1,'fade4.val':2,'testMode.val':1,'idleSeconds.val':119})
        m.eeprom[512]=MAGIC+7
        m.packets.clear();m.run('homeBtn','codesup-')
        check(v['viewMode.val']==0 and v['seqView.val']==0,'manual home exits each mode and sequencer')
        check([p[2:4] for p in m.packets]==[bytes([2,255]),bytes([5,0])],'manual return stops sound before entering Home')
        check(v['testMode.val']==0 and all(v[f'held{k}.val']==0 and v[f'fade{k}.val']==0 for k in range(16)), 'manual return clears sustained touch and animation')
        check(m.eeprom[512]==MAGIC+7,'manual return preserves saved physical mappings')
    check(v['homeBtn.txt']=='返回首页','explicit Chinese manual return label')
    v.update({'viewMode.val':2,'tch0':40,'tch1':320});m.packets.clear()
    m.run('ui4','codesdown-');check(m.packets[-1][2:4]==bytes([1,4]),'piano screen event')
    m.run('tmHeart');check(m.packets[-1][2:4]==bytes([1,4]),'touch keepalive')
    m.run('ui4','codesup-');check(v['held4.val']==0,'touch release')
    v['rxKeys.val']=16;m.run('ui4','codesdown-');m.run('ui4','codesup-')
    check(v['ui4.bco']==C['cyan'],'touch release keeps a physical note highlighted')
    v.update({'rxKeys.val':0,'prevKeys.val':16});m.run('ui4','codesdown-');m.run('tmUi')
    check(v['ui4.bco']==C['cyan'] and v['held4.val']==1,'late feedback must not erase a held touch')
    v.update({'rxKeys.val':0,'prevKeys.val':0,'rxP7.val':1900});m.run('ui4','codesup-');m.run('tmUi')
    check(v['pressureTxt.txt']=='最高压力 1900','pressure follows physical inputs independently of mapped pitch')
    v.update({'viewMode.val':2,'rxFlags.val':0,'rxKeys.val':0,'testMode.val':0,'tmRestore.en':0,'idleSeconds.val':0})
    for k in range(16):v[f'held{k}.val']=0
    for _ in range(spec['auto_home_idle_seconds']-1):m.run('tmIdle')
    check(v['viewMode.val']==2,'idle return waits the full timeout')
    m.run('tmIdle');check(v['viewMode.val']==0 and m.packets[-1][2:4]==bytes([5,0]),'idle return synchronizes FPGA Home mode')
    for flags,held,key,test in [(1,0,0,0),(2,0,0,0),(0,1,0,0),(0,0,16,0),(0,0,0,1)]:
        v.update({'viewMode.val':3,'rxFlags.val':flags,'rxKeys.val':key,'held0.val':held,'testMode.val':test,'idleSeconds.val':119})
        m.run('tmIdle');check(v['viewMode.val']==3 and v['idleSeconds.val']==0,'active performance blocks idle return')
    v.update({'viewMode.val':4,'rxFlags.val':0,'rxKeys.val':0,'held0.val':0,'testMode.val':0,'idleSeconds.val':119});m.run('tmIdle')
    check(v['viewMode.val']==4,'setup view does not auto-exit')
    v.update({'viewMode.val':2,'idleSeconds.val':100});m.run('toneBtn','codesup-')
    check(v['idleSeconds.val']==0,'user operation resets idle timeout')
    v['viewMode.val']=1;m.run('pad4','codesdown-');check(m.packets[-1][2:4]==bytes([6,4]),'drum screen fixed sound')
    v.update({'viewMode.val':4,'editBank.val':2,'editKey.val':3,'editKind.val':1,'editTone.val':0,'editNote.val':7})
    m.wire.clear();m.run('saveBtn','codesup-')
    check(m.eeprom[512+(16+3)*4]==MAGIC+0x4007,'persistent bank/key descriptor')
    wire=bytes(m.wire);check(len(wire)==30,'five staged packets plus commit')
    for i,op in enumerate((32,33,34,35,36,37)):
        p=wire[i*5:(i+1)*5];check(p[2]==op and p[-1]==(255^op^p[3]),'dynamic checksum')
    for _ in range(48):m.run('tmRestore')
    check(v['tmRestore.en']==0,'paced EEPROM restore')
    v.update({'viewMode.val':2,'rxMode.val':2,'lastRxMode.val':2,'rxFlags.val':128,'bootLatch.val':0})
    m.run('tmUi');check(v['tmRestore.en']==1 and v['eeSlot.val']==0,'FPGA reset requests saved mappings again')
    v['tmRestore.en']=0;m.run('tmUi');check(v['tmRestore.en']==0,'stale pending flag must not loop restoration')
    v['rxFlags.val']=0;m.run('tmUi');v['rxFlags.val']=128;m.run('tmUi')
    check(v['tmRestore.en']==1,'next FPGA reset rearms restoration')
    v.update({'rxFlags.val':16,'viewMode.val':1,'seqView.val':0,'rxKeys.val':0,'prevKeys.val':0,'rxDrums.val':1,'prevDrums.val':0})
    m.run('tmUi');check(v['fade0.val']==2,'drum event starts animation')
    m.run('tmUi');m.run('tmUi');check(v['fade0.val']==0,'drum animation ends despite event bit staying high')
    m.draws.clear();m.run('tmUi');check(not any(d.startswith('fill ') for d in m.draws),'no idle animation')
    v['rxDrums.val']=0;m.run('tmUi');check(v['fade0.val']==2,'next hit animates even when event bit flips low')
    for mask,names in chord_table().items():
        v['rxKeys.val']=mask;m.run('chordCalc','codesdown-')
        bass=PC_NAMES[min(k for k in range(12) if mask&(1<<k))]
        check(v['chordTxt.txt']==display_label_zh(names,bass),f'chord {mask}')
    v['rxKeys.val']=0x891;m.run('chordCalc','codesdown-')
    check(v['chordTxt.txt']=='C大七','Chinese chord quality label')
    v.update({'rxKeys.val':0x91,'viewMode.val':2,'lastRxMode.val':2,'rxMode.val':2});m.packets.clear();m.run('tmUi')
    check(v['held0.val']==0 and v['held4.val']==0,'physical feedback must not become touch hold')
    v.update({'viewMode.val':1,'seqView.val':1,'tch0':231,'tch1':302,'rxPat0.val':0});m.wire.clear();m.run('gridHit','codesdown-')
    check(v['payload.val']==1,'grid coordinate step')
    m.draws.clear();v.update({'viewMode.val':1,'seqView.val':0});m.run('seqBtn','codesup-')
    check('vis gridHit,1' in m.draws and 'vis pad0,0' in m.draws,'sequencer replaces pads with an editable grid')
    m.draws.clear();m.run('homeBtn','codesup-')
    check('vis gridHit,0' in m.draws,'return Home removes sequencer touch interception')
    ids={w['objname']:i for i,w in enumerate(spec['widgets'])}
    for sharp in SHARPS:
        check(all(ids[f'ui{sharp}']>ids[f'ui{white}'] for white in WHITES),'black keys on top for drawing and touch')
    for white in WHITES:
        check(spec['widgets'][ids[f'ui{white}']]['fields']['ycen']==2,'white key label below overlapping black keys')
    for k in range(16):
        x,y,w,h=geometry(k);point=(x+w//2,y+(h//2 if k in SHARPS else h-12))
        hits=[]
        for n in range(16):
            nx,ny,nw,nh=geometry(n)
            if nx<=point[0]<nx+nw and ny<=point[1]<ny+nh:hits.append(n)
        check(max(hits,key=lambda n:ids[f'ui{n}'])==k,'native touch layer matches visible key')
    for k in range(16):
        check(tuple(spec['widgets'][ids[f'pad{k}']]['fields'][f] for f in ('x','y','w','h'))==drum_geometry(k),'4x4 fixed pad geometry')
    # 黑键松开必须恢复深色，不能恢复为白键；声音帧先于绘图。
    v.update({'viewMode.val':2,'testMode.val':0});m.run('ui1','codesdown-');m.run('ui1','codesup-')
    check(v['ui1.bco']==C['sharp'] and v['ui1.pco']==C['white'],'black key release style')
    for widget in spec['widgets']:
        for lines in widget.get('events',{}).values():
            check(not any(re.match(r'\w+\.(?:w|h)=',line) for line in lines),'no unsupported runtime size writes')
    target=args.out.resolve()
    report=build_hmi(SCREEN/'design/workstation/controls_manifest.json',target,SCREEN/'uart_minimal_manual.HMI',SCREEN/'vendor/TJC1060X570_factory.HMI')
    validate_saved_events(spec,target)
    # 使用最终ZI的字形，而非近似系统字体；预览按原生矩形与层级绘制。
    font=ZiFont(SCREEN/'design/workstation'/spec['font_resource'])
    check(font.mode==2,'Chinese font uses official subset charset mode')
    check(list(font.glyphs)==sorted(font.glyphs),'Chinese font index sorted as official mixed font')
    display_characters=set()
    for widget in spec['widgets']:
        for text in [widget['fields'].get('txt',''),*[s for lines in widget['events'].values() for line in lines for s in re.findall(r'"([^"\n]*)"',line)]]:
            display_characters.update(text)
    for char in display_characters:check(font._map_char_to_codepoint(char) in font.glyphs,'Chinese UI character covered')
    for mode,name in [(0,'home'),(1,'drums'),(1,'sequencer'),(2,'piano'),(3,'mix'),(4,'setup'),(2,'piano_pressed')]:
        model=WorkstationModel(spec);model.values['viewMode.val']=mode
        if name=='sequencer':model.values.update({'seqView.val':1,'rxPat0.val':257,'rxPat1.val':4112,'rxPat2.val':21845,'rxStep.val':4,'rxSnd0.val':0,'rxSnd1.val':1,'rxSnd2.val':2,'rxSnd3.val':7})
        model.run('drawView','codesdown-')
        if name=='piano_pressed':
            model.values.update({'rxMode.val':2,'lastRxMode.val':2,'rxKeys.val':0x891,'rxFlags.val':16,
                'rxP0.val':3000,'rxP4.val':2048,'rxP7.val':1800,'rxP11.val':1600})
            model.run('ui4','codesdown-');model.run('tmUi')
        visible={'titleTxt','hintTxt'}
        img=Image.open(SCREEN/'design/workstation/instrument_background.png').copy();draw=ImageDraw.Draw(img)
        by_name={w['objname']:w for w in spec['widgets']}
        def paint(name):
            w=by_name[name]
            if w['type']!='text' or name not in visible:return
            p=model.values;x,y,width,height=[p[f'{name}.{k}'] for k in ('x','y','w','h')]
            draw.rectangle((x,y,x+width-1,y+height-1),fill=rgb565(p[f'{name}.bco']))
            tile=font.render_text(p[f'{name}.txt'],rgb565(p[f'{name}.pco']))
            tx=x if p[f'{name}.xcen']==0 else x+(width-tile.width)//2
            ycen=p[f'{name}.ycen'];ty=0 if ycen==0 else (height-32 if ycen==2 else (height-32)//2)
            layer=Image.new('RGBA',(width,height),(0,0,0,0));layer.paste(tile,(int(tx-x),ty),tile)
            img.paste(layer,(x,y),layer)
        for command in model.draws:
            if command=='pic 0,0,0':img=Image.open(SCREEN/'design/workstation/instrument_background.png').copy();draw=ImageDraw.Draw(img)
            elif command.startswith('fill '):
                x,y,w,h,c=map(int,command[5:].split(','));draw.rectangle((x,y,x+w-1,y+h-1),fill=rgb565(c))
            elif command.startswith('vis '):
                key,state=command[4:].split(',')
                if state=='1':visible.add(key);paint(key)
                else:visible.discard(key)
            elif command.startswith('ref '):paint(command[4:])
        img.save(ROOT/f'build/tests/workstation_{name}.png')
    summary={'checks':checks,'controls':len(spec['widgets']),'native_cfs_crc_valid':report['native_cfs_crc_valid'],'official_compile_status':'pending','hardware_status':'pending'}
    (ROOT/'build/tests/workstation_verification.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')
    print(f'PASS workstation HMI {checks} checks, {len(spec["widgets"])} controls, official compilation pending')

def rgb565(c):return ((c>>11)*255//31,((c>>5)&63)*255//63,(c&31)*255//31)
if __name__=='__main__':main()
