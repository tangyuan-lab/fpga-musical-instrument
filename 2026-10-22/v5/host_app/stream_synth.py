"""有界块合成，稳定音符身份和轨道后级混音；不访问串口或声卡。"""
from __future__ import annotations
import ctypes as C
import hashlib
import json
import math
import os
from pathlib import Path
import numpy as np
from .music_project import PARTS, FS
from .preview_audio import TempoMap, _envelope


def owners(song):
    return [t.track_id for t in song.source_tracks] if song.source_tracks else [f'part:{i}' for i in range(4)]


def mix_values(song, muted=(), solo=()):
    keys = owners(song)
    if song.source_tracks:
        return {t.track_id: dict(db=t.gain_db, mute=t.preview_muted or t.track_id in muted,
                                solo=t.preview_solo or t.track_id in solo) for t in song.source_tracks}
    values = getattr(song, 'track_mix', {})
    return {key: dict(db=values.get(key, {}).get('db', 0.), mute=i in muted or values.get(key, {}).get('mute', False),
                      solo=i in solo or values.get(key, {}).get('solo', False)) for i, key in enumerate(keys)}


def audio_identity(song):
    """混音和确认标志不使合成失效；音符、音色、原控制事件和配器会使其失效。"""
    from dataclasses import asdict
    data = asdict(song)
    for key in ('revision', 'name', 'issues', 'score_document', 'track_mix'):
        data.pop(key, None)
    for n in data['notes']:
        for key in ('uncertain', 'box', 'page'):
            n.pop(key, None)
    for t in data['source_tracks']:
        for key in ('gain_db', 'preview_muted', 'preview_solo', 'name', 'device_part'):
            t.pop(key, None)
    return hashlib.sha256(json.dumps(data, sort_keys=True).encode()).hexdigest()


class BlockMixer:
    """后级增益单位dB；静音优先于独奏，5ms跨块线性平滑，不改变音符力度。"""
    def __init__(self, keys, sample_rate, ramp_ms=5):
        self.keys = list(keys); self.sample_rate = sample_rate
        self.length = max(1, round(sample_rate*ramp_ms/1000))
        self.current = np.zeros(len(keys), np.float64)
        self.target = self.current.copy(); self.remaining = np.zeros(len(keys), np.int32)
        self.peaks = {}; self.clipped = 0

    def set(self, values):
        any_solo = any(v.get('solo') for v in values.values())
        for i, key in enumerate(self.keys):
            v = values.get(key, {}); db = float(v.get('db', 0))
            if not math.isfinite(db) or not -120 <= db <= 6:
                raise ValueError('轨道音量必须为静音或 -60..+6 dB')
            gain = 0. if db <= -90 or v.get('mute') or any_solo and not v.get('solo') else 10**(db/20)
            if gain != self.target[i]:self.target[i] = gain; self.remaining[i] = self.length

    def process(self, planes):
        count = planes.shape[-1]; output = np.zeros((count, 2), np.float32); self.peaks = {}
        for i, key in enumerate(self.keys):
            ramp = min(count, int(self.remaining[i])); gains = np.full(count, self.target[i])
            if ramp:
                step = (self.target[i]-self.current[i])/self.remaining[i]
                gains[:ramp] = self.current[i]+step*np.arange(1, ramp+1)
                self.current[i] = gains[ramp-1]; self.remaining[i] -= ramp
            else:self.current[i] = self.target[i]
            track = planes[i].T*gains[:, None]
            self.peaks[key] = dict(peak=float(np.max(np.abs(track), initial=0)), rms=float(np.sqrt(np.mean(track*track))))
            output += track
        self.clipped += int(np.any(np.abs(output) > 1))
        return output


class FluidSynth:
    """DLL仅由独立进程持有。三个组数保持一致，防止本机2.6.1多输出配置越界。"""
    def __init__(self, groups, sample_rate, soundfont=None):
        from .reference_audio import resources
        exe, font = resources(soundfont); folder = exe.parent
        self.dll_directory = os.add_dll_directory(str(folder)) if os.name == 'nt' else None
        dll = folder/'libfluidsynth-3.dll'
        self.lib = C.CDLL(str(dll)); self.settings = None; self.synth = None
        self.groups = groups; self.channels = 256
        def bind(name, restype, args):
            fn = getattr(self.lib, name); fn.restype = restype; fn.argtypes = args; return fn
        p=C.c_void_p; i=C.c_int; f=C.c_float; pp=C.POINTER(C.POINTER(f))
        self.new_settings=bind('new_fluid_settings',p,[])
        self.setint=bind('fluid_settings_setint',i,[p,C.c_char_p,i]);self.setnum=bind('fluid_settings_setnum',i,[p,C.c_char_p,C.c_double])
        self.new_synth=bind('new_fluid_synth',p,[p]);self.sfload=bind('fluid_synth_sfload',i,[p,C.c_char_p,i])
        self.render=bind('fluid_synth_process',i,[p,i,i,pp,i,pp])
        self.on=bind('fluid_synth_noteon',i,[p,i,i,i]);self.off=bind('fluid_synth_noteoff',i,[p,i,i])
        self.cc=bind('fluid_synth_cc',i,[p,i,i,i]);self.program=bind('fluid_synth_program_change',i,[p,i,i])
        self.bend=bind('fluid_synth_pitch_bend',i,[p,i,i]);self.kind=bind('fluid_synth_set_channel_type',i,[p,i,i])
        self.alloff=bind('fluid_synth_all_sounds_off',i,[p,i]);self.delete=bind('delete_fluid_synth',None,[p])
        self.delete_settings=bind('delete_fluid_settings',None,[p])
        self.settings=self.new_settings()
        for key,value in {'audio-groups':groups,'audio-channels':groups,'effects-groups':groups,
                          'midi-channels':self.channels,'polyphony':512,'cpu-cores':1,
                          'reverb.active':0,'chorus.active':0,'limiter.active':0}.items():
            if self.setint(self.settings,('synth.'+key).encode(),value)<0:raise ValueError('FluidSynth参数不支持：'+key)
        self.setnum(self.settings,b'synth.sample-rate',sample_rate);self.setnum(self.settings,b'synth.gain',.6)
        self.synth=self.new_synth(self.settings)
        if not self.synth:raise ValueError('FluidSynth实例创建失败')
        if self.sfload(self.synth,os.fsencode(font),1)<0:self.close();raise ValueError('SoundFont载入失败')
        self.fx_count=bind('fluid_synth_count_effects_channels',i,[p])(self.synth)
        self.fx_groups=bind('fluid_synth_count_effects_groups',i,[p])(self.synth)

    def block(self, count):
        out=np.zeros((self.groups*2,count),np.float32)
        fx=np.zeros((max(1,self.fx_count*self.fx_groups),count),np.float32)
        def pointers(array):return (C.POINTER(C.c_float)*len(array))(*(row.ctypes.data_as(C.POINTER(C.c_float)) for row in array))
        if self.render(self.synth,count,len(fx),pointers(fx),len(out),pointers(out))<0:raise ValueError('FluidSynth块合成失败')
        return out.reshape(self.groups,2,count)

    def close(self):
        if self.synth:self.delete(self.synth);self.synth=None
        if self.settings:self.delete_settings(self.settings);self.settings=None
        if self.dll_directory:self.dll_directory.close();self.dll_directory=None


class EventStream:
    """按样本帧调度乐谱。私有MIDI lane保留同音身份，通道取模后汇入原音频组。"""
    def __init__(self, song, sample_rate=48000, soundfont=None, synth_factory=FluidSynth):
        self.song=song;self.clock=TempoMap(song);self.sample_rate=sample_rate;self.keys=owners(song)
        if len(self.keys)>32:raise ValueError('本版实时试听最多32条源轨道；请分组试听，未合并或丢弃轨道')
        self.groups=max(1,1<<(max(1,len(self.keys))-1).bit_length());self.lanes=256//self.groups
        self.synth=synth_factory(self.groups,sample_rate,soundfont)
        self.events=[];self.index=0;self.seconds=0.;self.rate=1.;self.loop=None;self.note_ons=0
        self.active={};self.states={};self.occupied={};self.drums=set();self.programs={};self.section=None
        tracks={t.track_id:t for t in song.source_tracks}
        for owner,key in enumerate(self.keys):
            t=tracks.get(key);self.programs[owner]=(t.program if t.reference_override is None else t.reference_override) if t else song.reference_programs[owner]
            if t.is_drum if t else owner==3:self.drums.add(owner)
        for n in song.notes:
            if not (0<=n.start<n.end and 0<=n.pitch<128 and 0<n.velocity<128):raise ValueError('请修正无效音符')
            key=n.track_id if song.source_tracks else f'part:{n.part}'
            if key not in self.keys:raise ValueError('音符缺少源轨道身份')
            owner=self.keys.index(key);track=tracks.get(key)
            # 保留旧工程的力度缩放；新轨道推子在BlockMixer中独立处理。
            velocity=round(n.velocity*(track.reference_volume/100 if track else 1))
            if velocity<=0:continue
            on=n.source_start_order*4 if n.source_start_order is not None else 2
            off=n.source_end_order*4 if n.source_end_order is not None else 1
            self.events.extend([(self.clock.to_seconds(n.start),on,'on',owner,n.note_id,(n.pitch,velocity,n.part)),
                                (self.clock.to_seconds(n.end),off,'off',owner,n.note_id,())])
        for event in song.source_midi_events:
            m=event['message'];channel=m.get('channel')
            if event.get('meta'):continue
            if m['type'] not in ('control_change','program_change','pitchwheel','aftertouch','polytouch'):
                raise ValueError('当前实时试听不支持源控制消息：'+m['type'])
            for owner,t in enumerate(song.source_tracks):
                if t.channel==channel and not (m['type']=='program_change' and t.reference_override is not None):
                    self.events.append((self.clock.to_seconds(event['tick']),event.get('order',0)*4,'control',owner,'',m))
        for section in song.sections:self.events.append((self.clock.to_seconds(section.start),-3000000,'section',0,'',section))
        self.events.sort(key=lambda e:(e[0],e[1]));self.end=self.clock.to_seconds(song.duration)
        self.reset()

    def channels(self,owner):
        # 本机2.6.1 DLL的255号通道在CC调用中越界；保留该槽，容量按真实lane数检查。
        return range(owner,255,self.groups)

    def reset(self):
        self.active.clear();self.occupied.clear();self.states={};self.section=None
        for owner in range(len(self.keys)):
            self.states[owner]=dict(program=self.programs[owner],cc={},bend=8192)
            for channel in self.channels(owner):
                self.synth.alloff(self.synth.synth,channel);self.synth.cc(self.synth.synth,channel,121,0)
                self.synth.kind(self.synth.synth,channel,int(owner in self.drums))
                self.synth.program(self.synth.synth,channel,self.programs[owner]);self.synth.bend(self.synth.synth,channel,8192)

    def apply(self,event,audible=True):
        _,_,op,owner,identifier,data=event;state=self.states[owner]
        if op=='section':self.section=data;return
        if hasattr(self.synth,'context_tick'):self.synth.context_tick=self.clock.to_tick(self.seconds)
        if op=='on':
            pitch,velocity,part=data
            lane=next((channel for channel in self.channels(owner) if (channel,pitch) not in self.occupied),None)
            if lane is None:raise ValueError(f'轨道 {self.keys[owner]} 同音/踏板占用超过{len(self.channels(owner))}个独立通道，未截音')
            item=dict(owner=owner,lane=lane,pitch=pitch,velocity=velocity,down=True,sostenuto=False,program=state['program'])
            self.active[identifier]=item;self.occupied[lane,pitch]=identifier
            if audible:self.synth.on(self.synth.synth,lane,pitch,velocity);self.note_ons+=1
        elif op=='off':
            item=self.active.get(identifier)
            if item:
                item['down']=False
                if audible:self.synth.off(self.synth.synth,item['lane'],item['pitch'])
                self.release_finished(owner)
        else:
            kind=data['type']
            if kind=='program_change':
                state['program']=data['program']
                if audible:
                    for channel in self.channels(owner):self.synth.program(self.synth.synth,channel,data['program'])
            elif kind=='pitchwheel':
                state['bend']=data['pitch']+8192
                if audible:
                    for channel in self.channels(owner):self.synth.bend(self.synth.synth,channel,state['bend'])
            elif kind=='control_change':
                cc,value=data['control'],data['value'];previous=state['cc'].get(cc,0)
                if cc==66 and value>=64 and previous<64:
                    for item in self.active.values():
                        if item['owner']==owner:item['sostenuto']=item['down']
                if cc==66 and value<64:
                    for item in self.active.values():
                        if item['owner']==owner:item['sostenuto']=False
                state['cc'][cc]=value
                if cc in (120,123):
                    for item in self.active.values():
                        if item['owner']==owner:item['down']=False
                if cc==120:
                    self.active={identifier:item for identifier,item in self.active.items() if item['owner']!=owner}
                if cc==121:
                    state['cc'].clear();state['bend']=8192
                    for item in self.active.values():
                        if item['owner']==owner:item['sostenuto']=False
                if audible:
                    for channel in self.channels(owner):self.synth.cc(self.synth.synth,channel,cc,value)
                self.release_finished(owner)
            elif kind in ('aftertouch','polytouch'):
                lib=getattr(self.synth,'lib',None)
                fn=getattr(lib,'fluid_synth_channel_pressure' if kind=='aftertouch' else 'fluid_synth_key_pressure',None) if audible else None
                if fn:
                    fn.argtypes=[C.c_void_p,C.c_int,C.c_int] if kind=='aftertouch' else [C.c_void_p,C.c_int,C.c_int,C.c_int]
                    for channel in self.channels(owner):fn(self.synth.synth,channel,*([data['note']] if kind=='polytouch' else []),data['value'])

    def release_finished(self,owner):
        pedal=self.states[owner]['cc'].get(64,0)>=64
        for identifier,item in list(self.active.items()):
            if item['owner']==owner and not item['down'] and not pedal and not item['sostenuto']:
                self.active.pop(identifier);self.occupied.pop((item['lane'],item['pitch']),None)

    def seek(self,tick):
        self.reset();self.seconds=self.clock.to_seconds(tick);self.index=0
        # 严格处理目标之前的事件，目标上的事件由下一块恰好执行一次。
        while self.index<len(self.events) and self.events[self.index][0]<self.seconds-1e-10:
            self.apply(self.events[self.index],False);self.index+=1
        for owner,state in self.states.items():
            for channel in self.channels(owner):
                for cc,value in state['cc'].items():
                    if cc not in (64,66,120,121,123):self.synth.cc(self.synth.synth,channel,cc,value)
                self.synth.bend(self.synth.synth,channel,state['bend'])
            items=[v for v in self.active.values() if v['owner']==owner]
            for captured in (True,False):
                for item in items:
                    if item['sostenuto']==captured:
                        self.synth.program(self.synth.synth,item['lane'],item['program'])
                        self.synth.on(self.synth.synth,item['lane'],item['pitch'],item['velocity'])
                if captured and state['cc'].get(66,0)>=64:
                    for channel in self.channels(owner):self.synth.cc(self.synth.synth,channel,66,state['cc'][66])
            for channel in self.channels(owner):
                self.synth.cc(self.synth.synth,channel,64,state['cc'].get(64,0));self.synth.program(self.synth.synth,channel,state['program'])
            for item in items:
                if not item['down']:self.synth.off(self.synth.synth,item['lane'],item['pitch'])

    def block(self,count):
        out=np.zeros((len(self.keys),2,count),np.float32);offset=0
        while offset<count:
            if self.loop and self.seconds>=self.loop[1]-1e-10:self.seek(self.clock.to_tick(self.loop[0]))
            while self.index<len(self.events) and self.events[self.index][0]<=self.seconds+1e-10:
                self.apply(self.events[self.index]);self.index+=1
            boundary=self.events[self.index][0] if self.index<len(self.events) else float('inf')
            if self.loop:boundary=min(boundary,self.loop[1])
            length=min(count-offset,max(1,math.ceil((boundary-self.seconds)*self.sample_rate/self.rate-1e-8))) if math.isfinite(boundary) else count-offset
            if hasattr(self.synth,'context_tick'):self.synth.context_tick=self.clock.to_tick(self.seconds)
            planes=self.synth.block(length)[:len(self.keys)]
            if self.section:
                for owner in range(len(self.keys)):
                    role=self.song.source_tracks[owner].device_part if self.song.source_tracks else owner
                    if role not in (0,1,2,3):continue
                    s=self.section
                    factor=0 if s.mute&(1<<role) or s.solo and not s.solo&(1<<role) else s.volumes[role]/100
                    planes[owner]*=factor
            out[:,:,offset:offset+length]=planes
            self.seconds+=length/self.sample_rate*self.rate;offset+=length
        return out

    def close(self):self.synth.close()


class ModelSynth:
    """设备参数的浮点参考模型：逐块保留相位/包络，不冒充FPGA定点或声部分配结果。"""
    def __init__(self,groups,sample_rate,song,patches):
        self.groups=groups;self.sample_rate=sample_rate;self.song=song;self.patches=patches
        self.voices={};self.time=0.;self.context_tick=0;self.synth=self;self.programs={};self.pedals={};self.drum_channels=set()
        self.bends={};self.controllers={}
    def kind(self,_,channel,kind):
        if kind:self.drum_channels.add(channel)
        else:self.drum_channels.discard(channel)
    def program(self,_,channel,program):self.programs[channel]=program
    def bend(self,_,channel,value):self.bends[channel]=value
    def alloff(self,_,channel):
        for key in list(self.voices):
            if key[0]==channel:self.voices.pop(key)
    def cc(self,_,channel,control,value):
        previous=self.controllers.get((channel,control),0)
        self.controllers[channel,control]=value
        if control==66:
            for (lane,_),voice in self.voices.items():
                if lane==channel:
                    if value>=64 and previous<64:voice['sostenuto']=not voice.get('released',False)
                    elif value<64:voice['sostenuto']=False
        if control in (120,123):
            if control==120:self.alloff(self,channel)
            else:
                for key in list(self.voices):
                    if key[0]==channel:self.off(self,*key)
        if control in (64,66,121):
            if control!=66:self.pedals[channel]=value>=64 if control==64 else False
            if control==121:
                for (lane,_),voice in self.voices.items():
                    if lane==channel:voice['sostenuto']=False
                for key in list(self.controllers):
                    if key[0]==channel:self.controllers.pop(key)
                self.bends[channel]=8192
            for key,v in self.voices.items():
                if key[0]==channel and v.get('released') and v['off'] is None and not self.pedals.get(channel,False) and not v.get('sostenuto',False):v['off']=self.time
    def on(self,_,channel,pitch,velocity):
        owner=channel%self.groups;role=self.song.source_tracks[owner].device_part if self.song.source_tracks else owner
        if role not in (0,1,2,3):raise ValueError('设备模型试听需要先映射源轨道到设备角色')
        section=next((s for s in self.song.sections if s.start<=self.context_tick<s.end),None)
        bank=section.timbres[role] if section else 0
        parameters=(512,8,600,64) if bank==0 else (64,8,3072,32);table=None
        if bank>=2 and role!=3:
            if bank-2>=len(self.patches):raise ValueError('设备模型缺少配器引用的波表')
            p=self.patches[bank-2];p.validate();parameters=(p.attack,p.decay,p.sustain,p.release);table=np.asarray(p.waveform,np.float32)/32768
        sounding=pitch+(section.transpose if section and role!=3 else 0)
        self.voices[channel,pitch]=dict(start=self.time,off=None,pitch=sounding,velocity=velocity,params=parameters,
                                       table=table,drum=role==3,released=False,phase=0.,rng=np.random.default_rng(channel*1000003+pitch+round(self.time*self.sample_rate)))
    def off(self,_,channel,pitch):
        v=self.voices.get((channel,pitch))
        if v:
            v['released']=True
            if not self.pedals.get(channel,False) and not v.get('sostenuto',False):v['off']=self.time
    def block(self,count):
        out=np.zeros((self.groups,2,count),np.float32);dt=np.arange(count)/self.sample_rate
        for key,v in list(self.voices.items()):
            channel,pitch=key;t=self.time+dt-v['start'];bend=(self.bends.get(channel,8192)-8192)/8192*2
            freq=440*2**((v['pitch']+bend-69)/12);phase=np.remainder(v['phase']+dt*freq,1);v['phase']=(v['phase']+count/self.sample_rate*freq)%1
            if v['drum']:
                signal=np.sin(2*np.pi*(48*t+5*(1-np.exp(-28*t))))*np.exp(-14*t) if pitch in (35,36) else v['rng'].uniform(-1,1,count)*np.exp(-(35 if pitch in (42,44,46) else 18)*t)
                signal*=np.minimum(1,t/.001)
                finished=t[-1]>.7
            else:
                if v['table'] is not None:
                    position=phase*256;index=position.astype(np.int32);weight=position-index
                    signal=v['table'][index]*(1-weight)+v['table'][(index+1)&255]*weight
                elif v['params'][0]==512:signal=1-4*np.abs(phase-.5)+.25*(1-4*np.abs(np.remainder(phase*2,1)-.5))
                else:signal=np.sin(2*np.pi*phase)+.18*np.sin(4*np.pi*phase)+.08*np.sin(6*np.pi*phase)
                held=v['off']-v['start'] if v['off'] is not None else float('inf')
                signal*=_envelope(t,held,v['params']);finished=v['off'] is not None and self.time+dt[-1]>v['off']+4095/(max(1,v['params'][3])*FS)
            expression=self.controllers.get((channel,7),100)/100*self.controllers.get((channel,11),127)/127
            signal=(signal*v['velocity']/127*.12*expression).astype(np.float32)
            out[channel%self.groups,0]+=signal;out[channel%self.groups,1]+=signal
            if finished:self.voices.pop(key,None)
        self.time+=count/self.sample_rate;return out
    def close(self):self.voices.clear()
