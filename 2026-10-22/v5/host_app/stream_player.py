"""子进程合成＋Qt原生推写缓冲。音频线程不执行Python合成或等待IPC。"""
from __future__ import annotations
import multiprocessing as mp
from multiprocessing import shared_memory
import queue
import time
import traceback
import numpy as np
from PySide6.QtCore import QObject, QThread, QTimer, Qt, Signal, Slot
from PySide6.QtMultimedia import QAudioSink, QAudioFormat, QMediaDevices
from .stream_synth import owners, mix_values, BlockMixer

BLOCK=256
SLOTS=8


def synth_worker(name, shape, free, ready, pipe, song, patches, engine, font, rate, sample_rate, tick, loop, epoch):
    """free/ready队列发布完整块；旧epoch的块由消费者回收，不写入新播放流。"""
    memory=None;stream=None;paused=False
    try:
        from .stream_synth import EventStream, ModelSynth, FluidSynth
        memory=shared_memory.SharedMemory(name=name);array=np.ndarray(shape,np.float32,buffer=memory.buf)
        factory=FluidSynth if engine=='reference' else lambda n,s,f:ModelSynth(n,s,song,patches)
        stream=EventStream(song,sample_rate,font,factory);stream.rate=rate;stream.seek(tick)
        stream.loop=tuple(stream.clock.to_seconds(v) for v in loop) if loop else None
        pipe.send(('ready',epoch))
        while True:
            while pipe.poll():
                command=pipe.recv();op=command[0]
                if op=='close':return
                if op=='pause':paused=command[1]
                elif op=='seek':epoch,tick=command[1:];stream.seek(tick)
                elif op=='rate':epoch,tick,stream.rate=command[1:];stream.seek(tick)
                elif op=='loop':stream.loop=tuple(stream.clock.to_seconds(v) for v in command[1]) if command[1] else None
            if paused:time.sleep(.005);continue
            try:slot=free.get(timeout=.02)
            except queue.Empty:continue
            start=min(song.duration,stream.clock.to_tick(stream.seconds));array[slot]=stream.block(BLOCK)
            end=min(song.duration,stream.clock.to_tick(stream.seconds))
            final=not stream.loop and stream.seconds>=stream.end+.35
            ready.put((slot,epoch,start,end,final))
            if final:
                paused=True
    except (EOFError,BrokenPipeError):pass
    except BaseException as exc:
        try:pipe.send(('error',str(exc)+'\n'+traceback.format_exc()[-1000:]))
        except (EOFError,BrokenPipeError):pass
    finally:
        if stream:stream.close()
        if memory:memory.close()
        pipe.close()


class AudioPump(QObject):
    position=Signal(float);message=Signal(str);error=Signal(str);meters=Signal(object);readyChanged=Signal(bool)
    def __init__(self):
        super().__init__();self.sink=None;self.process=None;self.memory=None;self.timer=None
        self.epoch=0;self.pending=b'';self.frame_count=0;self.boundaries=[];self.paused=False
        self.ready_audio=False;self.volume=.45;self.underruns=0;self.last_meter=0.;self.finishing=None

    @Slot(object)
    def begin(self,options):
        self.end();self.options=options;self.epoch+=1;self.paused=False;self.underruns=0;self.finishing=None
        try:
            device=options['device'] or QMediaDevices.defaultAudioOutput()
            if device.isNull():raise ValueError('未找到电脑音频输出，请连接耳机或扬声器')
            fmt=None
            rates=list(dict.fromkeys([device.preferredFormat().sampleRate(),48000,44100]))
            for sample_format in (QAudioFormat.SampleFormat.Float,QAudioFormat.SampleFormat.Int16):
                for rate in rates:
                    candidate=QAudioFormat();candidate.setSampleRate(rate);candidate.setChannelCount(2);candidate.setSampleFormat(sample_format)
                    if device.isFormatSupported(candidate):fmt=candidate;break
                if fmt is not None:break
            if fmt is None:raise ValueError('输出设备不支持44.1/48k等双声道Float32或Int16格式')
            self.format=fmt;self.sink=QAudioSink(device,fmt,self);self.sink.setBufferFrameCount(1024)
            self.sink.setVolume(options['volume']);self.output=None
            self.bytes_per_frame=fmt.bytesPerFrame();self.frame_count=0;self.boundaries=[];self.pending=b''
            self.keys=owners(options['song']);self.mixer=BlockMixer(self.keys,fmt.sampleRate());self.mixer.set(options['mix'])
            self.shape=(SLOTS,len(self.keys),2,BLOCK);size=int(np.prod(self.shape))*4
            self.memory=shared_memory.SharedMemory(create=True,size=size);self.array=np.ndarray(self.shape,np.float32,buffer=self.memory.buf)
            context=mp.get_context('spawn');self.free=context.Queue(SLOTS);self.ready=context.Queue(SLOTS)
            for slot in range(SLOTS):self.free.put(slot)
            self.pipe,child=context.Pipe()
            self.process=context.Process(target=synth_worker,args=(self.memory.name,self.shape,self.free,self.ready,child,
                options['song'],options['patches'],options['engine'],options['font'],options['rate'],fmt.sampleRate(),
                options['tick'],options['loop'],self.epoch),daemon=True)
            self.process.start();child.close();self.ready_audio=False;self._underflowed=False
            self.timer=QTimer(self);self.timer.setTimerType(Qt.TimerType.PreciseTimer);self.timer.setInterval(2);self.timer.timeout.connect(self.pump);self.timer.start()
            self.message.emit(f"音源准备中 · {fmt.sampleRate()}Hz · 实际缓冲{self.sink.bufferFrameCount()}帧")
        except Exception as exc:self.error.emit(str(exc));self.end()

    @Slot(object)
    def command(self,command):
        op=command[0]
        if op=='stop':self.end();return
        if op=='mix':
            if hasattr(self,'mixer'):self.mixer.set(command[1])
            return
        if op=='volume':
            self.volume=command[1]
            if self.sink:self.sink.setVolume(self.volume)
            return
        if not self.process or not self.process.is_alive():return
        if op=='pause':
            self.paused=not self.paused;self.pipe.send(('pause',self.paused))
            if self.sink:self.sink.suspend() if self.paused else self.sink.resume()
            self.message.emit('电脑试听已暂停' if self.paused else '电脑试听中');return
        if op in ('seek','rate'):
            self.epoch+=1;tick=command[1];self.pending=b'';self.boundaries=[];self.frame_count=0;self.finishing=None
            self.sink.reset();self.output=None;self.ready_audio=False
            self.pipe.send((op,self.epoch,*command[1:]));self.position.emit(tick)
        elif op=='loop':self.pipe.send(command)

    @Slot()
    def pump(self):
        try:
            while self.pipe.poll():
                message=self.pipe.recv()
                if message[0]=='error':raise RuntimeError(message[1])
            if self.process.exitcode is not None:raise RuntimeError(f'合成进程退出（{self.process.exitcode}）；工程仍保留')
            if self.paused:return
            if self.output is None:
                self.output=self.sink.start()
                if self.output is None:raise RuntimeError('Qt音频设备启动失败：'+str(self.sink.error()))
            written=0
            while self.sink.framesFree()>0:
                if not self.pending:
                    try:item=self.ready.get_nowait()
                    except queue.Empty:break
                    slot,epoch,start,end,final=item
                    if epoch!=self.epoch:self.free.put(slot);continue
                    planes=self.array[slot].copy();self.free.put(slot)
                    audio=self.mixer.process(planes)
                    if self.format.sampleFormat()==QAudioFormat.SampleFormat.Float:self.pending=audio.astype('<f4').tobytes()
                    else:self.pending=(np.clip(audio,-1,1)*32767).astype('<i2').tobytes()
                    self.boundaries.append((self.frame_count,self.frame_count+BLOCK,start,end))
                    self.frame_count+=BLOCK
                    if final:self.finishing=self.frame_count
                    if time.monotonic()-self.last_meter>.08:
                        self.meters.emit(dict(tracks=self.mixer.peaks,clipped=self.mixer.clipped,underruns=self.underruns));self.last_meter=time.monotonic()
                capacity=self.sink.framesFree()*self.bytes_per_frame
                sent=self.output.write(self.pending[:capacity])
                if sent<0:raise RuntimeError('音频写入失败')
                self.pending=self.pending[sent:];written+=sent
                if not sent:break
            if not self.ready_audio and written:
                self.ready_audio=True;self.readyChanged.emit(True);self.sink.resume()
                self.message.emit(f'电脑实时试听 · {self.format.sampleRate()}Hz · {len(self.keys)}轨')
            if self.ready_audio:
                processed=self.sink.processedUSecs()*self.format.sampleRate()/1e6
                while len(self.boundaries)>1 and self.boundaries[0][1]<=processed:self.boundaries.pop(0)
                if self.boundaries:
                    first,last,start,end=self.boundaries[0];self.position.emit(start+(end-start)*max(0,min(1,(processed-first)/(last-first))))
                if self.finishing is not None and not self.pending and processed>=self.finishing-1:
                    self.end();self.message.emit('电脑试听结束');return
                if self.sink.state().name=='IdleState' and not self.finishing and not self._underflowed:
                    self.underruns+=1;self._underflowed=True
                    self.message.emit(f'输出欠载{self.underruns}次，正在补充缓冲')
                if written:self._underflowed=False
                if self.sink.error().name not in ('NoError','UnderrunError'):raise RuntimeError('音频输出错误：'+str(self.sink.error()))
        except Exception as exc:self.error.emit(str(exc));self.end()

    @Slot()
    def end(self):
        if self.timer:self.timer.stop();self.timer.deleteLater();self.timer=None
        if self.sink:self.sink.reset();self.sink.deleteLater();self.sink=None
        if self.process:
            try:
                if self.process.is_alive():self.pipe.send(('close',));self.process.join(.15)
            except (BrokenPipeError,EOFError,OSError):pass
            if self.process.is_alive():self.process.terminate();self.process.join(.5)
            self.pipe.close();self.process=None
            for q in (self.free,self.ready):q.cancel_join_thread();q.close()
        if self.memory:self.array=None;self.memory.close();self.memory.unlink();self.memory=None
        self.pending=b'';self.ready_audio=False;self.readyChanged.emit(False)


class StreamingPreview(QObject):
    positionChanged=Signal(float);messageChanged=Signal(str);error=Signal(str);metersChanged=Signal(object)
    startRequested=Signal(object);commandRequested=Signal(object)
    def __init__(self,parent=None):
        super().__init__(parent);self.thread=QThread(self);self.pump=AudioPump();self.pump.moveToThread(self.thread)
        self.startRequested.connect(self.pump.begin);self.commandRequested.connect(self.pump.command)
        self.pump.position.connect(self._position);self.pump.message.connect(self.messageChanged);self.pump.error.connect(self.error)
        self.pump.error.connect(self._failed)
        self.pump.readyChanged.connect(self._ready);self.pump.meters.connect(self.metersChanged)
        self.thread.finished.connect(self.pump.deleteLater);self.thread.start()
        self.ready=False;self.rendering=False;self.cursor=0;self.duration_tick=0;self.rate=1.;self.volume=.45
        self.output_device=None;self.clock=None;self._loop_range=None;self.song=None;self.options=None;self.generation=0
    def _position(self,tick):self.cursor=tick;self.positionChanged.emit(tick)
    def _failed(self,text):self.ready=False;self.rendering=False
    def _ready(self,value):self.ready=value;self.rendering=False if value else self.rendering
    @property
    def loop_range(self):return self._loop_range
    @loop_range.setter
    def loop_range(self,value):
        self._loop_range=value
        if self.options:self.commandRequested.emit(('loop',value))
    def play(self,song,patches,muted=(),solo=(),loop_range=None,engine='model',soundfont=None):
        from .preview_audio import TempoMap
        self.stop(False);self.clock=TempoMap(song);self.song=song;self.duration_tick=song.duration;self._loop_range=loop_range
        self.options=dict(song=song,patches=patches,engine=engine,font=soundfont,tick=self.cursor,loop=loop_range,
                          rate=self.rate,volume=self.volume,device=self.output_device,mix=mix_values(song,muted,solo))
        self.rendering=True;self.startRequested.emit(self.options)
    def pause_resume(self):self.commandRequested.emit(('pause',))
    def seek(self,tick):
        self.cursor=max(0,min(self.duration_tick,tick));self.commandRequested.emit(('seek',self.cursor));self.positionChanged.emit(self.cursor)
    def stop(self,reset=True):
        self.generation+=1;self.ready=False;self.rendering=False;self.options=None;self.commandRequested.emit(('stop',))
        if reset:self.cursor=0;self.positionChanged.emit(0)
        self.messageChanged.emit('电脑试听已停止')
    def invalidate(self):
        active=self.ready or self.rendering;self.stop(False)
        if active:self.messageChanged.emit('音符或音色已修改，请重新试听')
    def update_mix(self,song,muted=(),solo=()):self.commandRequested.emit(('mix',mix_values(song,muted,solo)))
    def set_rate(self,value):
        self.rate=value/100
        if self.options:self.commandRequested.emit(('rate',self.cursor,self.rate))
    def set_volume(self,value):self.volume=value/100;self.commandRequested.emit(('volume',self.volume))
    def set_output(self,device):
        if self.ready or self.rendering:self.stop(False)
        self.output_device=device
    def shutdown(self):
        if not self.thread.isRunning():return
        from PySide6.QtCore import QMetaObject
        QMetaObject.invokeMethod(self.pump,'end',Qt.ConnectionType.BlockingQueuedConnection)
        self.thread.quit();self.thread.wait(2000)
