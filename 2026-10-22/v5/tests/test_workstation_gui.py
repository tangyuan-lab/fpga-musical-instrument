"""离线验证设备目录、异步编辑及钢琴卷帘，不连接串口。"""
import copy,os,tempfile,unittest
from pathlib import Path
os.environ.setdefault('QT_QPA_PLATFORM','offscreen')
from PySide6.QtWidgets import QApplication
from PySide6.QtCore import Qt,QPoint
from PySide6.QtTest import QTest
from host_app.workstation_gui import WorkstationWindow,EditSong
from host_app.music_project import Song,Note,Patch,Section,MusicProject


class FakeDevice:
    def __init__(self,catalog):self.items=copy.deepcopy(catalog);self.commands=[]
    def catalog(self):return copy.deepcopy(self.items)
    def control(self,*args):self.commands.append(args)
    def close(self):pass
    def state(self):
        return dict(revision=7,song=2,live_timbre=5,voices=1,pressure=0,
            paused=False,playing=True,section=0,tick=10,duration=480)


class GuiTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.app=QApplication.instance() or QApplication([])
    def setUp(self):
        self.w=WorkstationWindow();self.w.poller.stop()
        self.items=[dict(kind=0,slot=2,name='设备歌曲',resource_id='song-id',revision=3),
            dict(kind=1,slot=3,name='设备音色',resource_id='patch-id',revision=2)]
        self.w.catalog_received(self.items);self.w.catalog_revision=7
        self.device=FakeDevice(self.items);self.w.device=self.device
        def inline(label,fn,success=None,quiet=False):
            result=fn()
            if success:success(result)
        self.w.run=inline
    def tearDown(self):self.w.confirm_saved=lambda:True;self.w.close()
    def test_emergency_bypasses_busy_upload_queue(self):
        import threading
        called=[];self.device.features=4;self.device.emergency=lambda **kwargs:called.append(threading.get_ident())
        self.w.busy=True;self.w.pending_tasks.append(('开始设备演奏',lambda:None,None,False))
        self.w.control('panic')
        for _ in range(100):
            QTest.qWait(10)
            if self.w.emergency_task is None:break
        self.w.busy=False
        self.assertEqual(len(called),1);self.assertNotEqual(called[0],threading.get_ident())
        self.assertFalse(self.w.pending_tasks);self.assertFalse(self.device.commands)
    def test_preview_target_stops_fpga_and_waits_for_ack_before_computer_sound(self):
        self.w.project.songs=[Song(notes=[Note(0,480,60)])];self.w.song_index=0;self.w.refresh()
        calls=[];failures=[];pending=[];self.w.local_player.play=lambda *a,**k:calls.append(True)
        self.w.failure=lambda label,text:failures.append(text)
        self.w.preview_engine.setCurrentIndex(self.w.preview_engine.findData('fpga'))
        self.w.run=lambda label,fn,success=None,quiet=False:pending.append((fn,success))
        self.w.preview_engine.setCurrentIndex(self.w.preview_engine.findData('reference'))
        self.assertTrue(self.w._preview_stop_pending)
        self.w.play_local();self.assertFalse(calls);self.assertIn('确认停音',failures[-1])
        fn,success=pending.pop();success(fn())
        self.assertEqual(self.device.commands,[('panic',)]);self.assertFalse(self.w._preview_stop_pending)
        self.w.play_local();self.assertEqual(calls,[True])
    def test_track_capacity_check_is_read_only_and_does_not_use_the_port(self):
        from PySide6.QtWidgets import QDialog
        self.w.project.songs=[Song(notes=[Note(0,960,60),Note(480,1200,60)])];self.w.song_index=0;self.w.refresh()
        before=copy.deepcopy(self.w.project)
        report=self.w.inspect_track_capacity()
        self.assertEqual(report['channels'][:2],[0,0]);self.assertFalse(report['integrated_firmware'])
        self.assertEqual(self.w.project,before);self.assertFalse(self.device.commands)
        for dialog in self.w.findChildren(QDialog):dialog.reject()
    def test_save_keeps_unsent_editor_drafts_and_section_transpose(self):
        self.w.project.songs=[Song(notes=[Note(0,480,60)],sections=[Section(transpose=7)])]
        self.w.project.patches=[Patch()];self.w.song_index=0;self.w.patch_index=0;self.w.refresh()
        self.w.patch_name.setText('本地修订');self.w.sections.item(0,0).setText('修改段名')
        self.w.waveform.samples[0]=12345
        self.assertNotEqual(self.w.project.patches[0].waveform[0],12345)
        self.assertTrue(all(self.w.editor_drafts()))
        with tempfile.TemporaryDirectory() as d:
            self.w.project_path=str(Path(d)/'draft.fpgamusic');self.assertTrue(self.w.save_project())
            loaded=MusicProject.load(self.w.project_path)
        self.assertEqual(loaded.patches[0].name,'本地修订')
        self.assertEqual(loaded.patches[0].waveform[0],12345)
        self.assertEqual(loaded.songs[0].sections[0].transpose,7)
        self.assertEqual(loaded.songs[0].sections[0].name,'修改段名')
        self.assertFalse(any(self.w.editor_drafts()));self.assertFalse(self.device.commands)
    def test_pdf_import_starts_staff_recognition(self):
        with tempfile.TemporaryDirectory() as d:
            source=Path(d)/'score.pdf';source.write_bytes(b'%PDF-test')
            called=[]
            self.w.recognize=lambda kind: called.append((kind,self.w.current_song().name))
            self.w.import_score(str(source))
            self.assertEqual(called,[('staff','score')])
            self.assertEqual(self.w.current_song().issues,['待识谱或手动录入'])
    def test_play_explains_unrecognized_score_and_missing_device(self):
        failures=[];self.w.failure=lambda label,message:failures.append(message)
        self.w.project.songs=[Song(name='仅PDF')];self.w.song_index=0;self.w.play()
        self.assertIn('等待识谱',failures[-1])
        self.w.project.songs[0].notes=[Note(0,480,60,uncertain=True)];self.w.play()
        self.assertIn('确认识别',failures[-1])
        self.w.project.songs[0].notes[0].uncertain=False;self.w.device=None;self.w.play()
        self.assertIn('V2位流',failures[-1]);self.assertFalse(self.device.commands)
    def test_play_resident_song_without_local_project(self):
        self.assertFalse(self.w.project.songs);self.w.play_resident_song()
        self.assertEqual(self.device.commands,[('mode',3),('select_song',2),('play',)])
        self.assertIn('设备歌曲',self.w.actual_selection.text())
    def test_catalog_replacement_rejected_before_play(self):
        self.device.items[0]['resource_id']='replacement'
        with self.assertRaisesRegex(ValueError,'曲库已变化'):self.w.play_resident_song()
        self.assertFalse(self.device.commands)
    def test_select_resident_patch_and_reject_replacement(self):
        self.w.resident_patch.setCurrentIndex(2);self.w.apply_resident_patch()
        self.assertEqual(self.device.commands,[('live_timbre',5),('screen_timbre',5)])
        self.assertIn('设备音色',self.w.actual_selection.text())
        self.device.commands.clear();self.device.items[1]['revision']=99
        with self.assertRaisesRegex(ValueError,'音色已变化'):self.w.apply_resident_patch()
        self.assertFalse(self.device.commands)
    def test_edit_targets_resource_when_selection_changes(self):
        original=Song(name='待识谱',notes=[Note(0,480,60)])
        other=Song(name='用户当前选择',notes=[Note(0,480,72)])
        self.w.project.songs=[original,other];self.w.song_index=1
        result=copy.deepcopy(original);result.notes[0].pitch=64
        self.w.undo.push(EditSong(self.w,original,result,'后台识谱'))
        self.assertEqual([s.notes[0].pitch for s in self.w.project.songs],[64,72])
        self.w.undo.undo();self.assertEqual([s.notes[0].pitch for s in self.w.project.songs],[60,72])
    def test_local_preview_accepts_uncertain_notes_without_device_commands(self):
        self.w.project.songs=[Song(notes=[Note(0,480,60,uncertain=True)],sections=[Section()])]
        self.w.song_index=0;self.w.refresh();calls=[]
        options=[]
        self.w.local_player.play=lambda *args,**kwargs:(calls.append(args),options.append(kwargs))
        self.w.play_local();self.assertEqual(len(calls),1)
        self.assertTrue(calls[0][0].notes[0].uncertain);self.assertFalse(self.device.commands)
        self.assertEqual(options[0]['engine'],'reference')
        self.assertTrue(self.w.current_song().notes[0].uncertain)
        self.w.track_mutes[0].setChecked(True);self.w.play_local();self.assertEqual(calls[-1][2],{0})
    def test_roll_drag_resize_velocity_and_undo(self):
        self.w.project.songs=[Song(notes=[Note(240,720,60,uncertain=True)],sections=[Section()])]
        self.w.song_index=0;self.w.refresh();self.w.show();self.app.processEvents();roll=self.w.roll
        roll.horizontalScrollBar().setValue(0)
        roll.verticalScrollBar().setValue(round((127-60)*roll.ROW-55))
        rect=roll.note_rect(self.w.current_song().notes[0]);point=rect.center().toPoint()
        QTest.mousePress(roll.viewport(),Qt.MouseButton.LeftButton,pos=point)
        target=point+QPoint(round(roll.ppb/2),-roll.ROW)
        QTest.mouseMove(roll.viewport(),target);QTest.mouseRelease(roll.viewport(),Qt.MouseButton.LeftButton,pos=target)
        note=self.w.current_song().notes[0];self.assertEqual((note.start,note.end,note.pitch),(480,960,61));self.assertTrue(note.uncertain)
        self.assertEqual(self.w.selected_rows(),[0]);self.w.undo.undo();note=self.w.current_song().notes[0]
        self.assertEqual((note.start,note.end,note.pitch),(240,720,60))
        rect=roll.note_rect(note);point=QPoint(round(rect.right()-2),round(rect.center().y()))
        QTest.mousePress(roll.viewport(),Qt.MouseButton.LeftButton,pos=point)
        target=point+QPoint(round(roll.ppb/2),0);QTest.mouseMove(roll.viewport(),target);QTest.mouseRelease(roll.viewport(),Qt.MouseButton.LeftButton,pos=target)
        self.assertEqual(self.w.current_song().notes[0].end,960)
        point=QPoint(round(roll.x(240)+2),roll.viewport().height()-20)
        QTest.mousePress(roll.viewport(),Qt.MouseButton.LeftButton,pos=point);QTest.mouseRelease(roll.viewport(),Qt.MouseButton.LeftButton,pos=point)
        self.assertLess(self.w.current_song().notes[0].velocity,100);self.assertFalse(self.device.commands)
    def test_roll_add_delete_and_selection_loop(self):
        self.w.project.songs=[Song(notes=[Note(0,480,60)],sections=[Section()])]
        self.w.song_index=0;self.w.refresh();self.w.add_roll_note(960,1440,64,1)
        self.w.select_roll_notes([0,1]);self.w.local_loop.setChecked(True)
        self.assertEqual(self.w.local_loop_range(),(0,1440));self.assertEqual(self.w.roll.selected,{0,1})
        self.w.delete_roll_note(1);self.assertEqual(len(self.w.current_song().notes),1)
        self.w.undo.undo();self.assertEqual(len(self.w.current_song().notes),2);self.assertFalse(self.device.commands)
    def test_numeric_editor_rejects_out_of_range_part(self):
        self.w.project.songs=[Song(notes=[Note(0,480,60)])];self.w.song_index=0;self.w.refresh()
        errors=[];self.w.failure=lambda label,message:errors.append(message)
        self.w.notes.item(0,4).setText('9')
        self.assertEqual(self.w.current_song().notes[0].part,0);self.assertIn('声部0..3',errors[0])
    def test_source_position_highlight_does_not_confirm_or_modify_notes(self):
        from PIL import Image
        with tempfile.TemporaryDirectory() as d:
            path=Path(d)/'source.png';Image.new('RGB',(200,100),'white').save(path)
            self.w.project.songs=[Song(notes=[Note(0,480,60,box=[20,20,10,10],uncertain=True)],source_files=[str(path)])]
            self.w.song_index=0;self.w.refresh();self.w.select_roll_notes([0])
            color=self.w.preview.pixmap().toImage().pixelColor(16,16)
            self.assertGreater(color.red(),color.green()+80)
            self.assertTrue(self.w.current_song().notes[0].uncertain);self.assertFalse(self.device.commands)

    def test_competition_disables_both_local_preview_paths(self):
        calls=[];self.w.local_player.play=lambda *args,**kwargs:calls.append(args)
        errors=[];self.w.failure=lambda title,message:errors.append(message)
        self.w.competition.setChecked(True);self.w.play_local();self.w.audition_local()
        self.assertFalse(calls);self.assertEqual(len(errors),2);self.assertFalse(self.w.local_play_button.isEnabled())
    def test_actual_background_queue_delivers_results_in_order(self):
        import time
        self.w.run=WorkstationWindow.run.__get__(self.w);received=[]
        self.w.run('读取',lambda:(time.sleep(.03),41)[1],received.append)
        self.w.run('用户操作',lambda:42,received.append)
        deadline=time.monotonic()+3
        while time.monotonic()<deadline and (self.w.busy or self.w.pending_tasks):QTest.qWait(20)
        self.assertEqual(received,[41,42]);self.assertFalse(self.w.busy)

    def test_actual_background_notation_keeps_selected_resource(self):
        import time
        first=Song(name='旧选择',notes=[Note(0,480,60)]);second=Song(name='新选择',notes=[Note(0,480,72)])
        self.w.project.songs=[first,second];self.w.song_index=0;self.w.refresh();self.w.score_views.setCurrentIndex(3)
        self.w.song_index=1;self.w.refresh()
        deadline=time.monotonic()+5
        while time.monotonic()<deadline and not self.w.notation.pages:QTest.qWait(20)
        self.assertTrue(self.w.notation.pages);self.assertEqual(self.w.notation.song.resource_id,second.resource_id)
        self.assertIn(second.notes[0].note_id,self.w.notation.canvas.source);self.assertNotIn(first.notes[0].note_id,self.w.notation.canvas.source)
    def test_property_editor_and_clip_copy_preserve_original_and_undo(self):
        song=Song(notes=[Note(0,480,60,uncertain=True)],sections=[Section()]);self.w.project.songs=[song];self.w.song_index=0;self.w.refresh();self.w.select_roll_notes([0])
        self.w.note_properties['pitch'].setValue(62);self.w.apply_note_properties()
        self.assertEqual(self.w.current_song().notes[0].pitch,62);self.assertTrue(self.w.current_song().notes[0].uncertain)
        self.w.transform_clip([0],960,True);actual=self.w.current_song()
        self.assertEqual([(n.start,n.end) for n in actual.notes],[(0,480),(960,1440)]);self.assertNotEqual(actual.notes[0].note_id,actual.notes[1].note_id)
        self.w.undo.undo();self.assertEqual(len(self.w.current_song().notes),1);self.w.undo.undo();self.assertEqual(self.w.current_song().notes[0].pitch,60)
        self.assertFalse(self.device.commands)
    def test_external_correction_isolated_to_selected_resource(self):
        from host_app.score_document import from_song
        s=Song(name='原曲',notes=[Note(0,480,60)]);other=Song(notes=[Note(0,480,80)])
        self.w.project.songs=[s,other];self.w.song_index=0;self.w.refresh();replacement=Song(notes=[Note(0,960,62)])
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'edited.musicxml';path.write_text(from_song(replacement).current_xml,encoding='utf-8')
            self.w.import_corrected(str(path),confirm=False)
            self.assertEqual(self.w.current_song().resource_id,s.resource_id);self.assertTrue(all(n.uncertain for n in self.w.current_song().notes));self.assertEqual(self.w.project.songs[1].notes[0].pitch,80)
            self.w.undo.undo();self.assertEqual(self.w.current_song().notes[0].pitch,60)

    def test_late_recognition_does_not_overwrite_manual_edits(self):
        original=Song(name='待识谱',source_files=['source.pdf'],notes=[Note(0,480,60)])
        self.w.project.songs=[original];self.w.song_index=0;callbacks=[];preserved=[]
        self.w.run_background=lambda label,fn,success=None,quiet=False:callbacks.append(success)
        self.w.preserve_recognition_candidate=lambda result:preserved.append(result)
        self.w.recognize('staff')
        original.notes[0].pitch=67
        result=Song(name='识谱候选',notes=[Note(0,480,64)])
        callbacks[0](result)
        self.assertEqual(original.notes[0].pitch,67)
        self.assertEqual(preserved,[result]);self.assertEqual(self.w.undo.count(),0)

    def test_conflicting_candidate_survives_session_close(self):
        with tempfile.TemporaryDirectory() as directory:
            source=Path(directory)/'original.pdf';source.write_bytes(b'%PDF-preserved')
            candidate=Song(source_files=[str(source)],notes=[Note(0,480,60,uncertain=True)])
            path=self.w.preserve_recognition_candidate(candidate,Path(directory)/'candidates')
            restored=MusicProject.load(path)
            self.assertTrue(restored.songs[0].notes[0].uncertain)
            self.assertEqual(restored.songs[0].resource_id,candidate.resource_id)
            self.assertEqual(Path(restored.songs[0].source_files[0]).read_bytes(),b'%PDF-preserved')

    def test_workspaces_do_not_send_device_commands_and_text_keeps_space(self):
        for index in range(4):self.w.workspace.setCurrentIndex(index)
        self.assertFalse(self.device.commands)
        played=[];self.w.play_local=lambda:played.append(True)
        self.w.patch_name.setText('A');QTest.keyClick(self.w.patch_name,Qt.Key.Key_Space)
        self.assertEqual(self.w.patch_name.text(),'A ');self.assertFalse(played)

    def test_switching_away_from_source_clears_comparison(self):
        from PySide6.QtGui import QPixmap
        self.w.comparison_source.set_image(QPixmap(120,180))
        self.w.project.songs=[Song()];self.w.song_index=0;self.w.refresh()
        self.assertIsNone(self.w.comparison_source.image)

    def test_midi_import_filters_original_tracks_and_upgrades_without_overwrite(self):
        import mido,zipfile,json
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'tracks.mid';midi=mido.MidiFile(type=1)
            for channel,pitch in ((3,60),(4,67)):
                midi.tracks.append(mido.MidiTrack([mido.MetaMessage('track_name',name=f'Instrument {channel}'),mido.Message('note_on',channel=channel,note=pitch,velocity=90),mido.Message('note_off',channel=channel,note=pitch,time=480)]))
            midi.save(path);self.w.import_score(str(path))
            song=self.w.current_song();self.assertEqual(len(song.source_tracks),2)
            self.w.roll_track.setCurrentIndex(1);identifier=self.w.roll.source_track
            self.assertEqual(sum(self.w.roll.matches(n) for n in song.notes),1)
            self.w.select_roll_notes([0]);self.assertEqual(self.w.property_part.currentData(),song.notes[0].track_id)
            self.assertEqual(identifier,song.source_tracks[0].track_id)
            old=Path(directory)/'legacy.fpgamusic'
            with zipfile.ZipFile(old,'w') as package:package.writestr('project.json',json.dumps({'format':3,'project':{'name':'old','songs':[],'patches':[]}}))
            before=old.read_bytes();self.w.load_project_file(old);self.w.save_project()
            self.assertEqual(old.read_bytes(),before);self.assertTrue(Path(self.w.project_path).name.endswith('_v5.fpgamusic'))

    def test_unsupported_snap_is_not_silently_rounded_and_free_grid_renders(self):
        self.w.project.songs=[Song(notes=[Note(0,480,60)])];self.w.song_index=0;self.w.refresh()
        self.w.roll_snap.setCurrentIndex(5)
        self.assertEqual(self.w.roll.snap_division,4)
        self.assertIn('不能精确',self.w.status.text())
        self.w.roll_snap.setCurrentIndex(6);self.w.show();QTest.qWait(10)
        self.assertEqual(self.w.roll.snap,1);self.assertFalse(self.w.roll.grab().isNull())

if __name__=='__main__':unittest.main()
