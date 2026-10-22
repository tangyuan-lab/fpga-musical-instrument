"""印刷谱导入：原谱始终保留，光学识别输出必须经过校正后再下发。"""
from pathlib import Path
import hashlib,logging,os,re,shutil,subprocess,tempfile,uuid,zipfile,json,time
from .music_project import Song,Note,Section,MusicProject,import_musicxml

def parse_jianpu(text,root=60,ppqn=480,numerator=4):
    """可校正文本语法：1..7、0休止、'高八度、,低八度、/2八分、.附点、|小节。"""
    song=Song(name='简谱',ppqn=ppqn,numerator=numerator);tick=0;bar_start=0;scale=(0,2,4,5,7,9,11);sounding=None
    tokens=re.findall(r"\||[0-7](?:[#b])?[' ,]*(?:/\d+)?\.?|-",text.replace('，',','))
    cleaned=re.sub(r"\||[0-7](?:[#b])?[' ,]*(?:/\d+)?\.?|-",'',text.replace('，',','))
    if cleaned.strip():raise ValueError('简谱含无法识别的字符：'+cleaned.strip()[:50])
    for token in tokens:
        token=token.replace(' ','')
        if token=='|':
            if tick-bar_start!=numerator*ppqn:song.issues.append(f'第{bar_start//(ppqn*numerator)+1}小节拍数不符')
            bar_start=tick;continue
        if token=='-':
            # 延音线延长紧邻的音符或休止，不能跨过休止去拉长更早的音符。
            if sounding is not None:sounding.end+=ppqn
            tick+=ppqn;continue
        m=re.fullmatch(r"([0-7])([#b]?)([',]*)(?:/(\d+))?(\.)?",token)
        if not m:raise ValueError('简谱记号无效：'+token)
        duration=ppqn//int(m[4] or 1)
        if duration<1:raise ValueError('时值小于1tick')
        if m[5]:duration+=duration//2
        if m[1]!='0':
            pitch=root+scale[int(m[1])-1]+12*(m[3].count("'")-m[3].count(','))+({'#':1,'b':-1}.get(m[2],0))
            sounding=Note(tick,tick+duration,pitch);song.notes.append(sounding)
        else:sounding=None
        tick+=duration
    song.sections=[Section(end=max(tick,ppqn*numerator))];return song

def recognize_staff(path,audiveris=None,cache_dir=None,force=False,engine='audiveris',cancel=None,pages=None):
    """默认保留官方原始 MusicXML；矢量启发式仅作为显式选用的诊断候选。"""
    vector_issue=None
    if cancel is not None and cancel.is_set():raise InterruptedError('识谱已取消')
    if engine=='vector':
        from .vector_score import recognize_vector_pdf
        native=recognize_vector_pdf(path)
        if native is None:raise ValueError('该谱面不支持矢量诊断，请使用光学识谱')
        for note in native.notes:note.uncertain=True
        native.issues.append('矢量诊断候选，未证明记谱准确；需对照原谱逐小节审核')
        return native
    if engine!='audiveris':
        from .omr_providers import recognize_candidate
        return recognize_candidate(path,engine,cache_dir,force,cancel,pages)
    candidates=[audiveris,os.environ.get('AUDIVERIS_EXE'),shutil.which('Audiveris'),
        r'C:\Program Files\Audiveris\Audiveris.exe',r'C:\Program Files\Audiveris\bin\Audiveris.bat']
    candidates.extend(sorted((Path(__file__).resolve().parents[1]/'build/tools/audiveris/runtime').rglob('Audiveris.exe')))
    exe=next((str(p) for p in candidates if p and Path(p).is_file()),None)
    if not exe:raise RuntimeError('未找到Audiveris。安装官方Audiveris后设置AUDIVERIS_EXE；原谱可先浏览和手动校正。')
    source=Path(path).resolve();fingerprint=hashlib.sha256(source.read_bytes())
    # 缓存官方原始MusicXML：谱面或识谱器改变才重跑光学识别；解析器更新会重新导入原始数据。
    fingerprint.update(b'Audiveris-batch-transcribe-export-v1')
    if pages:fingerprint.update(json.dumps(sorted(pages)).encode())
    dependencies=[Path(exe)]
    dependencies.extend(sorted((Path(exe).parent/'app').glob('*audiveris*.jar')))
    for dependency in dependencies:fingerprint.update(hashlib.sha256(dependency.read_bytes()).digest())
    cache_root=Path(cache_dir or Path(__file__).resolve().parents[1]/'build/cache/staff_omr')
    entry=next((cache_root/(fingerprint.hexdigest()+ext) for ext in ('.mxl','.musicxml','.xml') if (cache_root/(fingerprint.hexdigest()+ext)).is_file()),None)
    def prepare_song(xml):
        song=import_musicxml(xml,preserve_tracks=True);song.name=source.stem;song.source_files=[str(source)]
        for note in song.notes:note.uncertain=True
        if vector_issue:song.issues.append(vector_issue)
        song.issues.append('光学识谱结果待校正确认')
        song.recognition=dict(engine='audiveris',fingerprint=fingerprint.hexdigest(),raw_path=str(xml),cached=True,pages=pages or [])
        return song
    if entry is not None and not force:
        try:
            return prepare_song(entry)
        except Exception:logging.warning('识谱缓存读取失败，将重新识别',exc_info=True)
    cache_root.mkdir(parents=True,exist_ok=True)
    d=cache_root/fingerprint.hexdigest()/('run_'+time.strftime('%Y%m%d_%H%M%S')+'_'+uuid.uuid4().hex[:6]);d.mkdir(parents=True)
    command=[exe,'-batch','-save','-transcribe','-export','-output',str(d)]
    if pages:command+=['-sheets',*[str(n) for n in sorted(pages)]]
    command+=['--',str(source)]
    record=dict(engine='audiveris',source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),fingerprint=fingerprint.hexdigest(),command=command,status='running',pages=pages or [])
    (d/'manifest.json').write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding='utf-8')
    try:
        from .process_job import run_tool
        record.update(run_tool(command,d,cancel=cancel));record['status']='finished'
        candidates=list(Path(d).rglob('*.mxl'))+list(Path(d).rglob('*.musicxml'))+list(Path(d).rglob('*.xml'))
        candidates=[p for p in candidates if p.name not in ('container.xml','book.xml') and p.suffix=='.mxl' or p.name not in ('container.xml','book.xml') and p.read_text(encoding='utf-8',errors='ignore').find('score-partwise')>=0]
        if not candidates:raise RuntimeError('Audiveris未输出曲谱，请查看：'+str(d/'process.log'))
        song=prepare_song(candidates[0])
        try:
            cache_root.mkdir(parents=True,exist_ok=True)
            temporary=cache_root/(uuid.uuid4().hex+candidates[0].suffix)
            shutil.copyfile(candidates[0],temporary);temporary.replace(cache_root/(fingerprint.hexdigest()+candidates[0].suffix))
        except OSError:logging.warning('识谱结果未能缓存；本次结果仍可编辑',exc_info=True)
        song.recognition.update(cached=False,run_dir=str(d));return song
    except BaseException as exc:
        record.update(status='cancelled' if isinstance(exc,InterruptedError) else 'failed',error=str(exc));raise
    finally:
        (d/'manifest.json').write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding='utf-8')

def page_image(path,page=0,dpi=180):
    from PIL import Image
    path=Path(path)
    if path.suffix.lower()=='.pdf':
        import pymupdf
        with pymupdf.open(path) as document:
            pix=document[page].get_pixmap(matrix=pymupdf.Matrix(dpi/72,dpi/72),alpha=False)
            return Image.frombytes('RGB',(pix.width,pix.height),pix.samples)
    return Image.open(path).convert('RGB')

def recognize_jianpu(path,root=60,page=0):
    """简谱数字模板识别＋点/减时线几何分析；低分与节奏疑点始终标记待确认。"""
    import cv2,numpy as np
    from PIL import Image,ImageDraw,ImageFont
    image=page_image(path,page);gray=np.asarray(image.convert('L'))
    binary=cv2.adaptiveThreshold(gray,255,cv2.ADAPTIVE_THRESH_GAUSSIAN_C,cv2.THRESH_BINARY_INV,31,12)
    count,labels,stats,centers=cv2.connectedComponentsWithStats(binary)
    components=[tuple(map(int,r)) for r in stats[1:] if r[4]>=3]
    candidates=[r for r in components if 10<=r[3]<=120 and 0.18<=r[2]/r[3]<=1.1 and r[4]>=20]
    if not candidates:raise ValueError('未检测到清晰简谱数字；可裁剪谱行或使用简谱文本录入')
    heights=[r[3] for r in candidates];median=float(np.median(heights));candidates=[r for r in candidates if .55*median<=r[3]<=1.7*median]
    templates=[]
    for font_path in [r'C:\Windows\Fonts\arial.ttf',r'C:\Windows\Fonts\times.ttf',r'C:\Windows\Fonts\simsun.ttc']:
        if not Path(font_path).exists():continue
        font=ImageFont.truetype(font_path,48)
        for digit in '01234567':
            tile=Image.new('L',(80,80),0);ImageDraw.Draw(tile).text((8,0),digit,font=font,fill=255)
            box=tile.getbbox();tile=tile.crop(box);templates.append((digit,cv2.resize(np.asarray(tile),(24,40))/255))
    rows=[]
    for rect in sorted(candidates,key=lambda r:(r[1]+r[3]/2,r[0])):
        x,y,w,h,area=rect;cy=y+h/2
        row=next((r for r in rows if abs(r['y']-cy)<median*.65),None)
        if row is None:row={'y':cy,'items':[]};rows.append(row)
        sample=cv2.resize(binary[y:y+h,x:x+w],(24,40))/255
        scored=[(float(np.mean((sample-t)**2)),digit) for digit,t in templates];score,digit=min(scored)
        if score<.35:row['items'].append((rect,digit,score))
    song=Song(name=Path(path).stem,source_files=[str(Path(path).resolve())]);tick=0;scale=[0,2,4,5,7,9,11]
    for row in sorted(rows,key=lambda r:r['y']):
        if len(row['items'])<3:continue
        for (x,y,w,h,area),digit,score in sorted(row['items'],key=lambda n:n[0][0]):
            dots_above=dots_below=lines=0
            for sx,sy,sw,sh,sa in components:
                if abs(sx+sw/2-(x+w/2))<w*.65:
                    if sw<h*.35 and sh<h*.35:
                        if y-h<sy<y: dots_above+=1
                        elif y+h<sy<y+2*h:dots_below+=1
                    if sw>=w*.7 and sh<h*.2 and y+h<=sy<y+1.7*h:lines+=1
            duration=max(1,song.ppqn>>min(lines,3))
            if digit!='0':song.notes.append(Note(tick,tick+duration,root+scale[int(digit)-1]+12*(min(dots_above,2)-min(dots_below,2)),
                page=page,box=[x,y,w,h],uncertain=True))
            tick+=duration
    if not song.notes:raise ValueError('识别不到有效谱行，请裁剪谱面或手动录入')
    song.sections=[Section(end=max(tick,1920))];song.issues=['简谱光学识别：请确认调号、拍号、时值、延音及小节边界']
    return song

def download_score(url,destination):
    from urllib.request import Request,urlopen
    from urllib.parse import urlparse
    parsed=urlparse(url)
    if parsed.scheme!='https':raise ValueError('在线曲谱需要HTTPS直链')
    target=Path(destination);total=0
    with urlopen(Request(url,headers={'User-Agent':'FPGA-Music-Workstation/2'}),timeout=30) as response:
        with target.open('wb') as out:
            while block:=response.read(65536):
                total+=len(block)
                if total>30_000_000:raise ValueError('曲谱文件超过30MB')
                out.write(block)
    return target
