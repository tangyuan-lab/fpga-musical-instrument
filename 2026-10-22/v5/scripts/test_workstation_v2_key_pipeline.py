"""验证实时键流水线，不依赖ADC或屏幕实物。"""
from pathlib import Path
import os
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
TOOLS = Path(__import__('os').environ.get('FPGA_SIM_BIN','C:/msys64/ucrt64/bin'))

def main():
    tcl = (ROOT/'gowin/build_instrument_workstation_v2.tcl').read_text(encoding='utf-8')
    sources = ['rtl/'+s.replace(' ', '/') for s in re.findall(r'add_file -type verilog \[file join \$root rtl (.*?)\]', tcl)]
    sources = [s for s in sources if not s.endswith(('video_pll.sv', 'DVI_TX_Top.v'))]
    sources += ['tests/models/video_elaboration_stubs.sv', 'tests/models/sdpb_model.sv', 'tests/tb_workstation_v2_key_pipeline.sv']
    env = os.environ.copy()
    env['PATH'] = str(TOOLS)+os.pathsep+env['PATH']
    output = ROOT/'build/tests/tb_workstation_v2_key_pipeline.vvp'
    log = ROOT/'build/tests/tb_workstation_v2_key_pipeline.log'
    with log.open('w', encoding='utf-8') as stream:
        for command in ([str(TOOLS/'iverilog.exe'), '-g2012', '-s', 'tb_workstation_v2_key_pipeline', '-o', str(output), *sources], [str(TOOLS/'vvp.exe'), str(output)]):
            result = subprocess.run(command, cwd=ROOT, env=env, stdout=stream, stderr=subprocess.STDOUT, timeout=120)
            if result.returncode:
                print(log.read_text(encoding='utf-8'))
                return result.returncode
    print(log.read_text(encoding='utf-8'))
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
