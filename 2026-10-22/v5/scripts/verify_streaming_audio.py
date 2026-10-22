"""静音验证真实Qt音频缓冲和子进程清理，不把结果当作听音或FPGA延迟证据。"""
from pathlib import Path
import json,os,sys,time
sys.path.insert(0,str(Path(__file__).resolve().parents[1]));os.environ.setdefault('QT_QPA_PLATFORM','offscreen')

def main():
    from PySide6.QtWidgets import QApplication
    from PySide6.QtCore import QTimer
    from PySide6.QtMultimedia import QMediaDevices
    from host_app.music_project import Song,Note,Section
    from host_app.stream_player import StreamingPreview
    app=QApplication([]);player=StreamingPreview();player.set_volume(0)
    report=dict(muted=True,devices=[d.description() for d in QMediaDevices.audioOutputs()],messages=[],errors=[],max_tick=0)
    player.messageChanged.connect(lambda text:report['messages'].append(text));player.error.connect(report['errors'].append)
    player.positionChanged.connect(lambda tick:report.update(max_tick=max(report['max_tick'],tick)))
    if report['devices']:
        song=Song(notes=[Note(0,960,60),Note(240,480,60),Note(0,960,64)],sections=[Section(end=960,volumes=[100]*4)])
        QTimer.singleShot(0,lambda:player.play(song,[],engine='reference'))
        QTimer.singleShot(6000,app.quit);app.exec()
        report['passed']=not report['errors'] and 900<=report['max_tick']<=song.duration
    else:report.update(passed=False,reason='没有音频输出设备，未执行实设备缓冲测试')
    player.shutdown();target=Path(__file__).resolve().parents[1]/'build/tests/realtime_audio.json';target.parent.mkdir(parents=True,exist_ok=True)
    target.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps(report,ensure_ascii=True));return 0 if report['passed'] else 1

if __name__=='__main__':raise SystemExit(main())
