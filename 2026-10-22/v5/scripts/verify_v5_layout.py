"""离屏检查窗口能否容纳常用分辨率/缩放；不代表真实显示器交互验收。"""
from pathlib import Path
import argparse,json,os,subprocess,sys,tempfile

ROOT=Path(__file__).resolve().parents[1]


def render(width,height,scale):
    os.environ['QT_QPA_PLATFORM']='offscreen';os.environ['QT_SCALE_FACTOR']=str(scale)
    sys.path.insert(0,str(ROOT))
    from PySide6.QtCore import QSettings
    from PySide6.QtWidgets import QApplication,QDialogButtonBox
    from PySide6.QtTest import QTest
    from host_app.workstation_gui import WorkstationWindow,configure_appearance
    from host_app.music_project import Song,Note,Section
    from host_app.score_document import from_song
    from host_app.measure_dialog import MeasureDialog
    with tempfile.TemporaryDirectory() as directory:
        QSettings.setDefaultFormat(QSettings.Format.IniFormat)
        QSettings.setPath(QSettings.Format.IniFormat,QSettings.Scope.UserScope,directory)
        app=QApplication([]);configure_appearance(app);window=WorkstationWindow();window.poller.stop();window.autosave_timer.stop()
        song=Song(notes=[Note(0,480,60),Note(480,960,64),Note(960,1440,67)],sections=[Section()]);song.score_document=from_song(song)
        window.project.songs=[song];window.song_index=0;window.refresh()
        logical=(round(width/scale),round(height/scale));window.fit_to_space(*logical);window.show();QTest.qWait(80)
        folder=ROOT/'build/tests/layout_v5';folder.mkdir(parents=True,exist_ok=True)
        result=dict(physical=[width,height],scale=scale,requested=list(logical),workspaces=[],
                    minimum=[window.minimumSizeHint().width(),window.minimumSizeHint().height()],
                    editor_minimum=[[window.score_views.tabText(i),window.score_views.widget(i).minimumSizeHint().width(),window.score_views.widget(i).minimumSizeHint().height()] for i in range(window.score_views.count())])
        for index in range(4):
            window.workspace.setCurrentIndex(index);QTest.qWait(70)
            record=dict(index=index,actual=[window.width(),window.height()],fits=window.width()<=logical[0] and window.height()<=logical[1],
                        playback_target_visible=window.preview_engine.isVisible())
            if index in (0,1):window.grab().save(str(folder/f'{width}_{height}_{scale}_{index}.png'))
            result['workspaces'].append(record)
        dialog=MeasureDialog(song.score_document,window);dialog.resize(max(400,logical[0]-40),max(320,logical[1]-60));dialog.show();QTest.qWait(50)
        dialog.grab().save(str(folder/f'{width}_{height}_{scale}_measure.png'))
        result['measure']=dict(actual=[dialog.width(),dialog.height()],fits=dialog.width()<=logical[0]-20 and dialog.height()<=logical[1]-20,
                               rows=len(dialog.values()))
        dialog.context_toggle.setChecked(True);QTest.qWait(30)
        dialog.grab().save(str(folder/f'{width}_{height}_{scale}_context.png'))
        result['measure']['expanded_fits']=dialog.width()<=logical[0]-20 and dialog.height()<=logical[1]-20
        result['measure']['table_minimum']=dialog.table.height()>=150
        result['passed']=all(x['fits'] and x['playback_target_visible'] for x in result['workspaces']) and result['measure']['fits'] and result['measure']['expanded_fits'] and result['measure']['table_minimum']
        dialog.reject();window.confirm_saved=lambda:True;window.close();app.processEvents()
    target=folder/f'{width}_{height}_{scale}.json';target.write_text(json.dumps(result,indent=2),encoding='utf-8');print(json.dumps(result))
    return 0 if result['passed'] else 1


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--render',nargs=3);args=parser.parse_args()
    if args.render:return render(int(args.render[0]),int(args.render[1]),float(args.render[2]))
    records=[]
    for width,height in ((1366,768),(1920,1080)):
        for scale in (1,1.25,1.5):
            result=subprocess.run([sys.executable,__file__,'--render',str(width),str(height),str(scale)],cwd=ROOT,text=True,capture_output=True,timeout=40)
            if not result.stdout:raise RuntimeError(result.stderr)
            record=json.loads(result.stdout.strip().splitlines()[-1]);records.append(record)
            print(f'{width}x{height} {scale}: '+('PASS' if record['passed'] else json.dumps(record)))
    target=ROOT/'build/tests/layout_v5/result.json';target.write_text(json.dumps(dict(passed=all(r['passed'] for r in records),cases=records),indent=2),encoding='utf-8')
    return 0 if all(r['passed'] for r in records) else 1

if __name__=='__main__':raise SystemExit(main())
