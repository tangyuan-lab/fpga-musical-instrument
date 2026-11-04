"""实际V2音频顶层的数字延迟测试；不包含传感器模拟响应、屏幕扫描和DAC延迟。"""
from pathlib import Path
import os,re,subprocess,sys
ROOT=Path(__file__).resolve().parents[1];TOOLS=Path(__import__('os').environ.get('FPGA_SIM_BIN','C:/msys64/ucrt64/bin'))
def main():
    tcl=(ROOT/'gowin/build_instrument_workstation_v2.tcl').read_text(encoding='utf-8')
    sources=['rtl/'+s.replace(' ','/') for s in re.findall(r'add_file -type verilog \[file join \$root rtl (.*?)\]',tcl)]
    sources=[s for s in sources if not s.endswith(('video_pll.sv','DVI_TX_Top.v'))]
    sources+=['tests/models/video_elaboration_stubs.sv','tests/models/sdpb_model.sv','tests/mcp3208_dynamic_model.sv','tests/tb_workstation_v2_latency.sv']
    env=os.environ.copy();env['PATH']=str(TOOLS)+os.pathsep+env['PATH'];out=ROOT/'build/tests/tb_workstation_v2_latency.vvp'
    log=ROOT/'build/tests/tb_workstation_v2_latency.log'
    with log.open('w',encoding='utf-8') as f:
        for cmd in ([str(TOOLS/'iverilog.exe'),'-g2012','-s','tb_workstation_v2_latency','-o',str(out),*sources],[str(TOOLS/'vvp.exe'),'-i',str(out)]):
            result=subprocess.run(cmd,cwd=ROOT,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=1800)
            if result.returncode:print(log.read_text());return result.returncode
    print(log.read_text());return subprocess.call([sys.executable,str(ROOT/'scripts/report_workstation_v2_latency.py')],cwd=ROOT,env=env)
if __name__=='__main__':raise SystemExit(main())
