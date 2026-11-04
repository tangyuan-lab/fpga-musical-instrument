import tempfile, unittest, wave, struct, math
from pathlib import Path
from host_app.music_project import *
from host_app.device_v2 import display_name
from host_app.score_import import parse_jianpu
from host_app.score_import import recognize_staff
from unittest.mock import patch
from types import SimpleNamespace

class ProjectTests(unittest.TestCase):
    def test_reengraving_schema_migration_keeps_source_and_review_state(self):
        from host_app.score_document import from_song
        song=Song(notes=[Note(0,160,61,91,uncertain=True)])
        song.score_document=from_song(song)
        song.score_document.notation_schema=2
        song.score_document.original_xml='原始识谱稿'
        song.score_document.initial_xml='识别初稿'
        song.score_document.revision=7
        identity=song.resource_id
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'old.fpgamusic';MusicProject(songs=[song]).save(path)
            original=path.read_bytes();loaded=MusicProject.load(path).songs[0]
            self.assertEqual(path.read_bytes(),original)
        self.assertEqual(loaded.resource_id,identity)
        self.assertEqual(loaded.score_document.notation_schema,3)
        self.assertEqual(loaded.score_document.revision,8)
        self.assertEqual(loaded.score_document.original_xml,'原始识谱稿')
        self.assertEqual(loaded.score_document.initial_xml,'识别初稿')
        self.assertEqual(loaded.notes,song.notes)
        self.assertTrue(loaded.notes[0].uncertain)
    def test_musicxml_piano_staves_preserve_simultaneous_unison(self):
        xml='''<score-partwise><part id="P1"><measure number="1"><attributes><divisions>1</divisions></attributes>
        <note><pitch><step>C</step><octave>4</octave></pitch><duration>2</duration><voice>1</voice><staff>1</staff></note><backup><duration>2</duration></backup>
        <note><pitch><step>C</step><octave>4</octave></pitch><duration>1</duration><voice>2</voice><staff>1</staff></note><backup><duration>1</duration></backup>
        <note><pitch><step>C</step><octave>4</octave></pitch><duration>2</duration><voice>5</voice><staff>2</staff></note>
        </measure></part></score-partwise>'''
        with tempfile.TemporaryDirectory() as d:
            source=Path(d)/'piano.musicxml';source.write_text(xml);song=import_musicxml(source)
        self.assertEqual([(n.start,n.end,n.part) for n in song.notes],[(0,960,0),(0,480,1),(0,960,2)])
        with self.assertRaisesRegex(ValueError,'速度'):song.validate()
        song.score_document.confirmed_assumptions.update(missing_tempo=True,missing_meter=True)
        song.validate()
    def test_musicxml_conflicting_voice_keeps_original_note_duration(self):
        xml='''<score-partwise><part id="P1"><measure><attributes><divisions>1</divisions></attributes>
        <note><pitch><step>C</step><octave>4</octave></pitch><duration>2</duration><voice>1</voice></note><backup><duration>2</duration></backup>
        <note><pitch><step>C</step><octave>4</octave></pitch><duration>1</duration><voice>2</voice></note>
        </measure></part></score-partwise>'''
        with tempfile.TemporaryDirectory() as d:
            source=Path(d)/'voices.musicxml';source.write_text(xml);song=import_musicxml(source)
        self.assertEqual([n.end for n in song.notes],[960,480]);self.assertEqual(len({n.part for n in song.notes}),2)
        self.assertTrue(any(n.uncertain for n in song.notes))
        for n in song.notes:n.uncertain=False
        song.score_document.confirmed_assumptions.update(missing_tempo=True,missing_meter=True)
        song.validate()
    def test_staff_cache_reuses_matching_source_and_invalidates_changes(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);source=root/'score.pdf';source.write_bytes(b'pdf-one');exe=root/'Audiveris.exe';exe.write_bytes(b'launcher')
            def batch(cmd,folder,**kwargs):
                (Path(cmd[cmd.index('-output')+1])/'score.musicxml').write_text('<score-partwise/>')
                return {'returncode':0}
            with patch('host_app.vector_score.recognize_vector_pdf',side_effect=AssertionError('默认导入不得隐式调用矢量启发式')),patch('host_app.process_job.run_tool',side_effect=batch) as run,patch('host_app.score_import.import_musicxml',side_effect=lambda p,**kwargs:Song(notes=[Note(0,480,60)])):
                first=recognize_staff(source,exe,root/'cache');second=recognize_staff(source,exe,root/'cache')
                self.assertEqual(run.call_count,1);self.assertTrue(all(n.uncertain for n in second.notes))
                self.assertEqual(second.source_files,[str(source.resolve())]);self.assertEqual(first.notes[0].pitch,second.notes[0].pitch)
                source.write_bytes(b'pdf-two');recognize_staff(source,exe,root/'cache');self.assertEqual(run.call_count,2)
                recognize_staff(source,exe,root/'cache',force=True);self.assertEqual(run.call_count,3)
    def test_same_part_unison_overlap_is_rejected_without_truncation(self):
        song=Song(notes=[Note(0,960,60,part=0),Note(480,1440,60,part=0)])
        with self.assertRaisesRegex(ValueError,'重叠音符'):song.midi()
        self.assertEqual([n.end for n in song.notes],[960,1440])
        song.notes[1].part=1;song.validate()
    def test_jianpu_rest_extension_does_not_extend_previous_note(self):
        song=parse_jianpu('1 0 - 2 -')
        self.assertEqual([(n.start,n.end,n.pitch) for n in song.notes],[(0,480,60),(1440,2400,62)])
    def test_imported_melody_is_not_muted_by_default(self):
        song=parse_jianpu('1 2 3 4 |');song.validate()
        self.assertEqual(song.sections[0].mute,0)
    def test_midi_roundtrip_preserves_parts(self):
        song=Song(notes=[Note(0,480,60,90,0),Note(0,960,60,80,1),Note(480,960,36,100,3)])
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'x.mid';p.write_bytes(song.midi());actual=import_midi(p)
        self.assertEqual(sorted((n.start,n.end,n.pitch,n.part) for n in actual.notes),sorted((n.start,n.end,n.pitch,n.part) for n in song.notes))
        self.assertEqual(len(song.arrangement()),24)
    def test_project_embeds_original(self):
        with tempfile.TemporaryDirectory() as d:
            original=Path(d)/'source.png';original.write_bytes(b'original')
            s=Song(notes=[Note(0,480,60,uncertain=True)],source_files=[str(original)])
            p=Path(d)/'x.fpgamusic';MusicProject(songs=[s],patches=[Patch()]).save(p);original.unlink()
            loaded=MusicProject.load(p)
            self.assertEqual(Path(loaded.songs[0].source_files[0]).read_bytes(),b'original')
            with self.assertRaises(ValueError):loaded.validate()
    def test_wav_single_cycle(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'wave.wav'
            with wave.open(str(p),'wb') as w:
                w.setnchannels(1);w.setsampwidth(2);w.setframerate(48000)
                w.writeframes(struct.pack('<64h',*[round(10000*math.sin(i*2*math.pi/64))+100 for i in range(64)]))
            patch=import_patch(p);self.assertEqual(len(patch.binary()),512);self.assertLess(abs(sum(patch.waveform)),512)
    def test_section_and_capacity_validation(self):
        with self.assertRaises(ValueError):MusicProject(songs=[Song() for _ in range(5)]).validate()
        s=Song(notes=[Note(0,480,60)],sections=[Section(start=1)])
        with self.assertRaises(ValueError):s.validate()
    def test_names_command_safe_and_complete_gbk(self):
        b=display_name('测试"\\\n'+('琴'*30));self.assertEqual(len(b),32)
        s=b.split(b'\0')[0].decode('gb2312');self.assertNotIn('"',s);self.assertNotIn('\\',s)
    def test_accompaniment_requires_explicit_chords(self):
        s=Song(notes=[Note(0,480,60)]);generate_accompaniment(s,['C','Am'])
        self.assertEqual({n.part for n in s.notes},{0,1,2,3});s.validate()
    def test_xml_backup_chords(self):
        xml='''<score-partwise><part id="P1"><measure><attributes><divisions>1</divisions></attributes><note><pitch><step>C</step><octave>4</octave></pitch><duration>1</duration></note><note><chord/><pitch><step>E</step><octave>4</octave></pitch><duration>1</duration></note></measure></part></score-partwise>'''
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'x.musicxml';p.write_text(xml);s=import_musicxml(p)
        self.assertEqual([(n.start,n.end) for n in s.notes],[(0,480),(0,480)])
    def test_musicxml_metronome_and_noncontiguous_tie_warning(self):
        xml='''<score-partwise><part id="P1"><measure number="1"><attributes><divisions>1</divisions><time><beats>3</beats><beat-type>4</beat-type></time></attributes><direction><direction-type><metronome><beat-unit>quarter</beat-unit><per-minute>158</per-minute></metronome></direction-type></direction><note><pitch><step>C</step><octave>4</octave></pitch><duration>1</duration><tie type="start"/></note><note><rest/><duration>2</duration></note></measure><measure number="2"><note><pitch><step>C</step><octave>4</octave></pitch><duration>1</duration><tie type="stop"/></note><note><rest/><duration>3</duration></note></measure></part></score-partwise>'''
        with tempfile.TemporaryDirectory() as d:
            path=Path(d)/'x.musicxml';path.write_text(xml);song=import_musicxml(path)
        self.assertEqual(song.tempos[0][1],round(60_000_000/158))
        self.assertEqual([(n.start,n.end) for n in song.notes],[(0,480),(1440,1920)])
        self.assertTrue(any('延音不连续' in issue for issue in song.issues))
        self.assertTrue(any('超出拍号' in issue for issue in song.issues))
if __name__=='__main__':unittest.main()
