"""保留原谱结构的小节编辑器；时间以四分音符为1，允许输入精确分数。"""
import copy
import uuid
from fractions import Fraction
from PySide6.QtWidgets import (QDialog,QVBoxLayout,QHBoxLayout,QGridLayout,QLabel,QComboBox,
    QTableWidget,QTableWidgetItem,QPushButton,QDialogButtonBox,QMessageBox,QPlainTextEdit,QLineEdit,QSpinBox,QWidget,QScrollArea)
from .score_document import xml_root
from .measure_editor import measure_data,apply_measure


class MeasureDialog(QDialog):
    type_names={'maxima':'八全音符','long':'四全音符','breve':'二全音符','whole':'全音符','half':'二分音符','quarter':'四分音符','eighth':'八分音符','16th':'十六分音符','32nd':'三十二分音符','64th':'六十四分音符','128th':'128分音符','256th':'256分音符','512th':'512分音符','1024th':'1024分音符'}
    fields=('voice','staff','start','duration','pitch','type','dots','actual','normal','tie_start','tie_stop','tuplet_start','tuplet_stop','grace')
    labels=('声部','谱表','起点','时长','MIDI音高/休止','记谱时值','附点','连音数','正常数','延音起','延音止','连音起','连音止','装饰音')
    def __init__(self,document,parent=None):
        super().__init__(parent);self.setWindowTitle('逐小节校正');available=self.screen().availableGeometry();self.resize(min(1150,available.width()-40),min(570,available.height()-60))
        self.document=copy.deepcopy(document);self.result_document=None;outer=QVBoxLayout(self)
        self.form_scroll=QScrollArea();self.form_scroll.setWidgetResizable(True);self.form_scroll.setFrameShape(QScrollArea.Shape.NoFrame)
        body=QWidget();layout=QVBoxLayout(body);layout.setContentsMargins(0,0,0,0);self.form_scroll.setWidget(body);outer.addWidget(self.form_scroll,1)
        hint=QLabel('时间单位：四分音符=1；支持 1/6、4/9 等分数。音高留空为休止；布尔项填 0 或 1。切换小节前请先应用。');hint.setWordWrap(True);layout.addWidget(hint)
        self.pick=QComboBox();root=xml_root(document.current_xml);self.locations=[]
        for part in root.findall('part'):
            for index,measure in enumerate(part.findall('measure')):
                self.locations.append((part.get('id'),index));self.pick.addItem(f'{part.get("id")} · 第 {measure.get("number",str(index+1))} 小节')
        layout.addWidget(self.pick)
        tempo_row=QHBoxLayout();tempo_row.addWidget(QLabel('本小节起点速度 BPM（四分音符每分钟；留空不改）'));self.tempo=QLineEdit();self.tempo.setPlaceholderText('例如158');tempo_row.addWidget(self.tempo)
        tempo_row.addWidget(QLabel('本小节拍号（留空不改）'));self.meter=QLineEdit();self.meter.setPlaceholderText('例如3/4');tempo_row.addWidget(self.meter);layout.addLayout(tempo_row)
        self.context_toggle=QPushButton('谱号／调号（可选）');self.context_toggle.setCheckable(True);layout.addWidget(self.context_toggle)
        self.context_panel=QWidget();marks_layout=QVBoxLayout(self.context_panel);marks_layout.setContentsMargins(0,0,0,0)
        marks=QGridLayout();marks_layout.addLayout(marks);layout.addWidget(self.context_panel)
        self.mark_position=QLineEdit('0');self.mark_position.setMaximumWidth(85);self.mark_position.setToolTip('小节内精确位置，四分音符=1；可输入1/2等分数')
        self.clef=QComboBox()
        for label,value in (('不改谱号',None),('高音谱号 G2',('G',2)),('低音谱号 F4',('F',4)),('中音谱号 C3',('C',3)),('次中音谱号 C4',('C',4))):self.clef.addItem(label,value)
        self.clef_staff=QSpinBox();self.clef_staff.setRange(1,128);self.clef_staff.setMaximumWidth(64)
        self.clef_octave=QSpinBox();self.clef_octave.setRange(-2,2);self.clef_octave.setMaximumWidth(64)
        self.key=QComboBox();self.key.addItem('不改调号',None)
        for fifths in range(-7,8):self.key.addItem(f'{abs(fifths)}个'+('降号' if fifths<0 else '升号') if fifths else '无升降号',fifths)
        for column,(label,widget) in enumerate((('记号位置',self.mark_position),('谱号',self.clef),('目标谱表',self.clef_staff),('八度变化',self.clef_octave),('调号（整件乐器）',self.key))):
            marks.addWidget(QLabel(label),0,column);marks.addWidget(widget,1,column)
        marks_hint=QLabel('谱号与调号只修正记谱，不自动改绝对音高；声音不对时还需修正下表音高。');marks_hint.setWordWrap(True);marks_layout.addWidget(marks_hint)
        self.context_toggle.toggled.connect(self.context_panel.setVisible);self.context_panel.hide()
        self.table=QTableWidget(0,len(self.fields));self.table.setMinimumHeight(150);self.table.setHorizontalHeaderLabels(self.labels);layout.addWidget(self.table,1)
        row=QGridLayout();layout.addLayout(row)
        for i,(label,fn) in enumerate((('添加音符/休止',self.add_row),('删除选中行',self.remove_rows),('按记谱与比例重算时长',self.recalculate),('应用当前小节',self.apply))):
            button=QPushButton(label);button.clicked.connect(fn);row.addWidget(button,i//2 if available.width()<1050 else 0,i%2 if available.width()<1050 else i)
        self.status=QLabel();self.status.setWordWrap(True);layout.addWidget(self.status)
        self.issues=QPlainTextEdit();self.issues.setReadOnly(True);self.issues.setMinimumHeight(40);self.issues.setMaximumHeight(80);layout.addWidget(self.issues)
        buttons=QDialogButtonBox(QDialogButtonBox.StandardButton.Ok|QDialogButtonBox.StandardButton.Cancel)
        buttons.button(QDialogButtonBox.StandardButton.Ok).setText('确认校正');buttons.button(QDialogButtonBox.StandardButton.Cancel).setText('取消')
        buttons.accepted.connect(self.accept_changes);buttons.rejected.connect(self.reject);outer.addWidget(buttons)
        self.dirty=False;self.loaded_index=None;self.table.itemChanged.connect(self.changed)
        self.tempo.textChanged.connect(self.changed)
        self.meter.textChanged.connect(self.changed)
        self.mark_position.textChanged.connect(self.changed);self.clef.currentIndexChanged.connect(self.changed)
        self.clef_staff.valueChanged.connect(self.changed);self.clef_octave.valueChanged.connect(self.changed);self.key.currentIndexChanged.connect(self.changed)
        self.pick.currentIndexChanged.connect(self.load);self.load()
    def changed(self,*_):self.dirty=True
    def load(self,*_):
        if not self.locations:return
        if self.dirty:
            answer=QMessageBox.question(self,'小节校正','切换前是否应用当前小节修改？',QMessageBox.StandardButton.Yes|QMessageBox.StandardButton.No|QMessageBox.StandardButton.Cancel)
            if answer==QMessageBox.StandardButton.Cancel or answer==QMessageBox.StandardButton.Yes and not self.apply():
                self.pick.blockSignals(True);self.pick.setCurrentIndex(self.loaded_index);self.pick.blockSignals(False);return
        self.part,self.index=self.locations[self.pick.currentIndex()];self.rows=measure_data(self.document,self.part,self.index)['rows'];self.table.setRowCount(0)
        for row in self.rows:self.insert(row)
        self.tempo.clear();self.meter.clear();self.mark_position.setText('0');self.clef.setCurrentIndex(0);self.key.setCurrentIndex(0)
        self.clef_staff.setValue(1);self.clef_octave.setValue(0);self.loaded_index=self.pick.currentIndex();self.dirty=False
        self.status.setText('本小节尚未修改；保存会重新检查拍数与延音链。')
        self.refresh_issues()
    def refresh_issues(self):
        from .score_audit import audit
        issues,measures,_=audit(xml_root(self.document.current_xml))
        current=next(m for m in measures if m['part']==self.part and m['index']==self.index)
        selected=[i for i in issues if i['part'] in ('*',self.part) and (i['part']=='*' or i['measure']==current['measure'])]
        self.issues.setPlainText('\n'.join(('待确认：' if i['severity']=='question' else '错误：')+i['message'] for i in selected) or '本小节结构检查未发现问题；这不代表已与原谱核对。')
    def insert(self,row):
        index=self.table.rowCount();self.table.insertRow(index)
        for column,key in enumerate(self.fields):
            if key=='type':
                choice=QComboBox()
                for value,label in self.type_names.items():choice.addItem(label,value)
                current=row.get(key,'quarter')
                if current not in self.type_names:choice.addItem(current,current)
                choice.setCurrentIndex(choice.findData(current));choice.currentIndexChanged.connect(self.changed)
                self.table.setCellWidget(index,column,choice);continue
            value=row.get(key,'');value=int(value) if isinstance(value,bool) else '' if value is None else value
            self.table.setItem(index,column,QTableWidgetItem(str(value)))
    def add_row(self):
        row=dict(id='n'+uuid.uuid4().hex,voice='1',staff='1',start='0',duration='1',pitch=None,type='quarter',dots=0,actual=1,normal=1)
        self.rows.append(row);self.insert(row)
        self.dirty=True
    def remove_rows(self):
        for row in sorted({i.row() for i in self.table.selectedIndexes()},reverse=True):self.table.removeRow(row);self.rows.pop(row)
        self.dirty=True
    def values(self):
        rows=copy.deepcopy(self.rows)
        for index,row in enumerate(rows):
            for column,key in enumerate(self.fields):
                value=self.table.cellWidget(index,column).currentData() if key=='type' else self.table.item(index,column).text().strip()
                if key in ('start','duration'):
                    number=Fraction(value)
                    if number<0:raise ValueError('起点和时长不能为负数')
                    row[key]=str(number)
                elif key=='pitch':
                    row[key]=int(value) if value else None
                    if row[key] is not None and not 0<=row[key]<=127:raise ValueError('MIDI音高必须为0～127')
                elif key in ('dots','actual','normal'):row[key]=int(value)
                elif key in self.fields[9:]:
                    if value not in ('0','1',''):raise ValueError('布尔项只能填0或1')
                    row[key]=value=='1'
                else:row[key]=value
            if not 0<=row['dots']<=4 or min(row['actual'],row['normal'])<1:raise ValueError('附点范围0～4，连音比例必须为正整数')
        return rows
    def recalculate(self):
        from .score_audit import TYPES
        try:
            rows=self.values();selected={i.row() for i in self.table.selectedIndexes()}
            if not selected:raise ValueError('请先选中需要重算的行')
            for index in selected:
                row=rows[index];duration=Fraction(TYPES[row['type']])*sum((Fraction(1,2**i) for i in range(row['dots']+1)),Fraction())*Fraction(row['normal'],row['actual'])
                self.table.item(index,3).setText(str(duration))
        except Exception as exc:QMessageBox.warning(self,'时值重算',str(exc))
    def apply(self):
        try:
            candidate=copy.deepcopy(self.document);apply_measure(candidate,self.part,self.index,self.values())
            if self.tempo.text().strip():
                from .measure_editor import set_measure_tempo
                set_measure_tempo(candidate,self.part,self.index,self.tempo.text().strip())
            if self.meter.text().strip():
                from .measure_editor import set_measure_meter
                pair=self.meter.text().strip().split('/')
                if len(pair)!=2:raise ValueError('拍号格式为分子/分母，例如3/4')
                set_measure_meter(candidate,self.part,self.index,*pair)
            if self.clef.currentData() is not None:
                from .measure_editor import set_measure_clef
                sign,line=self.clef.currentData();set_measure_clef(candidate,self.part,self.index,self.clef_staff.value(),sign,line,self.clef_octave.value(),self.mark_position.text())
            if self.key.currentData() is not None:
                from .measure_editor import set_measure_key
                set_measure_key(candidate,self.part,self.index,self.key.currentData(),self.mark_position.text())
            self.document=candidate
            self.refresh_issues()
            self.dirty=False
            self.status.setText('已应用。确认后重新生成试听时间线；结构疑点仍需核对。');return True
        except Exception as exc:QMessageBox.warning(self,'小节校正',str(exc));return False
    def accept_changes(self):
        if self.apply():self.result_document=self.document;self.accept()
