"""V2动态资源目录与演奏台。HMI只发控制，所有状态从FPGA回传。"""
from pathlib import Path
import json,sys
from PIL import Image,ImageDraw,ImageFont
HERE=Path(__file__).resolve().parent;SCREEN=HERE.parent;ROOT=SCREEN.parents[1]
sys.path.insert(0,str(SCREEN));sys.path.insert(0,str(HERE))
from build_workstation_font import generate_font as build_font
from build_dashboard_hmi import generate as build_hmi
from workstation_theme import geometry,C,SHARPS,WHITES

def frame(op,value):
    lines=[f'printh A5 5A {op:02X} {value:02X} {255^op^value:02X}']
    if op==2 and value==255:lines += [f'held{k}.val=0' for k in range(16)]
    return lines
def control(op,value=0,aux=0):return [f'cmdOp.val={op}',f'cmdValue.val={value}',f'cmdAux.val={aux}','click sendCmd,1']
def create():
    out=HERE/'workstation_v2';out.mkdir(exist_ok=True);widgets=[];by={};groups={i:[] for i in range(10)}
    def variable(name,val=0):
        item={'objname':name,'type':'variable','fields':{'sta':0,'val':val},'events':{}};widgets.append(item);by[name]=item;return item
    def text(name,rect,label='',modes=(),event=None,color='white',bg='panel',hidden=False):
        x,y,w,h=rect;item={'objname':name,'type':'text','hidden':hidden,'fields':{'x':x,'y':y,'w':w,'h':h,'sta':1,'font':0,
            'pco':C[color],'bco':C[bg],'xcen':1,'ycen':1,'txt':label,'txt_maxl':128},'events':event or {}}
        widgets.append(item);by[name]=item
        for mode in modes:groups[mode].append(name)
        return item
    def helper(name,lines):
        item={'objname':name,'type':'hotspot','hidden':True,'fields':{'x':0,'y':0,'w':1,'h':1},'events':{'codesdown-':lines}};widgets.append(item);by[name]=item
    def button(name,rect,label,modes,lines,color='white'):
        return text(name,rect,label,modes,{'codesup-':['idle.val=0']+lines},color)
    text('t0',(0,0,64,32),hidden=True)
    # rx0..13为设备状态，rx14..17为当前音色A/D/S/R，均由FPGA确认后刷新。
    for i in range(41):variable('rx'+str(i))
    for name in ('lastSnap','pendingSerial','pendingOp','activeTone','pendingValue','pendingAux','partVolume'):variable(name)
    for i in range(12):variable('r'+str(i))
    for name,val in [('view',0),('oldMode',0),('cmdOp',0),('cmdValue',0),('cmdAux',0),('op',0),('byte',0),('check',0),('scratch',0),('dragTick',0),
      ('idle',0),('touching',0),('patchChoice',0),('part',0),('setting',0),('bank',1),('key',0),('kind',0),('tone',63),('note',0),('mapValue',0),
      ('eeSlot',0),('eeAddress',0),('eeValue',0),('restoreLatch',0),('loopOn',0),('scratch2',0),
      ('envA',64),('envD',8),('envS',3072),('envR',32),('envPatch',0),('envDirty',0)]:variable(name,val)
    for i in range(16):variable('held'+str(i))
    text('title',(24,14,710,52),'演奏工作站',color='cyan',bg='page')
    button('home',(830,14,170,52),'返回首页',range(1,10),frame(2,255)+frame(5,0)+['view.val=0','click drawView,1'],'cyan')
    text('hint',(24,554,976,34),'音频由 FPGA 实时合成',color='muted',bg='page')
    for index,(label,view,mode) in enumerate([('设备曲库',5,None),('音色库',6,None),('弹琴模式',2,2),('鼓点模式',1,1),('混音模式',3,3),('实体键设置',4,4)]):
        x=32+(index%2)*496;y=114+(index//2)*136
        lines=frame(2,255)+(frame(5,mode) if mode is not None else [])+[f'view.val={view}','click drawView,1']
        button('menu'+str(index),(x,y,464,110),label,(0,),lines,'cyan' if index<2 else 'white')
    for i in range(12):
        mode=5 if i<4 else 6;local=i if i<4 else i-4
        x=32 if i<4 else 32+(local%2)*496;y=108+local*98 if i<4 else 168+(local//2)*86
        w=960 if i<4 else 464;name='c'+str(i)
        lines=[f'if(r{i}.val==1)','{']
        if i<4:lines+=frame(2,255)+frame(5,3)+control(2,i)+['view.val=7','click drawView,1']
        else:lines+=[f'patchChoice.val={i-2}']+control(12,i-2)+control(13,i-2)+['hint.txt="音色选择已发送，等待设备确认"']
        lines+=['}'];button(name,(x,y,w,76),'尚未下发',(mode,),lines,'cyan')
    button('pluck',(32,92,464,58),'内置：拨弦',(6,),control(12,0)+control(13,0)+['patchChoice.val=0'])
    button('wind',(528,92,464,58),'内置：管乐',(6,),control(12,1)+control(13,1)+['patchChoice.val=1'])
    button('audition',(32,510,300,38),'试听当前音色',(6,),control(14,'patchChoice.val',60|(1000<<8)))
    button('editEnvelope',(364,510,300,38),'当前音色包络',(6,),['envPatch.val=rx3.val','envA.val=rx14.val','envD.val=rx15.val',
        'envS.val=rx16.val','envR.val=rx17.val','envDirty.val=0','view.val=9','click envLabels,1','click drawView,1'])
    text('envTitle',(32,98,960,52),'包络参数：FPGA确认后生效',(9,),color='cyan')
    labels=[]
    for i,(label,var,step,minimum) in enumerate([('起音步长 A','envA',1,1),('衰减步长 D','envD',1,1),('维持电平 S','envS',128,0),('释音步长 R','envR',1,1)]):
        y=176+i*76
        text('envLabel'+str(i),(32,y,270,56),label,(9,))
        text('envValue'+str(i),(476,y,250,56),'0',(9,),color='cyan')
        button('envMinus'+str(i),(330,y,120,56),'减少',(9,),[f'{var}.val={var}.val-{step}',f'if({var}.val<{minimum})','{',f'{var}.val={minimum}','}','envDirty.val=1','click envLabels,1'])
        button('envPlus'+str(i),(752,y,240,56),'增加',(9,),[f'{var}.val={var}.val+{step}',f'if({var}.val>4095)','{',f'{var}.val=4095','}','envDirty.val=1','click envLabels,1'])
        labels += [f'cov {var}.val,envValue{i}.txt,0']
    helper('envLabels',labels)
    button('envApply',(32,500,464,44),'应用到FPGA',(9,),['cmdValue.val=envA.val<<4','scratch.val=envD.val<<16',
        'cmdValue.val=cmdValue.val+scratch.val','cmdValue.val=cmdValue.val+envPatch.val','cmdAux.val=envR.val<<12',
        'cmdAux.val=cmdAux.val+envS.val','cmdOp.val=34','click sendCmd,1','envDirty.val=2','hint.txt="参数已发送，等待FPGA回传"'],'cyan')
    button('envBack',(528,500,464,44),'返回音色库',(9,),['view.val=6','click drawView,1'])
    text('status',(32,82,960,48),'设备尚未就绪',(1,2,3,7),color='amber')
    text('chord',(670,142,322,46),'和弦：待演奏',(2,3),color='cyan')
    for i in WHITES+SHARPS:
        rect=geometry(i);base='sharp' if i in SHARPS else 'key';label=['C4','C#4','D4','D#4','E4','F4','F#4','G4','G#4','A4','A#4','B4','C5','C#5','D5','D#5'][i]
        text('key'+str(i),rect,label,(2,3),{'codesdown-':['idle.val=0']+frame(1,i)+[f'held{i}.val=1',f'key{i}.bco={C["cyan"]}'],
            'codesup-':frame(0,i)+[f'held{i}.val=0',f'key{i}.bco={C[base]}']},'white' if i in SHARPS else 'ink',base)
    for i in range(16):
        x=32+(i%4)*244;y=148+(i//4)*96
        item=button('pad'+str(i),(x,y,228,80),['底鼓','军鼓','闭镲','开镲','低嗵','中嗵','高嗵','拍手','边击','叮叮镲','吊镲','牛铃','沙锤','铃鼓','木块','鼓棒'][i],(1,),[],'amber')
        item['events']={'codesdown-':['idle.val=0']+frame(6,i)+[f'pad{i}.bco={C["cyan"]}'],'codesup-':[f'pad{i}.bco={C["panel"]}']}
    for index,(label,op,value) in enumerate([('播放',3,0),('暂停继续',4,0),('停止',5,0),('分段配器',None,0)]):
        lines=control(op,value) if op else ['view.val=8','click drawView,1']
        button('transport'+str(index),(32+index*244,152,228,64),label,(7,),lines,'cyan')
    text('position',(32,236,960,54),'位置：0',(7,),color='white')
    text('timeline',(32,310,960,48),'拖动定位，松手生效',(7,),bg='border')
    by['timeline']['events']={'codesdown-':['touching.val=1','click locate,1'], 'codesup-':['click locate,1','touching.val=0']+control(6,'dragTick.val')}
    helper('locate',['scratch.val=tch0','if(scratch.val<32)','{','scratch.val=32','}','if(scratch.val>992)','{','scratch.val=992','}',
        'scratch.val=scratch.val-32','scratch.val=scratch.val*1000','scratch.val=scratch.val/960',
        # duration*permille/1000，拆成商和余数，避免短曲谱被量化为0，也避免32位乘法溢出。
        'dragTick.val=rx7.val/1000','dragTick.val=dragTick.val*scratch.val','scratch2.val=rx7.val/1000','scratch2.val=scratch2.val*1000',
        'scratch2.val=rx7.val-scratch2.val','scratch2.val=scratch2.val*scratch.val','scratch2.val=scratch2.val/1000','dragTick.val=dragTick.val+scratch2.val',
        'cov dragTick.val,position.txt,0','position.txt="预览位置 "+position.txt'])
    for index,(label,op,value) in enumerate([('设A点',7,'rx6.val'),('设B点',8,'rx6.val'),('循环开关',9,'loopOn.val'),('音色库',None,0)]):
        lines=control(op,value) if op else ['view.val=6','click drawView,1']
        if op==9:lines=['loopOn.val=1-loopOn.val']+lines
        button('playExtra'+str(index),(32+index*244,396,228,60),label,(7,),lines)
    for i,(label,op,expression,minimum,maximum) in enumerate([('减速',10,'rx31.val-5',50,200),('加速',10,'rx31.val+5',50,200),('降半音',11,'rx32.val-25',-24,24),('升半音',11,'rx32.val-23',-24,24)]):
        lines=[f'cmdValue.val={expression}',f'if(cmdValue.val<{minimum})','{',f'cmdValue.val={minimum}','}',f'if(cmdValue.val>{maximum})','{',f'cmdValue.val={maximum}','}']+control(op,'cmdValue.val')
        button('playAdjust'+str(i),(32+i*244,480,228,48),label,(7,),lines)
    text('sectionLabel',(32,110,960,52),'段落／声部配器',(8,),color='cyan')
    text('partActual',(528,186,464,60),'等待FPGA配器状态',(8,),color='cyan')
    for i,label in enumerate(['上一段','下一段']):button('sectionNav'+str(i),(32+i*244,186,228,60),label,(8,),control(23,'rx4.val-1' if i==0 else 'rx4.val+1'))
    for i,label in enumerate(['主旋律','和弦','低音','鼓']):button('part'+str(i),(32+i*244,266,228,60),label,(8,),[f'part.val={i}','hint.txt="选择下面的音色槽应用到此声部"'])
    for i in range(10):button('partTone'+str(i),(32+(i%5)*196,350+(i//5)*76,180,60),str(i),(8,),control(24,i,'part.val'))
    for i,(label,op,expression) in enumerate([('音量减少',25,'partVolume.val-5'),('音量增加',25,'partVolume.val+5'),('静音切换',26,'rx29.val^(1<<part.val)'),('独奏切换',27,'rx30.val^(1<<part.val)')]):
        lines=[f'cmdValue.val={expression}']
        if op==25:lines+=['if(cmdValue.val<0)','{','cmdValue.val=0','}','if(cmdValue.val>100)','{','cmdValue.val=100','}']
        button('partAdjust'+str(i),(32+i*244,504,228,40),label,(8,),lines+control(op,'cmdValue.val','part.val' if op==25 else 0))
    # 设置页保留三套16键映射；63表示跟随当前音色。
    text('mapping',(32,110,960,64),'实体键逐键设置',(4,),color='cyan')
    for i,(label,var,limit) in enumerate([('配置组','bank',3),('实体键','key',15),('声音类型','kind',1),('音色编号','tone',9),('音高鼓号','note',15)]):
        button('map'+str(i),(32,194+i*62,620,50),label+'：点击切换',(4,),[f'{var}.val={var}.val+1',f'if({var}.val>{limit})','{',f'{var}.val='+('1' if var=='bank' else '0'),'}','click mapLabel,1'])
    helper('mapLabel',['cov bank.val,mapping.txt,0','mapping.txt="配置 "+mapping.txt','cov key.val,t0.txt,0','mapping.txt=mapping.txt+"  实体键 "+t0.txt',
        'cov kind.val,t0.txt,0','mapping.txt=mapping.txt+"  类型 "+t0.txt','cov tone.val,t0.txt,0','mapping.txt=mapping.txt+"  音色 "+t0.txt',
        'cov note.val,t0.txt,0','mapping.txt=mapping.txt+"  音高 "+t0.txt'])
    def send_dynamic(op,expression):return [f'op.val={op}',f'byte.val={expression}','click txFrame,1']
    mapping_send=send_dynamic(0x20,'bank.val')+send_dynamic(0x21,'key.val')+send_dynamic(0x22,'kind.val')+send_dynamic(0x23,'tone.val')+send_dynamic(0x24,'note.val')+frame(0x25,1)
    button('saveMapping',(696,194,296,72),'保存此键',(4,),mapping_send+['eeAddress.val=bank.val-1','eeAddress.val=eeAddress.val*16','eeAddress.val=eeAddress.val+key.val','eeAddress.val=eeAddress.val*4','eeAddress.val=eeAddress.val+512',
        'eeValue.val=kind.val<<14','scratch.val=tone.val<<8','eeValue.val=eeValue.val+scratch.val','eeValue.val=eeValue.val+note.val','eeValue.val=eeValue.val+1459683328','wepo eeValue.val,eeAddress.val','hint.txt="已保存，等待设备确认"'],'cyan')
    button('followTone',(696,290,296,72),'跟随当前音色',(4,),['tone.val=63','click mapLabel,1'])
    reset_mapping=send_dynamic(0x26,'bank.val')
    for b in range(1,4):
        reset_mapping += [f'if(bank.val=={b})','{']+[f'wepo {1459683328+(0x4000 if b==1 else 0x3f00)+k},{512+((b-1)*16+k)*4}' for k in range(16)]+['}']
    button('resetBank',(696,386,296,72),'恢复本组默认',(4,),reset_mapping)
    helper('txFrame',['printh A5 5A','prints op.val,1','prints byte.val,1','check.val=255^op.val','check.val=check.val^byte.val','prints check.val,1'])
    send=[]
    for i in range(4):send+=send_dynamic(0x70+i,f'(cmdValue.val>>{8*i})&255')
    for i in range(4):send+=send_dynamic(0x74+i,f'(cmdAux.val>>{8*i})&255')
    send+=['pendingSerial.val=rx18.val','pendingOp.val=cmdOp.val','pendingValue.val=cmdValue.val','pendingAux.val=cmdAux.val','hint.txt="待确认：正在发送到FPGA"','op.val=64+cmdOp.val','byte.val=0','click txFrame,1'];helper('sendCmd',send)
    draw=['pic 0,0,0','title.txt="演奏工作站"']
    all_visual=[w['objname'] for w in widgets if w['type']=='text' and not w.get('hidden')]
    for name in all_visual:draw.append(f'vis {name},0')
    draw+=['vis title,1','vis hint,1']
    for view,names in groups.items():
        draw += [f'if(view.val=={view})','{']+[f'vis {n},1' for n in names]+['}']
    # 黑键最后重绘，避免刷新白键把黑键覆盖。
    draw+=['if(view.val==2||view.val==3)','{']+[f'ref key{k}' for k in SHARPS]+['}'];helper('drawView',draw)
    update=['if(view.val==1||view.val==2||view.val==3||view.val==7)','{','cov rx9.val,status.txt,0','status.txt="最高压力 "+status.txt',
      'cov rx5.val,t0.txt,0','status.txt=status.txt+"  活动声部 "+t0.txt','cov rx4.val,t0.txt,0','status.txt=status.txt+"  段落 "+t0.txt','}',
      'if(view.val==7&&touching.val==0)','{','cov rx6.val,position.txt,0','position.txt="位置 "+position.txt','cov rx7.val,t0.txt,0','position.txt=position.txt+" / "+t0.txt','}',
      'if(rx0.val!=oldMode.val)','{','oldMode.val=rx0.val','if(rx0.val<=4&&(view.val!=7||rx0.val!=3))','{','view.val=rx0.val','click drawView,1','}','}',
      'if(view.val==2||view.val==3)','{']
    for i in range(16):
        base='sharp' if i in SHARPS else 'key'
        update += [f'if((rx10.val&{1<<i})!=0||held{i}.val==1)','{',f'key{i}.bco={C["cyan"]}','}else','{',f'key{i}.bco={C[base]}','}']
    update += [f'ref key{k}' for k in SHARPS]+['}']
    # 复用现有和弦识别源码，变量名适配实际旋律位图。
    old=json.loads((HERE/'workstation/controls_manifest.json').read_text(encoding='utf-8'))
    chord=next(w for w in old['widgets'] if w['objname']=='chordCalc')
    old_vars=set()
    for lines in chord['events'].values():
        import re
        for line in lines:old_vars.update(re.findall(r'\b([A-Za-z_]\w*)\.val',line))
    for name in sorted(old_vars-{'rxKeys'}):
        if name not in by:variable(name)
    helper('chordCalc',[s.replace('rxKeys','rx10').replace('chordTxt','chord') for s in chord['events']['codesdown-']])
    update+=['if(view.val==2||view.val==3)','{','click chordCalc,1','}',
        'if(view.val==9&&envDirty.val==2&&rx3.val==envPatch.val&&rx14.val==envA.val&&rx15.val==envD.val&&rx16.val==envS.val&&rx17.val==envR.val)',
        '{','envDirty.val=0','hint.txt="FPGA已确认包络参数"','}']
    update += ['if(rx18.val!=pendingSerial.val&&rx20.val==pendingOp.val&&rx36.val==(pendingValue.val&65535)&&rx37.val==((pendingValue.val>>16)&65535)&&rx38.val==(pendingAux.val&65535)&&rx39.val==((pendingAux.val>>16)&65535))','{','pendingSerial.val=rx18.val','if(rx19.val==0)','{','hint.txt="已生效：FPGA确认完成"','}else','{','cov rx19.val,t0.txt,0','hint.txt="失败：FPGA错误码 "+t0.txt','}','}',
      'if(view.val==8)','{']
    for i in range(4):update += [f'if(part.val=={i})','{',f'activeTone.val=rx{21+i}.val',f'partVolume.val=rx{25+i}.val',f'cov rx{25+i}.val,t0.txt,0','}']
    for i in range(10):
        label='"内置：拨弦"' if i==0 else '"内置：管乐"' if i==1 else f'c{i+2}.txt'
        update += [f'partTone{i}.txt={label}',f'if(activeTone.val=={i})','{',f'partActual.txt={label}+"  音量 "+t0.txt+"%"',f'partTone{i}.bco={C["cyan"]}','}else','{',f'partTone{i}.bco={C["panel"]}','}']
    for i in range(4):update += [f'if(part.val=={i})','{',f'part{i}.bco={C["cyan"]}','}else','{',f'part{i}.bco={C["panel"]}','}']
    for widget,field,color in [('partAdjust2','rx29','amber'),('partAdjust3','rx30','cyan')]:
        update += [f'if(({field}.val&(1<<part.val))!=0)','{',f'{widget}.bco={C[color]}','}else','{',f'{widget}.bco={C["panel"]}','}']
    update += ['}','if(view.val==7)','{']
    for i in range(4):update += [f'if(rx2.val=={i})','{',f'title.txt="曲目："+c{i}.txt','}']
    update += ['if(touching.val==0)','{','scratch.val=rx4.val+1','cov scratch.val,t0.txt,0','position.txt="第"+t0.txt+"段  "+position.txt',
        'cov rx31.val,t0.txt,0','position.txt=position.txt+"  速度"+t0.txt+"%"','if(rx35.val>0)','{','scratch.val=60000000/rx35.val',
        'cov scratch.val,t0.txt,0','position.txt=position.txt+"  基准"+t0.txt+"BPM"','}','}','}']
    # rx40是完整快照提交序号；命令值分16位传输，兼容屏幕有符号32位变量。
    update=['if(rx40.val!=lastSnap.val)','{','lastSnap.val=rx40.val']+update+['}']
    widgets.append({'objname':'tmUi','type':'timer','fields':{'tim':100,'en':1},'events':{'codestimer-':update}})
    heart=[]
    for i in range(16):heart += [f'if(held{i}.val==1)','{']+frame(1,i)+['}']
    widgets.append({'objname':'tmHeart','type':'timer','fields':{'tim':150,'en':1},'events':{'codestimer-':heart}})
    # 屏幕EEPROM保存三套16键映射；每50ms恢复一个槽，48槽约2.4秒。
    restore=['restoreLatch.val=eeSlot.val'];magic=1459683328
    for bank in range(1,4):
        for key in range(16):
            slot=(bank-1)*16+key;address=512+slot*4
            restore += [f'if(restoreLatch.val=={slot})','{',f'repo eeValue.val,{address}',
                f'if(eeValue.val>={magic}&&eeValue.val<={magic+0x410f})','{',
                f'eeValue.val=eeValue.val-{magic}',f'bank.val={bank}',f'key.val={key}',
                'kind.val=eeValue.val/16384','scratch.val=eeValue.val/256','tone.val=scratch.val&63','note.val=eeValue.val&255',
                *mapping_send,'}','eeSlot.val=eeSlot.val+1','}']
    restore += ['if(eeSlot.val>=48)','{','eeSlot.val=0','tmRestore.en=0',*frame(0x27,1),'hint.txt="映射已恢复"','}']
    widgets.append({'objname':'tmRestore','type':'timer','fields':{'tim':50,'en':1},'events':{'codestimer-':restore}})
    idle=['if(rx10.val!=0||rx9.val>16||(rx1.val&1)!=0)','{','idle.val=0','}else','{','idle.val=idle.val+1','}',
      'if(idle.val>=120&&view.val!=0&&view.val!=4)','{']+frame(2,255)+frame(5,0)+['view.val=0','idle.val=0','click drawView,1','}']
    widgets.append({'objname':'tmIdle','type':'timer','fields':{'tim':1000,'en':1},'events':{'codestimer-':idle}})
    initial=frame(5,0)+['view.val=0','click drawView,1','eeSlot.val=0','tmRestore.en=1']+[f'vis {w["objname"]},0' for w in widgets if w.get('hidden')]
    # 使用陶晶驰已验证的四参数covx，避免混用其他屏幕厂商的cov语法。
    for widget in widgets:
        for event,lines in widget.get('events',{}).items():
            widget['events'][event]=['covx '+line[4:]+',0' if line.startswith('cov ') else line for line in lines]
    spec={'model':'TJC1060X570_011','version':'workstation-v2-linked','page':{'name':'page0','width':1024,'height':600},
      'full_gb2312':True,
      'legacy_text_controls':1,
      'font_resource':'workstation_v2_32.zi','widgets':widgets,'page_events':{'codesloadend-':initial,'codesunload-':frame(2,255)},'official_compile_status':'pending'}
    background=Image.new('RGB',(1024,600),'#101b28');draw_image=ImageDraw.Draw(background)
    draw_image.rounded_rectangle((12,8,1012,74),radius=18,fill='#182c3e');draw_image.line((24,542,1000,542),fill='#29465a',width=2)
    background.save(out/'instrument_background.png')
    # GB2312全集保证导入新中文名称后无需重新编译屏幕。
    chars=[]
    for high in range(0xa1,0xf8):
        for low in range(0xa1,0xff):
            try:chars.append(bytes([high,low]).decode('gb2312'))
            except UnicodeDecodeError:pass
    spec['extra_characters']=''.join(chars)
    font=out/spec['font_resource']
    metadata=font.with_suffix('.json')
    if not font.exists() or not metadata.exists() or json.loads(metadata.read_text(encoding='utf-8')).get('coverage')!='GB2312':build_font(spec,font)
    spec.pop('extra_characters');manifest=out/'controls_manifest.json';manifest.write_text(json.dumps(spec,ensure_ascii=False,indent=2),encoding='utf-8')
    target=SCREEN/'generated/instrument_workstation_v2/instrument_workstation_v2.HMI';target.parent.mkdir(parents=True,exist_ok=True)
    build_hmi(manifest,target,SCREEN/'uart_minimal_manual.HMI',SCREEN/'vendor/TJC1060X570_factory.HMI')
    print('Generated',target,'controls=',len(widgets),'font GB2312 full; official compile pending')
    return spec
if __name__=='__main__':create()
