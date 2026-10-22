"""生成联动验收工程：只生成曲谱和单周期波表，演奏及包络由FPGA执行。"""
from pathlib import Path
import math,sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from host_app.music_project import MusicProject,Song,Section,Note,Patch


def create():
    patches=[Patch(name='明亮拨弦',resource_id='bbfc3f21-4c1b-4c83-b7c7-000000000001',
        waveform=[round(24000*(math.sin(2*math.pi*i/256)+.25*math.sin(4*math.pi*i/256))) for i in range(256)],
        attack=384,decay=12,sustain=768,release=64),
        Patch(name='柔和管音',resource_id='bbfc3f21-4c1b-4c83-b7c7-000000000002',
        waveform=[round(24000*math.sin(2*math.pi*i/256)) for i in range(256)],
        attack=32,decay=8,sustain=3400,release=24)]
    sections=[Section(name='拨弦段',start=0,end=1920,timbres=[2,0,1,0],live_timbre=2),
        Section(name='管音段',start=1920,end=3840,timbres=[3,1,0,0],live_timbre=3)]
    scale=Song(name='十六键与分段音色',resource_id='bbfc3f21-4c1b-4c83-b7c7-000000000003',
        notes=[Note(i*240,i*240+230,60+i) for i in range(16)],sections=sections)
    ensemble=Song(name='四声部配器演示',resource_id='bbfc3f21-4c1b-4c83-b7c7-000000000004',
        sections=[Section(name='主歌',start=0,end=1920,timbres=[2,3,1,0],live_timbre=2),
                  Section(name='副歌',start=1920,end=3840,timbres=[3,2,0,0],live_timbre=3)])
    for index,chord in enumerate(((60,64,67),(57,60,64),(53,57,60),(55,59,62))):
        start=index*960
        ensemble.notes.append(Note(start,start+900,chord[-1]+12,90,0))
        ensemble.notes.extend(Note(start,start+900,n,68,1) for n in chord)
        ensemble.notes.append(Note(start,start+900,chord[0]-12,84,2))
        ensemble.notes.extend((Note(start,start+60,36,96,3),Note(start+480,start+540,38,80,3)))
    project=MusicProject(name='上下位机联动验收',songs=[scale,ensemble],patches=patches)
    project.validate();return project


if __name__=='__main__':
    output=ROOT/'examples/workstation_v2_demo.fpgamusic';output.parent.mkdir(parents=True,exist_ok=True)
    project=create();project.save(output)
    print(f'PASS demo: {len(project.songs)} songs, {len(project.patches)} custom patches; {output}')
