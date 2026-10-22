"""V2设备协议：目录由设备确认，文件按CRC提交，控制操作等待执行结果。"""
from __future__ import annotations
from dataclasses import dataclass
import struct,time,uuid,zlib,threading
from .serial_link import FpgaSerialLink

CAPS=0x30;CATALOG=0x31;BEGIN=0x32;DATA=0x33;COMMIT=0x34;CONTROL=0x35;STATE=0x36;RUNTIME_DETAILS=0x37;EMERGENCY=0x3B;ARRANGEMENT=2
FEATURE_RUNTIME=1;FEATURE_JOINT_PUBLISH=2;FEATURE_EMERGENCY=4;FEATURE_TRACK_MIX=8
OPERATIONS={'mode':1,'select_song':2,'play':3,'pause':4,'stop':5,'seek':6,'loop_a':7,'loop_b':8,
 'loop':9,'tempo':10,'transpose':11,'live_timbre':12,'screen_timbre':13,'audition':14,'panic':15,
 'bend':16,'vibrato_depth':17,'vibrato_rate':18,'delay_mix':19,'reverb_mix':20,'delay_time':21,
 'feedback':22,'section':23,'part_timbre':24,'part_volume':25,'part_mute':26,'part_solo':27,
 'test4':28,'test32':29,'map_bank':30,'map_key':31,'map_descriptor':32,'record':33,'adsr':34}

def display_name(name):
    # HMI命令字符串禁止引号、反斜线及控制字符；不可显示字符使用问号显示名。
    text=''.join(c if c>=' ' and c not in '"\\' else '_' for c in name)
    raw=text.encode('gb2312',errors='replace')[:32]
    while raw:
        try:return raw.decode('gb2312').encode('gb2312').ljust(32,b'\0')
        except UnicodeDecodeError:raw=raw[:-1]
    return b'\0'*32

class DeviceV2(FpgaSerialLink):
    def __init__(self,*args,**kwargs):
        super().__init__(*args,**kwargs);self._transfer_cancelled=threading.Event()
    def _cancel_event(self):
        if not hasattr(self,'_transfer_cancelled'):self._transfer_cancelled=threading.Event()
        return self._transfer_cancelled
    def _check_transfer(self):
        if self._cancel_event().is_set():
            from .serial_executor import TransferAborted
            raise TransferAborted('资源上传已由用户中止')
    def emergency(self,abort=True):
        if not getattr(self,'features',0)&FEATURE_EMERGENCY:
            raise RuntimeError('当前位流不支持上传期间紧急停止，需要新版位流')
        if abort:self._cancel_event().set()
        return self.send_and_wait_ack(EMERGENCY,bytes([3 if abort else 1]),timeout=1,retries=3,urgent=True,abort=abort)
    def capabilities(self):
        frame=self.send_and_wait_ack(CAPS)
        if len(frame.payload)<16 or frame.payload[2:6]!=b'WSV2':raise RuntimeError('当前FPGA不是工作站V2，请先下载对应位流')
        p=frame.payload
        self.features=int.from_bytes(p[16:18],'little') if len(p)>=18 else 0
        return {'version':p[6],'songs':p[7],'patches':p[8],'voices':p[9],
                'song_bytes':int.from_bytes(p[10:14],'little'),'max_events':int.from_bytes(p[14:16],'little'),'features':self.features}
    def catalog(self):
        output=[]
        for kind,count in ((0,4),(1,8)):
            for slot in range(count):
                p=self.send_and_wait_ack(CATALOG,bytes([kind,slot])).payload
                if len(p)<68:raise RuntimeError('设备目录长度错误')
                if not p[4]:continue
                output.append({'kind':kind,'slot':slot,'ready':bool(p[4]),'revision':int.from_bytes(p[6:10],'little'),
                    'resource_id':str(uuid.UUID(bytes=p[10:26])),'name':p[26:58].split(b'\0')[0].decode('gb2312',errors='replace'),
                    'size':int.from_bytes(p[58:62],'little'),'duration_ticks':int.from_bytes(p[62:66],'little'),'sections':p[66],
                    'adsr':list(struct.unpack_from('<4H',p,68)) if len(p)>=76 else None})
        return output
    def control(self,name,value=0,aux=0):
        opcode=OPERATIONS[name] if isinstance(name,str) else name
        self.send_and_wait_ack(CONTROL,struct.pack('<BII',opcode,value&0xffffffff,aux&0xffffffff),timeout=3)
    def upload_resource(self,kind,slot,item,data,progress=None,duration=0,reset_cancel=True):
        if reset_cancel:self._cancel_event().clear()
        self._check_transfer()
        crc=zlib.crc32(data)&0xffffffff
        header=struct.pack('<BBII16sI32sI4H',kind,slot,len(data),crc,uuid.UUID(item.resource_id).bytes,item.revision,
            display_name(item.name),duration,*([item.attack,item.decay,item.sustain,item.release] if kind==1 else [0]*4))
        self.send_and_wait_ack(BEGIN,header,timeout=3)
        for offset in range(0,len(data),128):
            self._check_transfer()
            self.send_and_wait_ack(DATA,struct.pack('<I',offset)+data[offset:offset+128],timeout=3)
            if progress:progress(min(offset+128,len(data)),len(data))
        self._check_transfer();self.send_and_wait_ack(COMMIT,struct.pack('<I',crc),timeout=3)
    def upload_project(self,project,progress=None):
        self._cancel_event().clear()
        project.validate();self.control('stop');self.capabilities()
        for slot,patch in enumerate(project.patches):self.upload_resource(1,slot,patch,patch.binary(),progress,reset_cancel=False)
        for slot,song in enumerate(project.songs):
            self.upload_resource(0,slot,song,song.midi(),progress,song.duration,reset_cancel=False)
            self.upload_resource(2,slot,song,song.arrangement(),progress,song.duration,reset_cancel=False)
        return self.catalog()
    def state(self):
        if getattr(self,'features',0)&1:return self.runtime_details()
        p=self.send_and_wait_ack(STATE).payload
        return self.decode_state(p)
    @staticmethod
    def decode_state(p):
        if len(p)<30:raise RuntimeError('设备状态长度错误')
        return {'mode':p[2],'playing':bool(p[3]&1),'paused':bool(p[3]&2),'busy':bool(p[3]&4),'error':bool(p[3]&8),
          'song':p[4],'live_timbre':p[5],'section':p[6],'voices':p[7], 'tick':int.from_bytes(p[8:12],'little'),
          'duration':int.from_bytes(p[12:16],'little'),'revision':int.from_bytes(p[16:20],'little'),
          'pressure':int.from_bytes(p[20:22],'little'),'keys':int.from_bytes(p[22:24],'little'),
          'loop_a':int.from_bytes(p[24:28],'little'),'loop':bool(p[28]),'deadline_error':bool(p[29])}
    def runtime_details(self):
        p=self.send_and_wait_ack(RUNTIME_DETAILS).payload
        if len(p)!=80 or p[2]!=1:raise RuntimeError('运行详情长度或版本错误')
        result=self.decode_state(bytes(2)+p[10:38])
        result.update(part_timbres=list(p[38:42]),part_volumes=list(p[42:46]),part_mute=p[46],part_solo=p[47],
            speed=int.from_bytes(p[48:50],'little'),transpose=int.from_bytes(p[50:51],'little',signed=True),screen_timbre=p[51],
            loop_b=int.from_bytes(p[52:56],'little'),tempo=int.from_bytes(p[56:60],'little'),adsr=list(struct.unpack_from('<4H',p,60)),
            snapshot=int.from_bytes(p[68:72],'little'),last_op=p[3],last_result=p[4],command_serial=int.from_bytes(p[6:10],'little'),
            last_value=int.from_bytes(p[72:76],'little'),last_aux=int.from_bytes(p[76:80],'little'))
        return result
