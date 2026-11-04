"""轨道头和混音器复用同一种通道条；控件只发意图，不持有另一份工程数据。"""
from PySide6.QtCore import Qt, Signal
from PySide6.QtWidgets import QWidget,QVBoxLayout,QHBoxLayout,QLabel,QSlider,QDoubleSpinBox,QCheckBox,QProgressBar,QScrollArea
from .music_project import PARTS
from .stream_synth import owners,mix_values
import math


class GainSlider(QSlider):
    def mouseDoubleClickEvent(self,event):self.setValue(0);self.sliderReleased.emit();event.accept()


class TrackMixer(QWidget):
    changed=Signal(str,float,bool,bool);finished=Signal()
    def __init__(self,parent=None,horizontal=False):
        super().__init__(parent);self.widgets={};self.identity=None;self.horizontal=horizontal
        outer=QVBoxLayout(self);outer.setContentsMargins(0,0,0,0)
        self.scroll=QScrollArea();self.scroll.setWidgetResizable(True);outer.addWidget(self.scroll)
        self.body=QWidget();self.rows=QHBoxLayout(self.body) if horizontal else QVBoxLayout(self.body)
        self.rows.setContentsMargins(3,3,3,3);self.rows.setSpacing(4);self.scroll.setWidget(self.body)
        self.rows.addStretch()
    def set_song(self,song):
        keys=owners(song) if song else [];identity=(song.resource_id,tuple(keys)) if song else None
        if identity!=self.identity:
            while self.rows.count():
                item=self.rows.takeAt(0)
                if item.widget():item.widget().deleteLater()
            self.widgets={};self.identity=identity
            for i,key in enumerate(keys):
                strip=QWidget();column=QVBoxLayout(strip);column.setContentsMargins(3,2,3,2);column.setSpacing(2)
                name=song.source_tracks[i].name if song.source_tracks else PARTS[i]
                label=QLabel(name);label.setToolTip(name);label.setWordWrap(True);column.addWidget(label)
                row=QHBoxLayout();row.setSpacing(3);slider=GainSlider(Qt.Orientation.Horizontal);slider.setRange(-610,60);slider.setToolTip('合成后音量；双击恢复0 dB；最左端静音')
                number=QDoubleSpinBox();number.setRange(-61,6);number.setDecimals(1);number.setSingleStep(.1);number.setSuffix(' dB');number.setSpecialValueText('−∞');number.setFixedWidth(86)
                row.addWidget(slider,1);row.addWidget(number);column.addLayout(row)
                row=QHBoxLayout();mute=QCheckBox('静音');solo=QCheckBox('独奏');meter=QProgressBar();meter.setRange(0,600);meter.setTextVisible(False);meter.setFixedHeight(8)
                row.addWidget(mute);row.addWidget(solo);row.addWidget(meter,1);column.addLayout(row)
                self.rows.addWidget(strip);self.widgets[key]=(slider,number,mute,solo,meter)
                slider.valueChanged.connect(lambda v,n=number,k=key:self._slide(k,v,n))
                number.valueChanged.connect(lambda v,s=slider,k=key:self._number(k,v,s))
                slider.sliderReleased.connect(self.finished);number.editingFinished.connect(self.finished)
                mute.toggled.connect(lambda b,k=key:self._emit(k));solo.toggled.connect(lambda b,k=key:self._emit(k))
                mute.clicked.connect(self.finished);solo.clicked.connect(self.finished)
                if self.horizontal:strip.setMinimumWidth(230)
            self.rows.addStretch()
        if song:self.set_values(mix_values(song))
    def _emit(self,key):
        _,n,m,s,_=self.widgets[key];self.changed.emit(key,-120. if n.value()<=-61 else n.value(),m.isChecked(),s.isChecked())
    def _slide(self,key,value,number):
        number.blockSignals(True);number.setValue(value/10);number.blockSignals(False);self._emit(key)
    def _number(self,key,value,slider):
        slider.blockSignals(True);slider.setValue(round(value*10));slider.blockSignals(False);self._emit(key)
    def set_values(self,values):
        for key,v in values.items():
            if key not in self.widgets:continue
            slider,number,mute,solo,_=self.widgets[key];db=-61 if v.get('db',0)<=-90 else v.get('db',0)
            for widget,value in ((slider,round(db*10)),(number,db),(mute,v.get('mute',False)),(solo,v.get('solo',False))):
                widget.blockSignals(True)
                widget.setChecked(value) if isinstance(widget,QCheckBox) else widget.setValue(value)
                widget.blockSignals(False)
    def set_meters(self,snapshot):
        for key,values in snapshot.get('tracks',{}).items():
            if key not in self.widgets:continue
            meter=self.widgets[key][-1];peak=values['peak'];db=20*math.log10(max(1e-6,peak))
            meter.setValue(round(max(0,min(600,(db+60)*10))));meter.setToolTip(f'峰值 {db:.1f} dBFS · RMS {values["rms"]:.4f}')
            meter.setStyleSheet('QProgressBar::chunk{background:'+('#eb645f' if peak>=1 else '#57ccac')+';}')
