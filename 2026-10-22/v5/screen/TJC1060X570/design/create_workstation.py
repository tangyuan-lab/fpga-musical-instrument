"""由源码生成四入口工作站 HMI；native page0 内切换视图，屏幕键不读取实体映射。

扩展模式/音色请先更新 registry.json 和 FPGA 支持，再增加界面；保留现有协议编号。
"""
from pathlib import Path
import json
from PIL import Image,ImageDraw,ImageFont
from create_touch_piano import branch,packet
from chord_library import lookup_code,QUALITIES,PC_NAMES
from workstation_zh import localize,display_label_zh
from workstation_theme import C,rgb,geometry,drum_geometry,resting,WHITES,SHARPS,PAD_TINTS,MENU_RECTS,background

DESIGN=Path(__file__).resolve().parent
OUT=DESIGN/'workstation'
REGISTRY=json.loads((DESIGN.parents[2]/'config/instrument_registry.json').read_text(encoding='utf-8'))
NOTES=REGISTRY['sound_kinds'][0]['notes']
DRUMS=REGISTRY['sound_kinds'][1]['notes']
MAGIC=0x57010000
AUTO_HOME_SECONDS=int(REGISTRY.get('ui_settings',{}).get('auto_home_idle_seconds',120))
if not 0<=AUTO_HOME_SECONDS<=3600:raise ValueError('auto_home_idle_seconds must be 0..3600')

def dynamic_packet(op,source):
    # prints 数值变量,1 输出最低字节；校验计算分步，避免屏幕算式优先级差异。
    return [f'payload.val={source}',f'checkByte.val={255^op}^payload.val',
            f'printh A5 5A {op:02X}','prints payload.val,1','prints checkByte.val,1']

def generate():
    OUT.mkdir(parents=True,exist_ok=True)
    widgets=[];by={};groups={m:[] for m in range(5)}
    def variable(name,value=0):
        w={'objname':name,'type':'variable','fields':{'sta':0,'val':value},'events':{}}
        widgets.append(w);by[name]=w
    def text(name,rect,label='',color='white',bg='panel',event=None,modes=(),hidden=False):
        x,y,w,h=rect
        item={'objname':name,'type':'text','hidden':hidden,'fields':{'x':x,'y':y,'w':w,'h':h,'sta':1,'font':0,
              'pco':C[color],'bco':C[bg],'xcen':1,'ycen':1,'txt':label,'txt_maxl':128},'events':event or {}}
        widgets.append(item);by[name]=item
        for mode in modes:groups[mode].append(name)
        return item
    # 官方生成器保留 t0..t15 的兼容位置，工作站使用独立数字数据接口。
    for k in range(16):text(f't{k}',(0,0,64,32),'',hidden=True)
    rxnames=['rxMode','rxKeys','rxDrums','rxStep','rxBpm','rxFlags','rxBank','rxKey','rxConfig']+[f'rxVol{i}' for i in range(3)]+[f'rxPat{i}' for i in range(4)]+[f'rxSnd{i}' for i in range(4)]+[f'rxP{i}' for i in range(16)]
    for name in rxnames:variable(name)
    for name,val in [('viewMode',0),('lastRxMode',0),('prevKeys',-1),('prevDrums',0),('pcMask',0),('bassPc',-1),
                    ('lastMask',-1),('lastBass',-1),('touchCount',0),('payload',0),('checkByte',0),('scratch',0),('selected',0),
                    ('editBank',1),('editKey',0),('editKind',0),('editTone',0),('editNote',0),('eeAddr',0),('eeValue',0),
                    ('editDirty',0),('lastDesc',-1),('bpmEdit',120),('octMode',0),('testMode',0),('preset',1),('track',0),('lastFlags',-1),
                    ('lastStep',-1),('lastBpm',-1),('lastPat0',-1),('lastPat1',-1),('lastPat2',-1),('lastPat3',-1),
                    ('eeSlot',0),('priorBit',0),('cfgBank',0),('cfgKey',0),('cfgDesc',0),('bootLatch',0),('peakPressure',0),('idleSeconds',0)]:variable(name,val)
    for tr in range(4):variable(f'lastSnd{tr}',-1);variable(f'mixFade{tr}')
    for k in range(16):variable(f'held{k}');variable(f'fade{k}')
    text('titleTxt',(88,20,670,48),'MUSIC STUDIO',bg='page')['fields']['xcen']=0
    text('homeBtn',(846,20,146,48),'HOME',color='cyan',modes=(1,2,3,4))
    text('hintTxt',(32,550,960,40),'Choose a mode',color='muted',bg='page')
    for m,label in [(1,'DRUMS'),(2,'PIANO'),(3,'MIX'),(4,'KEY SETUP')]:
        x,y,w,h=MENU_RECTS[m]
        name=f'menu{m}'
        item={'objname':name,'type':'hotspot','fields':{'x':x,'y':y,'w':w,'h':h},'events':{}}
        widgets.append(item);by[name]=item;groups[0].append(name)
    text('chordTxt',(650,90,342,44),'----',color='cyan',modes=(2,3))
    text('pressureTxt',(32,90,270,44),'PRESS MAX ----',color='muted',modes=(1,2,3))
    text('stateTxt',(316,90,304,44),'WAIT',color='amber',modes=(1,2,3))
    text('octBtn',(32,210,168,44),'OCT 0',color='cyan',modes=(2,3))
    text('toneBtn',(212,210,180,44),'TONE TRI',color='cyan',modes=(2,3))
    text('testBtn',(404,210,176,44),'TEST 4',color='muted',modes=(2,))
    text('offBtn',(804,210,188,44),'STOP ALL',color='amber',modes=(1,2,3))
    text('pianoGuide',(32,150,960,44),'C4 - D#5  /  16 KEYS  /  LIVE CHORDS',color='muted',bg='page',modes=(2,))
    # 白键在下，黑键在上：触摸命中与实际显示层级相同。
    for k in (*WHITES,*SHARPS):
        bg,fg=resting(k)
        key=text(f'ui{k}',geometry(k),NOTES[k],color=fg,bg=bg,modes=(2,3))
        # 白键名称置底，避开黑键覆盖区；黑键文字保持居中。
        key['fields']['ycen']=2 if k in WHITES else 1
    for k in range(16):
        text(f'pad{k}',drum_geometry(k),DRUMS[k],color=PAD_TINTS[k],bg='panel',modes=(1,))
    # 编排网格作为逻辑子视图(模式值仍是鼓点)，不用64个原生控件。
    variable('seqView',0)
    text('seqBtn',(600,210,188,44),'SEQUENCER',color='cyan',modes=(1,))
    text('bpmTxt',(32,150,164,44),'BPM 120',modes=(1,3))
    text('bpmMinus',(208,150,60,44),'-',color='cyan',modes=(1,3))
    text('bpmPlus',(280,150,60,44),'+',color='cyan',modes=(1,3))
    text('beatBtn',(354,150,180,44),'BEAT PLAY',color='cyan',modes=(1,3))
    text('presetBtn',(546,150,174,44),'ROCK',color='muted',modes=(1,))
    text('midiBtn',(546,150,174,44),'MIDI PLAY',color='cyan',modes=(3,))
    text('startBtn',(732,150,126,44),'START',color='cyan',modes=(3,))
    text('stopBtn',(870,150,122,44),'STOP',color='amber',modes=(3,))
    # MIX音量通过三个数值按钮调节，点击+10循环；另设静音按钮恢复最近非零值。
    for i,label in enumerate(['PIANO','DRUM','MIDI']):
        variable(f'volEdit{i}',80 if i==0 else 60);variable(f'volKeep{i}',80 if i==0 else 60)
        variable(f'lastVol{i}',-1)
        text(f'vol{i}',(404+i*130,210,122,44),label,color=['cyan','amber','purple'][i],modes=(3,))
        text(f'mute{i}',(404+i*130,258,122,32),'MUTE',color='muted',modes=(3,))
    # 混音保留16键屏幕钢琴；鼓音可从紧凑4个鼓垫或编排播放。
    for i,label in enumerate(['KICK','SNARE','C-HAT','CLAP']):
        text(f'mixPad{i}',(32+i*244,508,228,34),label,color='amber',modes=(3,),event={'codesdown-':[packet(6,[0,1,2,7][i]),f'mixFade{i}.val=2',f'mixPad{i}.bco={C["amber"]}',f'mixPad{i}.pco={C["ink"]}',f'ref mixPad{i}']})
    # 实体键设置：选择三套配置之一、选择键号、声音类型、音色和音高，再保存。
    text('bankBtn',(32,110,300,56),'BANK DRUMS',color='cyan',modes=(4,))
    text('keyMinus',(350,110,64,56),'-',modes=(4,));text('keyTxt',(426,110,250,56),'KEY 01',modes=(4,));text('keyPlus',(688,110,64,56),'+',modes=(4,))
    text('kindBtn',(32,194,300,64),'TYPE PIANO',color='cyan',modes=(4,))
    text('toneCfg',(350,194,402,64),'TONE TRI',color='cyan',modes=(4,))
    text('noteMinus',(32,280,64,64),'-',modes=(4,));text('noteTxt',(108,280,568,64),'C4',color='amber',modes=(4,));text('notePlus',(688,280,64,64),'+',modes=(4,))
    text('saveBtn',(32,388,346,72),'SAVE KEY',color='cyan',modes=(4,))
    text('resetBtn',(406,388,346,72),'RESET BANK',color='amber',modes=(4,))
    text('setupHelp',(32,474,960,48),'Screen keys keep their own sounds',color='muted',modes=(4,))
    for name,y,h,label in [('bankHelp',110,56,'3 BANKS'),('keysHelp',194,64,'16 KEYS'),('saveHelp',280,64,'SAVED MAPS')]:
        text(name,(780,y,212,h),label,color='muted',bg='page',modes=(4,))
    def hidden_event(name,lines):text(name,(0,0,32,32),'',hidden=True,event={'codesdown-':lines})
    def reset_touch():return [packet(2,255),'testMode.val=0','octMode.val=0','octBtn.txt="OCT 0"','testBtn.txt="TEST 4"',
                             *[f'held{k}.val=0' for k in range(16)],*[f'fade{k}.val=0' for k in range(16)],
                             *[s for k in range(16) for s in (f'pad{k}.bco={C["panel"]}',f'pad{k}.pco={C[PAD_TINTS[k]]}')]]
    def frame(rect,color):
        x,y,w,h=rect
        return [f'fill {x},{y},2,{h},{color}',f'fill {x+w-2},{y},2,{h},{color}',
                f'fill {x},{y},{w},2,{color}',f'fill {x},{y+h-2},{w},2,{color}']
    def edges(k,color):
        # 白键刷新后重绘相邻黑键，避免覆盖重叠部分及其按下状态。
        return [*frame(geometry(k),color),*[f'ref ui{n}' for n in SHARPS if k in WHITES and abs(n-k)==1]]
    def release(k):
        bg,fg=resting(k)
        return [f'ui{k}.bco={C[bg]}',f'ui{k}.pco={C[fg]}',f'ref ui{k}',*edges(k,C['page'])]
    def keep_pressed(k):
        return [f'ui{k}.bco={C["cyan"]}',f'ui{k}.pco={C["ink"]}',f'ref ui{k}',*edges(k,C['page'])]
    def select_mode(m):return ['idleSeconds.val=0',*reset_touch(),packet(5,m),f'viewMode.val={m}','seqView.val=0','click drawView,1']
    # 各模式共用手动返回：先停音并清除触摸保活，再回首页；不清除已保存的实体映射。
    by['homeBtn']['events']={'codesup-':select_mode(0)}
    for m in range(1,5):by[f'menu{m}']['events']={'codesup-':branch('tmRestore.en==0',select_mode(m))}
    by['offBtn']['events']={'codesup-':reset_touch()}
    by['stopBtn']['events']={'codesup-':[packet(15,0),packet(16,0),*reset_touch()]}
    by['startBtn']['events']={'codesup-':[packet(15,1),packet(16,1)]}
    by['beatBtn']['events']={'codesup-':['scratch.val=rxFlags.val&1',*branch('scratch.val==0',[packet(15,1)],[packet(15,0)])]}
    by['midiBtn']['events']={'codesup-':['scratch.val=rxFlags.val&2',*branch('scratch.val==0',[packet(16,1)],[packet(16,0)])]}
    by['bpmMinus']['events']={'codesup-':branch('bpmEdit.val>40',['bpmEdit.val--',*dynamic_packet(7,'bpmEdit.val')])}
    by['bpmPlus']['events']={'codesup-':branch('bpmEdit.val<240',['bpmEdit.val++',*dynamic_packet(7,'bpmEdit.val')])}
    by['presetBtn']['events']={'codesup-':['preset.val++',*branch('preset.val>2',['preset.val=0']),*dynamic_packet(18,'preset.val'),
        *branch('preset.val==0',['presetBtn.txt="EMPTY"'],branch('preset.val==1',['presetBtn.txt="ROCK"'],['presetBtn.txt="4 FLOOR"']))]}
    by['seqBtn']['events']={'codesup-':['seqView.val=1-seqView.val','click drawView,1']}
    by['octBtn']['events']={'codesup-':['octMode.val++',*branch('octMode.val>2',['octMode.val=0']),*dynamic_packet(3,'octMode.val'),
        *branch('octMode.val==0',['octBtn.txt="OCT 0"'],branch('octMode.val==1',['octBtn.txt="OCT +1"'],['octBtn.txt="OCT -1"']))]}
    # OP08 是屏幕旋律音色，不修改实体配置；新的合成音色可扩充此注册表。
    variable('screenTone',0)
    by['toneBtn']['events']={'codesup-':['screenTone.val=1-screenTone.val',*dynamic_packet(8,'screenTone.val'),
        *branch('screenTone.val==0',['toneBtn.txt="TONE TRI"'],['toneBtn.txt="TONE SOFT"'])]}
    by['testBtn']['events']={'codesup-':branch('testMode.val==0',[*reset_touch(),packet(4,1),'testMode.val=1','testBtn.txt="TEST ON"'],[*reset_touch(),'testBtn.txt="TEST 4"'])}
    for i in range(3):
        by[f'vol{i}']['events']={'codesup-':[f'volEdit{i}.val=volEdit{i}.val+10',*branch(f'volEdit{i}.val>100',[f'volEdit{i}.val=0']),*dynamic_packet(9+i,f'volEdit{i}.val')]}
        by[f'mute{i}']['events']={'codesup-':branch(f'volEdit{i}.val>0',[f'volKeep{i}.val=volEdit{i}.val',f'volEdit{i}.val=0'],[f'volEdit{i}.val=volKeep{i}.val'])+dynamic_packet(9+i,f'volEdit{i}.val')}
    for k in range(16):
        by[f'ui{k}']['events']={'codesdown-':branch('viewMode.val>=2&&viewMode.val<=3&&testMode.val==0',
            [packet(1,k),f'held{k}.val=1',f'fade{k}.val=2',f'ui{k}.bco={C["cyan"]}',f'ui{k}.pco={C["ink"]}',f'ref ui{k}',*edges(k,C['white']),f'selected.val={k}']),
            'codesup-':branch(f'held{k}.val==1',[packet(0,k),f'held{k}.val=0',f'fade{k}.val=0',
                f'scratch.val=rxKeys.val&{1<<k}',*branch('scratch.val>0',keep_pressed(k),release(k))])}
        by[f'pad{k}']['events']={'codesdown-':branch('viewMode.val==1&&seqView.val==0',
            [packet(6,k),f'fade{k}.val=2',f'pad{k}.bco={C[PAD_TINTS[k]]}',f'pad{k}.pco={C["ink"]}',f'ref pad{k}',*frame(drum_geometry(k),C['white'])])}
    # 设置值与回传值分离，编辑期间不被迟到状态覆盖。
    hidden_event('selectEdit',[*dynamic_packet(32,'editBank.val'),*dynamic_packet(33,'editKey.val'),'editDirty.val=0','lastDesc.val=-1'])
    by['bankBtn']['events']={'codesup-':['editBank.val++',*branch('editBank.val>3',['editBank.val=1']),'click selectEdit,1']}
    for name,delta in [('keyMinus',-1),('keyPlus',1)]:
        by[name]['events']={'codesup-':[f'editKey.val=editKey.val{"+" if delta>0 else "-"}1',*branch('editKey.val<0',['editKey.val=15']),*branch('editKey.val>15',['editKey.val=0']),'click selectEdit,1']}
    by['kindBtn']['events']={'codesup-':['editKind.val=1-editKind.val','editTone.val=0','editDirty.val=1','click drawSetup,1']}
    by['toneCfg']['events']={'codesup-':branch('editKind.val==0',['editTone.val=1-editTone.val','editDirty.val=1','click drawSetup,1'])}
    for name,delta in [('noteMinus',-1),('notePlus',1)]:
        by[name]['events']={'codesup-':[f'editNote.val=editNote.val{"+" if delta>0 else "-"}1',*branch('editNote.val<0',['editNote.val=15']),*branch('editNote.val>15',['editNote.val=0']),'editDirty.val=1','click drawSetup,1']}
    commit=[*dynamic_packet(32,'editBank.val'),*dynamic_packet(33,'editKey.val'),*dynamic_packet(34,'editKind.val'),
            *dynamic_packet(35,'editTone.val'),*dynamic_packet(36,'editNote.val'),packet(37,1)]
    # 每个映射字保存版本标记；只写按下保存的一个槽，避免每次旋钮变化都写EEPROM。
    address=['eeAddr.val=editBank.val-1','eeAddr.val=eeAddr.val*16','eeAddr.val=eeAddr.val+editKey.val',
             'eeAddr.val=eeAddr.val*4','eeAddr.val=eeAddr.val+512']
    descriptor=['eeValue.val=editKind.val*16384','scratch.val=editTone.val*256','eeValue.val=eeValue.val+scratch.val','eeValue.val=eeValue.val+editNote.val']
    by['saveBtn']['events']={'codesup-':[*commit,*address,*descriptor,f'eeValue.val=eeValue.val+{MAGIC}',
        'wepo eeValue.val,eeAddr.val','hintTxt.txt="Saved - wait 1s before power off"','editDirty.val=0','lastDesc.val=-1']}
    reset=[*dynamic_packet(38,'editBank.val')]
    for bank in range(1,4):
        reset+=branch(f'editBank.val=={bank}',[f'wepo {MAGIC+(0x4000 if bank==1 else 0)+k},{512+((bank-1)*16+k)*4}' for k in range(16)])
    by['resetBtn']['events']={'codesup-':[*reset,'editDirty.val=0','lastDesc.val=-1','hintTxt.txt="Bank reset - wait 1s before power off"']}
    setup=['scratch.val=editKey.val+1','covx scratch.val,keyTxt.txt,0,0','keyTxt.txt="KEY "+keyTxt.txt',
           *branch('editBank.val==1',['bankBtn.txt="BANK DRUMS"'],branch('editBank.val==2',['bankBtn.txt="BANK PIANO"'],['bankBtn.txt="BANK MIX"'])),
           *branch('editKind.val==0',['kindBtn.txt="TYPE PIANO"',*branch('editTone.val==0',['toneCfg.txt="TONE TRIANGLE"'],['toneCfg.txt="TONE SOFT SQUARE"'])],['kindBtn.txt="TYPE DRUM"','toneCfg.txt="TONE DRUM KIT"'])]
    for k in range(16):setup+=branch(f'editNote.val=={k}',branch('editKind.val==0',[f'noteTxt.txt="{NOTES[k]}"'],[f'noteTxt.txt="{DRUMS[k]}"']))
    hidden_event('drawSetup',setup)
    # 一次只切换控件可见性，未显示的原生按钮不接收触摸。
    all_group=sorted(set(sum(groups.values(),[])))
    draw=[*[f'vis {name},0' for name in all_group],'pic 0,0,0',*branch('viewMode.val>0',[f'fill 0,80,1024,450,{C["page"]}']),
          'prevKeys.val=-1','prevDrums.val=0','lastFlags.val=-1','lastStep.val=-1','lastPat0.val=-1','lastPat1.val=-1','lastPat2.val=-1','lastPat3.val=-1']
    for mode,title in [(0,'MUSIC STUDIO'),(1,'DRUM STUDIO'),(2,'PIANO / LIVE'),(3,'PERFORMANCE MIX'),(4,'KEY ASSIGNMENT')]:
        lines=[f'titleTxt.txt="{title}"',*[f'vis {name},1' for name in groups[mode]]]
        if mode==1:
            # 隐藏控件不保证清除既有像素；先擦净鼓垫区域，再绘制编排网格。
            lines+=branch('seqView.val==1',[*[f'vis pad{k},0' for k in range(16)],
                f'fill 32,278,960,240,{C["page"]}','seqBtn.txt="DRUM PADS"','click drawGrid,1'],['seqBtn.txt="SEQUENCER"'])
            lines+=['hintTxt.txt="Tap a pad. Build a beat."']
        elif mode in (2,3):
            lines+=[s for k in (*WHITES,*SHARPS) for s in (f'ui{k}.txt="{NOTES[k]}"',*release(k))]
            lines+=['hintTxt.txt="Play keys - your chord appears above"']
        elif mode==4:lines+=['click selectEdit,1','click drawSetup,1','hintTxt.txt="Edit a key, then SAVE KEY"']
        else:lines+=['hintTxt.txt="Choose a mode to start"']
        draw+=branch(f'viewMode.val=={mode}',lines)
    draw+=['ref titleTxt','ref hintTxt']
    hidden_event('drawView',draw)
    # 每轨编号标签可点击切换鼓音，编辑网格仅使用一个覆盖热区。
    for tr in range(4):
        text(f'trackBtn{tr}',(32,292+tr*50,138,42),DRUMS[[0,1,2,7][tr]],color='amber',hidden=True,
             event={'codesup-':[f'payload.val=rxSnd{tr}.val+1',*branch('payload.val>15',['payload.val=0']),f'payload.val=payload.val+{tr*16}',*dynamic_packet(14,'payload.val')]})
    grid=[]
    for tr in range(4):
        grid+=[f'vis trackBtn{tr},1']
        for drum in range(16):grid+=branch(f'rxSnd{tr}.val=={drum}',[f'trackBtn{tr}.txt="{DRUMS[drum]}"'])
        for step in range(16):
            x=180+step*50;y=292+tr*50
            grid += [f'scratch.val=rxPat{tr}.val&{1<<step}',*branch('scratch.val>0',[f'fill {x},{y},42,42,{C["cyan"]}'],[f'fill {x},{y},42,42,{C["panel"]}'])]
    hidden_event('drawGrid',grid)
    widgets.append({'objname':'gridHit','type':'hotspot','hidden':True,'fields':{'x':180,'y':292,'w':800,'h':200},'events':{'codesdown-':[
        'payload.val=tch0-180','payload.val=payload.val/50','track.val=tch1-292','track.val=track.val/50',
        *sum([branch(f'track.val=={tr}',[f'scratch.val=1<<payload.val',f'scratch.val=rxPat{tr}.val&scratch.val',
             f'payload.val=payload.val+{tr*16}',*branch('scratch.val==0',dynamic_packet(12,'payload.val'),dynamic_packet(13,'payload.val'))]) for tr in range(4)],[])]}})
    # 补充隐藏网格组到切页逻辑，防止旧视图热区拦截钢琴键。
    by['drawView']['events']['codesdown-'][:0]=['vis gridHit,0',*[f'vis trackBtn{tr},0' for tr in range(4)]]
    by['drawGrid']['events']['codesdown-'].insert(0,'vis gridHit,1')
    recognize=['pcMask.val=0','bassPc.val=-1','touchCount.val=0']
    for k in range(16):recognize += [f'scratch.val=rxKeys.val&{1<<k}',*branch('scratch.val>0',['touchCount.val++',*branch('bassPc.val==-1',[f'bassPc.val={k%12}'])])]
    for pc in range(12):
        mask=sum(1<<k for k in range(pc,16,12))
        recognize += [f'scratch.val=rxKeys.val&{mask}',*branch('scratch.val>0',[f'pcMask.val=pcMask.val+{1<<pc}'])]
    lookup=['chordTxt.txt="NOTES"',*branch('pcMask.val==0',['chordTxt.txt="----"'])]
    for pc,name in enumerate(PC_NAMES):lookup+=branch(f'pcMask.val=={1<<pc}',[f'chordTxt.txt="{name}"'])
    lookup+=lookup_code(branch,formatter=display_label_zh)
    recognize+=branch('pcMask.val!=lastMask.val||bassPc.val!=lastBass.val',[*lookup,'lastMask.val=pcMask.val','lastBass.val=bassPc.val'])
    hidden_event('chordCalc',recognize)
    poll=branch('rxMode.val!=lastRxMode.val',[*reset_touch(),'lastRxMode.val=rxMode.val','viewMode.val=rxMode.val','seqView.val=0','click drawView,1'])
    # LCD 重绘与声音控制分离，物理回传不会置位 heldN，也不发送触摸保活。
    for k in range(16):
        bg,fg=resting(k)
        poll+=branch('viewMode.val>=2&&viewMode.val<=3&&seqView.val==0',[
            f'scratch.val=rxKeys.val&{1<<k}',f'priorBit.val=prevKeys.val&{1<<k}',
            *branch('scratch.val>0&&priorBit.val==0',[f'fade{k}.val=2',f'ui{k}.bco={C["cyan"]}',f'ui{k}.pco={C["ink"]}',f'ref ui{k}',*edges(k,C['white'])]),
            *branch('scratch.val==0&&priorBit.val>0',branch(f'held{k}.val==0',[f'fade{k}.val=0',*release(k)])),
            *branch('scratch.val>0',[f'ui{k}.bco={C["cyan"]}'],
               branch(f'held{k}.val==0&&fade{k}.val==0',[f'ui{k}.bco={C[bg]}',f'ui{k}.pco={C[fg]}'])),
            *branch(f'fade{k}.val>0',[f'fade{k}.val--',*branch(f'fade{k}.val==1',edges(k,C['muted']),
                [*edges(k,C['page']),*branch(f'held{k}.val==0&&scratch.val==0',release(k))])])])
        # 鼓点回传脉冲高亮；按键保持不会让动画连续循环。
        poll+=branch('viewMode.val==1&&seqView.val==0',[
            *branch(f'fade{k}.val>0',[f'fade{k}.val--',*branch(f'fade{k}.val==0',[f'pad{k}.bco={C["panel"]}',f'pad{k}.pco={C[PAD_TINTS[k]]}',f'ref pad{k}',*frame(drum_geometry(k),C['page'])])]),
            'scratch.val=rxDrums.val^prevDrums.val',f'scratch.val=scratch.val&{1<<k}',
            *branch('scratch.val>0',[f'fade{k}.val=2',f'pad{k}.bco={C[PAD_TINTS[k]]}',f'pad{k}.pco={C["ink"]}',f'ref pad{k}',*frame(drum_geometry(k),C['white'])])])
    for i,drum in enumerate([0,1,2,7]):
        poll+=branch('viewMode.val==3',['scratch.val=rxDrums.val^prevDrums.val',f'scratch.val=scratch.val&{1<<drum}',
            *branch('scratch.val>0',[f'mixFade{i}.val=2',f'mixPad{i}.bco={C["amber"]}',f'mixPad{i}.pco={C["ink"]}',f'ref mixPad{i}']),
            *branch(f'mixFade{i}.val>0',[f'mixFade{i}.val--',*branch(f'mixFade{i}.val==0',[f'mixPad{i}.bco={C["panel"]}',f'mixPad{i}.pco={C["amber"]}',f'ref mixPad{i}'])])])
    # 真实演奏活动重置空闲时间；自动回首页不能打断实体鼓键或保持的琴音。
    poll+=branch('rxDrums.val!=prevDrums.val||rxKeys.val>0',['idleSeconds.val=0'])
    poll+=['prevDrums.val=rxDrums.val']
    poll+=branch('rxKeys.val!=prevKeys.val',['click chordCalc,1','prevKeys.val=rxKeys.val'])
    # 显示16路实体压力最大值，不把屏幕音高误当成映射后的物理传感器编号。
    poll+=branch('viewMode.val>=1&&viewMode.val<=3',['peakPressure.val=0',
        *sum([branch(f'rxP{k}.val>peakPressure.val',[f'peakPressure.val=rxP{k}.val']) for k in range(16)],[]),
        'covx peakPressure.val,pressureTxt.txt,0,0','pressureTxt.txt="PRESS MAX "+pressureTxt.txt'])
    poll+=branch('rxBpm.val!=lastBpm.val',['lastBpm.val=rxBpm.val','bpmEdit.val=rxBpm.val','covx rxBpm.val,bpmTxt.txt,0,0','bpmTxt.txt="BPM "+bpmTxt.txt'])
    for i,label in enumerate(['PIA','DRM','MID']):poll += branch(f'rxVol{i}.val!=lastVol{i}.val',[
        f'lastVol{i}.val=rxVol{i}.val',f'volEdit{i}.val=rxVol{i}.val',f'covx rxVol{i}.val,vol{i}.txt,0,0',f'vol{i}.txt="{label} "+vol{i}.txt'])
    poll+=branch('rxFlags.val!=lastFlags.val',['lastFlags.val=rxFlags.val','scratch.val=rxFlags.val&1',*branch('scratch.val>0',['beatBtn.txt="BEAT STOP"'],['beatBtn.txt="BEAT PLAY"']),
        'scratch.val=rxFlags.val&2',*branch('scratch.val>0',['midiBtn.txt="MIDI STOP"'],['midiBtn.txt="MIDI PLAY"']),
        'stateTxt.txt="READY"','scratch.val=rxFlags.val&4',*branch('scratch.val==0&&viewMode.val==3',['stateTxt.txt="MIDI NO FILE"']),
        'scratch.val=rxFlags.val&32',*branch('scratch.val>0&&viewMode.val==3',['stateTxt.txt="MIDI ERROR"']),
        'scratch.val=rxFlags.val&16',*branch('scratch.val==0',['stateTxt.txt="AUDIO WAIT"'])])
    poll+=['cfgBank.val=rxConfig.val/1048576','scratch.val=rxConfig.val/65536','cfgKey.val=scratch.val&15','cfgDesc.val=rxConfig.val&65535']
    poll+=branch('viewMode.val==4&&editDirty.val==0&&cfgBank.val==editBank.val&&cfgKey.val==editKey.val',branch('cfgDesc.val!=lastDesc.val',[
        'lastDesc.val=cfgDesc.val','editKind.val=cfgDesc.val/16384','scratch.val=cfgDesc.val/256','editTone.val=scratch.val&63','editNote.val=cfgDesc.val&255','click drawSetup,1']))
    grid_changed='||'.join([f'rxPat{tr}.val!=lastPat{tr}.val' for tr in range(4)]+[f'rxSnd{tr}.val!=lastSnd{tr}.val' for tr in range(4)]+['rxStep.val!=lastStep.val'])
    poll+=branch('viewMode.val==1&&seqView.val==1',branch(grid_changed,[
        'click drawGrid,1',f'fill 180,500,800,4,{C["page"]}',*[f'lastPat{tr}.val=rxPat{tr}.val' for tr in range(4)],*[f'lastSnd{tr}.val=rxSnd{tr}.val' for tr in range(4)],'lastStep.val=rxStep.val',
        'scratch.val=rxStep.val*50','scratch.val=scratch.val+180',f'fill scratch.val,500,42,4,{C["amber"]}']))
    widgets.append({'objname':'tmUi','type':'timer','fields':{'tim':50,'en':1},'events':{'codestimer-':poll}})
    heartbeat=[]
    for k in range(16):heartbeat+=branch(f'held{k}.val==1',branch('tch0==0&&tch1==0',[packet(0,k),f'held{k}.val=0'],[packet(1,k)]))
    heartbeat+=branch('testMode.val==1',[packet(4,1)])
    widgets.append({'objname':'tmHeart','type':'timer','fields':{'tim':150,'en':1},'events':{'codestimer-':heartbeat}})
    poll+=['scratch.val=rxFlags.val&128',*branch('scratch.val==0',['bootLatch.val=0'],
        branch('bootLatch.val==0',['bootLatch.val=1',*branch('tmRestore.en==0',['eeSlot.val=0','tmRestore.en=1','hintTxt.txt="Restoring saved key maps"'])]))]
    restore=[]
    for bank in range(1,4):
        for key in range(16):
            restore+=branch(f'eeSlot.val=={(bank-1)*16+key}',[f'repo eeValue.val,{512+((bank-1)*16+key)*4}',*branch(f'eeValue.val>={MAGIC}&&eeValue.val<={MAGIC+0x410f}',[
                f'eeValue.val=eeValue.val-{MAGIC}','editKind.val=eeValue.val/16384','scratch.val=eeValue.val/256','editTone.val=scratch.val&63','editNote.val=eeValue.val&255',
                packet(32,bank),packet(33,key),*dynamic_packet(34,'editKind.val'),*dynamic_packet(35,'editTone.val'),*dynamic_packet(36,'editNote.val'),packet(37,1)])])
    restore+=['eeSlot.val++',*branch('eeSlot.val>=48',['editBank.val=1','editKey.val=0','editDirty.val=0',packet(32,1),packet(33,0),packet(39,1),'tmRestore.en=0','hintTxt.txt="Ready - choose a mode"'])]
    # 官方定时器最小50ms；48个槽共约2.4s，恢复结束后才解锁首页模式入口。
    widgets.append({'objname':'tmRestore','type':'timer','fields':{'tim':50,'en':1},'events':{'codestimer-':restore}})
    # 只对演奏视图计算空闲；设置页不自动退出，伴奏/触摸/TEST保持时不计时。
    idle_busy='||'.join(['rxKeys.val>0','scratch.val>0','testMode.val==1','tmRestore.en==1']+[f'held{k}.val==1' for k in range(16)])
    idle=branch('viewMode.val>=1&&viewMode.val<=3',['scratch.val=rxFlags.val&3',
        *branch(idle_busy,['idleSeconds.val=0'],['idleSeconds.val++',*branch(f'idleSeconds.val>={AUTO_HOME_SECONDS}',select_mode(0))])],['idleSeconds.val=0'])
    widgets.append({'objname':'tmIdle','type':'timer','fields':{'tim':1000,'en':int(AUTO_HOME_SECONDS>0)},'events':{'codestimer-':idle}})
    for widget in widgets:
        # 网格和轨道控件初始隐藏，但在鼓点视图接收真实触摸；隐藏逻辑事件除外。
        if widget['objname']=='gridHit' or widget['objname'].startswith('trackBtn') or (widget['type'] in ('text','hotspot') and not widget.get('hidden')):
            for event in ('codesdown-','codesup-'):
                if event in widget['events']:widget['events'][event].insert(0,'idleSeconds.val=0')
    localize(widgets)
    spec={'model':'TJC1060X570_011','version':'workstation-v3-zh-font-timer-fix','page':{'name':'page0','width':1024,'height':600},
          'font_resource':'workstation_zh_32.zi','colors_rgb565':C,'widgets':widgets,
          'page_events':{'codesloadend-':[packet(5,0),*[f'vis {w["objname"]},0' for w in widgets if w.get('hidden')],'click drawView,1'],
                         'codesunload-':reset_touch()},
          'features':['three performance modes','independent physical key setup','3 saved mapping banks','4x16 sequencer','3-source mix',f'{len(QUALITIES)} chord qualities','idle return to Home'],
          'auto_home_idle_seconds':AUTO_HOME_SECONDS,
          'eeprom':{'start':512,'end':704,'format':'48 little-endian uint32: 0x57010000 + descriptor','save_settle_ms':1000},
          'official_compile_status':'pending','hardware_status':'pending','multi_touch_hardware_status':'unconfirmed'}
    localize([{'fields':{},'events':spec['page_events']}])
    assert len(widgets)<=250,len(widgets)
    from build_workstation_font import generate_font
    generate_font(spec,OUT/'workstation_zh_32.zi')
    (OUT/'controls_manifest.json').write_text(json.dumps(spec,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    background(OUT/'instrument_background.png')
    registry=REGISTRY
    (OUT/'registry.json').write_text(json.dumps(registry,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    return spec

if __name__=='__main__':print(f"Generated {len(generate()['widgets'])} workstation controls")
