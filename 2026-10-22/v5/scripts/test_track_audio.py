"""逐轨后级增益的RTL音频验证；不连接声卡或串口，不发布整机位流。"""
from pathlib import Path
import hashlib,json,os,re,shutil,subprocess,sys

ROOT=Path(__file__).resolve().parents[1]


def main():
    subprocess.run([sys.executable,str(ROOT/'scripts/prepare_track_synth.py')],cwd=ROOT,check=True)
    tools=Path(__import__('os').environ.get('FPGA_SIM_BIN','C:/msys64/ucrt64/bin'));env=os.environ.copy();env['PATH']=str(tools)+os.pathsep+env['PATH']
    iv=shutil.which('iverilog',path=env['PATH']);vvp=shutil.which('vvp',path=env['PATH'])
    if not iv or not vvp:raise RuntimeError('未找到Icarus Verilog工具')
    folder=ROOT/'build/tests';folder.mkdir(exist_ok=True)
    cases=[]
    for top,extra in [('tb_track_gain_bank',[]),('tb_synth32_tracks',['experiments/workstation_tracks/synth32_tracks.sv'])]:
        source=['experiments/workstation_tracks/track_gain_bank.sv',*extra,'tests/'+top+'.sv'];out=folder/(top+'.vvp')
        compile_run=subprocess.run([iv,'-g2012','-s',top,'-o',str(out),*source],cwd=ROOT,env=env,text=True,capture_output=True,timeout=60)
        log=compile_run.stdout+compile_run.stderr
        if compile_run.returncode:raise RuntimeError(log)
        run=subprocess.run([vvp,str(out)],cwd=ROOT,env=env,text=True,capture_output=True,timeout=60);log+=run.stdout+run.stderr
        (folder/(top+'.log')).write_text(log,encoding='utf-8')
        if run.returncode or 'PASS' not in log:raise RuntimeError(log)
        print(log.strip());cases.append(dict(name=top,passed=True,sources={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in source}))
    (folder/'track_audio.json').write_text(json.dumps(dict(passed=True,tests=cases,firmware_integrated=False),indent=2),encoding='utf-8')

if __name__=='__main__':main()
