"""生成确定性V2端到端测试事务；音色仅作为资源数据，不在PC播放。"""
from pathlib import Path
import struct,sys,uuid,zlib
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from host_app.music_project import Song,Note,Section,Patch
from host_app.device_v2 import DeviceV2,display_name

class CapturedDevice(DeviceV2):
    """记录真实上位机上传请求，交给RTL处理；不打开串口。"""
    def __init__(self):self.requests=[]
    def send_and_wait_ack(self,typ,payload=b'',**kwargs):self.requests.append((typ,payload))

def prepare():
    lines=[];sequence=0
    def send(typ,data=b'',result=0,repeat=False):
        nonlocal sequence
        if not repeat:sequence+=1
        lines.append(f"        send(8'h{typ:02x},16'd{sequence},{len(data)},1056'h{int.from_bytes(data,'little'):0264x},{result});")
    def upload(kind,slot,item,data,duration=0,duplicate=False,bad_crc=False,commit_result=0):
        crc=zlib.crc32(data)&0xffffffff
        expected=crc^1 if bad_crc else crc
        device=CapturedDevice();device.upload_resource(kind,slot,item,data,duration=duration)
        for typ,payload in device.requests:
            if bad_crc and typ==0x32:payload=payload[:6]+struct.pack('<I',expected)+payload[10:]
            if bad_crc and typ==0x34:payload=struct.pack('<I',expected)
            send(typ,payload,(3 if bad_crc else commit_result) if typ==0x34 else 0)
            if duplicate and typ==0x33 and payload[:4]==bytes(4):send(typ,payload,repeat=True)
    patch=Patch(name='测试音色',resource_id=str(uuid.UUID(int=1)))
    songs=[Song(name='双声部曲谱',resource_id=str(uuid.UUID(int=2+i)),notes=[Note(0,960,60,100,0),Note(0,960,64,90,1)],
                sections=[Section(end=1920,timbres=[2,1,0,0],mute=0)]) for i in range(2)]
    songs[0].sections=[Section(end=480,timbres=[2,1,0,0],mute=0),Section(start=480,end=1920,timbres=[0,1,0,0],mute=0)]
    songs[1].tempos=[[i*120,500000+i*1000] for i in range(64)];songs[1].sections[0].end=8000
    send(0x30);upload(1,0,patch,patch.binary(),duplicate=True)
    upload(0,3,songs[0],b'MThd'+bytes(24),songs[0].duration,commit_result=5)
    lines.append('        if(mask[3] || resources.song_data_ready[3]) $fatal(1,"malformed MIDI was published despite correct CRC");')
    upload(1,7,patch,patch.binary(),bad_crc=True)
    lines.append('        if(patches!=1) $fatal(1,"bad CRC resource was published");')
    send(0x35,struct.pack('<BII',34,2+(16<<4)+(12<<16),2100+(50<<12)))
    lines.append('        if(synth.atk[2]!=16 || synth.dec[2]!=12 || synth.sus[2]!=2100 || synth.rel[2]!=50) $fatal(1,"ADSR write did not reach synth");')
    send(0x31,bytes([1,0]))
    lines.append('        if(received_payload[607:544]!={16\'d50,16\'d2100,16\'d12,16\'d16}) $fatal(1,"catalog ADSR differs from synth");')
    for slot,song in enumerate(songs):
        upload(0,slot,song,song.midi(),song.duration)
        lines.append(f'        if(mask[{slot}]) $fatal(1,"song became playable before arrangement commit");')
        captured=CapturedDevice();captured.upload_resource(2,slot,song,song.arrangement(),duration=song.duration)
        wrong=bytearray(captured.requests[0][1]);wrong[10]^=0x80;send(0x32,bytes(wrong),6)
        upload(2,slot,song,song.arrangement(),song.duration)
    original=songs[0].arrangement();corrupt=bytearray(original);corrupt[8]=0
    upload(2,0,songs[0],bytes(corrupt),bad_crc=True)
    invalid=bytearray(original);invalid[0]=1
    upload(2,0,songs[0],bytes(invalid),commit_result=3)
    missing_patch=bytearray(original);missing_patch[18]=9
    upload(2,0,songs[0],bytes(missing_patch),commit_result=3)
    lines.append(f'        if(resources.arrangements[0]!=192\'h{int.from_bytes(original[:24],"little"):048x}) $fatal(1,"failed arrangement transaction changed published data");')
    send(0x31,bytes([0,0]));lines.append('        if(received_length!=76 || received_payload[39:32]!=1) $fatal(1,"long catalog ACK");')
    lines.append(f'        if(received_payload[207:80]!=128\'h{int.from_bytes(uuid.UUID(songs[0].resource_id).bytes,"little"):032x}) $fatal(1,"resource UUID mismatch");')
    lines.append(f'        if(resources.catalog_name!=256\'h{int.from_bytes(display_name(songs[0].name),"little"):064x}) $fatal(1,"screen metadata mirror mismatch");')
    send(0x31,bytes([1,0]));name=int.from_bytes(display_name(patch.name),'little')
    lines.append(f'        if(received_payload[463:208]!=256\'h{name:064x}) $fatal(1,"GB2312 name mismatch");')
    send(0x35,struct.pack('<BII',2,0,0));send(0x35,struct.pack('<BII',3,0,0))
    out=ROOT/'build/tests/v2_fixture.inc';out.parent.mkdir(parents=True,exist_ok=True);out.write_text('\n'.join(lines)+'\n',encoding='utf-8')
    return out
if __name__=='__main__':print(prepare())
