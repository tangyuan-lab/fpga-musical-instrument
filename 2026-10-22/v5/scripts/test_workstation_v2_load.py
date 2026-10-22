"""32声部、两种效果器及完整屏幕UART目录/状态刷新同时运行的持续负载检查。"""
from pathlib import Path
import os,subprocess,sys,json,re
ROOT=Path(__file__).resolve().parents[1];TOOLS=Path(__import__('os').environ.get('FPGA_SIM_BIN','C:/msys64/ucrt64/bin'))

def main():
    build=ROOT/'build/tests';build.mkdir(parents=True,exist_ok=True)
    env=os.environ.copy();env['PATH']=str(TOOLS)+os.pathsep+env['PATH']
    binary=build/'tb_workstation_v2_load.vvp';log=build/'tb_workstation_v2_load.log'
    sources=['rtl/audio/synth32.sv','rtl/audio/audio_effects.sv','rtl/audio/sample_ram.sv','rtl/audio/i2s_tx.sv',
             'rtl/io/workstation_v2_screen.sv','rtl/io/uart_tx.sv','rtl/io/uart_rx.sv','tests/models/sdpb_model.sv','tests/tb_workstation_v2_load.sv']
    with log.open('w',encoding='utf-8') as output:
        for command in ([str(TOOLS/'iverilog.exe'),'-g2012','-I',str(ROOT/'rtl/audio'),'-s','tb_workstation_v2_load','-o',str(binary),*sources],
                        [str(TOOLS/'vvp.exe'),'-i',str(binary)]):
            process=subprocess.run(command,cwd=ROOT,env=env,stdout=output,stderr=subprocess.STDOUT,timeout=1200)
            if process.returncode:print(log.read_text());return process.returncode
    content=log.read_text();print(content)
    found=re.search(r'samples=(\d+) screen_commands=(\d+) max_compute_cycles=(\d+)',content)
    if not found:return 1
    result=dict(passed=True,voices=32,samples=int(found[1]),screen_commands=int(found[2]),max_compute_cycles=int(found[3]),
                sample_period_cycles=1024,clock_hz=50_000_000,screen_baud=115200,effects=['delay','reverb'],
                boundary='音频与屏幕发送模块RTL持续负载；不含完整顶层压力输入、资源上传、HDMI厂商IP及模拟链路')
    (build/'workstation_v2_load.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    return 0

if __name__=='__main__':raise SystemExit(main())
