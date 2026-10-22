"""可编辑钢琴卷帘与四声部概览。坐标使用歌曲 tick，修改由主窗口统一记入撤销栈。"""
from __future__ import annotations

import math
from PySide6.QtCore import Qt, Signal, QRectF
from PySide6.QtGui import QColor, QPainter, QPen, QFont
from PySide6.QtWidgets import QAbstractScrollArea, QWidget

from .music_project import PARTS

COLORS = ('#59d6bb', '#69a8fa', '#bca0f4', '#f0b66b')
NAMES = ('C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B')


def note_name(pitch): return f'{NAMES[pitch%12]}{pitch//12-1}'


class TrackOverview(QWidget):
    seekRequested = Signal(int)
    clipEdited = Signal(int,int,int,int,bool)

    def __init__(self, parent=None):
        super().__init__(parent); self.song=None; self.tick=0; self.muted=set(); self.solo=set()
        self.drag_clip=None;self.track_offset=0
        self.setFixedHeight(108); self.setToolTip('点击定位试听；拖动片段移动，Ctrl+拖动复制；颜色对应四个声部')

    def paintEvent(self, event):
        p=QPainter(self); p.fillRect(self.rect(), QColor('#111e2b'))
        if not self.song: return
        left=84; scale=max(1,self.width()-left-8)/max(1,self.song.duration)
        for section in self.song.sections:
            x=left+section.start*scale; width=(section.end-section.start)*scale
            p.fillRect(QRectF(x,0,width-1,24), QColor('#23374a')); p.setPen(QColor('#afc6d9'))
            p.drawText(QRectF(x+5,0,max(0,width-8),24), Qt.AlignmentFlag.AlignVCenter, section.name)
        if self.song.source_tracks:
            visible=max(1,(self.height()-26)//24);self.track_offset=min(self.track_offset,max(0,len(self.song.source_tracks)-visible))
            for row,track in enumerate(self.song.source_tracks[self.track_offset:self.track_offset+visible]):
                y=26+row*24;color=COLORS[(self.track_offset+row)%len(COLORS)]
                p.setPen(QColor(color));p.drawText(QRectF(3,y,left-6,22),Qt.AlignmentFlag.AlignVCenter,p.fontMetrics().elidedText(track.name,Qt.TextElideMode.ElideRight,left-8))
                p.fillRect(QRectF(left,y,self.width()-left,23),QColor('#182a39'))
                for note in self.song.notes:
                    if note.track_id==track.track_id:p.fillRect(QRectF(left+note.start*scale,y+2+(127-note.pitch)*.1,max(1,(note.end-note.start)*scale),3),QColor(color))
            x=left+self.tick*scale;p.setPen(QColor('#ffdc8d'));p.drawLine(round(x),0,round(x),self.height());return
        for i, name in enumerate(PARTS):
            y=26+i*20; p.setPen(QColor(COLORS[i])); p.drawText(9,y+15,name)
            p.fillRect(QRectF(left,y,self.width()-left,19),QColor('#182a39' if i%2==0 else '#142433'))
            for n in self.song.notes:
                if n.part!=i: continue
                opacity=.22 if i in self.muted or (self.solo and i not in self.solo) else .8
                color=QColor(COLORS[i]); color.setAlphaF(opacity)
                p.fillRect(QRectF(left+n.start*scale,y+1+(127-n.pitch)*.10,max(1,(n.end-n.start)*scale),3), color)
        p.setPen(QPen(QColor('#f5f9ff'),1.5)); x=left+self.tick*scale; p.drawLine(round(x),0,round(x),self.height())
        if self.drag_clip:
            d=self.drag_clip;p.setPen(QPen(QColor('#ffdc8d'),2));p.setBrush(QColor(255,220,141,50))
            p.drawRect(QRectF(left+d['target']*scale,26+d['part']*20,(d['end']-d['start'])*scale,19))

    def mousePressEvent(self,event):
        if not self.song or event.position().x()<84:return
        tick=max(0,round((event.position().x()-84)/max(1,self.width()-92)*self.song.duration));part=int((event.position().y()-26)//20)
        if self.song.source_tracks:self.seekRequested.emit(tick);return
        section=next((s for s in self.song.sections if s.start<=tick<s.end),None)
        if event.button()==Qt.MouseButton.LeftButton and 0<=part<4 and section:
            self.drag_clip=dict(part=part,start=section.start,end=section.end,target=section.start,x=event.position().x(),copy=bool(event.modifiers()&Qt.KeyboardModifier.ControlModifier),moved=False)
        else:self.seekRequested.emit(tick)
    def mouseMoveEvent(self,event):
        if not self.drag_clip or not self.song:return
        delta=(event.position().x()-self.drag_clip['x'])/max(1,self.width()-92)*self.song.duration
        self.drag_clip['target']=max(0,self.drag_clip['start']+round(delta/self.song.ppqn)*self.song.ppqn)
        self.drag_clip['moved']|=abs(event.position().x()-self.drag_clip['x'])>5;self.update()
    def mouseReleaseEvent(self,event):
        if not self.drag_clip:return
        d=self.drag_clip;self.drag_clip=None
        if d['moved']:self.clipEdited.emit(d['part'],d['start'],d['end'],d['target'],d['copy'])
        elif self.song:self.seekRequested.emit(max(0,round((event.position().x()-84)/max(1,self.width()-92)*self.song.duration)))
        self.update()
    def wheelEvent(self,event):
        if self.song and self.song.source_tracks:
            self.track_offset=max(0,self.track_offset+(-1 if event.angleDelta().y()>0 else 1));self.update();event.accept()
        else:super().wheelEvent(event)


class PianoRoll(QAbstractScrollArea):
    selectionChanged = Signal(object)
    noteEdited = Signal(int,int,int,int,int)
    noteAdded = Signal(int,int,int,int)
    noteDeleted = Signal(int)
    seekRequested = Signal(int)
    zoomChanged = Signal(int)

    LEFT=76; TOP=26; ROW=17; VELOCITY=62

    def __init__(self,parent=None):
        super().__init__(parent)
        self.song=None; self.selected=set(); self.track=-1; self.source_track=None; self.zoom=100; self.snap_division=4
        self.tick=0; self.drag=None; self.muted=set(); self.solo=set()
        self.setMinimumHeight(240); self.setFocusPolicy(Qt.FocusPolicy.StrongFocus)
        self.horizontalScrollBar().valueChanged.connect(lambda:self.viewport().update())
        self.verticalScrollBar().valueChanged.connect(lambda:self.viewport().update())
        self.setToolTip('单击选择；拖动移动音符；拖右端改时长；双击空白加音符；右键删除；下方改力度；Ctrl+滚轮缩放')

    @property
    def ppb(self): return 104*self.zoom/100
    @property
    def snap(self): return max(1,round(self.song.ppqn/self.snap_division)) if self.song and self.snap_division else 1
    @property
    def grid_bottom(self): return self.viewport().height()-self.VELOCITY
    def x(self,tick): return self.LEFT+tick/max(1,self.song.ppqn)*self.ppb-self.horizontalScrollBar().value()
    def y(self,pitch): return self.TOP+(127-pitch)*self.ROW-self.verticalScrollBar().value()
    def tick_at(self,x): return max(0,round(((x-self.LEFT+self.horizontalScrollBar().value())/self.ppb*self.song.ppqn)/self.snap)*self.snap)
    def pitch_at(self,y): return max(0,min(127,127-int((y-self.TOP+self.verticalScrollBar().value())//self.ROW)))
    def note_rect(self,n): return QRectF(self.x(n.start),self.y(n.pitch)+2,max(5,(n.end-n.start)/self.song.ppqn*self.ppb),self.ROW-4)
    def hit(self,pos):
        if not self.song or pos.x()<self.LEFT or pos.y()<self.TOP or pos.y()>=self.grid_bottom:return None
        return next((i for i in reversed(range(len(self.song.notes))) if
                     self.matches(self.song.notes[i]) and self.note_rect(self.song.notes[i]).contains(pos)),None)

    def matches(self,note):
        return note.track_id==self.source_track if self.source_track else self.track<0 or note.part==self.track
    def color(self,note):
        if self.song and self.song.source_tracks:
            index=next((i for i,t in enumerate(self.song.source_tracks) if t.track_id==note.track_id),0)
            return COLORS[index%len(COLORS)]
        return COLORS[note.part]
    def is_muted(self,note):
        if self.song and self.song.source_tracks:
            track=next((t for t in self.song.source_tracks if t.track_id==note.track_id),None)
            return track is None or track.preview_muted or any(t.preview_solo for t in self.song.source_tracks) and not track.preview_solo
        return note.part in self.muted or self.solo and note.part not in self.solo

    def set_song(self,song):
        changed=not self.song or not song or self.song.resource_id!=song.resource_id
        self.song=song; self.selected={i for i in self.selected if song and i<len(song.notes)}; self.drag=None
        self.update_ranges()
        if changed:
            self.selected=set(); self.horizontalScrollBar().setValue(0); self.tick=0
            center=sum(n.pitch for n in song.notes)/len(song.notes) if song and song.notes else 64
            self.verticalScrollBar().setValue(round((127-center)*self.ROW-max(0,self.grid_bottom-self.TOP)/2))
        self.viewport().update()

    def update_ranges(self):
        duration=(self.song.duration/self.song.ppqn+4) if self.song else 16
        self.horizontalScrollBar().setRange(0,max(0,round(duration*self.ppb-self.viewport().width()+self.LEFT)))
        self.horizontalScrollBar().setPageStep(max(1,self.viewport().width()-self.LEFT))
        self.verticalScrollBar().setRange(0,max(0,128*self.ROW-max(1,self.grid_bottom-self.TOP)))
        self.verticalScrollBar().setPageStep(max(1,self.grid_bottom-self.TOP))

    def resizeEvent(self,event): super().resizeEvent(event); self.update_ranges()
    def set_zoom(self,value):
        center=(self.horizontalScrollBar().value()+max(0,self.viewport().width()-self.LEFT)/2)/self.ppb
        self.zoom=value; self.update_ranges(); self.horizontalScrollBar().setValue(round(center*self.ppb-max(0,self.viewport().width()-self.LEFT)/2)); self.viewport().update()
    def set_tick(self,tick,follow=False):
        self.tick=tick
        if self.song and follow:
            x=self.x(tick)
            if x>self.viewport().width()-35 or x<self.LEFT:
                self.horizontalScrollBar().setValue(round(tick/self.song.ppqn*self.ppb-90))
        self.viewport().update()

    def ensure_note_visible(self,row):
        if not self.song or not 0<=row<len(self.song.notes):return
        n=self.song.notes[row];rect=self.note_rect(n)
        if rect.top()<self.TOP or rect.bottom()>self.grid_bottom:
            self.verticalScrollBar().setValue(round((127-n.pitch)*self.ROW-max(0,self.grid_bottom-self.TOP)/2))
        if rect.right()<self.LEFT or rect.left()>self.viewport().width():
            self.horizontalScrollBar().setValue(round(n.start/self.song.ppqn*self.ppb-40))

    def paintEvent(self,event):
        p=QPainter(self.viewport()); p.fillRect(self.viewport().rect(),QColor('#111c29'))
        w=self.viewport().width(); bottom=self.grid_bottom
        p.setFont(QFont('Microsoft YaHei UI',9))
        if not self.song:
            p.setPen(QColor('#8aa0b5'));p.drawText(self.viewport().rect(),Qt.AlignmentFlag.AlignCenter,'导入 PDF／图片、MIDI 或 MusicXML，开始编曲与校谱');return
        p.save(); p.setClipRect(self.LEFT,self.TOP,w-self.LEFT,max(0,bottom-self.TOP))
        for pitch in range(128):
            y=self.y(pitch)
            if y+self.ROW<self.TOP or y>bottom:continue
            black=pitch%12 in (1,3,6,8,10)
            p.fillRect(QRectF(self.LEFT,y,w-self.LEFT,self.ROW),QColor('#142130' if black else '#1a2938'))
            p.setPen(QColor('#344759' if pitch%12==0 else '#233343')); p.drawLine(self.LEFT,round(y+self.ROW),w,round(y+self.ROW))
        grid_division=max(1,self.snap_division)
        start=max(0,int(self.horizontalScrollBar().value()/self.ppb*grid_division))
        end=math.ceil((self.horizontalScrollBar().value()+w)/self.ppb*grid_division)
        bars=self.song.bar_markers()
        for step in range(start,end+1):
            tick=step*self.song.ppqn/grid_division; x=self.x(tick)
            p.setPen(QColor('#344454' if step%grid_division==0 else '#243545'))
            p.drawLine(round(x),self.TOP,round(x),bottom)
        p.setPen(QColor('#526373'))
        for tick,_ in bars:
            x=self.x(tick)
            if self.LEFT<=x<=w:p.drawLine(round(x),self.TOP,round(x),bottom)
        for i,n in enumerate(self.song.notes):
            if not self.matches(n):continue
            rect=self.note_rect(n)
            if self.drag and self.drag['index']==i:
                start,end,pitch,velocity=self.drag['values']; rect=QRectF(self.x(start),self.y(pitch)+2,max(5,(end-start)/self.song.ppqn*self.ppb),self.ROW-4)
            if not rect.intersects(QRectF(self.LEFT,self.TOP,w-self.LEFT,bottom-self.TOP)):continue
            color=QColor(self.color(n)); color.setAlpha(75 if self.is_muted(n) else 130+n.velocity)
            p.setBrush(color); p.setPen(QPen(QColor('#ffffff' if i in self.selected else '#e6b765' if n.uncertain else self.color(n)),2 if i in self.selected else 1))
            p.drawRoundedRect(rect,3,3)
            if rect.width()>32:
                p.setPen(QColor('#10212d')); p.drawText(rect.adjusted(5,0,-3,0),Qt.AlignmentFlag.AlignVCenter,note_name(n.pitch))
            if n.uncertain and rect.width()>10:
                p.setPen(QColor('#ffe1a4')); p.drawLine(round(rect.right()-4),round(rect.top()+3),round(rect.right()-4),round(rect.top()+6))
        p.restore()
        # 固定琴键、标尺、力度区不随音符内容滚动。
        p.fillRect(0,self.TOP,self.LEFT,max(0,bottom-self.TOP),QColor('#25394a'))
        for pitch in range(128):
            y=self.y(pitch)
            if y<self.TOP or y+self.ROW>bottom:continue
            black=pitch%12 in (1,3,6,8,10)
            p.fillRect(QRectF(0,y,self.LEFT-1,self.ROW-1),QColor('#13212e' if black else '#c5d4de'))
            p.setPen(QColor('#b7c9d8' if black else '#304559'));p.drawText(QRectF(6,y,self.LEFT-8,self.ROW),Qt.AlignmentFlag.AlignVCenter,note_name(pitch))
        p.fillRect(0,0,w,self.TOP,QColor('#283d4e'));p.setPen(QColor('#d8e8f2'));p.drawText(9,20,'小节 / 拍')
        for tick,label in bars:
            x=self.x(tick)
            if self.LEFT<=x<=w:p.drawText(round(x+5),20,label)
        p.fillRect(0,bottom,w,self.VELOCITY,QColor('#0e1925'));p.setPen(QColor('#8aa7bd'));p.drawText(12,bottom+20,'力度')
        p.save();p.setClipRect(self.LEFT,bottom,w-self.LEFT,self.VELOCITY)
        for i,n in enumerate(self.song.notes):
            if not self.matches(n):continue
            x=self.x(n.start)
            if self.LEFT<=x<=w:
                velocity=self.drag['values'][3] if self.drag and self.drag['index']==i else n.velocity
                p.setPen(QPen(QColor('#ffffff' if i in self.selected else self.color(n)),3 if i in self.selected else 2))
                p.drawLine(round(x+2),bottom+self.VELOCITY-8,round(x+2),round(bottom+self.VELOCITY-8-velocity/127*(self.VELOCITY-18)))
        p.restore()
        x=self.x(self.tick)
        if x>=self.LEFT:
            p.setPen(QPen(QColor('#ffdc8d'),2));p.drawLine(round(x),self.TOP,round(x),self.viewport().height())

    def mousePressEvent(self,event):
        if not self.song:return
        self.setFocus();pos=event.position()
        if pos.y()<self.TOP and pos.x()>=self.LEFT:self.seekRequested.emit(self.tick_at(pos.x()));return
        row=self.hit(pos)
        if row is None and pos.y()>=self.grid_bottom and pos.x()>=self.LEFT:
            candidates=[i for i,n in enumerate(self.song.notes) if self.matches(n) and abs(self.x(n.start)-pos.x())<9]
            row=next((i for i in candidates if i in self.selected),candidates[-1] if candidates else None)
            if row is not None:
                n=self.song.notes[row];self.selected={row};self.selectionChanged.emit([row]);self.drag=dict(index=row,mode='velocity',origin=pos,values=[n.start,n.end,n.pitch,n.velocity],original=[n.start,n.end,n.pitch,n.velocity]);self.mouseMoveEvent(event)
            return
        if row is None:
            self.selected=set();self.selectionChanged.emit([]);self.viewport().update();return
        if event.button()==Qt.MouseButton.RightButton:self.noteDeleted.emit(row);return
        if event.button()!=Qt.MouseButton.LeftButton:return
        if event.modifiers()&Qt.KeyboardModifier.ControlModifier:
            self.selected.symmetric_difference_update({row});self.selectionChanged.emit(sorted(self.selected));self.viewport().update();return
        self.selected={row};self.selectionChanged.emit([row]);n=self.song.notes[row]
        mode='resize' if self.note_rect(n).right()-pos.x()<8 else 'move'
        self.drag=dict(index=row,mode=mode,origin=pos,values=[n.start,n.end,n.pitch,n.velocity],original=[n.start,n.end,n.pitch,n.velocity]);self.viewport().update()

    def mouseMoveEvent(self,event):
        if not self.drag:return
        d=self.drag;start,end,pitch,velocity=d['original'];pos=event.position()
        delta=round((pos.x()-d['origin'].x())/self.ppb*self.song.ppqn/self.snap)*self.snap
        if d['mode']=='resize':end=max(start+self.snap,end+delta)
        elif d['mode']=='velocity':velocity=max(1,min(127,round((self.viewport().height()-8-pos.y())/(self.VELOCITY-18)*127)))
        else:
            delta=max(-start,delta);start+=delta;end+=delta;pitch=max(0,min(127,pitch-round((pos.y()-d['origin'].y())/self.ROW)))
        d['values']=[start,end,pitch,velocity];self.viewport().update()

    def mouseReleaseEvent(self,event):
        if not self.drag:return
        d=self.drag;self.drag=None
        if d['values']!=d['original']:self.noteEdited.emit(d['index'],*d['values'])
        self.viewport().update()

    def mouseDoubleClickEvent(self,event):
        if self.song and event.button()==Qt.MouseButton.LeftButton and self.hit(event.position()) is None and self.LEFT<=event.position().x() and self.TOP<=event.position().y()<self.grid_bottom:
            start=self.tick_at(event.position().x());self.noteAdded.emit(start,start+self.song.ppqn,self.pitch_at(event.position().y()),max(0,self.track))

    def wheelEvent(self,event):
        if event.modifiers()&Qt.KeyboardModifier.ControlModifier:
            value=max(25,min(300,self.zoom+(10 if event.angleDelta().y()>0 else -10)));self.set_zoom(value);self.zoomChanged.emit(value);event.accept()
        else:super().wheelEvent(event)

    def keyPressEvent(self,event):
        if len(self.selected)==1 and self.song:
            row=next(iter(self.selected));n=self.song.notes[row];key=event.key()
            if key==Qt.Key.Key_Delete:self.noteDeleted.emit(row);return
            delta={Qt.Key.Key_Left:-self.snap,Qt.Key.Key_Right:self.snap}.get(key,0)
            shift={Qt.Key.Key_Up:1,Qt.Key.Key_Down:-1}.get(key,0)
            if delta or shift:
                delta=max(-n.start,delta);self.noteEdited.emit(row,n.start+delta,n.end+delta,max(0,min(127,n.pitch+shift)),n.velocity);return
        super().keyPressEvent(event)
