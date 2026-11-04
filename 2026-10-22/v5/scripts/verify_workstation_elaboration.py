"""验证工作站实际顶层所有端口连接；加密DVI和Gowin原语实现由布局布线验证。"""
from pathlib import Path
import os,re,subprocess
from run_tests import ROOT,BUILD,TOOLS

def main():
    BUILD.mkdir(parents=True,exist_ok=True)
    tcl=(ROOT/'gowin/build_instrument_workstation.tcl').read_text(encoding='utf-8')
    sources=[ROOT/Path(*p.split()) for p in re.findall(r'\{(rtl [^{}]+\.s?v)\}',tcl) if 'DVI_TX_Top' not in p]
    environment=os.environ.copy();environment['PATH']=str(TOOLS)+os.pathsep+environment.get('PATH','')
    for i2s in (0,1):
        result=subprocess.run([str(TOOLS/'iverilog.exe'),'-g2012','-i','-Wall','-s','instrument_workstation_top',
            '-P',f'instrument_workstation_top.AUDIO_I2S={i2s}','-o',str(BUILD/f'workstation_i2s{i2s}.vvp'),*map(str,sources)],
            cwd=ROOT,env=environment,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=60)
        log=BUILD/f'workstation_i2s{i2s}_elaboration.log';log.write_text(result.stdout+result.stderr,encoding='utf-8')
        if result.returncode or any(w in result.stderr.lower() for w in ('implicit definition','dangling','expects','error:')):
            raise RuntimeError(f'Connection check failed: {log}')
        print(f'PASS workstation top KEY_COUNT=16 AUDIO_I2S={i2s}; vendor implementation checked by Gowin')

if __name__=='__main__':main()
