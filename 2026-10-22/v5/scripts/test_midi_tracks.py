"""把真实源轨编译结果交给RTL字节解析器；旧工作位流与主RTL不变。"""
from pathlib import Path
import io,json,os,shutil,subprocess,sys,uuid
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import mido
from host_app.music_project import Song,Note,SourceTrack,Section
from host_app.track_compiler import compile_tracks

ROOT=Path(__file__).resolve().parents[1]


def raw(messages):
    song=mido.MidiFile(type=0,ticks_per_beat=480);song.tracks.append(mido.MidiTrack(messages))
    out=io.BytesIO();song.save(file=out);return out.getvalue()


def expected(data):
    tick=0;notes=[];held={};tempos={0:500000}
    song=mido.MidiFile(file=io.BytesIO(data))
    for message in song.tracks[0]:
        tick+=message.time
        if message.type=='set_tempo':tempos[tick]=message.tempo
        elif message.type=='note_on' and message.velocity:
            held[message.channel,message.note]=len(notes)
            notes.append([tick,None,message.channel,message.note,message.velocity])
        elif message.type in ('note_on','note_off'):
            notes[held.pop((message.channel,message.note))][1]=tick
    if held:raise AssertionError('unpaired expected note')
    return notes,sorted(tempos.items()),tick,song.ticks_per_beat


def main():
    folder=ROOT/'build/tests/midi_tracks';folder.mkdir(parents=True,exist_ok=True)
    exe=folder/'parser.vvp'
    tools=Path(__import__('os').environ.get('FPGA_SIM_BIN','C:/msys64/ucrt64/bin'));env=os.environ.copy();env['PATH']=str(tools)+os.pathsep+env['PATH']
    iverilog=shutil.which('iverilog',path=env['PATH']);vvp=shutil.which('vvp',path=env['PATH'])
    if not iverilog or not vvp:raise RuntimeError('未找到iverilog/vvp，请检查工具安装')
    subprocess.run([iverilog,'-g2012','-s','tb_midi_tracks_parser','-o',str(exe),
                    'experiments/workstation_tracks/midi_tracks_parser.sv','tests/tb_midi_tracks_parser.sv'],cwd=ROOT,env=env,check=True)
    tracks=[SourceTrack(str(uuid.uuid4()),f'乐器{i}',device_part=i%4) for i in range(14)]
    song=Song(source_tracks=tracks,notes=[Note(i*10,480+i*10,60+i,velocity=80+i,track_id=t.track_id) for i,t in enumerate(tracks)],sections=[Section(end=1920)])
    song.notes.extend([Note(100,650,60,101,track_id=tracks[0].track_id),Note(300,700,60,72,track_id=tracks[0].track_id)])
    compiled=compile_tracks(song)
    cases=[('sixteen_lanes_unison',compiled.midi,0)]
    base=[mido.Message('note_on',channel=15,note=60,velocity=100),mido.Message('note_on',channel=15,note=64,velocity=87),
          mido.Message('note_on',channel=15,note=60,velocity=0,time=480),mido.Message('note_on',channel=15,note=64,velocity=0)]
    cases.append(('running_status_zero_off',raw(base),0))
    # 恰好64KiB，证明17位文件末尾不会回卷。
    length=65400
    data=raw([mido.MetaMessage('text',text='x'*length)]+base)
    length+=65536-len(data);data=raw([mido.MetaMessage('text',text='x'*length)]+base)
    if len(data)!=65536:raise AssertionError('64KiB fixture')
    cases.append(('exact_64k',data,0))
    tempos=[mido.MetaMessage('set_tempo',tempo=500000-i*1000,time=0 if i==0 else 10) for i in range(64)]
    cases.append(('sixty_four_tempos',raw(tempos+base),0))
    many=[]
    for i in range(2048):
        many.extend([mido.Message('note_on',channel=i%16,note=60,velocity=100),mido.Message('note_off',channel=i%16,note=60,time=1)])
    cases.append(('max_2048_events',raw(many),0))
    cases.append(('event_overflow',raw(many+base),8))
    cases.extend([
        ('tempo_overflow',raw(tempos+[mido.MetaMessage('set_tempo',tempo=400000,time=10)]+base),10),
        ('duplicate_on',raw([base[0],base[0]]),7),
        ('unmatched_off',raw([base[2]]),7),
        ('zero_duration',raw([base[0],base[2].copy(time=0)]),7),
        ('missing_off',raw([base[0]]),9),
        ('unsupported_control',raw([mido.Message('control_change',control=64,value=127)]),6),
        ('zero_tempo',raw([mido.MetaMessage('set_tempo',tempo=0)]+base),10),
    ])
    results=[]
    for name,data,error in cases:
        path=folder/(name+'.hex');path.write_text(''.join(f'{b:02x}\n' for b in data),encoding='ascii')
        args=[vvp,str(exe),f'+HEX={path.as_posix()}',f'+SIZE={len(data)}',f'+ERROR={error}']
        if not error:
            notes,tempo_map,duration,ppqn=expected(data)
            events=folder/(name+'.events');tempos_path=folder/(name+'.tempos')
            events.write_text(''.join(f'{(a<<51)|(b<<19)|(c<<15)|(n<<8)|v:021x}\n' for a,b,c,n,v in notes),encoding='ascii')
            tempos_path.write_text(''.join(f'{(tick<<24)|us:014x}\n' for tick,us in tempo_map),encoding='ascii')
            args.extend([f'+EXPECTED={events.as_posix()}',f'+COUNT={len(notes)}',f'+TEMPOS={tempos_path.as_posix()}',
                         f'+TEMPO_COUNT={len(tempo_map)}',f'+DURATION={duration}',f'+PPQN={ppqn}'])
        run=subprocess.run(args,cwd=ROOT,env=env,text=True,capture_output=True,timeout=30)
        (folder/(name+'.log')).write_text(run.stdout+run.stderr,encoding='utf-8')
        if run.returncode:raise RuntimeError(name+': '+run.stdout+run.stderr)
        print(run.stdout.strip());results.append(dict(name=name,bytes=len(data),expected_error=error,passed=True))
    (folder/'result.json').write_text(json.dumps(dict(passed=True,cases=results,firmware_integrated=False),indent=2),encoding='utf-8')

if __name__=='__main__':main()
