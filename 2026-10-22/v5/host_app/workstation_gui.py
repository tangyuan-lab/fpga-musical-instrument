"""中文演奏工作站。电脑编曲与离线校谱试听；设备演奏仍由 FPGA 独立合成。"""
from __future__ import annotations
import argparse,copy,json,math,sys,time,traceback,threading
from collections import deque
from dataclasses import asdict
from pathlib import Path
from PySide6.QtCore import Qt,QObject,Signal,QRunnable,QThreadPool,QTimer,QRectF,QItemSelectionModel,QUrl,QSettings
from PySide6.QtGui import QPainter,QColor,QPen,QPixmap,QImage,QUndoStack,QUndoCommand,QFontDatabase,QFont,QShortcut,QKeySequence,QDesktopServices
from PySide6.QtMultimedia import QMediaDevices
from PySide6.QtWidgets import (QApplication,QMainWindow,QWidget,QVBoxLayout,QHBoxLayout,QGridLayout,
    QLabel,QPushButton,QComboBox,QTabWidget,QSplitter,QListWidget,QTableWidget,QTableWidgetItem,
    QFileDialog,QMessageBox,QSpinBox,QSlider,QPlainTextEdit,QInputDialog,QCheckBox,QGroupBox,QLineEdit,
    QAbstractItemView,QHeaderView,QScrollArea,QDialog,QDialogButtonBox)
from .music_project import MusicProject,Song,Section,Note,Patch,PARTS,import_midi,import_musicxml,import_patch,generate_accompaniment
from .device_v2 import DeviceV2,FEATURE_EMERGENCY
from .serial_link import list_serial_ports
from .score_import import recognize_staff,recognize_jianpu,page_image,parse_jianpu,download_score
from .piano_roll import PianoRoll,TrackOverview,COLORS,note_name
from .preview_audio import TempoMap,format_time
from .stream_player import StreamingPreview as PreviewPlayer
from .deployment import DeploymentSession
from .stream_synth import audio_identity,mix_values
from .score_document import ensure_document,sync_song,difference,performance_hash
from .notation_view import NotationPanel

STYLE='''QWidget{background:#24272d;color:#e0e4eb;font-family:"Microsoft YaHei UI";font-size:13px}
QGroupBox{border:1px solid #2a3a4b;border-radius:12px;margin-top:18px;padding:14px}QGroupBox::title{subcontrol-origin:margin;left:14px;color:#7bddcf}
QPushButton{background:#353c47;border:1px solid #4b5664;border-radius:4px;padding:4px 8px}QPushButton:hover{background:#48586b}
QPushButton:disabled{color:#647488}QPushButton#primary{background:#126f68;border:1px solid #41c4ae}
QLineEdit,QSpinBox,QComboBox,QPlainTextEdit{background:#182332;border:1px solid #33465a;border-radius:5px;padding:5px}
QTableWidget,QListWidget{background:#131e2c;alternate-background-color:#1b2939;border:1px solid #2a3a4b;selection-background-color:#246b71}
QHeaderView::section{background:#303844;color:#c6d9e8;padding:5px;border:0}QTabBar::tab{padding:6px 12px;background:#2c333d}QTabBar::tab:selected{background:#3a576a}
QToolBar{background:#2c323b;border:0;spacing:4px;padding:3px}QDockWidget::title{background:#303844;padding:5px}QMenuBar,QStatusBar{background:#282e37}QMenu{background:#303844}QMenu::item:selected{background:#405f78}
QSlider::groove:horizontal{height:7px;background:#304458;border-radius:3px}QSlider::sub-page:horizontal{background:#48c9b0}QSlider::handle:horizontal{width:18px;background:#e8fff9;margin:-6px 0;border-radius:8px}
'''

class TaskSignals(QObject):
    result=Signal(object);failed=Signal(str);finished=Signal(bool)
class Task(QRunnable):
    def __init__(self,fn):super().__init__();self.fn=fn;self.signals=TaskSignals()
    def run(self):
        succeeded=False
        try:self.signals.result.emit(self.fn());succeeded=True
        except Exception as exc:self.signals.failed.emit(str(exc))
        finally:self.signals.finished.emit(succeeded)

class Waveform(QWidget):
    def __init__(self):super().__init__();self.samples=[];self.last_point=None;self.setMinimumHeight(180);self.setToolTip('按住鼠标左键绘制单周期波表；保存后由 FPGA 合成')
    def paintEvent(self,event):
        p=QPainter(self);p.setRenderHint(QPainter.RenderHint.Antialiasing);p.fillRect(self.rect(),QColor('#142332'))
        p.setPen(QPen(QColor('#2a4358'),1));p.drawLine(0,self.height()//2,self.width(),self.height()//2)
        if not self.samples:return
        p.setPen(QPen(QColor('#5ee0c0'),2))
        for i in range(1,len(self.samples)):
            p.drawLine(round((i-1)*self.width()/len(self.samples)),round(self.height()/2-self.samples[i-1]*self.height()/70000),
                       round(i*self.width()/len(self.samples)),round(self.height()/2-self.samples[i]*self.height()/70000))
    def edit_point(self,event):
        if not self.samples:return
        index=max(0,min(len(self.samples)-1,round(event.position().x()*len(self.samples)/max(1,self.width()))))
        value=max(-32767,min(32767,round((self.height()/2-event.position().y())*70000/max(1,self.height()))))
        if self.last_point is None or self.last_point[0]==index:self.samples[index]=value
        else:
            old_index,old_value=self.last_point;distance=abs(index-old_index)
            for step in range(distance+1):
                slot=old_index+step*(1 if index>=old_index else -1)
                self.samples[slot]=round(old_value+(value-old_value)*step/max(1,distance))
        self.last_point=index,value;self.update()
    def mousePressEvent(self,event):
        if event.button()==Qt.MouseButton.LeftButton:self.last_point=None;self.edit_point(event)
    def mouseMoveEvent(self,event):
        if event.buttons() & Qt.MouseButton.LeftButton:self.edit_point(event)
    def mouseReleaseEvent(self,event):self.last_point=None

class EditSong(QUndoCommand):
    def __init__(self,window,before,after,label):
        super().__init__(label)
        if after.score_document is None or after.score_document.performance_hash!=performance_hash(after):sync_song(before,after)
        self.w=window;self.before=before;self.after=after;self.resource_id=before.resource_id
    def apply(self,value):
        # 后台识谱完成时用户可能已切换曲目，撤销/重做也必须定位原资源。
        index=next((i for i,song in enumerate(self.w.project.songs) if song.resource_id==self.resource_id),None)
        if index is not None:
            self.w.capture_editor_drafts()
            if self.w.project.songs[index].sections!=value.sections:self.w._section_drafts.pop(self.resource_id,None)
            if index==self.w.song_index and audio_identity(self.w.project.songs[index])!=audio_identity(value):self.w.local_player.invalidate()
            self.w.project.songs[index]=copy.deepcopy(value);self.w.refresh(capture=False)
    def undo(self):self.apply(self.before)
    def redo(self):self.apply(self.after)

class EditProject(QUndoCommand):
    def __init__(self,window,before,after,label):super().__init__(label);self.w=window;self.before=before;self.after=after
    def apply(self,value):
        highwater=dict(self.w.project.publication_versions);self.w.project=copy.deepcopy(value)
        for key,revision in highwater.items():self.w.project.publication_versions[key]=max(revision,self.w.project.publication_versions.get(key,0))
        self.w.song_index=min(self.w.song_index,len(self.w.project.songs)-1);self.w.patch_index=min(self.w.patch_index,len(self.w.project.patches)-1)
        self.w.refresh(capture=False)
    def undo(self):self.apply(self.before)
    def redo(self):self.apply(self.after)

class WorkstationWindow(QMainWindow):
    def __init__(self):
        super().__init__();self.setWindowTitle('FPGA 音乐工作站 V5 · 实时混音与校谱');self.resize(1366,768)
        self.project=MusicProject();self.project_path=None;self.device=None;self.catalog=[];self.song_index=-1;self.patch_index=-1
        self.saved_signature=self.project_signature()
        self.deployment=DeploymentSession();self._mix_before=None;self._last_device_seen=0.;self._patch_drafts={};self._section_drafts={}
        self._shown_patch_id=None;self._shown_song_id=None;self.recognition_cancel=None;self._closing=False
        self.busy=False;self.pending_tasks=deque();self.active_task=None;self.catalog_revision=None;self.refreshing=False;self.dragging=False;self.last_state={};self.pool=QThreadPool(self);self.pool.setMaxThreadCount(1)
        self.emergency_pool=QThreadPool(self);self.emergency_pool.setMaxThreadCount(1);self.emergency_task=None
        self.undo=QUndoStack(self);self.local_player=PreviewPlayer(self);self.local_tick=0
        self.preview_muted=set();self.preview_solo=set();self._local_identity=None
        self._last_preview_target='reference';self._preview_stop_pending=False
        self.settings=QSettings('FPGA-Music','Workstation');self.reference_font=self.settings.value('soundfont','')
        self._build();self.refresh_ports()
        self.component_status()
        self.local_player.positionChanged.connect(self.local_position)
        self.local_player.messageChanged.connect(self.local_message.setText)
        self.local_player.error.connect(lambda text:self.failure('电脑试听',text))
        self.local_player.metersChanged.connect(self.meters_received)
        self.poller=QTimer(self);self.poller.timeout.connect(self.poll);self.poller.start(500)
        self.background_pool=QThreadPool(self);self.background_pool.setMaxThreadCount(1);self.background_tasks=[]
        if self.settings.value('windowGeometry') is not None:self.restoreGeometry(self.settings.value('windowGeometry'))
        if self.settings.value('windowState') is not None:self.restoreState(self.settings.value('windowState'))
        self.autosave_timer=QTimer(self);self.autosave_timer.timeout.connect(self.autosave);self.autosave_timer.start(30000);self._autosave_signature=None
    def run_background(self,label,fn,success):
        task=Task(fn);self.background_tasks.append(task)
        task.signals.result.connect(lambda result:success(result) if not self._closing else None)
        task.signals.failed.connect(lambda text:(self.log_message(text) if '已取消' in text else self.failure(label,text)) if not self._closing else None)
        task.signals.finished.connect(lambda ok:self.background_tasks.remove(task) if task in self.background_tasks else None)
        self.background_pool.start(task);self.log_message(label+'：后台运行，设备控制保持可用')
    def capture_editor_drafts(self):
        if not hasattr(self,'sections') or self.refreshing:return
        patch=next((p for p in self.project.patches if p.resource_id==self._shown_patch_id),None)
        if patch:
            current=(self.patch_name.text(),list(self.waveform.samples),[s.value() for s in self.adsr])
            expected=(patch.name,patch.waveform,[patch.attack,patch.decay,patch.sustain,patch.release])
            if current!=expected:self._patch_drafts[patch.resource_id]=current
            else:self._patch_drafts.pop(patch.resource_id,None)
        song=next((s for s in self.project.songs if s.resource_id==self._shown_song_id),None)
        if song:
            actual=[[self.sections.item(r,c).text() if self.sections.item(r,c) else '' for c in range(14)] for r in range(self.sections.rowCount())]
            expected=[[str(v) for v in [s.name,s.start,s.end,*s.timbres,*s.volumes,s.mute,s.solo,s.live_timbre]] for s in song.sections]
            if actual!=expected:self._section_drafts[song.resource_id]=actual
            else:self._section_drafts.pop(song.resource_id,None)
    def autosave(self):
        if self._closing:return
        self.capture_editor_drafts();snapshot=copy.deepcopy(self.project)
        snapshot.editor_drafts=dict(patches=self._patch_drafts,sections=self._section_drafts)
        signature=json.dumps(asdict(snapshot),sort_keys=True,ensure_ascii=False)
        if signature==self._autosave_signature or not snapshot.songs and not snapshot.patches:return
        try:
            folder=Path(__file__).resolve().parents[1]/'build/autosave';folder.mkdir(parents=True,exist_ok=True)
            name=__import__('hashlib').sha256(str(self.project_path or 'untitled').encode()).hexdigest()[:16]+'.fpgamusic'
            snapshot.save(folder/name);self._autosave_signature=signature
        except Exception as exc:self.log_message('自动恢复副本未保存：'+str(exc))
    def mix_changed(self,key,db,mute,solo):
        if self.refreshing:return
        song=self.current_song()
        if not song:return
        if self._mix_before is None:self._mix_before=copy.deepcopy(song)
        track=next((t for t in song.source_tracks if t.track_id==key),None)
        if track:track.gain_db=db;track.preview_muted=mute;track.preview_solo=solo
        else:song.track_mix[key]=dict(db=db,mute=mute,solo=solo)
        values=mix_values(song);self.track_heads.set_values(values);self.mix_console.set_values(values)
        self.local_player.update_mix(song,self.preview_muted,self.preview_solo);self.roll.viewport().update()
        # bit1仅表示曲谱/配器联合发布，不能把它误判为尚未接入的硬件逐轨混音。
    def mix_finished(self):
        before=self._mix_before;self._mix_before=None;song=self.current_song()
        if before and song and before.resource_id==song.resource_id and before!=song:
            after=copy.deepcopy(song);after.revision+=1;self.undo.push(EditSong(self,before,after,'轨道混音'))
    def meters_received(self,snapshot):
        self.track_heads.set_meters(snapshot);self.mix_console.set_meters(snapshot)
        if snapshot.get('clipped'):self.local_message.setText(f'输出出现削波：{snapshot["clipped"]}块；请降低轨道或总线音量')
    def inspect_track_capacity(self):
        song=self.current_song()
        if not song:self.failure('设备轨道检查','请先选择曲谱');return
        try:
            from .track_compiler import compile_tracks,capacity_text
            result=compile_tracks(song,allow_uncertain=True);text=capacity_text(result)
        except ValueError as exc:self.failure('设备轨道检查',str(exc));return
        dialog=QDialog(self);dialog.setWindowTitle('设备轨道容量检查');dialog.resize(720,480)
        layout=QVBoxLayout(dialog);view=QPlainTextEdit();view.setReadOnly(True);view.setPlainText(text);layout.addWidget(view)
        buttons=QDialogButtonBox(QDialogButtonBox.StandardButton.Close);buttons.rejected.connect(dialog.reject);layout.addWidget(buttons)
        dialog.setAttribute(Qt.WidgetAttribute.WA_DeleteOnClose);dialog.show()
        return result.report()
    def transport_play(self):
        if self.preview_engine.currentData()=='fpga':self.play()
        else:self.play_local()
    def preview_target_changed(self):
        current=self.preview_engine.currentData();previous=self._last_preview_target;self._last_preview_target=current
        self.local_player.invalidate()
        for mixer in (self.track_heads,self.mix_console):
            mixer.setEnabled(current!='fpga')
            mixer.setToolTip('切换到电脑参考或设备模型后可调整逐轨音量' if current=='fpga' else '电脑试听的合成后音量，不改变音符力度')
        if previous=='fpga' and current!='fpga' and self.device:
            self._preview_stop_pending=True;self.pending_tasks.clear()
            if getattr(self.device,'features',0)&FEATURE_EMERGENCY:self.emergency_stop()
            else:
                device=self.device
                self.run('切换试听目标前停止 FPGA',lambda:device.control('panic'),lambda _:setattr(self,'_preview_stop_pending',False))
    def transport_pause(self):
        if self.preview_engine.currentData()=='fpga':self.control('pause')
        else:self.local_player.pause_resume()
    def transport_stop(self):
        self.local_player.stop()
        if self.preview_engine.currentData()=='fpga' or self._preview_stop_pending:self.control('panic')
    def delete_song(self):
        if self.current_song() is None:return
        self.capture_editor_drafts();before=copy.deepcopy(self.project);after=copy.deepcopy(self.project)
        removed=after.songs.pop(self.song_index);self._section_drafts.pop(removed.resource_id,None)
        self.undo.push(EditProject(self,before,after,'移除曲谱'))
    def delete_patch(self):
        index=self.patch_index
        if not 0<=index<len(self.project.patches):return
        self.capture_editor_drafts();number=index+2
        referenced=any(number in s.timbres+[s.live_timbre] for song in self.project.songs for s in song.sections)
        replacement=0
        if referenced:
            options=['拨弦','管乐']+[p.name for i,p in enumerate(self.project.patches) if i!=index]
            choice,ok=QInputDialog.getItem(self,'替换被引用音色','此音色正在被配器使用，替换为：',options,0,False)
            if not ok:return
            replacement=options.index(choice)
        before=copy.deepcopy(self.project);after=copy.deepcopy(self.project);removed=after.patches.pop(index)
        for song in after.songs:
            for section in song.sections:
                def remap(n):return replacement if n==number else n-1 if n>number else n
                section.timbres=[remap(n) for n in section.timbres];section.live_timbre=remap(section.live_timbre)
        self._patch_drafts.pop(removed.resource_id,None);self.undo.push(EditProject(self,before,after,'移除音色并更新引用'))
    def open_recovery(self):
        folder=Path(__file__).resolve().parents[1]/'build/autosave';folder.mkdir(parents=True,exist_ok=True)
        path,_=QFileDialog.getOpenFileName(self,'打开自动恢复副本',str(folder),'歌曲工程 (*.fpgamusic)')
        if path and self.confirm_saved():self.load_project_file(path);self.project_path=None
    def button(self,text,fn,primary=False):
        b=QPushButton(text);b.clicked.connect(fn)
        if primary:b.setObjectName('primary')
        return b
    def _build(self):
        from .workstation_layout import build_window
        build_window(self, Waveform)
    def resizeEvent(self,event):
        super().resizeEvent(event)
        if hasattr(self,'workspace') and hasattr(self,'editor_maximized'):
            if self.height()<620:self.overview.hide()
            if self.width()<1150:self.library_dock.hide()
    def fit_to_space(self,width,height):
        # 先收起区域再调整尺寸，否则旧minimumSizeHint会把高DPI窗口撑出可用区域。
        if height<620:self.overview.hide()
        if width<1150:self.library_dock.hide();self.inspector_dock.hide()
        self.layout().activate();self.resize(width,height)
        # QSplitter在下一轮布局才传播隐藏项的最小尺寸，随后再应用一次目标大小。
        self._fit_target=(width,height)
        QTimer.singleShot(0,lambda:self.resize(width,height) if not self._closing and self._fit_target==(width,height) else None)
    def keyPressEvent(self,event):
        # 文本编辑框先处理自己的按键；只接管传递到主窗口的编曲快捷键。
        modifiers=event.modifiers()
        if event.key()==Qt.Key.Key_Space and modifiers==Qt.KeyboardModifier.NoModifier:
            if self.preview_engine.currentData()=='fpga':self.control('pause') if self.last_state.get('playing') else self.play()
            elif self.local_player.ready:self.local_player.pause_resume()
            elif not self.local_player.rendering:self.play_local()
            event.accept();return
        if modifiers & Qt.KeyboardModifier.ControlModifier:
            if event.key()==Qt.Key.Key_Z:
                self.undo.redo() if modifiers & Qt.KeyboardModifier.ShiftModifier else self.undo.undo()
                event.accept();return
            if event.key()==Qt.Key.Key_Y:self.undo.redo();event.accept();return
        super().keyPressEvent(event)
    def log_message(self,text):self.log.appendPlainText(time.strftime('%H:%M:%S  ')+text)
    def component_status(self):
        from .music_components import status_text
        self.log_message(status_text())
    def run(self,label,fn,success=None,quiet=False):
        if self.busy:
            # 状态轮询可跳过，用户操作必须排队；避免点击恰逢轮询时丢失播放/停止指令。
            if not quiet:self.pending_tasks.append((label,fn,success,quiet));self.log_message('已排队：'+label)
            return
        self.busy=True;self.status.setText(label+'…');task=Task(fn)
        # 保留Python任务及其信号包装，直到GUI线程收到完成事件，再启动下一条用户操作。
        self.active_task=task
        task.signals.result.connect(success or (lambda result:None));task.signals.failed.connect(lambda text:self.failure(label,text,quiet))
        task.signals.finished.connect(lambda ok:self.finish_task(label,quiet,ok));self.pool.start(task)
    def finish_task(self,label,quiet,succeeded):
        self.busy=False;self.active_task=None
        if not quiet and succeeded:self.log_message(label+'完成')
        self.status.setText('已连接 FPGA' if self.device else '离线编辑 · 尚未连接 FPGA')
        if self.pending_tasks:self.run(*self.pending_tasks.popleft())
    def failure(self,label,text,quiet=False):
        self.log_message(label+'：'+text)
        if '已中止' in text:return
        if not quiet:QMessageBox.warning(self,label,text)
    def refresh_ports(self):
        self.port.clear()
        for name,description in list_serial_ports():
            if 'COM14'==name:continue
            self.port.addItem(name+' · '+description,name)
        i=self.port.findData('COM15')
        if i>=0:self.port.setCurrentIndex(i)
    def connect_device(self):
        if self.emergency_task:self.log_message('等待紧急停止确认后即可重新连接');return
        port=self.port.currentData()
        if not port:return
        def work():
            previous=self.device;self.device=None
            if previous:previous.close()
            device=DeviceV2(port)
            try:caps=device.capabilities();catalog=device.catalog()
            except Exception:device.close();raise
            self.device=device;return caps,catalog
        def connected(result):
            self.deployment.reset();self._last_device_seen=time.monotonic()
            caps,catalog=result;self.catalog_received(catalog);self.connection.setText(f"已连接 · {caps['voices']} 声部");self.log_message(str(caps))
        self.run('连接并核对设备能力',work,connected)
    def disconnect_device(self):
        if self.busy or self.emergency_task:return
        if self.device:self.device.close();self.device=None
        self._preview_stop_pending=False
        self.deployment.reset()
        self.connection.setText('未连接 · 可本机试听与编辑')
    def project_signature(self):return json.dumps(asdict(self.project),sort_keys=True,ensure_ascii=False)
    def editor_drafts(self):
        patch=None;sections=None;song=self.current_song()
        if 0<=self.patch_index<len(self.project.patches):
            p=self.project.patches[self.patch_index]
            if [self.patch_name.text(),*[s.value() for s in self.adsr]]!=[p.name,p.attack,p.decay,p.sustain,p.release] or self.waveform.samples!=p.waveform:patch=p
        if song:
            expected=[[str(v) for v in [s.name,s.start,s.end,*s.timbres,*s.volumes,s.mute,s.solo,s.live_timbre]] for s in song.sections]
            actual=[[self.sections.item(r,c).text() if self.sections.item(r,c) else '' for c in range(14)] for r in range(self.sections.rowCount())]
            if actual!=expected:sections=song
        return patch,sections
    def confirm_saved(self):
        self.capture_editor_drafts()
        if self.project_signature()==self.saved_signature and not self._patch_drafts and not self._section_drafts:return True
        choice=QMessageBox.question(self,'工程尚未保存','保存当前工程的更改？',
            QMessageBox.StandardButton.Save|QMessageBox.StandardButton.Discard|QMessageBox.StandardButton.Cancel,
            QMessageBox.StandardButton.Save)
        if choice==QMessageBox.StandardButton.Save:return self.save_project()
        return choice==QMessageBox.StandardButton.Discard
    def new_project(self):
        if not self.confirm_saved():return
        self.project=MusicProject();self.project_path=None;self.song_index=-1;self.patch_index=-1;self.saved_signature=self.project_signature();self.undo.clear()
        self._patch_drafts.clear();self._section_drafts.clear();self._shown_patch_id=None;self._shown_song_id=None;self.refresh(capture=False)
    def open_project(self):
        path,_=QFileDialog.getOpenFileName(self,'打开歌曲工程','','歌曲工程 (*.fpgamusic)')
        if path:
            if not self.confirm_saved():return
            try:self.load_project_file(path)
            except Exception as e:self.failure('打开工程',str(e))
    def load_project_file(self,path):
        import zipfile
        with zipfile.ZipFile(path) as package:legacy=json.loads(package.read('project.json'))['format'] in (2,3,4)
        self.project=MusicProject.load(path);self.project_path=str(Path(path).with_name(Path(path).stem+'_v5.fpgamusic') if legacy else path);self.saved_signature=self.project_signature()
        self._shown_patch_id=None;self._shown_song_id=None
        self._patch_drafts=self.project.editor_drafts.get('patches',{});self._section_drafts=self.project.editor_drafts.get('sections',{})
        self.song_index=0 if self.project.songs else -1;self.patch_index=0 if self.project.patches else -1;self.undo.clear();self.refresh()
        self.setWindowTitle('FPGA 音乐工作站 V5 · '+Path(path).stem)
    def save_project(self):
        path=self.project_path
        if not path:path,_=QFileDialog.getSaveFileName(self,'保存歌曲工程','','歌曲工程 (*.fpgamusic)')
        if path:
            try:
                self.capture_editor_drafts();snapshot=copy.deepcopy(self.project)
                for patch in snapshot.patches:
                    if patch.resource_id in self._patch_drafts:
                        patch.name,patch.waveform,parameters=copy.deepcopy(self._patch_drafts[patch.resource_id])
                        patch.attack,patch.decay,patch.sustain,patch.release=parameters;patch.revision+=1
                for song in snapshot.songs:
                    if song.resource_id in self._section_drafts:
                        rows=self._section_drafts[song.resource_id];items=[]
                        for row,values in enumerate(rows):
                            n=list(map(int,values[1:]));transpose=song.sections[row].transpose if row<len(song.sections) else 0
                            items.append(Section(values[0],n[0],n[1],n[2:6],n[6:10],n[10],n[11],n[12],transpose))
                        song.sections=items;song.revision+=1
                snapshot.editor_drafts={};snapshot.save(path);self.project=snapshot
                self._patch_drafts.clear();self._section_drafts.clear();self.project_path=path;self.saved_signature=self.project_signature();self.refresh(capture=False);self.log_message('工程已保存：'+path);return True
            except Exception as e:self.failure('保存工程',str(e))
        return False
    def import_score(self,path=None):
        if not path:path,_=QFileDialog.getOpenFileName(self,'导入曲谱','','曲谱 (*.pdf *.png *.jpg *.jpeg *.mid *.midi *.musicxml *.xml *.mxl)')
        if not path:return
        try:
            suffix=Path(path).suffix.lower()
            song=import_midi(path,preserve_tracks=True) if suffix in ('.mid','.midi') else import_musicxml(path,preserve_tracks=True) if suffix in ('.xml','.musicxml','.mxl') else Song(name=Path(path).stem,source_files=[str(Path(path).resolve())],issues=['待识谱或手动录入'])
            self.project.songs.append(song);self.song_index=len(self.project.songs)-1;self.refresh()
            if suffix in ('.pdf','.png','.jpg','.jpeg'):
                # PDF/图片先保存原稿，再自动调用官方识谱；结果全部标记待确认，不能直接下发。
                self.score_issue.setText(f'{song.name} 已导入，正在进行五线谱识别；完成后请检查并确认音符')
                self.recognize('staff')
        except Exception as e:self.failure('导入曲谱',str(e))
    def import_timbre(self):
        path,_=QFileDialog.getOpenFileName(self,'导入合成音色','','音色 (*.ftb *.wav)')
        if not path:return
        try:
            try:patch=import_patch(path)
            except ValueError as e:
                if '4096' not in str(e):raise
                start,ok=QInputDialog.getInt(self,'选择单周期','起点采样编号',0,0,100000000)
                if not ok:return
                end,ok=QInputDialog.getInt(self,'选择单周期','结束采样编号（不包含）',start+256,start+8,100000000)
                if not ok:return
                patch=import_patch(path,start,end)
            self.project.patches.append(patch);self.patch_index=len(self.project.patches)-1;self.refresh()
            if self.device and self.patch_index<8:self.sync_patch(self.patch_index)
        except Exception as e:self.failure('导入音色',str(e))
    def sync_patch(self,index):
        if not self.device:return
        if not 0<=index<8:self.log_message('音色保存在电脑库，设备部署时选择8个驻留音色');return
        patch=copy.deepcopy(self.project.patches[index])
        self.deployment.reset()
        patch.revision=max(patch.revision,self.project.publication_versions.get(patch.resource_id,0),
            max([c['revision'] for c in self.catalog if c['resource_id']==patch.resource_id]+[0]))+1
        self.project.publication_versions[patch.resource_id]=patch.revision
        def work():self.device.control('stop');self.device.upload_resource(1,index,patch,patch.binary());return self.device.catalog()
        self.run('同步音色到设备',work,self.catalog_received)
    def new_patch(self):
        patch=Patch(name=f'自定义音色{len(self.project.patches)+1}',waveform=[round(28000*math.sin(2*math.pi*i/256)) for i in range(256)])
        self.project.patches.append(patch);self.patch_index=len(self.project.patches)-1;self.refresh()
        if self.device and self.patch_index<8:self.sync_patch(self.patch_index)
    def draw_waveform(self,shape):
        if not 0<=self.patch_index<len(self.project.patches):return
        def value(p):
            if shape=='正弦':return math.sin(2*math.pi*p)
            if shape=='三角':return 1-4*abs(p-.5)
            if shape=='锯齿':return 2*p-1
            return 1 if p<.5 else -1
        self.waveform.samples=[round(28000*value(i/256)) for i in range(256)];self.waveform.update()
    def save_patch(self):
        if not 0<=self.patch_index<len(self.project.patches):return
        p=self.project.patches[self.patch_index];p.name=self.patch_name.text();p.waveform=list(self.waveform.samples);p.attack,p.decay,p.sustain,p.release=[s.value() for s in self.adsr];p.revision+=1
        self.local_player.invalidate();self.refresh();self.sync_patch(self.patch_index)
    def audition(self):
        if self.patch_index>=0:self.control('audition',self.patch_index+2,60|(1000<<8))
    def current_song(self):return self.project.songs[self.song_index] if 0<=self.song_index<len(self.project.songs) else None
    def local_tracks_changed(self):
        self.preview_muted={i for i,check in enumerate(self.track_mutes) if check.isChecked()}
        self.preview_solo={i for i,check in enumerate(self.track_solos) if check.isChecked()}
        self.roll.muted=set(self.preview_muted);self.roll.solo=set(self.preview_solo);self.roll.viewport().update()
        self.overview.muted=set(self.preview_muted);self.overview.solo=set(self.preview_solo);self.overview.update()
        if self.current_song():self.local_player.update_mix(self.current_song(),self.preview_muted,self.preview_solo)
        self.local_message.setText('轨道静音／独奏已实时更新')
    def local_loop_range(self):
        song=self.current_song();rows=self.selected_rows()
        if self.local_loop.isChecked() and song and rows:
            return min(song.notes[i].start for i in rows),max(song.notes[i].end for i in rows)
        return None
    def update_local_loop(self):self.local_player.loop_range=self.local_loop_range()
    def play_local(self):
        if self.competition.isChecked():self.failure('电脑试听','比赛验证模式已关闭电脑出声；请使用 FPGA 实际演奏');return
        if self._preview_stop_pending:self.failure('电脑试听','等待 FPGA 确认停音后再播放；失败时可重按停止或断开设备进入离线校谱');return
        song=self.current_song()
        if not song or not song.notes:self.failure('电脑试听','请先导入曲谱并等待识谱，或双击卷帘添加音符');return
        try:
            snapshot=copy.deepcopy(song)
            # 尚未保存的配器草稿也参与本机试听，但不修改设备资源或自动确认识谱结果。
            if self.editor_drafts()[1]:snapshot.sections=self.sections_from_editor(song)
            patches=copy.deepcopy(self.project.patches)
            if 0<=self.patch_index<len(patches):
                p=patches[self.patch_index];p.waveform=list(self.waveform.samples);p.attack,p.decay,p.sustain,p.release=[spin.value() for spin in self.adsr]
            self._auditioning=False;loop_range=self.local_loop_range()
            self.local_player.cursor=loop_range[0] if loop_range else self.local_tick if self.local_tick<snapshot.duration else 0
            self.local_player.play(snapshot,patches,self.preview_muted,self.preview_solo,loop_range,engine=self.preview_engine.currentData(),soundfont=self.reference_font or None)
        except Exception as e:self.failure('电脑试听',str(e))
    def audition_local(self):
        if self.competition.isChecked():self.failure('电脑试听','比赛验证模式已关闭电脑出声');return
        if self._preview_stop_pending:self.failure('电脑试听','等待 FPGA 确认停音后再试听');return
        if not 0<=self.patch_index<len(self.project.patches):self.failure('电脑试听','请先选择或新建一个音色');return
        try:
            patch=copy.deepcopy(self.project.patches[self.patch_index]);patch.waveform=list(self.waveform.samples)
            patch.attack,patch.decay,patch.sustain,patch.release=[spin.value() for spin in self.adsr];patch.validate()
            song=Song(name='音色试听',notes=[Note(0,960,60),Note(960,1920,64),Note(1920,2880,67)],
                      sections=[Section(end=2880,timbres=[2,0,0,0])])
            self._auditioning=True;self.local_player.cursor=0;self.local_player.play(song,[patch])
        except Exception as e:self.failure('电脑试听',str(e))
    def local_position(self,tick):
        if getattr(self,'_auditioning',False):return
        song=self.current_song()
        if not song:return
        self.local_tick=tick
        try:
            clock=TempoMap(song);self.local_time.setText(f'{format_time(clock.to_seconds(tick))} / {format_time(clock.to_seconds(song.duration))}')
        except ValueError:self.local_time.setText('速度表无效')
        if not self.local_timeline.isSliderDown():self.local_timeline.setValue(round(tick/max(1,song.duration)*10000))
        self.roll.set_tick(tick,follow=self.local_player.ready);self.overview.tick=tick;self.overview.update()
        if self.score_views.currentIndex()==3:self.notation.set_tick(tick)
    def seek_local(self,tick):
        song=self.current_song()
        if not song:return
        if getattr(self,'_auditioning',False):self.local_player.stop();self._auditioning=False
        self.local_player.duration_tick=song.duration;self.local_player.clock=TempoMap(song);self.local_player.seek(tick)
    def roll_filter(self,index):
        song=self.current_song()
        self.roll.source_track=self.roll_track.currentData() if song and song.source_tracks else None
        self.roll_track.setToolTip(self.roll_track.currentText())
        self.roll.track=-1 if song and song.source_tracks else index-1;self.roll.viewport().update()
    def set_roll_snap(self,index):
        divisions=(4,2,1,3,5,9,0);division=divisions[index];song=self.current_song()
        if song and division and song.ppqn%division:
            self.roll_snap.blockSignals(True);self.roll_snap.setCurrentIndex(divisions.index(self.roll.snap_division));self.roll_snap.blockSignals(False)
            self.status.setText(f'当前PPQN={song.ppqn}不能精确表示1/{division}拍，吸附设置未改变');return
        self.roll.snap_division=division;self.roll.viewport().update()
    def select_roll_notes(self,rows):
        self.notes.blockSignals(True);self.notes.clearSelection()
        model=self.notes.selectionModel()
        for row in rows:
            model.select(self.notes.model().index(row,0),QItemSelectionModel.SelectionFlag.Select|QItemSelectionModel.SelectionFlag.Rows)
        if rows:self.notes.scrollToItem(self.notes.item(rows[0],0))
        self.notes.blockSignals(False);self.table_selection_changed()
    def table_selection_changed(self):
        if self.refreshing:return
        rows=self.selected_rows();self.roll.selected=set(rows);self.roll.viewport().update();song=self.current_song()
        if rows and song:
            n=song.notes[rows[0]];self.roll_selection.setText(f'{note_name(n.pitch)} · 力度 {n.velocity}'+(f' · {len(rows)}个' if len(rows)>1 else ''))
            for key,value in [('pitch',n.pitch),('start',n.start),('length',n.end-n.start),('velocity',n.velocity)]:self.note_properties[key].setValue(value)
            self.property_part.setCurrentIndex(self.property_part.findData(n.track_id) if song.source_tracks else n.part)
            self.roll.ensure_note_visible(rows[0])
        else:self.roll_selection.setText('拖动音符校正')
        self.update_local_loop()
        if rows and song and song.source_files and song.notes[rows[0]].box:
            self.preview_page.setValue(song.notes[rows[0]].page+1);self.refresh_preview()
            if getattr(self,'preview_source_image',None):
                n=song.notes[rows[0]];x,y,w,h=n.box;source=self.preview_source_image
                crop=source.crop((max(0,x-160),max(0,y-90),min(source.width,x+w+160),min(source.height,y+h+90))).convert('RGB');crop.thumbnail((230,260))
                raw=crop.tobytes();self.source_crop.setPixmap(QPixmap.fromImage(QImage(raw,crop.width,crop.height,crop.width*3,QImage.Format.Format_RGB888).copy()))
            QTimer.singleShot(0,self.ensure_source_note)
        elif hasattr(self,'source_crop'):self.source_crop.clear();self.source_crop.setText('此音符没有原谱位置，五线谱与卷帘共用当前编辑稿')
    def ensure_source_note(self):
        song=self.current_song();rows=self.selected_rows()
        if not song or not rows or not self.preview.pixmap() or not getattr(self,'preview_source_image',None):return
        note=song.notes[rows[0]]
        if len(note.box)!=4:return
        pixmap=self.preview.pixmap();scale=pixmap.width()/self.preview_source_image.width
        x,y,w,h=note.box
        px=(self.preview.width()-pixmap.width())/2+(x+w/2)*scale
        py=(self.preview.height()-pixmap.height())/2+(y+h/2)*scale
        self.preview_scroll.ensureVisible(round(px),round(py),80,60)
    def edit_roll_note(self,row,start,end,pitch,velocity):
        song=self.current_song()
        if not song or not 0<=row<len(song.notes):return
        after=copy.deepcopy(song);n=after.notes[row];n.start,n.end,n.pitch,n.velocity=start,end,pitch,velocity
        # 拖动只修改内容，保留未确认标志，用户听完后再统一确认。
        if after.sections:after.sections[-1].end=max(after.sections[-1].end,end)
        after.revision+=1
        try:self.undo.push(EditSong(self,song,after,'卷帘编辑音符'));self.select_roll_notes([row])
        except ValueError as exc:self.failure('卷帘编辑',str(exc));self.refresh()
    def add_roll_note(self,start,end,pitch,part):
        song=self.current_song()
        if not song:return
        identifier=self.roll_track.currentData() if song.source_tracks else ''
        if song.source_tracks and not identifier:self.failure('添加音符','请先在“编辑声部”中选择一条源轨道');return
        after=copy.deepcopy(song);after.notes.append(Note(start,end,pitch,part=part,track_id=identifier))
        if after.sections:after.sections[-1].end=max(after.sections[-1].end,end)
        after.revision+=1
        if self.commit_song(song,after,'卷帘添加音符'):self.select_roll_notes([len(after.notes)-1])
    def delete_roll_note(self,row):self.select_roll_notes([row]);self.delete_notes()
    def recognize(self,kind):
        song=self.current_song()
        if not song or not song.source_files:return
        source=song.source_files[0];before=copy.deepcopy(song)
        if self.recognition_cancel:self.recognition_cancel.set()
        self.recognition_cancel=threading.Event();cancel=self.recognition_cancel
        def done(after):
            current=next((s for s in self.project.songs if s.resource_id==before.resource_id),None)
            if current is None:
                self.preserve_recognition_candidate(after);return
            # 资源仍存在不表示版本未变：用户可能在后台任务期间继续校谱。
            if asdict(current)!=asdict(before):
                self.preserve_recognition_candidate(after)
                return
            from .score_document import from_song
            if after.score_document is None:after.score_document=from_song(after)
            after.resource_id=before.resource_id;after.revision=before.revision+1;self.undo.push(EditSong(self,before,after,'辅助识谱'))
        self.run_background('五线谱辅助识别' if kind=='staff' else '简谱辅助识别',lambda:recognize_staff(source,cancel=cancel) if kind=='staff' else recognize_jianpu(source),done)
    def preserve_recognition_candidate(self,song,folder=None):
        """过期任务单独落盘；不覆盖用户的新编辑，也不因关闭会话丢失候选。"""
        import uuid
        folder=Path(folder) if folder else Path(__file__).resolve().parents[1]/'build/recognition_candidates';folder.mkdir(parents=True,exist_ok=True)
        path=folder/(time.strftime('%Y%m%d_%H%M%S_')+uuid.uuid4().hex[:8]+'.fpgamusic')
        MusicProject(name='待比较的识谱候选',songs=[song]).save(path)
        self.log_message('识谱期间原曲已变化或关闭，未覆盖。候选已另存，可用“打开工程”查看：'+str(path))
        return path
    def enter_jianpu(self):
        song=self.current_song()
        if not song:return
        text,ok=QInputDialog.getMultiLineText(self,'简谱校正录入',"示例：1 2 3 4 | 5/2 6/2 7 1' - |\n'高八度，逗号低八度，/2八分，点为附点，0休止")
        if ok:
            try:
                after=parse_jianpu(text);after.name=song.name;after.resource_id=song.resource_id;after.revision=song.revision+1;after.source_files=song.source_files
                self.undo.push(EditSong(self,song,after,'简谱录入'))
            except Exception as e:self.failure('简谱录入',str(e))
    def note_changed(self,item):
        if self.refreshing:return
        song=self.current_song()
        if not song:return
        before=copy.deepcopy(song);after=copy.deepcopy(song)
        try:
            n=after.notes[item.row()]
            values=[int(self.notes.item(item.row(),col).text()) if col!=4 or not song.source_tracks else n.part for col in range(6)]
            n.start,n.end,n.pitch,n.velocity,n.part=values[:5];n.uncertain=not bool(values[5]);after.revision+=1
            if not (0<=n.start<n.end and 0<=n.pitch<=127 and 1<=n.velocity<=127 and 0<=n.part<4 and values[5] in (0,1)):
                raise ValueError('起止tick需递增；音高0..127、力度1..127、声部0..3、已确认0或1')
            self.undo.push(EditSong(self,before,after,'编辑音符'))
        except Exception as e:self.failure('编辑音符',str(e));self.refresh()
    def selected_rows(self):return sorted({i.row() for i in self.notes.selectedIndexes()})
    def confirm_notes(self):
        song=self.current_song()
        if not song:return
        after=copy.deepcopy(song)
        for row in self.selected_rows():after.notes[row].uncertain=False
        after.revision+=1;self.commit_song(song,after,'确认识谱音符')
    def add_note(self):
        song=self.current_song()
        if not song:return
        identifier=self.roll_track.currentData() if song.source_tracks else ''
        if song.source_tracks and not identifier:self.failure('添加音符','请先选择一条源轨道');return
        after=copy.deepcopy(song);start=max([n.end for n in song.notes]+[0]);after.notes.append(Note(start,start+song.ppqn,60,track_id=identifier));after.revision+=1
        if after.sections:after.sections[-1].end=max(after.sections[-1].end,start+song.ppqn)
        self.commit_song(song,after,'添加音符')
    def delete_notes(self):
        song=self.current_song()
        if song:
            after=copy.deepcopy(song);rows=set(self.selected_rows());after.notes=[n for i,n in enumerate(after.notes) if i not in rows];after.revision+=1;self.commit_song(song,after,'删除音符')
    def add_section(self):
        song=self.current_song()
        if not song:return
        markers=song.bar_markers()
        number,ok=QInputDialog.getInt(self,'划分段落','从第几个小节开始？按播放顺序，弱起也计一小节',2,2,max(2,len(markers)))
        if not ok:return
        name,ok=QInputDialog.getText(self,'段落名称','例如：主歌／副歌')
        if not ok:return
        after=copy.deepcopy(song)
        if not after.sections:after.sections=[Section(end=after.duration)]
        if number>len(markers):self.failure('划分段落','曲谱没有该小节');return
        boundary=markers[number-1][0]
        for i,s in enumerate(after.sections):
            if s.start<boundary<s.end:
                next_section=copy.deepcopy(s);next_section.start=boundary;next_section.name=name;s.end=boundary;after.sections.insert(i+1,next_section);break
        else:self.failure('划分段落','位置必须在已有段落内部');return
        after.revision+=1;self.undo.push(EditSong(self,song,after,'划分段落'))
    def apply_sections(self):
        song=self.current_song()
        if not song:return
        try:
            after=copy.deepcopy(song);after.sections=self.sections_from_editor(song);after.validate();after.revision+=1;self.undo.push(EditSong(self,song,after,'修改分段配器'))
            if self.device:self.deploy()
        except Exception as e:self.failure('分段配器',str(e))
    def sections_from_editor(self,song):
        items=[]
        for row in range(self.sections.rowCount()):
            values=[self.sections.item(row,c).text() for c in range(14)];n=list(map(int,values[1:]))
            transpose=song.sections[row].transpose if row<len(song.sections) else 0
            items.append(Section(values[0],n[0],n[1],n[2:6],n[6:10],n[10],n[11],n[12],transpose))
        return items
    def accompaniment(self):
        song=self.current_song()
        if not song:return
        text,ok=QInputDialog.getText(self,'生成伴奏','每小节一个和弦，如 C Am F G7')
        if ok:
            try:
                after=copy.deepcopy(song);generate_accompaniment(after,text.split());self.undo.push(EditSong(self,song,after,'生成伴奏'))
            except Exception as e:self.failure('生成伴奏',str(e))
    def deploy(self):
        if not self.device:self.failure('下发工程','请先连接运行V2位流的FPGA');return
        try:snapshot=self.deployment.prepare(self.project,self.catalog)
        except Exception as e:self.failure('工程校验',str(e));return
        device=self.device
        def accepted(catalog):
            self.deployment.accept(snapshot,catalog);self.catalog_received(catalog)
        self.run('下发并校验整个工程',lambda:device.upload_project(snapshot),accepted)
    def control(self,name,value=0,aux=0):
        if not self.device:self.log_message('未连接FPGA，不能执行：'+name);return
        if name in ('stop','panic') and getattr(self.device,'features',0)&FEATURE_EMERGENCY:
            self.emergency_stop();return
        if name in ('stop','panic') and self.busy:
            self.log_message('旧位流不支持事务中抢占：停止将在当前事务结束后执行；新版支持独立紧急停止')
        self.run('设备操作 '+name,lambda:self.device.control(name,value,aux),
                 (lambda _:setattr(self,'_preview_stop_pending',False)) if name in ('stop','panic') else None)
    def emergency_stop(self):
        if self.emergency_task:return
        device=self.device
        if not device:return
        self.pending_tasks.clear()
        self.deployment.reset();task=Task(lambda:device.emergency(abort=True));self.emergency_task=task
        task.signals.result.connect(lambda _:self.log_message('FPGA已确认：清音并取消未完成上传'))
        task.signals.failed.connect(lambda text:self.failure('紧急停止',text))
        task.signals.finished.connect(self.emergency_finished)
        self.emergency_pool.start(task);self.log_message('紧急停止已提交独立串口队列')
    def emergency_finished(self,succeeded):
        self.emergency_task=None
        if succeeded:self._preview_stop_pending=False
    def play(self):
        song=self.current_song()
        if not song:self.failure('播放','请先选择一首曲谱');return
        if not song.notes:self.failure('播放','当前只有PDF/图片原谱，请等待识谱完成或录入音符');return
        if any(n.uncertain for n in song.notes):self.failure('播放','识谱已完成，请先检查音符并确认识别结果，再下发到FPGA');return
        if not self.device:self.failure('播放','请先连接运行V2位流的FPGA；演奏音频由FPGA输出');return
        match=self.deployment.song_match(song,self.project,self.catalog)
        if not match:self.failure('播放','当前曲谱尚未同步，或编辑后版本变化，请先下发工程');return
        def work():self.device.control('mode',3);self.device.control('select_song',match['slot']);self.device.control('play')
        self.run('开始设备演奏',work)
    def selected_resident(self,combo,kind):
        # 目录刷新后按稳定ID及版本复核，防止原槽位被新资源替换时选错歌曲或音色。
        identity=combo.currentData()
        return next((item for item in self.catalog if item['kind']==kind and
            (item['resource_id'],item['revision'])==identity),None)
    def play_resident_song(self):
        item=self.selected_resident(self.resident_song,0)
        if not self.device or item is None:return
        device=self.device;slot=item['slot'];identity=(item['resource_id'],item['revision'])
        def work():
            current=device.catalog()
            if not any(x['kind']==0 and x['slot']==slot and (x['resource_id'],x['revision'])==identity for x in current):
                raise ValueError('设备曲库已变化，请刷新目录后重新选择')
            device.control('mode',3);device.control('select_song',slot);device.control('play');return device.state()
        self.run('播放设备曲谱',work,self.state_received)
    def resident_patch_number(self):
        identity=self.resident_patch.currentData()
        if isinstance(identity,int):return identity
        item=self.selected_resident(self.resident_patch,1)
        return item['slot']+2 if item else None
    def apply_resident_patch(self):
        number=self.resident_patch_number()
        if self.device is None or number is None:return
        device=self.device;identity=self.resident_patch.currentData()
        def work():
            if number>=2 and not any(x['kind']==1 and x['slot']==number-2 and
                (x['resource_id'],x['revision'])==identity for x in device.catalog()):
                raise ValueError('设备音色已变化，请刷新目录后重新选择')
            device.control('live_timbre',number);device.control('screen_timbre',number);return device.state()
        self.run('选择设备演奏音色',work,self.state_received)
    def audition_resident_patch(self):
        number=self.resident_patch_number()
        if self.device is None or number is None:return
        device=self.device;identity=self.resident_patch.currentData()
        def work():
            if number>=2 and not any(x['kind']==1 and x['slot']==number-2 and
                (x['resource_id'],x['revision'])==identity for x in device.catalog()):
                raise ValueError('设备音色已变化，请刷新目录后重新选择')
            device.control('audition',number,60|(1000<<8));return device.state()
        self.run('试听设备音色',work,self.state_received)
    def target_tick(self,value):return int(value*self.last_state.get('duration',0)//10000)
    def seek(self):self.dragging=False;self.control('seek',self.target_tick(self.timeline.value()))
    def read_catalog(self):
        if self.device:self.run('读取设备目录',self.device.catalog,self.catalog_received)
    def catalog_received(self,catalog):self.catalog=catalog;self.catalog_revision=self.last_state.get('revision');self.show_catalog();self.refresh_lists()
    def show_catalog(self):
        self.device_catalog.setPlainText('\n'.join(f"{'曲谱' if x['kind']==0 else '音色'} {x['slot']}: {x['name']} · 版本{x['revision']} · 已校验"+
            (' · ADSR '+str(x['adsr']) if x['kind']==1 and x.get('adsr') else '') for x in self.catalog))
        old_song=self.resident_song.currentData();old_patch=self.resident_patch.currentData()
        self.resident_song.clear();self.resident_patch.clear()
        for number,name in enumerate(('拨弦','管乐')):self.resident_patch.addItem(name,number)
        for item in self.catalog:
            combo=self.resident_song if item['kind']==0 else self.resident_patch
            combo.addItem(item['name'],(item['resource_id'],item['revision']))
        for combo,identity in ((self.resident_song,old_song),(self.resident_patch,old_patch)):
            index=combo.findData(identity)
            if index>=0:combo.setCurrentIndex(index)
    def poll(self):
        if self.device and self._last_device_seen and time.monotonic()-self._last_device_seen>3:
            self.connection.setText('设备状态已过期 · 正在重试');self.deployment.reset()
        if self.device and not self.busy:self.run('读取设备状态',self.device.state,self.state_received,True)
    def state_received(self,state):
        self._last_device_seen=time.monotonic()
        self.last_state=state;self.connection.setText(f"FPGA在线 · 活动声部 {state['voices']} · 最高压力 {state['pressure']}")
        if state['revision']!=self.catalog_revision:self.read_catalog()
        self.position.setText(f"{'暂停' if state['paused'] else '演奏中' if state['playing'] else '已停止'}  段落 {state['section']+1}  {state['tick']} / {state['duration']} tick")
        song=next((x['name'] for x in self.catalog if x['kind']==0 and x['slot']==state['song']),f"槽 {state['song']}")
        patch=state['live_timbre'];patch_name=('拨弦','管乐')[patch] if patch<2 else next((x['name'] for x in self.catalog if x['kind']==1 and x['slot']==patch-2),f'槽 {patch}')
        self.actual_selection.setText(f'FPGA 实际状态：{song} ／ 实体键音色 {patch_name}')
        if 'part_timbres' in state:
            def title(number):return ('拨弦','管乐')[number] if number<2 else next((x['name'] for x in self.catalog if x['kind']==1 and x['slot']==number-2),f'未就绪槽 {number}')
            parts=' ｜ '.join(f'{PARTS[i]}：{title(number)} {state["part_volumes"][i]}%' for i,number in enumerate(state['part_timbres']))
            self.actual_selection.setText(self.actual_selection.text()+'\n'+parts+f'\n速度 {state["speed"]}% · 移调 {state["transpose"]} · 最近命令 {state["command_serial"]}：'+('已生效' if state['last_result']==0 else f'失败 {state["last_result"]}'))
        if not self.dragging:
            self.timeline.blockSignals(True);self.timeline.setValue(state['tick']*10000//max(1,state['duration']));self.timeline.blockSignals(False)
    def select_song(self,index):
        if self.refreshing:return
        self.capture_editor_drafts()
        self.song_index=index;self.refresh_details()
    def select_patch(self,index):
        if self.refreshing:return
        self.capture_editor_drafts()
        self.patch_index=index
        self._shown_patch_id=self.project.patches[index].resource_id if 0<=index<len(self.project.patches) else None
        if 0<=index<len(self.project.patches):
            p=self.project.patches[index];self.patch_name.setText(p.name);self.waveform.samples=list(p.waveform);self.waveform.update()
            for spin,value in zip(self.adsr,[p.attack,p.decay,p.sustain,p.release]):spin.setValue(value)
            if p.resource_id in self._patch_drafts:
                name,wave,parameters=self._patch_drafts[p.resource_id];self.patch_name.setText(name);self.waveform.samples=list(wave);self.waveform.update()
                for spin,value in zip(self.adsr,parameters):spin.setValue(value)
    def refresh_lists(self):
        self.refreshing=True;self.songs.clear();self.patches.clear()
        for item in self.project.songs:
            synced=self.deployment.song_match(item,self.project,self.catalog) is not None
            self.songs.addItem(('● ' if synced else '○ ')+item.name)
        for i,item in enumerate(self.project.patches):self.patches.addItem(f'{i+2} · {item.name}')
        self.songs.setCurrentRow(self.song_index);self.patches.setCurrentRow(self.patch_index);self.refreshing=False
    def refresh_details(self):
        self.refreshing=True;s=self.current_song();self.notes.setRowCount(0);self.sections.setRowCount(0)
        self._shown_song_id=s.resource_id if s else None
        identity=(s.resource_id,audio_identity(s)) if s else None
        if identity!=self._local_identity:
            same_song=self._local_identity and identity and self._local_identity[0]==identity[0]
            self.local_player.invalidate() if same_song else self.local_player.stop()
            if not same_song:self.local_tick=0
            self._local_identity=identity
        if s:self.local_player.update_mix(s,self.preview_muted,self.preview_solo)
        self.track_heads.set_song(s);self.mix_console.set_song(s)
        self.roll.set_song(s);self.overview.song=s;self.overview.update()
        if s and self.roll.snap_division and s.ppqn%self.roll.snap_division:self.roll_snap.setCurrentIndex(6)
        old_track=self.roll.source_track;self.roll_track.blockSignals(True);self.roll_track.clear();self.property_part.clear()
        if s and s.source_tracks:
            self.roll_track.addItem('全部源轨道',None)
            for track in s.source_tracks:self.roll_track.addItem(track.name,track.track_id);self.property_part.addItem(track.name,track.track_id)
            self.roll_track.setCurrentIndex(max(0,self.roll_track.findData(old_track)))
            self.overview.setToolTip('源轨道概览：单击定位；滚轮切换可见轨道。设备声部在下发前单独映射。')
        else:self.roll_track.addItems(['全部声部',*PARTS]);self.property_part.addItems(PARTS)
        self.roll_track.blockSignals(False);self.roll_filter(self.roll_track.currentIndex())
        self.legacy_mixer.setVisible(not (s and s.source_tracks));self.source_mixer_button.setVisible(bool(s and s.source_tracks))
        if s:
            remaining=sum(n.uncertain for n in s.notes)
            detail='；'.join(s.issues) or s.name;self.score_issue.setToolTip(detail)
            self.score_issue.setText(f'{len(s.notes)} 个音符 · {remaining} 个待确认 · '+(detail[:180]+'…（悬停查看全部）' if len(detail)>180 else detail))
            self.notes.setRowCount(len(s.notes))
            sources={track.track_id:track for track in s.source_tracks}
            for row,n in enumerate(s.notes):
                track=sources.get(n.track_id);role=PARTS[track.device_part] if track and track.device_part in (0,1,2,3) else '未映射' if track else n.part
                for col,value in enumerate([n.start,n.end,n.pitch,n.velocity,role,int(not n.uncertain),track.name if track else '旧版声部']):
                    cell=QTableWidgetItem(str(value))
                    if col==6 or col==4 and s.source_tracks:cell.setFlags(cell.flags() & ~Qt.ItemFlag.ItemIsEditable)
                    if n.uncertain:cell.setBackground(QColor('#5c4124'))
                    self.notes.setItem(row,col,cell)
            self.sections.setRowCount(len(s.sections))
            for row,section in enumerate(s.sections):
                for col,value in enumerate([section.name,section.start,section.end,*section.timbres,*section.volumes,section.mute,section.solo,section.live_timbre]):self.sections.setItem(row,col,QTableWidgetItem(str(value)))
            if s.resource_id in self._section_drafts:
                rows=self._section_drafts[s.resource_id];self.sections.setRowCount(len(rows))
                for r,row in enumerate(rows):
                    for c,text in enumerate(row):self.sections.setItem(r,c,QTableWidgetItem(text))
            try:
                count=1
                if s.source_files and Path(s.source_files[0]).suffix.lower()=='.pdf':
                    import pymupdf
                    with pymupdf.open(s.source_files[0]) as document:count=len(document)
                self.preview_page.blockSignals(True);self.comparison_page.blockSignals(True);self.preview_page.setMaximum(max(1,count));self.comparison_page.setMaximum(max(1,count));self.preview_page_count.setText(f'/ {count}')
                if self.preview_resource!=s.resource_id:self.preview_page.setValue(1)
                self.comparison_page.setValue(self.preview_page.value());self.preview_resource=s.resource_id;self.preview_page.blockSignals(False);self.comparison_page.blockSignals(False);self.refresh_preview()
            except Exception as e:
                self.preview_page.blockSignals(False);self.comparison_page.blockSignals(False);self.preview_key=None;self.preview.setText('原谱无法预览：'+str(e));self.comparison_source.clear_image('原谱无法预览：'+str(e))
        else:self.preview_key=None;self.preview.setText('原谱预览');self.comparison_source.clear_image('原谱预览')
        self.refreshing=False
        self.score_review.set_song(s)
        if self.score_views.currentIndex()==3:self.notation.set_song(s)
        self.select_roll_notes(sorted(self.roll.selected));self.local_position(self.local_tick)
    def refresh_preview(self):
        song=self.current_song()
        if not song or not song.source_files:
            self.preview_key=None;self.preview.setText('没有原谱图片；请在钢琴卷帘或音符明细中校正');self.comparison_source.clear_image('没有原谱图片');return
        try:
            source=Path(song.source_files[0]);source_key=(str(source),source.stat().st_mtime_ns,self.preview_page.value())
            selected=[song.notes[i] for i in self.selected_rows() if i<len(song.notes) and song.notes[i].page==self.preview_page.value()-1 and len(song.notes[i].box)==4]
            key=source_key+(tuple((n.pitch,*n.box) for n in selected),)
            if key==self.preview_key:return
            if source_key!=getattr(self,'preview_source_key',None):
                self.preview_source_image=page_image(source,self.preview_page.value()-1);self.preview_source_key=source_key
            image=self.preview_source_image.copy()
            if selected:
                from PIL import ImageDraw
                draw=ImageDraw.Draw(image)
                for n in selected:
                    x,y,w,h=n.box;draw.rectangle((x-4,y-4,x+w+4,y+h+4),outline='#e05338',width=4)
            image.thumbnail((960,900));raw=image.tobytes('raw','RGB')
            q=QImage(raw,image.width,image.height,image.width*3,QImage.Format.Format_RGB888).copy()
            pixmap=QPixmap.fromImage(q);self.preview.setPixmap(pixmap);self.preview.setMinimumSize(image.width,image.height);self.preview_key=key
            self.comparison_source.set_image(pixmap)
        except Exception as e:self.preview_key=None;self.preview.setText('原谱无法预览：'+str(e));self.comparison_source.clear_image('原谱无法预览：'+str(e))
    def refresh(self,capture=True):
        if capture:self.capture_editor_drafts()
        self.refresh_lists();self.refresh_details();self.select_patch(self.patch_index)
    def commit_song(self,before,after,label):
        try:self.undo.push(EditSong(self,before,after,label));return True
        except ValueError as exc:self.failure(label,str(exc));self.refresh();return False
    def apply_note_properties(self):
        song=self.current_song();rows=self.selected_rows()
        if not song or not rows:return
        after=copy.deepcopy(song);note=after.notes[rows[0]];p=self.note_properties
        note.start=p['start'].value();note.end=note.start+p['length'].value();note.pitch=p['pitch'].value();note.velocity=p['velocity'].value()
        if song.source_tracks:note.track_id=self.property_part.currentData()
        else:note.part=self.property_part.currentIndex()
        if after.sections:after.sections[-1].end=max(after.sections[-1].end,note.end)
        after.revision+=1;self.commit_song(song,after,'音符属性修改')
    def competition_changed(self,enabled):
        self.local_player.stop();self.local_play_button.setEnabled(not enabled)
        self.local_message.setText('比赛验证：电脑音频关闭，设备由 FPGA 实时合成' if enabled else '本机校谱工具；设备合成证据以 FPGA 实际输出为准')
    def choose_soundfont(self):
        path,_=QFileDialog.getOpenFileName(self,'选择电脑参考音源',self.reference_font,'SoundFont (*.sf2 *.sf3)')
        if not path:return
        try:
            from .reference_audio import presets
            presets(path);self.local_player.stop();self.reference_font=path;self.settings.setValue('soundfont',path)
            self.local_message.setText('电脑参考音源：'+Path(path).name+'；不会上传到 FPGA')
        except Exception as exc:self.failure('参考音源',str(exc))
    def choose_reference_programs(self):
        song=self.current_song()
        if not song:return
        try:
            from .reference_audio import resources,presets
            _,font=resources(self.reference_font or None);names={program:name for bank,program,name in presets(font) if bank==0}
            if song.source_tracks:
                dialog=QDialog(self);dialog.setWindowTitle('源轨道参考试听 · 不改变 FPGA 配器');layout=QVBoxLayout(dialog)
                rows=QWidget();rows_layout=QVBoxLayout(rows);choices=[]
                for track in song.source_tracks:
                    row=QHBoxLayout();row.addWidget(QLabel(track.name));choice=QComboBox();choice.addItem('保留原始乐器变化',None)
                    for number in range(128):choice.addItem(f'{number+1} · '+names.get(number,'GM 乐器'),number)
                    choice.setCurrentIndex(choice.findData(track.reference_override));row.addWidget(choice)
                    mute=QCheckBox('静音');mute.setChecked(track.preview_muted);solo=QCheckBox('独奏');solo.setChecked(track.preview_solo)
                    volume=QSpinBox();volume.setRange(0,100);volume.setSuffix('%');volume.setValue(track.reference_volume)
                    row.addWidget(volume);row.addWidget(mute);row.addWidget(solo);rows_layout.addLayout(row);choices.append((choice,mute,solo,volume))
                scroll=QScrollArea();scroll.setWidgetResizable(True);scroll.setWidget(rows);layout.addWidget(scroll)
                buttons=QDialogButtonBox(QDialogButtonBox.StandardButton.Ok|QDialogButtonBox.StandardButton.Cancel);buttons.accepted.connect(dialog.accept);buttons.rejected.connect(dialog.reject);layout.addWidget(buttons)
                dialog.resize(760,420)
                if dialog.exec():
                    after=copy.deepcopy(song)
                    for track,(choice,mute,solo,volume) in zip(after.source_tracks,choices):track.reference_override=choice.currentData();track.preview_muted=mute.isChecked();track.preview_solo=solo.isChecked();track.reference_volume=volume.value()
                    after.revision+=1;self.commit_song(song,after,'源轨道参考乐器与混音')
                return
            dialog=QDialog(self);dialog.setWindowTitle('电脑参考乐器 · 不改变 FPGA 配器');layout=QVBoxLayout(dialog);choices=[]
            for part in range(4):
                row=QHBoxLayout();row.addWidget(QLabel(PARTS[part]));choice=QComboBox()
                for number in range(128):choice.addItem(f'{number+1} · '+names.get(number,'GM 乐器'),number)
                choice.setCurrentIndex(song.reference_programs[part]);choice.setEnabled(part!=3);choices.append(choice);row.addWidget(choice);layout.addLayout(row)
            buttons=QDialogButtonBox(QDialogButtonBox.StandardButton.Ok|QDialogButtonBox.StandardButton.Cancel);buttons.accepted.connect(dialog.accept);buttons.rejected.connect(dialog.reject);layout.addWidget(buttons)
            if dialog.exec():
                after=copy.deepcopy(song);after.reference_programs=[c.currentData() for c in choices];after.revision+=1;self.undo.push(EditSong(self,song,after,'参考乐器设置'))
        except Exception as exc:self.failure('参考乐器',str(exc))
    def locate_measure(self,location):
        song=self.current_song()
        if not song:return
        self.preview_page.setValue(min(self.preview_page.maximum(),location['page']+1));self.score_views.setCurrentIndex(3)
        if song.score_document and location['index']<len(song.score_document.measure_grid):
            from fractions import Fraction
            self.local_player.seek(float(Fraction(song.score_document.measure_grid[location['index']][0])*song.ppqn))
        self.log_message(f'定位候选：{location["part"]} 第{location["measure"]}小节；原PDF位置仍需核对')
    def review_measure(self,measure_id,confirmed):
        song=self.current_song()
        if not song:return
        try:
            from .score_review import mark_measure
            after=mark_measure(song,measure_id,confirmed);self.undo.push(EditSong(self,song,after,'确认源小节' if confirmed else '撤销小节核对'))
        except Exception as exc:self.failure('小节核对',str(exc))
    def edit_measure(self,location=None):
        song=self.current_song()
        if not song:return
        try:
            from .measure_dialog import MeasureDialog
            from .measure_editor import recompile_song
            dialog=MeasureDialog(ensure_document(song),self)
            if isinstance(location,dict):dialog.pick.setCurrentIndex(dialog.locations.index((location['part'],location['index'])))
            if dialog.exec():
                after=recompile_song(song,dialog.result_document)
                self.undo.push(EditSong(self,song,after,'小节校正'))
        except Exception as exc:self.failure('小节校正',str(exc))
    def edit_notation(self,operation):
        song=self.current_song();rows=self.selected_rows()
        if not song or not rows:return
        if operation=='rest':self.delete_notes();return
        row=rows[0];note=song.notes[row];pitch=note.pitch+(1 if operation=='up' else -1 if operation=='down' else 0)
        duration=(note.end-note.start)*(2 if operation=='longer' else .5 if operation=='shorter' else 1)
        if duration!=int(duration) or duration<1:self.failure('谱面编辑','此时值无法用当前 PPQN 精确表示，请在 MuseScore 修改');return
        self.edit_roll_note(row,note.start,note.start+int(duration),max(0,min(127,pitch)),note.velocity)
    def export_score(self,path=None):
        song=self.current_song()
        if not song:return None
        if not path:path,_=QFileDialog.getSaveFileName(self,'导出当前编辑稿',song.name+'.musicxml','MusicXML (*.musicxml)')
        if not path:return None
        try:
            document=ensure_document(song);Path(path).parent.mkdir(parents=True,exist_ok=True);Path(path).write_text(document.current_xml,encoding='utf-8')
            if document.reconstructed:self.log_message('此谱面由演奏时间线重新记谱；复杂连音分组需要对照原谱校正。')
            self.log_message('已导出当前编辑稿：'+str(path));return str(path)
        except Exception as exc:self.failure('导出校谱',str(exc));return None
    def open_score_editor(self):
        import shutil,subprocess
        song=self.current_song()
        if not song:return
        path=Path(__file__).resolve().parents[1]/'build/cache/external_editor'/f'{song.resource_id}_{song.revision}.musicxml'
        if not self.export_score(str(path)):return
        self.external_score_path=str(path)
        candidates=[self.settings.value('musescore',''),shutil.which('MuseScore4'),r'C:\Program Files\MuseScore 4\bin\MuseScore4.exe']
        candidates.extend((Path(__file__).resolve().parents[1]/'build/tools/music/musescore').rglob('MuseScore4.exe'))
        executable=next((str(p) for p in candidates if p and Path(p).is_file()),None)
        if executable:subprocess.Popen([executable,str(path)])
        else:
            executable,_=QFileDialog.getOpenFileName(self,'选择 MuseScore 程序；取消后仍可手动打开已导出的 MusicXML',r'C:\Program Files','MuseScore (*.exe)')
            if executable:self.settings.setValue('musescore',executable);subprocess.Popen([executable,str(path)])
    def import_corrected(self,path=None,confirm=True):
        song=self.current_song()
        if not song:return
        if not path:path,_=QFileDialog.getOpenFileName(self,'导回外部校正版',getattr(self,'external_score_path',''),'MusicXML (*.musicxml *.mxl *.xml)')
        if not path:return
        try:
            after=import_musicxml(path,preserve_tracks=True);summary=difference(song,after)
            from .score_document import retain_arrangement
            retain_arrangement(song,after)
            if confirm and QMessageBox.question(self,'校正版差异',summary+'\n替换当前曲目？新音符仍需校正确认。')!=QMessageBox.StandardButton.Yes:return
            after.name=song.name;after.resource_id=song.resource_id;after.revision=song.revision+1
            original=song.score_document
            if original:
                after.score_document.original_xml=original.original_xml;after.score_document.initial_xml=original.initial_xml
            after.source_files=list(dict.fromkeys(song.source_files+[str(Path(path).resolve())]))
            for note in after.notes:note.uncertain=True
            self.undo.push(EditSong(self,song,after,'导回校正版'));self.log_message(summary)
        except Exception as exc:self.failure('导回校正版',str(exc))
    def map_score_parts(self):
        song=self.current_song()
        if not song:return
        try:
            if song.source_tracks:
                dialog=QDialog(self);dialog.setWindowTitle('源轨道 → FPGA 逻辑声部');layout=QVBoxLayout(dialog);choices=[]
                layout.addWidget(QLabel('GM参考音色只在电脑使用；FPGA音色请在分段配器中选择。'))
                rows=QWidget();rows_layout=QVBoxLayout(rows);scroll=QScrollArea();scroll.setWidgetResizable(True);scroll.setWidget(rows);layout.addWidget(scroll)
                for track in song.source_tracks:
                    row=QHBoxLayout();label=QLabel(track.name);label.setWordWrap(True);label.setMaximumWidth(280);row.addWidget(label);choice=QComboBox();choice.addItem('未映射',None)
                    for index,name in enumerate(PARTS):choice.addItem(name,index)
                    choice.setCurrentIndex(choice.findData(track.device_part));row.addWidget(choice);rows_layout.addLayout(row);choices.append(choice)
                buttons=QDialogButtonBox(QDialogButtonBox.StandardButton.Ok|QDialogButtonBox.StandardButton.Cancel);buttons.accepted.connect(dialog.accept);buttons.rejected.connect(dialog.reject);layout.addWidget(buttons)
                dialog.resize(650,420)
                if not dialog.exec():return
                after=copy.deepcopy(song)
                for track,choice in zip(after.source_tracks,choices):track.device_part=choice.currentData()
                after.revision+=1;self.commit_song(song,after,'修改设备声部映射');return
            document=copy.deepcopy(ensure_document(song));dialog=QDialog(self);dialog.setWindowTitle('原谱声部 → FPGA 四个逻辑声部');layout=QVBoxLayout(dialog);choices={}
            from .score_document import xml_root
            for pi,part in enumerate(xml_root(document.current_xml).findall('part')):
                for staff,voice in sorted({(n.findtext('staff','1'),n.findtext('voice','1')) for n in part.iter('note') if n.find('pitch') is not None}):
                    key=f'{part.get("id")}:{staff}:{voice}';row=QHBoxLayout();row.addWidget(QLabel(key));choice=QComboBox();choice.addItems(PARTS);choice.setCurrentIndex(document.mapping.get(key,min(pi,2)));row.addWidget(choice);layout.addLayout(row);choices[key]=choice
            buttons=QDialogButtonBox(QDialogButtonBox.StandardButton.Ok|QDialogButtonBox.StandardButton.Cancel);buttons.accepted.connect(dialog.accept);buttons.rejected.connect(dialog.reject);layout.addWidget(buttons)
            if not dialog.exec():return
            document.mapping={key:choice.currentIndex() for key,choice in choices.items()};after=document.compile(song.name,uncertain=True)
            from .score_document import retain_arrangement
            retain_arrangement(song,after)
            after.resource_id=song.resource_id;after.revision=song.revision+1;after.source_files=song.source_files;after.reference_programs=list(song.reference_programs)
            self.undo.push(EditSong(self,song,after,'修改原谱声部映射'))
        except Exception as exc:self.failure('声部映射',str(exc))
    def clip_edit(self,duplicate):
        song=self.current_song();rows=self.selected_rows()
        if not song or not rows:return
        first=min(song.notes[i].start for i in rows)
        beat,ok=QInputDialog.getDouble(self,'复制片段' if duplicate else '移动片段','目标起点（从0开始的四分音符拍数）',self.local_tick/song.ppqn,0,100000,3)
        if not ok:return
        try:
            self.transform_clip(rows,round(beat*song.ppqn),duplicate)
        except Exception as exc:self.failure('片段编辑',str(exc))
    def drag_clip(self,part,start,end,target,duplicate):
        song=self.current_song()
        if song:self.transform_clip([i for i,n in enumerate(song.notes) if n.part==part and start<=n.start<end],target,duplicate,origin=start)
    def transform_clip(self,rows,target,duplicate,origin=None):
        import uuid
        song=self.current_song()
        if not song or not rows:return
        first=min(song.notes[i].start for i in rows) if origin is None else origin;after=copy.deepcopy(song)
        for i in rows:
            note=copy.deepcopy(song.notes[i]);note.start+=target-first;note.end+=target-first
            if note.start<0:return
            if duplicate:note.note_id='n'+uuid.uuid4().hex;after.notes.append(note)
            else:after.notes[i]=note
        if after.sections:after.sections[-1].end=max(after.sections[-1].end,max(n.end for n in after.notes))
        after.revision+=1;self.commit_song(song,after,'复制片段' if duplicate else '移动片段')
    def online_import(self):
        url,ok=QInputDialog.getText(self,'在线曲谱','输入PDF／图片／MIDI／MusicXML的HTTPS直链')
        if not ok:return
        path,_=QFileDialog.getSaveFileName(self,'保存下载曲谱')
        if path:
            # result 信号先于 finished 信号到达；延后一拍再导入，避免自动下发被 busy 门禁丢弃。
            self.run('下载曲谱',lambda:download_score(url,path),lambda p:QTimer.singleShot(0,lambda:self.import_score(str(p))))
    def closeEvent(self,event):
        self.poller.stop()
        if self.busy or self.emergency_task:event.ignore();self.poller.start();self.log_message('设备任务结束后即可关闭');return
        if not self.confirm_saved():event.ignore();self.poller.start();return
        self.settings.setValue('windowGeometry',self.saveGeometry());self.settings.setValue('windowState',self.saveState())
        self.local_player.shutdown()
        self._closing=True
        if self.recognition_cancel:self.recognition_cancel.set()
        self.background_pool.clear();self.background_pool.waitForDone(2000)
        self.notation.generation+=1;self.notation.pool.clear();self.notation.pool.waitForDone(5000)
        if self.device:self.device.close()
        event.accept()

def configure_appearance(app):
    """使用已实际注册的中文字族，离屏与桌面入口共用同一套外观配置。"""
    style=STYLE
    font_path=Path('C:/Windows/Fonts/msyh.ttc')
    if font_path.exists():
        identifier=QFontDatabase.addApplicationFont(str(font_path));families=QFontDatabase.applicationFontFamilies(identifier)
        if families:
            app.setFont(QFont(families[0],10));style=style.replace('"Microsoft YaHei UI"','"'+families[0]+'"')
    app.setStyleSheet(style)


def main():
    parser=argparse.ArgumentParser(description='FPGA 中文演奏工作站');parser.add_argument('--project',help='启动后打开的.fpgamusic工程')
    args=parser.parse_args()
    app=QApplication(sys.argv);configure_appearance(app);window=WorkstationWindow()
    if args.project:
        try:window.load_project_file(Path(args.project).resolve())
        except Exception as e:window.failure('打开工程',str(e))
    available=window.screen().availableGeometry()
    window.fit_to_space(min(window.width(),available.width()-20),min(window.height(),available.height()-40))
    window.show();return app.exec()
if __name__=='__main__':raise SystemExit(main())
