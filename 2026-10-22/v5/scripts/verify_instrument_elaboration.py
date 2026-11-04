"""核查统一顶层两种音频接口的 HDL 连接；PLL/串化原语由 Gowin 实现阶段核查。"""
from pathlib import Path
import re
import subprocess
import os
from run_tests import TOOLS, ROOT, BUILD

build = (ROOT/'gowin/build_instrument_touch16.tcl').read_text(encoding='utf-8')
sources = [ROOT/Path(*parts.split()) for parts in re.findall(r'\{(rtl [^{}]+\.s?v)\}',build)]
# Gowin 加密 IP 不可交给 Icarus；其连线/时序由 Gowin 全量构建验证。
sources = [source for source in sources if source.name != 'DVI_TX_Top.v']
environment=os.environ.copy()
environment['PATH']=str(TOOLS)+os.pathsep+environment.get('PATH','')
for i2s in (0,1):
    command=[str(TOOLS/'iverilog.exe'),'-g2012','-i','-Wall','-s','instrument_full_top',
             '-P',f'instrument_full_top.AUDIO_I2S={i2s}','-o',str(BUILD/f'instrument16_i2s{i2s}.vvp'), *map(str,sources)]
    result=subprocess.run(command,cwd=ROOT,env=environment,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=60)
    log=BUILD/f'instrument16_i2s{i2s}_elaboration.log'
    log.write_text(result.stdout+result.stderr,encoding='utf-8')
    if result.returncode or any(word in result.stderr.lower() for word in ('implicit definition','dangling','expects','error:')):
        raise RuntimeError(f'Top connection failed; see {log}')
    print(f'PASS top KEY_COUNT=16 AUDIO_I2S={i2s} connection check (vendor primitive implementation pending Gowin)')
