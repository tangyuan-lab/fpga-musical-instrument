"""真实开源组件回归：记谱往返、音频合成、工程迁移和Qt SVG可见内容。"""
import copy,io,json,os,tempfile,unittest,wave,zipfile
from dataclasses import asdict
from pathlib import Path
os.environ.setdefault('QT_QPA_PLATFORM','offscreen')
import numpy as np
from host_app.music_project import Song,Note,Section,MusicProject,import_musicxml
from host_app.score_document import ScoreDocument,from_song,sync_song,render_pages
from host_app.reference_audio import render_reference,reference_midi,resources

def document(body,parts=1):
    listing=''.join(f'<score-part id="P{i}"><part-name>P{i}</part-name></score-part>' for i in range(parts))
    return '<score-partwise version="4.0"><part-list>'+listing+'</part-list>'+body+'</score-partwise>'

def load(text):
    with tempfile.TemporaryDirectory() as directory:
        path=Path(directory)/'score.musicxml';path.write_text(text,encoding='utf-8');return ScoreDocument.from_file(path)

def note(pitch='C',duration=1,extra=''):
    return f'<note><pitch><step>{pitch}</step><octave>4</octave></pitch><duration>{duration}</duration><voice>1</voice>{extra}</note>'

class DocumentTests(unittest.TestCase):
    def test_pickup_and_meter_change_keep_initial_rest_and_shared_origin(self):
        text=document('<part id="P0"><measure number="0" implicit="yes"><attributes><divisions>2</divisions><time><beats>4</beats><beat-type>4</beat-type></time></attributes><note><rest/><duration>1</duration></note>'+note('C',1)+'</measure><measure number="1"><attributes><time><beats>3</beats><beat-type>4</beat-type></time></attributes>'+note('D',6)+'</measure></part>')
        d=load(text);s=d.compile();self.assertFalse(d.errors)
        self.assertEqual([(n.start,n.end) for n in s.notes],[(240,480),(480,1920)])
        self.assertEqual(len(d.structure()['time']),2);self.assertEqual(len(d.structure()['rest']),1)
        self.assertEqual([tick for tick,_ in s.bar_markers()],[0,480,1920])

    def test_triplet_and_quintuplet_exact_durations(self):
        for size in (3,5):
            with self.subTest(size=size):
                notes=''.join(note('C',1,f'<type>eighth</type><time-modification><actual-notes>{size}</actual-notes><normal-notes>2</normal-notes></time-modification>') for _ in range(size))
                d=load(document(f'<part id="P0"><measure><attributes><divisions>{size}</divisions></attributes>'+notes+'</measure></part>'));s=d.compile()
                self.assertFalse(d.errors);self.assertEqual([(n.start,n.end) for n in s.notes],[(i*480//size,(i+1)*480//size) for i in range(size)])

    def test_duplicate_note_ids_rejected_without_losing_notes(self):
        text=document('<part id="P0"><measure><attributes><divisions>1</divisions></attributes>'+note('C').replace('<note>','<note id="same">')+note('E').replace('<note>','<note id="same">')+'</measure></part>')
        with self.assertRaisesRegex(ValueError,'ID 重复'):load(text)

    def test_external_correction_retains_arrangement_in_quarter_units(self):
        from host_app.score_document import retain_arrangement
        old=Song(ppqn=480,notes=[Note(0,1920,60)],reference_programs=[40,1,32,0],sections=[Section(end=960,timbres=[1,0,0,0]),Section(start=960,end=1920,mute=2)])
        new=Song(ppqn=1440,notes=[Note(0,4000,62)],sections=[Section(end=4000)])
        retain_arrangement(old,new)
        self.assertEqual([(s.start,s.end) for s in new.sections],[(0,2880),(2880,5760)])
        self.assertEqual(new.sections[1].mute,2);self.assertEqual(new.reference_programs,old.reference_programs)
        self.assertIsNot(new.sections[0],old.sections[0])

    def test_runtime_details_and_legacy_status_are_compatible(self):
        from host_app.device_v2 import DeviceV2,RUNTIME_DETAILS,STATE
        from types import SimpleNamespace
        import struct
        p=bytearray(80);p[:5]=bytes([0x37,0,1,25,0]);struct.pack_into('<I',p,6,0x12345678)
        p[10:16]=bytes([3,3,2,5,1,32]);struct.pack_into('<III',p,16,1234,9600,17)
        p[38:46]=bytes([1,2,3,4,100,90,80,70]);p[46:48]=bytes([2,4]);struct.pack_into('<H',p,48,125)
        p[50]=(-12)&255;p[51]=6;struct.pack_into('<II4HIII',p,52,8000,400000,64,8,3000,32,42,99,3)
        device=DeviceV2.__new__(DeviceV2);calls=[]
        device.send_and_wait_ack=lambda op:(calls.append(op) or SimpleNamespace(payload=bytes(p)))
        device.features=1;state=device.state()
        self.assertEqual(calls,[RUNTIME_DETAILS]);self.assertEqual(state['voices'],32);self.assertEqual(state['tick'],1234)
        self.assertEqual(state['part_volumes'],[100,90,80,70]);self.assertEqual(state['transpose'],-12)
        self.assertEqual(state['command_serial'],0x12345678);self.assertEqual(state['adsr'],[64,8,3000,32]);self.assertEqual(state['last_aux'],3)
        device.features=0;device.send_and_wait_ack=lambda op:(calls.append(op) or SimpleNamespace(payload=bytes(2)+p[10:38]))
        self.assertEqual(device.state()['tick'],1234);self.assertEqual(calls[-1],STATE)

    def test_exact_nonuplet_and_symbol_structure(self):
        notes=''.join(note('C',20,'<type>32nd</type><time-modification><actual-notes>9</actual-notes><normal-notes>8</normal-notes></time-modification>') for _ in range(9))
        text=document('<part id="P0"><measure number="1"><attributes><divisions>180</divisions><key><fifths>-2</fifths></key><time><beats>3</beats><beat-type>4</beat-type></time><clef><sign>G</sign><line>2</line></clef></attributes>'+notes+'<note><rest/><duration>360</duration></note></measure></part>')
        d=load(text);s=d.compile();self.assertEqual(s.ppqn,1440);self.assertEqual([n.start for n in s.notes],list(range(0,1440,160)))
        self.assertEqual(len(d.structure()['time-modification']),9);self.assertEqual(len(d.structure()['rest']),1)
        self.assertEqual(d.original_xml,text);self.assertFalse(d.errors)
    def test_cross_bar_ties_and_change_clef_preserved(self):
        text=document('<part id="P0"><measure number="1"><attributes><divisions>1</divisions><time><beats>3</beats><beat-type>4</beat-type></time><clef><sign>G</sign><line>2</line></clef></attributes>'+note('C',3,'<tie type="start"/>')+'</measure><measure number="2"><attributes><clef><sign>F</sign><line>4</line></clef></attributes>'+note('C',1,'<tie type="stop"/>')+'<note><rest/><duration>2</duration></note></measure></part>')
        d=load(text);s=d.compile();self.assertEqual([(n.start,n.end,n.pitch) for n in s.notes],[(0,1920,60)])
        a=copy.deepcopy(s);a.notes[0].pitch=62;sync_song(s,a)
        self.assertEqual(len(a.score_document.structure()['clef']),2);self.assertEqual(len(a.score_document.structure()['tie']),2)
        self.assertEqual(a.score_document.original_xml,text)
        actual=a.score_document.compile();self.assertEqual([(n.end,n.pitch) for n in actual.notes],[(1920,62)])
    def test_rhythm_edit_complex_score_is_explicit(self):
        d=load(document('<part id="P0"><measure><attributes><divisions>3</divisions></attributes>'+note('C',1,'<time-modification><actual-notes>3</actual-notes><normal-notes>2</normal-notes></time-modification>')+'</measure></part>'))
        s=d.compile();a=copy.deepcopy(s);a.notes[0].end+=1
        with self.assertRaisesRegex(ValueError,'MuseScore'):sync_song(s,a)
        self.assertEqual(d.current_xml,s.score_document.current_xml)
    def test_reconstructed_musicxml_preserves_cross_bar_performance(self):
        s=Song(notes=[Note(240,2500,60),Note(480,960,64),Note(0,110,36,part=3)],sections=[Section(end=3000)])
        d=from_song(s);a=d.compile()
        self.assertEqual(sorted((n.start,n.end,n.pitch) for n in a.notes),sorted((n.start,n.end,n.pitch) for n in s.notes))
        self.assertTrue(d.reconstructed);self.assertTrue(d.structure()['tie'])
        from host_app.score_document import xml_root
        chromatic=from_song(Song(notes=[Note(0,480,61),Note(480,960,60)]))
        self.assertEqual([n.text for n in xml_root(chromatic.current_xml).iter('accidental')],['sharp','natural'])
    def test_repeat_expansion(self):
        text=document('<part id="P0"><measure><attributes><divisions>1</divisions></attributes><barline location="left"><repeat direction="forward"/></barline>'+note('C',4).replace('<note>','<note dynamics="50">')+'</measure><measure>'+note('D',4).replace('<note>','<note dynamics="100">')+'<barline location="right"><repeat direction="backward"/></barline></measure></part>')
        s=load(text).compile();self.assertEqual([(n.start//s.ppqn,n.pitch) for n in s.notes],[(0,60),(4,62),(8,60),(12,62)])
        self.assertEqual([n.velocity for n in s.notes],[45,90,45,90])
    def test_fourth_instrument_requires_explicit_mapping(self):
        text=document(''.join(f'<part id="P{i}"><measure><attributes><divisions>1</divisions></attributes>'+note('C',1)+'</measure></part>' for i in range(4)),4)
        d=load(text);s=d.compile();self.assertTrue(any('明确映射' in e for e in d.errors))
        d.mapping['P3:1:1']=3;d.compile();self.assertFalse(any('明确映射' in e for e in d.errors))
    def test_unsupported_sounding_symbol_blocks_deploy(self):
        d=load(document('<part id="P0"><measure><attributes><divisions>1</divisions><transpose><diatonic>1</diatonic><chromatic>2</chromatic></transpose></attributes>'+note()+'</measure></part>'))
        s=d.compile()
        with self.assertRaisesRegex(ValueError,'transpose'):s.validate()
    def test_format2_load_and_format3_save_preserve_original(self):
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'old.fpgamusic';data=asdict(MusicProject(songs=[Song(notes=[Note(0,480,60,uncertain=True)])]))
            data['songs'][0].pop('score_document');data['songs'][0]['notes'][0].pop('note_id')
            with zipfile.ZipFile(path,'w') as package:package.writestr('project.json',json.dumps({'format':2,'project':data}))
            original=path.read_bytes();project=MusicProject.load(path);project.save(Path(directory)/'new.fpgamusic')
            self.assertEqual(path.read_bytes(),original);self.assertTrue(project.songs[0].score_document.reconstructed)
            actual=MusicProject.load(Path(directory)/'new.fpgamusic');self.assertTrue(actual.songs[0].notes[0].uncertain)
            self.assertEqual(actual.songs[0].score_document.current_xml,project.songs[0].score_document.current_xml)

class ComponentTests(unittest.TestCase):
    def test_svg_visible_note_and_hit_bounds(self):
        from PySide6.QtWidgets import QApplication
        from PySide6.QtGui import QImage,QPainter,QFontDatabase
        from PySide6.QtSvg import QSvgRenderer
        app=QApplication.instance() or QApplication([]);QFontDatabase.addApplicationFont('C:/Windows/Fonts/msyh.ttc')
        s=Song(notes=[Note(0,480,60)]);d=from_song(s);svg=render_pages(d)[0];r=QSvgRenderer(svg.encode())
        self.assertTrue(r.elementExists(d.links[s.notes[0].note_id][0]))
        image=QImage(800,1120,QImage.Format.Format_RGB32);image.fill(0xffffffff);p=QPainter(image);r.render(p);p.end()
        data=np.frombuffer(image.bits(),dtype=np.uint8);self.assertGreater(np.count_nonzero(data<100),1000)
    def test_reference_midi_tempo_transpose_mute_and_pending(self):
        s=Song(notes=[Note(0,480,60,uncertain=True),Note(480,960,64,part=1)],tempos=[[0,500000],[480,250000]],sections=[Section(end=960,transpose=12)])
        midi=reference_midi(s,muted=(1,));on=[m.note for m in midi.tracks[0] if m.type=='note_on'];self.assertEqual(on,[72])
        self.assertTrue(s.notes[0].uncertain);self.assertEqual(len([m for m in midi.tracks[0] if m.type=='set_tempo']),2)
    def test_real_fluidsynth_polyphony_and_font_cache(self):
        try:resources()
        except ValueError:self.skipTest('电脑参考音源尚未安装')
        s=Song(notes=[Note(0,480,69,uncertain=True),Note(0,480,81)],sections=[Section(end=480,volumes=[100]*4)])
        with tempfile.TemporaryDirectory() as directory:
            result=render_reference(s,cache_dir=directory)
            with wave.open(str(result.path)) as stream:
                data=np.frombuffer(stream.readframes(12000),dtype='<i2').reshape(-1,2).mean(axis=1);rate=stream.getframerate()
            spectrum=np.abs(np.fft.rfft(data*np.hanning(len(data))));frequency=np.fft.rfftfreq(len(data),1/rate)
            for pitch in (440,880):self.assertGreater(spectrum[np.abs(frequency-pitch)<6].max(),spectrum.max()*.04)
            self.assertTrue(s.notes[0].uncertain)
            s.reference_programs[0]=40;other=render_reference(s,cache_dir=directory);self.assertNotEqual(result.path,other.path)

if __name__=='__main__':unittest.main()
