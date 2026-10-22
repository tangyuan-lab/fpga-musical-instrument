"""按官方混合中英子集头与码表顺序生成ZI V6；ASCII复用旧字形，新增界面中文。"""
from pathlib import Path
import hashlib,json,re,struct
from PIL import Image,ImageDraw,ImageFont
from build_dashboard_font import compress_glyph

def generate_font(spec,out):
    from usarthmi.zi_font import ZiFont
    from usarthmi.hmi_cfs import parse_native_cfs_table
    old=ZiFont(Path(__file__).parent/'v2/dashboard_ascii_32.zi')
    factory=(Path(__file__).parent.parent/'vendor/TJC1060X570_factory.HMI').read_bytes()
    reference=next(record for record in parse_native_cfs_table(factory).records if record.name=='7.zi')
    reference_raw=factory[reference.data_offset:reference.data_offset+reference.length]
    reference_font=ZiFont.from_bytes(reference_raw)
    # 官方混合中英字库为子集模式2，并按码表中小端uint16数值升序查找。
    # ASCII专用模板的模式0不能直接扩展中文；按GB2312字节顺序排序也会命中错误字形。
    assert reference_font.version==6 and reference_font.codepage==2 and reference_font.mode==2
    assert list(reference_font.glyphs)==sorted(reference_font.glyphs)
    assert any(cp>255 for cp in reference_font.glyphs)
    assert int.from_bytes(reference_raw[0x24:0x28],'little')==reference_font.character_count
    texts=[]
    for widget in spec['widgets']:
        texts.append(widget['fields'].get('txt',''))
        for lines in widget['events'].values():
            for line in lines:texts.extend(re.findall(r'"([^"\n]*)"',line))
    characters=sorted(set(''.join(texts)+spec.get('extra_characters','')))
    if spec.get('full_gb2312'):
        for high in range(0xa1,0xf8):
            for low in range(0xa1,0xff):
                try:characters.append(bytes((high,low)).decode('gb2312'))
                except UnicodeDecodeError:pass
        characters=sorted(set(characters))
    glyphs={cp:(g.width,g.kerning_left,g.kerning_right,g.data) for cp,g in old.glyphs.items()}
    source=Path('C:/Windows/Fonts/msyh.ttc');font=ImageFont.truetype(str(source),28)
    masks={}
    for char in characters:
        if ord(char)<128:continue
        encoded=char.encode('gb2312');cp=int.from_bytes(encoded,'little')
        box=font.getbbox(char,anchor='lt');w,h=box[2]-box[0],box[3]-box[1]
        mask=Image.new('L',(32,32),0)
        ImageDraw.Draw(mask).text(((32-w)//2,(32-h)//2),char,font=font,fill=255,anchor='lt')
        shades=[min(7,(int(p)*7+127)//255) for p in mask.getdata()]
        if not any(shades) and not char.isspace():raise ValueError(f'字形为空：{char}')
        glyphs[cp]=(32,0,0,compress_glyph(shades))
        masks[cp]=bytes(0 if p==0 else 255 if p==7 else p*36 for p in shades)
    ordered=sorted(glyphs)
    name=b'Workstation_ZH32';descriptor=name+b'gb2312';count=len(ordered)
    header=bytearray(reference_raw[:44]);header[0x07]=32
    header[0x11]=len(descriptor);header[0x20]=len(name)
    struct.pack_into('<I',header,0x0c,count);struct.pack_into('<I',header,0x24,count)
    struct.pack_into('<I',header,0x14,len(descriptor)+count*10+sum(len(glyphs[cp][3]) for cp in ordered))
    table=bytearray();offset=count*10
    for cp in ordered:
        width,left,right,data=glyphs[cp]
        table.extend(struct.pack('<HBBB',cp,width,left,right)+offset.to_bytes(3,'little')+len(data).to_bytes(2,'little'))
        offset+=len(data)
    raw=bytes(header)+descriptor+bytes(table)+b''.join(glyphs[cp][3] for cp in ordered)
    actual=ZiFont.from_bytes(raw)
    assert actual.version==6 and actual.mode==2 and actual.character_count==count and actual.measure_text('4095')==(64,32)
    assert list(actual.glyphs)==sorted(actual.glyphs)
    for char in characters:
        assert actual._map_char_to_codepoint(char) in actual.glyphs,f'字库缺字：{char}'
    for cp,mask in masks.items():assert actual._glyph_mask(cp).tobytes()==mask,'中文字形回读不一致'
    out.write_bytes(raw)
    metadata={'format':'ZI V6 GB2312 subset','charset_mode':2,'index_order':'ascending little-endian uint16',
              'official_font_reference':'TJC1060X570_factory.HMI:7.zi','official_font_reference_sha256':hashlib.sha256(reference_raw).hexdigest(),
              'glyphs':count,'chinese_glyphs':len(masks),'sha256':hashlib.sha256(raw).hexdigest(),
              'chinese_font':str(source),'size_px':28,'cell_px':[32,32],'glyph_mask_roundtrip_equal':True,'official_compile_status':'pending'}
    metadata['coverage']='GB2312' if spec.get('full_gb2312') else 'interface subset'
    out.with_suffix('.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    return metadata
