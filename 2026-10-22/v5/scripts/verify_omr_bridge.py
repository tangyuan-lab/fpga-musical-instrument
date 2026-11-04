"""人工确定的kern夹具验证桥接；不将转换成功视为PDF识别正确。"""
from pathlib import Path
from fractions import Fraction as F
import json,sys
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT))


def main():
    from host_app.omr_bridge import convert_kern
    from host_app.score_document import ScoreDocument,xml_root
    folder=ROOT/'build/tests/omr_bridge';folder.mkdir(parents=True,exist_ok=True)
    lines=['**kern\t**kern','*staff2\t*staff1','*clefF4\t*clefG2','*k[b-e-]\t*k[b-e-]','*M3/4\t*M3/4','*MM158\t*MM158','=1\t=1']
    lines+=['2.CC\t18cc']+['.\t18cc']*8+['.\t4r','=2\t=2']
    lines+=['2.CC\t20dd']+['.\t20dd']*4+['.\t2r','=3\t=3']
    lines+=['[2.CC\t24ee-','.\t9ff','.\t72gg','.\t3r','.\t4r','=4\t=4','*\t*clefF4','2.CC]\t4a','.\t4b-','.\t4c','*-\t*-']
    source=folder/'known.krn';source.write_text('\n'.join(lines)+'\n',encoding='utf-8')
    output=convert_kern(source,folder);document=ScoreDocument.from_file(output)
    song=document.compile('桥接夹具',uncertain=True,device_constraints=False)
    events=[(F(n.start,song.ppqn),F(n.end-n.start,song.ppqn),n.pitch) for n in song.notes]
    expected=[(F(i*2,9),F(2,9),72) for i in range(9)]+[(F(3)+F(i,5),F(1,5),74) for i in range(5)]
    expected += [(F(6),F(1,6),75),(F(37,6),F(4,9),77),(F(119,18),F(1,18),79)]
    expected += [(F(i),F(1),p) for i,p in ((9,69),(10,70),(11,60))]
    expected += [(F(0),F(3),36),(F(3),F(3),36),(F(6),F(6),36)]
    root=xml_root(document.current_xml)
    report=dict(passed=sorted(events)==sorted(expected),expected_notes=len(expected),actual_notes=len(events),
        errors=document.errors,missing=[list(map(str,e)) for e in expected if e not in events],extra=[list(map(str,e)) for e in events if e not in expected],
        fifths=[n.text for n in root.iter('fifths')],clefs=[n.findtext('sign') for n in root.iter('clef')],
        boundary='Synthetic kern bridge test only; no PDF inference or recognition accuracy claim',
        notation_limit='Exact kern durations do not uniquely specify original printed tuplet groups; source review remains required')
    report['passed'] &= all(n.text=='-2' for n in root.iter('fifths')) and report['clefs'].count('F')>=2 and not document.errors
    (folder/'verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(report,ensure_ascii=True));return 0 if report['passed'] else 1

if __name__=='__main__':raise SystemExit(main())
