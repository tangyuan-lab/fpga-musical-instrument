"""按实际HMI事件渲染各逻辑页面，使用交付ZI字库；不替代官方TFT编译。"""
from pathlib import Path
import sys,json
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'scripts'))
from verify_workstation import WorkstationModel,rgb565
from usarthmi.zi_font import ZiFont

def main():
    folder=ROOT/'screen/TJC1060X570/design/workstation_v2'
    spec=json.loads((folder/'controls_manifest.json').read_text(encoding='utf-8'))
    font=ZiFont(folder/spec['font_resource']);controls={w['objname']:w for w in spec['widgets']};out=ROOT/'build/tests/workstation_v2_views';out.mkdir(parents=True,exist_ok=True)
    sheet=Image.new('RGB',(1024,5*330),'#101b28');labels=['首页','鼓点','弹琴','混音','实体键设置','设备曲库','音色库','歌曲演奏台','分段配器','包络参数']
    heading=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',20)
    for view,label in enumerate(labels):
        model=WorkstationModel(spec);p=model.values;p.update({'view.val':view,'oldMode.val':2,'rx0.val':2,'rx40.val':1,'rx7.val':1920,'rx6.val':480,'rx5.val':4,'rx9.val':2048,'rx31.val':100,'rx32.val':24})
        for i in range(12):p[f'c{i}.txt']=f'示例曲目{i+1}' if i<4 else f'自定义音色{i-3}';p[f'r{i}.val']=1
        p['rx21.val']=2;p['rx25.val']=90
        model.run('drawView','codesdown-');model.run('tmUi')
        img=Image.open(folder/'instrument_background.png').convert('RGB');draw=ImageDraw.Draw(img);visible=set()
        def paint(name):
            control=controls.get(name)
            if not control or control['type']!='text' or name not in visible:return
            x,y,w,h=[int(p[f'{name}.{key}']) for key in ('x','y','w','h')]
            draw.rectangle((x,y,x+w-1,y+h-1),fill=rgb565(p[f'{name}.bco']))
            tile=font.render_text(p[f'{name}.txt'],rgb565(p[f'{name}.pco']));layer=Image.new('RGBA',(w,h))
            px=0 if p[f'{name}.xcen']==0 else (w-tile.width)//2
            py=0 if p[f'{name}.ycen']==0 else h-32 if p[f'{name}.ycen']==2 else (h-32)//2
            layer.paste(tile,(px,py),tile);img.paste(layer,(x,y),layer)
        for event in model.draws:
            if event.startswith('vis '):
                name,state=event[4:].split(',')
                if state=='1':visible.add(name);paint(name)
                else:visible.discard(name)
            elif event.startswith('ref '):paint(event[4:])
        # 属性赋值在真屏自动刷新；模型只记录绘图命令，最后按控件顺序重绘当前可见内容。
        for name in controls:paint(name)
        if view in (2,3):
            from workstation_theme import SHARPS
            for index in SHARPS:paint('key'+str(index))
        img.save(out/f'{view}.png');sheet.paste(img.resize((512,300)),((view%2)*512,(view//2)*330+30));ImageDraw.Draw(sheet).text(((view%2)*512+10,(view//2)*330+3),label,font=heading,fill='#e4f4ff')
    sheet.save(out/'all_views.png');print('PASS 10 logical HMI view previews:',out/'all_views.png')

if __name__=='__main__':main()
