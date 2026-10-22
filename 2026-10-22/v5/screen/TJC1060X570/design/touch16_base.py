"""扩展原监控页面为两排各八键；保留 UART 原始数据与本地演示隔离。"""
from copy import deepcopy
import re
from PIL import Image, ImageDraw, ImageFont

NOTES = ['C4','C#4','D4','D#4','E4','F4','F#4','G4','G#4','A4','A#4','B4','C5','C#5','D5','D#5']
KEY_COUNT = len(NOTES)


def geometry(key):
    return 32+(key%8)*122, 266+(key//8)*118, 116, 110


def extend(spec):
    widgets = spec['widgets']
    old = {w['objname']: w for w in widgets}
    extras = []
    for k in range(13, KEY_COUNT):
        for prefix, prototype in [('t', 't15'),('cur','cur12'),('peak','peak12'),
                                  ('peakHex','peakHex12'),('sim','sim12'),('ui','ui12'),('j','j12'),('key','key12')]:
            w = deepcopy(old[prototype])
            w['objname'] = f'{prefix}{k+3 if prefix=="t" else k}'
            w['events'] = {}
            if prefix in ('ui', 'j'):
                w['events'] = {'codesup-': [f'selected.val={k}']}
            extras.append(w)
    widgets.extend(extras)
    by = {w['objname']:w for w in widgets}
    by['t1']['fields']['txt_maxl'] = 2
    for k in range(KEY_COUNT):
        x,y,w,h = geometry(k)
        for name in (f't{k+3}',f'ui{k}'):
            by[name]['fields'].update(x=x+12,y=y+69,w=72,h=36,
                bco=spec['colors_rgb565']['sharp' if '#' in NOTES[k] else 'key'],
                pco=spec['colors_rgb565']['amber' if '#' in NOTES[k] else 'ink'])
        by[f'j{k}']['fields'].update(x=x+88,y=y+41,w=16,h=60)
        by[f'key{k}']['fields'].update(x=x,y=y,w=w,h=h)

    # 克隆最后一个压力解析块，解析器与 HEX/DEC/峰值显示逻辑保持一致。
    timer = by['tm0']['events']['codestimer-']
    start = timer.index('sourceTxt.txt=sim12.txt')-2
    end = timer.index('if(modeTxt.txt=="MIDI")')
    block = timer[start:end]
    extra = []
    for k in range(13, KEY_COUNT):
        for line in block:
            line = re.sub(r'\b(cur|peak|peakHex|sim|ui|j)12\b', lambda m: m[1]+str(k), line)
            line = line.replace('t15.txt',f't{k+3}.txt').replace('selected.val==12',f'selected.val=={k}').replace('"C5"',f'"{NOTES[k]}"')
            extra.append(line)
    timer[end:end] = extra
    insert = timer.index('sim12.txt="000"')+1
    timer[insert:insert] = [f'sim{k}.txt="000"' for k in range(13,KEY_COUNT)]
    insert = timer.index('demoStep.val++')
    for k in reversed(range(13,KEY_COUNT)):
        timer[insert:insert] = [f'if(demoKey.val=={k})','{',f'sim{k}.txt=demoValue.txt','}']
    timer[:] = [line.replace('demoKey.val>=13','demoKey.val>=16') for line in timer]
    # 独立修正十六进制 E/F/10；不改变 A..D 的已有兼容分支。
    for value,n in [('E',14),('F',15),('10',16)]:
        # 放在整个更新脚本末尾，覆盖默认原始十六进制字符显示。
        timer.extend([f'if(demoMode.val==0&&t1.txt=="{value}")','{',f'activeTxt.txt="{n}"','}'])
    by['clearBtn']['events']['codesup-'].extend(line for k in range(13,KEY_COUNT) for line in
        [f'peak{k}.val=cur{k}.val','if(demoMode.val==1)','{',f'peakHex{k}.txt=sim{k}.txt','}else','{',f'peakHex{k}.txt=t{k+3}.txt','}'])
    by['demoBtn']['events']['codesup-'][0:0] = [line for k in range(13,KEY_COUNT) for line in
        [f'cur{k}.val=0',f'peak{k}.val=0',f'peakHex{k}.txt="000"']]
    # 热点统一最后放置，避免压力条/文本控件挡住演奏事件。
    widgets[:] = [w for w in widgets if w['type']!='hotspot']+[by[f'key{k}'] for k in range(KEY_COUNT)]
    spec['uart']['inputs'] = [f't{i}' for i in range(KEY_COUNT+3)]
    spec['touch_protocol'].update(key_range=[0,KEY_COUNT-1],note_order=NOTES)
    return spec


def background(base, colors, rgb):
    image = Image.open(base).convert('RGB')
    draw = ImageDraw.Draw(image)
    draw.rectangle((24,258,1010,505), fill=rgb(colors['page']))
    font = ImageFont.truetype('C:/Windows/Fonts/consolab.ttf',22)
    small = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',12)
    for k,note in enumerate(NOTES):
        x,y,w,h = geometry(k)
        sharp = '#' in note
        draw.rounded_rectangle((x,y,x+w-1,y+h-1),radius=8,fill=rgb(colors['sharp' if sharp else 'key']),outline=rgb(colors['border']))
        draw.text((x+12,y+7),note,font=font,fill=rgb(colors['white' if sharp else 'ink']))
        draw.text((x+88,y+13),f'{k+1:02}',font=small,fill=rgb(colors['muted' if sharp else 'ink']))
    draw.rectangle((596,29,669,80),fill=rgb(colors['page']))
    draw.text((578,65),'16 KEYS',font=small,fill=rgb(colors['cyan']))
    draw.rectangle((590,104,641,124),fill=rgb(colors['panel']))
    draw.text((634,107),'0-16',font=small,anchor='ra',fill=rgb(colors['muted']))
    return image
