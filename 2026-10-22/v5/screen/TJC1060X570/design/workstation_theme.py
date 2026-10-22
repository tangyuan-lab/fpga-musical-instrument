"""工作站视觉源：静态首页图稿与原生控件几何，图形全部由代码生成。"""
from PIL import Image, ImageDraw, ImageFont

def color(value):
    r,g,b=bytes.fromhex(value)
    return (r>>3)<<11 | (g>>2)<<5 | (b>>3)

C={name:color(value) for name,value in {
    'page':'0C1220','panel':'192438','border':'2A3A52','white':'F1F5F9',
    'muted':'91A0B6','cyan':'62D7C7','amber':'F2B46C','purple':'AAA4EF',
    'key':'E9EDEB','ink':'162535','sharp':'23314B'}.items()}
SHARPS=(1,3,6,8,10,13,15)
WHITES=(0,2,4,5,7,9,11,12,14)
PAD_TINTS=('amber','purple','cyan','cyan','amber','amber','amber','purple','purple','cyan','cyan','cyan','cyan','cyan','amber','amber')
MENU_RECTS={1:(32,152,468,164),2:(524,152,468,164),3:(32,334,468,164),4:(524,334,468,164)}

def rgb(c):return ((c>>11)*255//31,((c>>5)&63)*255//63,(c&31)*255//31)

def geometry(k):
    # 原生w/h不可在运行中修改；钢琴和鼓垫使用各自的固定尺寸控件。
    if k in WHITES:return (32+WHITES.index(k)*107,302,103,190)
    left=WHITES.index(k-1)
    return (min(32+(left+1)*107-33,930),302,62,116)

def drum_geometry(k):return (32+(k%4)*244,278+(k//4)*58,228,50)
def resting(k):return ('sharp','white') if k in SHARPS else ('key','ink')

def background(path):
    scale=2
    im=Image.new('RGB',(1024*scale,600*scale),rgb(C['page']))
    d=ImageDraw.Draw(im)
    def rect(box,fill,outline=None,radius=0,width=1):
        box=tuple(int(v*scale) for v in box)
        args={'fill':rgb(C[fill]),'outline':rgb(C[outline]) if outline else None,'width':width*scale}
        if radius:d.rounded_rectangle(box,radius*scale,**args)
        else:d.rectangle(box,**args)
    def line(points,fill,width=2):d.line([(int(x*scale),int(y*scale)) for x,y in points],fill=rgb(C[fill]),width=width*scale)
    def text(x,y,value,size=18,fill='muted',bold=False):
        font=ImageFont.truetype('C:/Windows/Fonts/msyhbd.ttc' if bold else 'C:/Windows/Fonts/msyh.ttc',size*scale)
        d.text((x*scale,y*scale),value,font=font,fill=rgb(C[fill]))
    for i,h in enumerate((18,34,25,44)):rect((32+i*9,58-h,36+i*9,58),'cyan',radius=2)
    line([(32,78),(992,78)],'border',1)
    text(32,103,'选择演奏模式',25,'white',True)
    text(760,114,'16 键 / 实时演奏',16)
    for m,title,subtitle,tint in [(1,'鼓点模式','16 个鼓垫，四轨节奏编排','amber'),
        (2,'弹琴模式','实时演奏，自动识别当前和弦','cyan'),
        (3,'混音模式','琴音、鼓点与 MIDI 同时播放','purple'),
        (4,'实体键设置','逐键选声音，独立保存三套配置','cyan')]:
        x,y,w,h=MENU_RECTS[m]
        rect((x,y+5,x+w,y+h+5),'page',radius=18)
        rect((x,y,x+w,y+h),'panel','border',18)
        rect((x+1,y+26,x+5,y+h-26),tint,radius=2)
        text(x+24,y+16,f'0{m}  /  '+('个性设置' if m==4 else '实时演奏'),14,tint,True)
        text(x+24,y+50,title,32,'white',True)
        text(x+24,y+108,subtitle,16)
        ix=x+w-119;iy=y+39
        if m==1:
            for row in range(3):
                for col in range(3):rect((ix+col*27,iy+row*27,ix+col*27+21,iy+row*27+21),tint if (row,col) in ((0,0),(1,2),(2,1)) else 'border',radius=4)
        elif m==2:
            for key in range(5):rect((ix+key*18,iy+9,ix+key*18+15,iy+81),'key',radius=3)
            for key in (0,1,3):rect((ix+key*18+11,iy+9,ix+key*18+23,iy+53),'page',radius=2)
        elif m==3:
            for col,v in enumerate((27,53,37)):
                xx=ix+col*29+8;line([(xx,iy),(xx,iy+81)],'border',4)
                rect((xx-8,iy+v,xx+8,iy+v+12),tint,radius=4)
        else:
            for row,col in ((0,0),(1,1),(0,1),(1,0)):
                xx=ix+col*45;yy=iy+row*45
                d.ellipse((xx*scale,yy*scale,(xx+32)*scale,(yy+32)*scale),outline=rgb(C['border']),width=3*scale)
                line([(xx+16,yy+16),(xx+24,yy+7)],tint,3)
    line([(32,535),(992,535)],'border',1)
    im.resize((1024,600),Image.Resampling.LANCZOS).save(path)
