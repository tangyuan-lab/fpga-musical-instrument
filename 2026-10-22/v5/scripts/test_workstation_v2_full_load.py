"""完整顶层ADC与UART并发压力检查；报告控制到声部分配，不当作模拟音频延迟。"""
from pathlib import Path
import json,os,re,struct,subprocess,sys

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from host_app.protocol import encode_frame,FrameDecoder

def main():
    build=ROOT/'build/tests';tools=Path(__import__('os').environ.get('FPGA_SIM_BIN','C:/msys64/ucrt64/bin'))
    setup=[]
    for sequence,(opcode,value) in enumerate(((1,2),(19,64),(20,64),(21,512),(22,48),(29,1)),1):
        frame=encode_frame(0x35,sequence,struct.pack('<BII',opcode,value,0))
        setup += [f"usb_send(8'h{byte:02x});" for byte in frame]
        setup += ['repeat(1000) @(negedge clk);']
    (build/'workstation_v2_full_load_setup.svh').write_text('\n'.join(setup),encoding='ascii')
    query=encode_frame(0x37,7)
    (build/'workstation_v2_full_load_query.svh').write_text('\n'.join(f"usb_send(8'h{b:02x});" for b in query),encoding='ascii')
    for name,frame in [('emergency',encode_frame(0x3b,8,b'\x03')),('after_stop',encode_frame(0x37,9))]:
        (build/f'workstation_v2_full_load_{name}.svh').write_text('\n'.join(f"usb_send(8'h{b:02x});" for b in frame),encoding='ascii')
    tcl=(ROOT/'gowin/build_instrument_workstation_v2.tcl').read_text(encoding='utf-8')
    sources=['rtl/'+s.replace(' ','/') for s in re.findall(r'add_file -type verilog \[file join \$root rtl (.*?)\]',tcl)]
    sources=[s for s in sources if not s.endswith(('video_pll.sv','DVI_TX_Top.v'))]
    sources += ['tests/models/video_elaboration_stubs.sv','tests/models/sdpb_model.sv','tests/mcp3208_dynamic_model.sv','tests/tb_workstation_v2_full_load.sv']
    env=os.environ.copy();env['PATH']=str(tools)+os.pathsep+env['PATH']
    output=build/'tb_workstation_v2_full_load.vvp';log=build/'tb_workstation_v2_full_load.log'
    with log.open('w',encoding='utf-8') as stream:
        for command in ([str(tools/'iverilog.exe'),'-g2012','-I',str(build),'-s','tb_workstation_v2_full_load','-o',str(output),*sources], [str(tools/'vvp.exe'),'-i',str(output)]):
            result=subprocess.run(command,cwd=ROOT,env=env,stdout=stream,stderr=subprocess.STDOUT,timeout=1800)
            if result.returncode:print(log.read_text(encoding='utf-8'));return result.returncode
    text=log.read_text(encoding='utf-8');print(text)
    match=re.search(r'voices=32 live_keys=4 samples=(\d+) screen_bytes=(\d+) control_to_voice_ms=([\d.]+)',text)
    if not match:raise RuntimeError('顶层并发测试未完成')
    frames=list(FrameDecoder().feed(bytes(int(b,16) for b in (build/'workstation_v2_full_load_usb.hex').read_text().split())))
    if len(frames)!=9 or any(f.message_type!=0x81 or f.sequence!=i+1 or f.payload[1]!=0 for i,f in enumerate(frames)):
        raise RuntimeError('真实USB UART响应缺帧、CRC失败或命令失败')
    if len(frames[-1].payload)!=80:raise RuntimeError('完整状态回读长度错误')
    if frames[7].payload[:2]!=b'\x3b\0' or frames[-1].payload[11]&3 or frames[-1].payload[17]!=0:
        raise RuntimeError('紧急停止ACK或停止后运行状态错误')
    result=dict(passed=True,voices=32,live_keys=4,samples=int(match[1]),screen_bytes=int(match[2]),control_to_voice_ms=float(match[3]),usb_crc_checked_frames=len(frames),effects=['delay','reverb'],boundary='真实顶层RTL ADC/SPI、USB/屏幕UART、32声部及效果器；四实体键到声部分配时间，不是独立新音的I2S或模拟起音延迟，HDMI厂商IP为隔离桩')
    result.update(emergency_ack_verified=True,held_keys_did_not_retrigger=True,post_stop_state_verified=True)
    (build/'workstation_v2_full_load.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    return 0

if __name__=='__main__':raise SystemExit(main())
