"""实际 Qt 音频后端的静音自检：解码、推进、暂停定位及区间循环，不连接 FPGA。"""
from pathlib import Path
import json
import os
import sys
import time

os.environ.setdefault('QT_QPA_PLATFORM','offscreen')
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT))
from PySide6.QtCore import QTimer
from PySide6.QtWidgets import QApplication
from PySide6.QtMultimedia import QMediaDevices,QMediaPlayer
from host_app.music_project import MusicProject
from host_app.preview_player import PreviewPlayer


def main():
    app=QApplication([]);player=PreviewPlayer();player.set_volume(0)
    outputs=QMediaDevices.audioOutputs()
    if not outputs:raise RuntimeError('没有实际音频输出设备，无法执行 Qt 后端自检')
    output=next((d for d in outputs if 'Realtek' in d.description()),outputs[0]);player.set_output(output)
    project=MusicProject.load(ROOT/'build/imported_scores/Nocturne_D_Minor_开源校谱版_v3.fpgamusic')
    song=project.songs[0];locate_tick=8*song.ppqn;loop_end=10*song.ppqn
    checks=[];errors=[];stage=0;paused_at=0;seen_loop_end=False;started=time.monotonic()
    player.error.connect(errors.append)
    def finish():
        timer.stop();player.shutdown();app.quit()
    def poll():
        nonlocal stage,paused_at,seen_loop_end
        if errors or time.monotonic()-started>30:finish();return
        if stage==0 and player.ready and player.cursor>80:
            checks.append('actual_audio_position_advances');player.pause_resume();player.seek(locate_tick)
            paused_at=time.monotonic();stage=1
        elif stage==1 and time.monotonic()-paused_at>.25:
            if player.media.playbackState()!=QMediaPlayer.PlaybackState.PausedState or abs(player.cursor-locate_tick)>5:
                errors.append(f'暂停定位失败：{player.cursor}');finish();return
            checks.append('seek_keeps_paused');player.loop_range=(locate_tick,loop_end);player.pause_resume();stage=2
        elif stage==2:
            if player.cursor>loop_end-song.ppqn//2:seen_loop_end=True
            if seen_loop_end and player.cursor<locate_tick+song.ppqn//2:
                checks.append('selection_loop_wraps');stage=3;finish()
    timer=QTimer();timer.timeout.connect(poll);timer.start(30)
    player.play(song,project.patches,engine='reference');app.exec()
    result=dict(passed=stage==3 and not errors,checks=checks,errors=errors,
                output=output.description(),volume=0,engine='FluidSynth reference',notes=len(project.songs[0].notes),
                uncertain_after=sum(n.uncertain for n in project.songs[0].notes),
                elapsed_seconds=round(time.monotonic()-started,3),
                boundary='仅验证电脑 Qt 音频后端；未连接 FPGA，未验证扬声器声学输出')
    report=ROOT/'build/tests/workstation_preview_backend.json';report.write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(result,ensure_ascii=False,indent=2));return 0 if result['passed'] else 1


if __name__=='__main__':raise SystemExit(main())
