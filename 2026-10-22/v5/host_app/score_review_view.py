"""逐小节疑点/审核覆盖率；不把自动结构检查视为人工准确性结论。"""
from PySide6.QtCore import Qt,Signal
from PySide6.QtWidgets import QWidget,QVBoxLayout,QHBoxLayout,QLabel,QTreeWidget,QTreeWidgetItem,QPlainTextEdit,QPushButton
from .score_review import snapshot


class ScoreReviewPanel(QWidget):
    editRequested=Signal(object);locateRequested=Signal(object);confirmRequested=Signal(str,bool)
    def __init__(self):
        super().__init__();layout=QVBoxLayout(self);self.summary=QLabel();self.summary.setWordWrap(True);layout.addWidget(self.summary)
        self.tree=QTreeWidget();self.tree.setHeaderLabels(['原谱声部','小节','候选页','状态','结构疑点']);layout.addWidget(self.tree)
        self.details=QPlainTextEdit();self.details.setReadOnly(True);self.details.setMaximumHeight(130);layout.addWidget(self.details)
        row=QHBoxLayout();layout.addLayout(row)
        for text,fn in [('定位候选',lambda:self.emit_location(False)),('编辑本小节',lambda:self.emit_location(True)),('已对照原谱核对本小节',lambda:self.mark(True)),('撤销本小节核对',lambda:self.mark(False))]:
            button=QPushButton(text);button.clicked.connect(fn);row.addWidget(button)
        self.tree.currentItemChanged.connect(self.selected)
        self.measures=[];self.issues=[]
    def set_song(self,song):
        selected=self.tree.currentItem();previous=selected.data(0,Qt.ItemDataRole.UserRole)['id'] if selected else None
        self.tree.clear();self.details.clear();self.measures=[];self.issues=[]
        if song is None or song.score_document is None:self.summary.setText('尚无MusicXML谱面；先导入或生成五线谱。');return
        try:self.issues,self.measures,_,valid=snapshot(song.score_document)
        except Exception as exc:self.summary.setText('无法检查谱面：'+str(exc));return
        prefix='此谱面由时间线重新记谱，原始记谱信息不完整。' if song.score_document.reconstructed else ''
        self.summary.setText(prefix+f'逐小节人工核对：{len(valid)}/{len(self.measures)}；结构检查不等于识谱正确。候选页码来自MusicXML，须与PDF核对。')
        for measure in self.measures:
            items=self.measure_issues(measure);errors=sum(i['severity']=='error' for i in items)
            item=QTreeWidgetItem([measure['part'],measure['measure'],str(measure['page']+1),'已核对' if measure['id'] in valid else '待核对',f'{errors}错误 / {len(items)-errors}疑点'])
            item.setData(0,Qt.ItemDataRole.UserRole,measure);self.tree.addTopLevelItem(item)
            if measure['id']==previous:self.tree.setCurrentItem(item)
        if not self.tree.currentItem() and self.tree.topLevelItemCount():self.tree.setCurrentItem(self.tree.topLevelItem(0))
        for column in range(4):self.tree.resizeColumnToContents(column)
    def measure_issues(self,measure):
        return [i for i in self.issues if i['part']=='*' or i['part']==measure['part'] and i['measure']==measure['measure']]
    def selected(self,current,*_):
        if current is None:return
        measure=current.data(0,Qt.ItemDataRole.UserRole)
        self.details.setPlainText('\n'.join(i['message'] for i in self.measure_issues(measure)) or '未发现结构疑点；请对照原谱核对音高、节奏、休止、谱号和延音。')
    def emit_location(self,edit):
        item=self.tree.currentItem()
        if item:(self.editRequested if edit else self.locateRequested).emit(item.data(0,Qt.ItemDataRole.UserRole))
    def mark(self,confirmed):
        item=self.tree.currentItem()
        if item:self.confirmRequested.emit(item.data(0,Qt.ItemDataRole.UserRole)['id'],confirmed)
