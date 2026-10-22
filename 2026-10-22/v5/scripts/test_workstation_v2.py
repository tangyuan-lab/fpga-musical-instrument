"""V2 离线验证：硬件合成 RTL、资源协议、编辑器及独立本机校谱试听。"""
from pathlib import Path
import subprocess,os,sys
ROOT=Path(__file__).resolve().parents[1];BUILD=ROOT/'build/tests';TOOLS=Path(__import__('os').environ.get('FPGA_SIM_BIN','C:/msys64/ucrt64/bin'))
def main():
    from prepare_workstation_v2_tests import prepare as fixtures
    from prepare_workstation_v2 import prepare
    prepare();fixtures()
    env=os.environ.copy();env['PATH']=str(TOOLS)+os.pathsep+env['PATH'];env['PYTHONIOENCODING']='utf-8';BUILD.mkdir(parents=True,exist_ok=True)
    tests={'tb_workstation_v2_emergency':['rtl/io/workstation_v2_emergency.sv','rtl/io/workstation_v2_resources.sv','rtl/io/midi_file_ram_sdp.sv','tests/models/sdpb_model.sv'],
      'tb_pressure_max16':['rtl/control/pressure_max16.sv'],
      'tb_workstation_v2_serial_router':['rtl/control/workstation_v2_router.sv','rtl/control/instrument_key_router.sv'],
      'tb_workstation_v2_router':['rtl/control/instrument_key_router.sv'],
      'tb_uart_frame_tx_v2':['rtl/io/uart_frame_tx_v2.sv','rtl/io/uart_tx.sv','rtl/io/uart_rx.sv'],
      'tb_synth32':['rtl/audio/synth32.sv'],'tb_i2s_tx':['rtl/audio/i2s_tx.sv'],
      'tb_audio_effects':['rtl/audio/audio_effects.sv','rtl/audio/sample_ram.sv','tests/models/sdpb_model.sv'],
      'tb_workstation_v2_screen':['rtl/io/workstation_v2_screen.sv','rtl/io/uart_tx.sv','rtl/io/uart_rx.sv'],
      'tb_workstation_v2_commands':['rtl/control/workstation_v2_commands.sv','rtl/control/instrument_mode_control_v2.sv'],
      'tb_workstation_v2_integration':['rtl/audio/synth32.sv','rtl/io/uart_tx.sv','rtl/io/uart_rx.sv','rtl/io/uart_frame_tx_v2.sv','rtl/io/uart_frame_protocol.sv',
       'rtl/common/control_ram_sdp.sv','rtl/io/midi_file_ram_sdp.sv','rtl/io/workstation_v2_resources.sv','rtl/midi/midi_type0_parser_v2.sv','rtl/control/workstation_v2_player.sv','tests/models/sdpb_model.sv']}
    for name,sources in tests.items():
        executable=BUILD/(name+'.vvp');log=''
        for cmd in ([str(TOOLS/'iverilog.exe'),'-g2012','-I',str(ROOT/'rtl/audio'),'-I',str(BUILD),'-s',name,'-o',str(executable),*sources,'tests/'+name+'.sv'],[str(TOOLS/'vvp.exe'),str(executable)]):
            r=subprocess.run(cmd,cwd=ROOT,env=env,capture_output=True,text=True,timeout=120);log+=r.stdout+r.stderr
            if r.returncode:print(log);return 1
        (BUILD/(name+'.log')).write_text(log,encoding='utf-8');print(log.strip())
    captured=bytes(int(s,16) for s in (BUILD/'workstation_v2_screen.hex').read_text().split())
    commands=captured.split(b'\xff\xff\xff')[:-1]
    expected=[]
    for index in range(12):
        name=b'A'*32 if index==0 else bytes([0xb2,0xd4,0x30+index])
        expected.extend([b'c'+str(index).encode()+b'.txt="'+name+b'"',f'r{index}.val={index&1}'.encode()])
    values=[3,0,0,0,0,0,123456,1920,7,0,0,0,0,0,64,8,3000,32,
            9,0,24,0,1,2,3,97,98,99,100,2,5,125,22,3,1800,379747,11,0,7,0,1]
    expected.extend(f'rx{i}.val={value:010d}'.encode() for i,value in enumerate(values))
    if commands!=expected:
        print('FAIL screen UART protocol',[(a,b) for a,b in zip(commands,expected) if a!=b]);return 1
    print('PASS screen UART names/32-byte boundary/41 coherent status values/terminators')
    from host_app.protocol import FrameDecoder
    raw=bytes(int(x,16) for x in (BUILD/'uart_frame_tx_v2.hex').read_text().split());frames=list(FrameDecoder().feed(raw))
    if len(frames)!=1 or frames[0].payload!=bytes((i*37+11)&255 for i in range(96)):raise AssertionError('96-byte ACK CRC/payload mismatch')
    for suite in ('test_music_project.py','test_preview_audio.py','test_workstation_gui.py','test_opensource_music.py'):
        result=subprocess.call([sys.executable,'-m','unittest','discover','-s','tests','-p',suite,'-v'],cwd=ROOT,env=env)
        if result:return result
    return 0
if __name__=='__main__':raise SystemExit(main())
