"""用实际 MuseScore CLI 做 MusicXML 往返；比较有声事件，不把排版成功当音乐正确。"""
from pathlib import Path
from collections import Counter
from fractions import Fraction
import argparse,hashlib,json,os,subprocess,sys
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT))
from host_app.music_project import Song,Note,MusicProject,import_musicxml
from host_app.score_document import from_song,ensure_document

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--project',type=Path);args=parser.parse_args()
    manifest=json.loads((ROOT/'build/tools/music/manifest.json').read_text(encoding='utf-8'))
    executable=ROOT/manifest['musescore'];folder=ROOT/('build/tests/musescore_nocturne' if args.project else 'build/tests/musescore_roundtrip');folder.mkdir(parents=True,exist_ok=True)
    song=Song(name='九连音与跨小节延音',ppqn=1440,tempos=[[0,400000],[5760,500000]],
              notes=[Note(i*160,(i+1)*160,60+i) for i in range(9)]+[Note(1440,7200,69),Note(0,2880,48,part=2)]+[Note(0,1440,60+i,velocity=70+i*5,part=1) for i in range(5)])
    project_digest=hashlib.sha256(args.project.read_bytes()).hexdigest() if args.project else None
    if args.project:song=MusicProject.load(args.project).songs[0]
    original_notes=[(n.note_id,n.start,n.end,n.pitch,n.velocity,n.part,n.uncertain) for n in song.notes]
    document=ensure_document(song)
    source=folder/'source.musicxml';target=folder/'returned.musicxml';source.write_text(document.current_xml,encoding='utf-8')
    provenance=dict(notation_schema=document.notation_schema,reconstructed=document.reconstructed,
                    source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
                    source_project=str(args.project.resolve()) if args.project else None,source_project_sha256=project_digest)
    environment=os.environ.copy()
    # 官方Windows包只带qwindows平台插件；转换模式本身不显示编辑窗口。
    environment['QT_QPA_PLATFORM']='windows' if os.name=='nt' else 'offscreen'
    target.unlink(missing_ok=True)
    try:
        with (folder/'musescore.log').open('w',encoding='utf-8') as output:
            # 4.7.5源码已移除旧版-s选项；Windows未知选项弹框会使无界面转换一直等待。
            result=subprocess.run([str(executable),'-o',str(target),str(source)],cwd=ROOT,env=environment,
                                  stdout=output,stderr=subprocess.STDOUT,timeout=120,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
    except subprocess.TimeoutExpired:
        report=dict(passed=False,status='runtime_timeout',boundary='官方可执行文件120秒未完成导出；不视为校谱往返通过',**provenance)
        (folder/'result.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
        print(report);return 1
    if result.returncode or not target.is_file():
        report=dict(passed=False,status='export_failed',returncode=result.returncode,output_exists=target.is_file(),**provenance)
        (folder/'result.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
        print(report);return 1
    actual=import_musicxml(target)
    def performance(s):return Counter((Fraction(n.start,s.ppqn),Fraction(n.end,s.ppqn),n.pitch,n.velocity,n.part) for n in s.notes)
    def tempos(s):return [(str(Fraction(t,s.ppqn)),round(v)) for t,v in s.tempos]
    expected,received=performance(song),performance(actual)
    unchanged_notes=original_notes==[(n.note_id,n.start,n.end,n.pitch,n.velocity,n.part,n.uncertain) for n in song.notes]
    unchanged_project=not args.project or project_digest==hashlib.sha256(args.project.read_bytes()).hexdigest()
    report=dict(passed=expected==received and tempos(song)==tempos(actual) and not actual.score_document.errors and unchanged_notes and unchanged_project,
                input_notes=len(song.notes),returned_notes=len(actual.notes),input_ppqn=song.ppqn,returned_ppqn=actual.ppqn,
                added=[str(x) for x in (received-expected).elements()],removed=[str(x) for x in (expected-received).elements()],
                expected_tempos=tempos(song),returned_tempos=tempos(actual),issues=actual.issues,
                input_notes_unchanged=unchanged_notes,source_project_unchanged=unchanged_project,
                input_uncertain_notes=sum(n.uncertain for n in song.notes),
                returned_sha256=hashlib.sha256(target.read_bytes()).hexdigest(),**provenance,
                boundary=('验证指定工程演奏时间线的精确起止、音高、力度、逻辑声部及速度表经实际MuseScore往返；不验证PDF逐音识别正确，未确认音符仍需人工校正'
                          if args.project else '验证此构造样谱的九连音、延音、休止、速度及多谱表往返；不代表任意PDF识别正确'))
    (folder/'result.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({key:value if key not in ('added','removed') else value[:8] for key,value in report.items()},ensure_ascii=False,indent=2));return 0 if report['passed'] else 1

if __name__=='__main__':raise SystemExit(main())
