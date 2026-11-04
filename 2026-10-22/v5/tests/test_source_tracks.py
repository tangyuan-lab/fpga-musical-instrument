"""保真导入、参考试听与设备编译互相独立，测试不连接硬件。"""
import copy,io,json,tempfile,unittest,zipfile
from pathlib import Path
import mido
from host_app.music_project import MusicProject,import_midi,import_musicxml
from host_app.source_tracks import device_song
from host_app.reference_audio import reference_midi
from host_app.score_document import from_song,xml_root,retain_arrangement,performance_hash


def midi_fixture(path,pedal=True):
    midi=mido.MidiFile(type=1,ticks_per_beat=480)
    conductor=mido.MidiTrack([mido.MetaMessage('track_name',name='Conductor'),mido.MetaMessage('time_signature',numerator=4,denominator=4),
        mido.MetaMessage('set_tempo',tempo=500000),mido.MetaMessage('time_signature',numerator=3,denominator=4,time=1920)])
    piano=mido.MidiTrack([mido.MetaMessage('track_name',name='Piano RH'),mido.Message('program_change',channel=3,program=0),mido.Message('note_on',channel=3,note=60,velocity=90)])
    if pedal:piano.append(mido.Message('control_change',channel=3,control=64,value=127,time=240))
    piano.append(mido.Message('note_off',channel=3,note=60,time=240 if pedal else 480))
    if pedal:piano.append(mido.Message('control_change',channel=3,control=64,value=0,time=480))
    strings=mido.MidiTrack([mido.MetaMessage('track_name',name='Strings'),mido.Message('program_change',channel=4,program=48),
        mido.Message('note_on',channel=4,note=64,velocity=80),mido.Message('note_off',channel=4,note=64,time=2400)])
    midi.tracks.extend([conductor,piano,strings]);midi.save(path)


class SourceTrackTests(unittest.TestCase):
    def load_midi(self,pedal=True):
        directory=tempfile.TemporaryDirectory();self.addCleanup(directory.cleanup)
        path=Path(directory.name)/'source.mid';midi_fixture(path,pedal);return import_midi(path,preserve_tracks=True)

    def test_source_identity_program_meter_and_pedal_are_preserved(self):
        song=self.load_midi()
        self.assertEqual([t.name for t in song.source_tracks],['Piano RH','Strings'])
        self.assertEqual([(t.channel,t.program) for t in song.source_tracks],[(3,0),(4,48)])
        self.assertEqual(len({n.track_id for n in song.notes}),2)
        self.assertEqual(song.meter_changes,[[0,4,4],[1920,3,4]])
        self.assertEqual([tick for tick,_ in song.bar_markers()],[0,1920,3360])
        controls=[e for e in song.source_midi_events if e['message']['type']=='control_change']
        self.assertEqual([e['message']['value'] for e in controls],[127,0])

    def test_reference_uses_distinct_instruments_and_preserves_controls(self):
        song=self.load_midi();result=reference_midi(song)
        channels={message.note:message.channel for message in result.tracks[0] if message.type=='note_on'}
        programs={message.channel:message.program for message in result.tracks[0] if message.type=='program_change'}
        self.assertNotEqual(channels[60],channels[64]);self.assertEqual(programs[channels[60]],0);self.assertEqual(programs[channels[64]],48)
        pedals=[message for message in result.tracks[0] if message.type=='control_change']
        self.assertEqual([(m.channel,m.value) for m in pedals],[(channels[60],127),(channels[60],0)])
        song.source_tracks[1].preview_solo=True
        self.assertEqual([m.note for m in reference_midi(song).tracks[0] if m.type=='note_on'],[64])

    def test_device_mapping_does_not_mutate_sources_and_rejects_unresolved_controls(self):
        song=self.load_midi()
        with self.assertRaisesRegex(ValueError,'映射'):song.midi()
        for part,track in enumerate(song.source_tracks):track.device_part=part
        with self.assertRaisesRegex(ValueError,'控制事件'):song.midi()
        clean=self.load_midi(False)
        for part,track in enumerate(clean.source_tracks):track.device_part=part
        snapshot=copy.deepcopy(clean);compiled=device_song(clean);compiled.validate()
        self.assertEqual([n.part for n in compiled.notes],[0,1]);self.assertEqual(clean,snapshot)
        output=mido.MidiFile(file=io.BytesIO(clean.midi()))
        self.assertEqual([m.channel for m in output.tracks[0] if m.type=='note_on'],[0,1])

    def test_format4_roundtrip_retains_raw_source_and_metadata(self):
        song=self.load_midi();raw=Path(song.source_files[0]).read_bytes()
        song.source_tracks[1].reference_volume=65
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'project.fpgamusic';MusicProject(songs=[song]).save(path)
            with zipfile.ZipFile(path) as package:self.assertEqual(json.loads(package.read('project.json'))['format'],5)
            restored=MusicProject.load(path).songs[0]
            self.assertEqual(restored.source_tracks,song.source_tracks);self.assertEqual(restored.source_midi_events,song.source_midi_events)
            self.assertEqual(restored.meter_changes,song.meter_changes);self.assertEqual(Path(restored.source_files[0]).read_bytes(),raw)
            root=xml_root(restored.score_document.current_xml)
            self.assertEqual([p.findtext('part-name') for p in root.findall('part-list/score-part')],['Piano RH','Strings'])
            self.assertEqual([(t.findtext('beats'),t.findtext('beat-type')) for t in root.find('part').iter('time')],[('4','4'),('3','4')])

    def test_same_tick_program_change_order_is_preserved(self):
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'order.mid';midi=mido.MidiFile()
            midi.tracks.append(mido.MidiTrack([mido.Message('note_on',note=60,velocity=80),mido.Message('program_change',program=48),mido.Message('note_off',note=60,time=480)]));midi.save(path)
            song=import_midi(path,preserve_tracks=True)
            messages=[m.type for m in reference_midi(song).tracks[0] if not m.is_meta]
            self.assertEqual(messages[:3],['program_change','note_on','program_change'])

    def test_xml_preserves_more_than_four_source_tracks_before_mapping(self):
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'ensemble.musicxml'
            listing=''.join(f'<score-part id="P{i}"><part-name>Instrument {i}</part-name></score-part>' for i in range(5))
            parts=''.join(f'<part id="P{i}"><measure number="1"><attributes><divisions>1</divisions><key><fifths>-2</fifths></key></attributes><note id="n{i}"><pitch><step>C</step><octave>4</octave></pitch><duration>1</duration></note></measure></part>' for i in range(5))
            path.write_text(f'<score-partwise><part-list>{listing}</part-list>{parts}</score-partwise>',encoding='utf-8')
            song=import_musicxml(path,preserve_tracks=True)
            self.assertEqual(len(song.source_tracks),5);self.assertEqual(len(song.notes),5)
            self.assertFalse(song.score_document.errors)
            original=song.score_document.current_xml
            song.source_tracks[0].device_part=0
            self.assertEqual(song.score_document.current_xml,original)
            self.assertEqual(song.score_document.performance_hash,performance_hash(song))
            after=import_musicxml(path,preserve_tracks=True);retain_arrangement(song,after)
            self.assertEqual([t.track_id for t in after.source_tracks],[t.track_id for t in song.source_tracks])
            self.assertEqual(after.source_tracks[0].device_part,0)

if __name__=='__main__':unittest.main()
