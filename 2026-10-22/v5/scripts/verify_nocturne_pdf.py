"""用人工读取的原谱锚点检验本次修正；不以音符数量或解析成功代替音乐准确性。"""
from pathlib import Path
from fractions import Fraction
import copy
import json
import sys

ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT))
from host_app.vector_score import recognize_vector_pdf
from host_app.music_project import MusicProject
from host_app.preview_audio import render_preview,TempoMap




def main():
    import argparse
    parser=argparse.ArgumentParser();parser.add_argument("source",type=Path,help="自行提供的Nocturne原PDF");args=parser.parse_args()
    source=args.source.resolve()
    report={};song=recognize_vector_pdf(source,report);checks=[]
    assert report['pages']==4 and report['bars']==102
    assert report['heads']==1775 and report['heads']-report['ties']==len(song.notes)
    checks.append('four_pages_102_bars_all_1775_heads_accounted_for')
    assert abs(song.tempos[0][1]-60_000_000/158)<.5
    checks.append('printed_quarter_note_tempo_158')
    # 直接读第一行五线谱：两降号；E♭5/C4 跨小节延音；B3临时还原跨小节保留。
    expected=[(0,Fraction(20,3),75),(1,Fraction(20,3),60),
              (Fraction(11,2),Fraction(13,2),59),
              (Fraction(13,2),7,48),(Fraction(13,2),7,60),(7,10,48),(10,12,50)]
    for start,end,pitch in expected:
        assert any(n.pitch==pitch and n.start==start*song.ppqn and n.end==end*song.ppqn for n in song.notes),(start,end,pitch)
    checks.append('manual_first_system_pitch_ties_and_inline_bass_clef_anchors')
    # 第3小节是9:8连音；包括附点32分和64分，不能从第3拍才开始或拉长小节。
    actual=sorted(Fraction(e['start'])-6 for e in report['events'] if e['bar']==3 and e['staff']==0)
    assert actual==[Fraction(x) for x in ['0','1/6','11/18','2/3','1','4/3','5/3','2','7/3','8/3']],actual
    checks.append('bar3_nonuplet_exact_rational_onsets')
    # 另对照两个省略休止声部：第29小节F#4在第2拍进入；第46小节D4从第2拍后半进入。
    for bar,offset,duration,pitch in [(29,1,2,66),(46,Fraction(3,2),Fraction(3,2),62)]:
        start=((bar-1)*3+offset)*song.ppqn;end=start+duration*song.ppqn
        # 谱面时值针对这个小节的音头；后接延音时，最终播放音符允许延长到后续小节。
        assert any(e['bar']==bar and pitch in e['pitches'] and Fraction(e['start'])*song.ppqn==start and Fraction(e['end'])*song.ppqn==end for e in report['events']),(bar,pitch)
        assert any(n.pitch==pitch and n.start==start and n.end>=end for n in song.notes),(bar,pitch)
    checks.append('manual_bar29_and_bar46_implicit_rest_entry_points')
    confirmed=copy.deepcopy(song)
    for n in confirmed.notes:n.uncertain=False
    confirmed.validate();checks.append('device_structure_checked_on_copy_only')
    target=ROOT/'build/imported_scores/Nocturne_D_Minor_矢量校正版.fpgamusic'
    song.issues=[i for i in song.issues if not i.startswith('省略休止定位需复核')]
    song.issues.append('第29、46小节省略休止起点已人工对照；其余音符仍保留待确认')
    MusicProject(name='Nocturne PDF 矢量校正版',songs=[song]).save(target)
    result=render_preview(song,[])
    report.update(checks=checks,passed=True,uncertain_after=sum(n.uncertain for n in song.notes),
                  project=str(target),preview=str(result.path),duration_seconds=TempoMap(song).to_seconds(song.duration),
                  limit='人工锚点覆盖开头4小节及29/46小节省略休止入口；不能宣称整曲逐音人工确认')
    (ROOT/'build/tests/nocturne_audit/native_audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({k:v for k,v in report.items() if k not in ('events','tuplets')},ensure_ascii=False,indent=2))


if __name__=='__main__':main()
