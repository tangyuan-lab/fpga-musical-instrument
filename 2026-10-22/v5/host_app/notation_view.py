"""Verovio 谱面显示：渲染按资源/版本隔离，点击与播放按稳定音符 ID 联动。"""
import copy,xml.etree.ElementTree as ET
from PySide6.QtCore import Qt,QObject,Signal,QRunnable,QThreadPool,QRectF
from PySide6.QtGui import QPainter,QColor
from PySide6.QtSvg import QSvgRenderer
from PySide6.QtWidgets import QWidget,QVBoxLayout,QHBoxLayout,QLabel,QSpinBox,QScrollArea,QToolButton,QMenu,QPushButton
from .score_document import ensure_document,render_pages

class _Signals(QObject):
    ready=Signal(int,object);failed=Signal(int,str)

class _Render(QRunnable):
    def __init__(self,generation,song):
        super().__init__();self.generation=generation;self.song=copy.deepcopy(song);self.signals=_Signals()
    def run(self):
        try:self.signals.ready.emit(self.generation,render_pages(ensure_document(self.song)))
        except Exception as exc:self.signals.failed.emit(self.generation,str(exc))

class ScoreSvg(QWidget):
    clicked=Signal(str)
    def __init__(self):
        super().__init__();self.renderer=QSvgRenderer(self);self.setMinimumSize(720,800);self.bounds={};self.source='';self.zoom=1
    def load(self,source):
        self.source=source;self.renderer.load(source.encode());self.bounds={}
        root=ET.fromstring(source)
        for node in root.iter():
            identifier=node.get('id')
            if identifier and 'note' in node.get('class','').split() and self.renderer.elementExists(identifier):
                self.bounds[identifier]=self.renderer.transformForElement(identifier).mapRect(self.renderer.boundsOnElement(identifier))
        self.resize_page();self.update()
    def resize_page(self):
        size=self.renderer.viewBoxF().size();width=round(850*self.zoom)
        if size.width()>0:self.setFixedSize(width,round(width*size.height()/size.width()))
    def paintEvent(self,event):
        painter=QPainter(self);painter.fillRect(self.rect(),QColor('white'))
        self.renderer.render(painter,QRectF(self.rect()))
    def mousePressEvent(self,event):
        box=self.renderer.viewBoxF();point=event.position();x=point.x()*box.width()/max(1,self.width())+box.x();y=point.y()*box.height()/max(1,self.height())+box.y()
        candidates=[(r.width()*r.height(),identifier) for identifier,r in self.bounds.items() if r.adjusted(-15,-15,15,15).contains(x,y)]
        if candidates:self.clicked.emit(min(candidates)[1])
    def highlight(self,identifiers):
        if not self.source:return
        root=ET.fromstring(self.source)
        for node in root.iter():
            if node.get('id') in identifiers:
                node.set('color','#e35d34');node.set('fill','#e35d34');node.set('stroke','#e35d34')
        self.renderer.load(ET.tostring(root));self.update()

class PageImageView(QScrollArea):
    """保存未缩放原图，视口变化只影响显示，不修改识谱坐标。"""
    def __init__(self):
        super().__init__();self.image=None;self.fit=True;self.label=QLabel('原谱预览');self.setWidget(self.label)
    def set_image(self,image):self.image=image;self.update_image()
    def set_fit(self,enabled):self.fit=enabled;self.update_image()
    def update_image(self):
        if self.image is None:return
        pixmap=self.image.scaledToWidth(max(1,self.viewport().width()-2),Qt.TransformationMode.SmoothTransformation) if self.fit else self.image
        self.label.setPixmap(pixmap);self.label.resize(pixmap.size())
    def clear_image(self,text):self.image=None;self.label.setText(text);self.label.adjustSize()
    def resizeEvent(self,event):super().resizeEvent(event);self.update_image()

class NotationPanel(QWidget):
    noteSelected=Signal(int);editRequested=Signal(str)
    def __init__(self,parent=None):
        super().__init__(parent);self.song=None;self.key=None;self.pages=[];self.generation=0;self.active=set();self.last_tick=0;self.pool=QThreadPool(self);self.pool.setMaxThreadCount(1)
        layout=QVBoxLayout(self);row=QHBoxLayout();self.label=QLabel('选择曲谱后显示五线谱');self.label.setWordWrap(True);layout.addWidget(self.label)
        row.addWidget(QLabel('页码'));self.page=QSpinBox();self.page.setRange(1,1);self.page.valueChanged.connect(self.show_page);row.addWidget(self.page)
        self.auto_fit=True
        row.addWidget(QLabel('缩放'));self.zoom=QSpinBox();self.zoom.setRange(20,300);self.zoom.setValue(100);self.zoom.setSuffix('%');self.zoom.valueChanged.connect(self.set_zoom);row.addWidget(self.zoom)
        fit_button=QPushButton('适宽');fit_button.clicked.connect(lambda:self.fit_width(True));row.addWidget(fit_button)
        edit=QToolButton();edit.setText('编辑音符');edit.setPopupMode(QToolButton.ToolButtonPopupMode.InstantPopup);menu=QMenu(edit)
        for text,operation in [('音高＋','up'),('音高－','down'),('时值×2','longer'),('时值÷2','shorter'),('改为休止','rest')]:
            action=menu.addAction(text);action.triggered.connect(lambda checked=False,op=operation:self.editRequested.emit(op))
        edit.setMenu(menu);row.addWidget(edit)
        row.addStretch();layout.addLayout(row);self.canvas=ScoreSvg();self.canvas.clicked.connect(self.select)
        self.scroll=QScrollArea();self.scroll.setWidget(self.canvas);layout.addWidget(self.scroll)
    def set_song(self,song):
        self.song=song;key=(song.resource_id,song.revision) if song else None
        if key==self.key:return
        self.key=key;self.generation+=1;self.pages=[];self.active=set();self.pool.clear()
        self.canvas.load('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 850 200"/>')
        if song is None:self.label.setText('选择曲谱后显示五线谱');return
        self.label.setText('正在生成五线谱…');task=_Render(self.generation,song)
        task.signals.ready.connect(self.ready);task.signals.failed.connect(self.failed);self.task=task;self.pool.start(task)
    def ready(self,generation,pages):
        if generation!=self.generation:return
        self.pages=pages;self.page.setMaximum(max(1,len(pages)));self.show_page()
        reconstructed=self.song.score_document is None or self.song.score_document.reconstructed
        self.label.setText(('重新记谱视图：旧时间线不含原始记谱分组。' if reconstructed else '当前编辑稿 · Verovio 排版。')+' 点击音符联动卷帘；复杂记谱使用“导出校谱”。')
    def failed(self,generation,message):
        if generation==self.generation:self.label.setText('五线谱暂不可用：'+message)
    def show_page(self,*args):
        if self.pages:
            self.canvas.load(self.pages[min(self.page.value(),len(self.pages))-1]);self.active=set();self.set_tick(self.last_tick)
            if self.auto_fit:self.fit_width(True)
    def set_zoom(self,value):self.auto_fit=False;self.canvas.zoom=value/100;self.canvas.resize_page()
    def fit_width(self,enabled=True):
        self.auto_fit=enabled
        value=max(20,min(300,int((self.scroll.viewport().width()-3)*100/850)))
        self.zoom.blockSignals(True);self.zoom.setValue(value);self.zoom.blockSignals(False)
        self.canvas.zoom=value/100;self.canvas.resize_page()
    def resizeEvent(self,event):
        super().resizeEvent(event)
        if getattr(self,'auto_fit',False) and hasattr(self,'scroll'):self.fit_width(True)
    def select(self,identifier):
        if not self.song:return
        document=self.song.score_document
        for i,note in enumerate(self.song.notes):
            if identifier==note.note_id or document and identifier in document.links.get(note.note_id,[]):self.noteSelected.emit(i);break
    def set_tick(self,tick):
        self.last_tick=tick
        if not self.song or not self.pages:return
        document=self.song.score_document;active=set()
        for note in self.song.notes:
            if note.start<=tick<note.end:active.update(document.links.get(note.note_id,[note.note_id]) if document else [note.note_id])
        if active!=self.active:self.active=active;self.canvas.highlight(active)
