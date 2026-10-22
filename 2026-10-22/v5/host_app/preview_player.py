"""Qt 本机试听控制器；异步渲染与 USB 任务分开排队，取消后丢弃过期结果。"""
from __future__ import annotations
import copy
import threading

from PySide6.QtCore import QObject, Signal, QRunnable, QThreadPool, QUrl
from PySide6.QtMultimedia import QMediaPlayer, QAudioOutput, QMediaDevices

from .preview_audio import TempoMap, render_preview


class RenderSignals(QObject):
    ready = Signal(int, object)
    failed = Signal(int, str)


class RenderTask(QRunnable):
    def __init__(self, number, cancel, song, patches, muted, solo, engine='model',soundfont=None):
        super().__init__(); self.number=number; self.cancel=cancel
        self.args=(song, patches); self.options=dict(muted=muted, solo=solo, cancel=cancel)
        self.engine=engine;self.soundfont=soundfont
        self.signals=RenderSignals()

    def run(self):
        try:
            if self.engine=='reference':
                from .reference_audio import render_reference
                result=render_reference(*self.args,**self.options,soundfont=self.soundfont)
            else:result=render_preview(*self.args, **self.options)
            self.signals.ready.emit(self.number,result)
        except InterruptedError: pass
        except Exception as exc: self.signals.failed.emit(self.number, str(exc))


class PreviewPlayer(QObject):
    positionChanged = Signal(float)
    messageChanged = Signal(str)
    error = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent); self.pool=QThreadPool(self); self.pool.setMaxThreadCount(1)
        self.media=None; self.audio=None; self.clock=None; self.cancel=None; self.generation=0
        self.rendering=False; self.ready=False; self.cursor=0; self.duration_tick=0
        self.rate=1.; self.volume=.45; self.output_device=None; self.loop_range=None; self.awaiting_load=False

    def ensure_media(self):
        if not QMediaDevices.audioOutputs(): raise ValueError('未找到电脑音频输出，请连接扬声器或耳机后重试')
        if self.media is None:
            self.audio=QAudioOutput(self); self.audio.setVolume(self.volume)
            if self.output_device is not None:self.audio.setDevice(self.output_device)
            self.media=QMediaPlayer(self); self.media.setAudioOutput(self.audio)
            if hasattr(self.media,'setPitchCompensation'):self.media.setPitchCompensation(True)
            self.media.positionChanged.connect(self._position)
            self.media.mediaStatusChanged.connect(self._media_status)
            self.media.playbackStateChanged.connect(self._state)
            self.media.errorOccurred.connect(lambda code,text:self.error.emit('电脑音频播放失败：'+text))

    def play(self, song, patches, muted=(), solo=(), loop_range=None,engine='model',soundfont=None):
        self.stop(reset=False); self.clock=TempoMap(song); self.duration_tick=song.duration
        self.ensure_media(); self.rendering=True; self.loop_range=loop_range
        self.cancel=threading.Event(); number=self.generation
        task=RenderTask(number,self.cancel,copy.deepcopy(song),copy.deepcopy(patches),set(muted),set(solo),engine,soundfont)
        task.signals.ready.connect(self._ready); task.signals.failed.connect(self._failed)
        self.messageChanged.emit('正在准备本机试听…'); self.pool.start(task)

    def _ready(self,number,result):
        if number!=self.generation:return
        self.rendering=False; self.ready=True; self.awaiting_load=True
        self.media.setPlaybackRate(self.rate); self.media.setSource(QUrl.fromLocalFile(str(result.path)))

    def _failed(self,number,text):
        if number!=self.generation:return
        self.rendering=False; self.messageChanged.emit('试听准备失败'); self.error.emit(text)

    def _media_status(self,status):
        if self.awaiting_load and status==QMediaPlayer.MediaStatus.LoadedMedia:
            self.awaiting_load=False; self.media.setPosition(round(self.clock.to_seconds(self.cursor)*1000)); self.media.play()
        elif status==QMediaPlayer.MediaStatus.EndOfMedia:
            if self.loop_range:
                self.seek(self.loop_range[0]); self.media.play()
            else:self.messageChanged.emit('本机试听结束')

    def _state(self,state):
        text={QMediaPlayer.PlaybackState.PlayingState:'本机试听中', QMediaPlayer.PlaybackState.PausedState:'本机试听已暂停'}
        if state in text:self.messageChanged.emit(text[state])

    def _position(self,milliseconds):
        if not self.ready or self.awaiting_load or not self.clock:return
        self.cursor=min(self.duration_tick,self.clock.to_tick(milliseconds/1000))
        if self.loop_range and self.cursor>=self.loop_range[1] and self.media.playbackState()==QMediaPlayer.PlaybackState.PlayingState:
            self.seek(self.loop_range[0]); return
        self.positionChanged.emit(self.cursor)

    def seek(self,tick):
        self.cursor=max(0,min(self.duration_tick,tick))
        if self.ready and not self.awaiting_load and self.media:self.media.setPosition(round(self.clock.to_seconds(self.cursor)*1000))
        self.positionChanged.emit(self.cursor)

    def pause_resume(self):
        if self.media and self.ready:
            if self.media.playbackState()==QMediaPlayer.PlaybackState.PlayingState:self.media.pause()
            else:self.media.play()

    def stop(self,reset=True):
        self.generation+=1
        if self.cancel:self.cancel.set()
        self.rendering=False; self.awaiting_load=False; self.ready=False
        if self.media:self.media.stop();self.media.setSource(QUrl())
        if reset:self.cursor=0;self.positionChanged.emit(0)
        self.messageChanged.emit('本机试听已停止')

    def invalidate(self):
        active=self.ready or self.rendering; self.stop(reset=False)
        if active:self.messageChanged.emit('音符或配器已修改，请重新试听')

    def set_rate(self,value):
        self.rate=value/100
        if self.media:self.media.setPlaybackRate(self.rate)

    def set_volume(self,value):
        self.volume=value/100
        if self.audio:self.audio.setVolume(self.volume)

    def set_output(self,device):
        self.output_device=device
        if self.audio and device is not None:self.audio.setDevice(device)

    def shutdown(self):
        self.stop(); self.pool.waitForDone(1000)
