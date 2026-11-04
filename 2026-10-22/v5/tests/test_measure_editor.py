import copy
from fractions import Fraction as F
import unittest
import xml.etree.ElementTree as ET
from host_app.music_project import Song,Note
from host_app.score_document import from_song,xml_root,ScoreDocument
from host_app.measure_editor import (measure_data,apply_measure,set_measure_tempo,set_measure_meter,
                                    set_measure_clef,set_measure_key)
from host_app.score_audit import audit


class MeasureEditorTests(unittest.TestCase):
    def test_fraction_edit_keeps_other_bar_and_ids(self):
        doc=from_song(Song(notes=[Note(0,480,60),Note(1920,2400,64)]))
        root=xml_root(doc.current_xml);part=root.find('part');pid=part.get('id')
        data=measure_data(doc,pid,0)
        rows=copy.deepcopy(data['rows']);row=next(r for r in rows if r['pitch'] is not None)
        identifier=row['id'];row.update(start='1/6',duration='4/9',type='eighth',actual=9,normal=8)
        apply_measure(doc,pid,0,rows)
        after=measure_data(doc,pid,0);edited=next(r for r in after['rows'] if r['id']==identifier)
        self.assertEqual(F(edited['start']),F(1,6));self.assertEqual(F(edited['duration']),F(4,9))
        # Other bars keep their musical data even if divisions changes globally.
        other=measure_data(doc,pid,1)
        self.assertEqual([(r['pitch'],r['start'],r['duration']) for r in other['rows'] if r['pitch'] is not None],[(64,'0','1')])
        self.assertEqual(xml_root(doc.current_xml).find('.//note').get('id'),identifier)

    def test_audit_detects_wrong_tuplet_duration(self):
        doc=from_song(Song(notes=[Note(0,480,60)]));root=xml_root(doc.current_xml)
        note=next(n for n in root.iter('note') if n.find('pitch') is not None)
        tm=ET.SubElement(note,'time-modification');ET.SubElement(tm,'actual-notes').text='9';ET.SubElement(tm,'normal-notes').text='8'
        issues,_,_=audit(root)
        self.assertTrue(any('时值' in i['message'] for i in issues))

    def test_invalid_duration_does_not_change_document(self):
        doc=from_song(Song(notes=[Note(0,480,60)]));pid=xml_root(doc.current_xml).find('part').get('id');rows=measure_data(doc,pid,0)['rows'];rows[0]['duration']='-1';before=doc.current_xml
        with self.assertRaises(ValueError):apply_measure(doc,pid,0,rows)
        self.assertEqual(doc.current_xml,before)
    def test_local_tempo_updates_same_xml_and_replaces_old_mark(self):
        doc=from_song(Song(notes=[Note(0,480,60)]));pid=xml_root(doc.current_xml).find('part').get('id')
        set_measure_tempo(doc,pid,0,'158');song=doc.compile()
        self.assertEqual(song.tempos[0],[0,round(60_000_000/158)])
        self.assertFalse(any(i['code']=='missing_tempo' for i in doc.review_items))
        self.assertEqual(len(xml_root(doc.current_xml).findall('.//sound[@tempo]')),1)
    def test_missing_meter_and_tempo_can_be_corrected_before_device_compile(self):
        text='<score-partwise><part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list><part id="P1"><measure number="1"><attributes><divisions>1</divisions></attributes><note id="n1"><pitch><step>C</step><octave>4</octave></pitch><duration>3</duration><voice>1</voice><type>half</type><dot/></note></measure></part></score-partwise>'
        doc=ScoreDocument(original_xml=text,initial_xml=text,current_xml=text)
        with self.assertRaisesRegex(ValueError,'速度'):doc.compile().validate()
        set_measure_meter(doc,'P1',0,3,4);set_measure_tempo(doc,'P1',0,158);song=doc.compile();song.validate()
        self.assertEqual((song.numerator,song.denominator),(3,4));self.assertEqual(song.notes[0].end,3*song.ppqn)

    def test_midmeasure_clef_preserves_absolute_pitches_other_staff_and_following_review(self):
        text='''<score-partwise><part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>
        <part id="P1"><measure number="1"><attributes><divisions>2</divisions><key><fifths>-2</fifths><mode>minor</mode></key>
        <time><beats>4</beats><beat-type>4</beat-type></time><staves>2</staves>
        <clef number="1"><sign>G</sign><line>2</line></clef><clef number="2"><sign>F</sign><line>4</line></clef></attributes>
        <note id="rh"><pitch><step>C</step><octave>4</octave></pitch><duration>8</duration><voice>1</voice><type>whole</type><staff>1</staff></note>
        <backup><duration>8</duration></backup>
        <note id="lh"><pitch><step>C</step><octave>3</octave></pitch><duration>8</duration><voice>2</voice><type>whole</type><staff>2</staff></note>
        </measure><measure number="2"><note id="next"><pitch><step>G</step><octave>4</octave></pitch><duration>8</duration><voice>1</voice><type>whole</type></note></measure></part></score-partwise>'''
        doc=ScoreDocument(original_xml=text,initial_xml=text,current_xml=text)
        before=doc.compile(device_constraints=False)
        _,bars,_=audit(xml_root(doc.current_xml));old_hash=bars[1]['content_hash']
        set_measure_clef(doc,'P1',0,2,'G',2,position='1/2')
        after=doc.compile(device_constraints=False)
        def pitches(song):return [(n.note_id,n.pitch,F(n.start,song.ppqn),F(n.end,song.ppqn)) for n in song.notes]
        self.assertEqual(pitches(before),pitches(after))
        marks=[(at,c.get('number'),c.findtext('sign')) for at,_,attrs in measure_data(doc,'P1',0)['other'] for c in attrs.findall('clef')]
        self.assertIn((F(0),'1','G'),marks);self.assertIn((F(0),'2','F'),marks);self.assertIn((F(1,2),'2','G'),marks)
        _,bars,_=audit(xml_root(doc.current_xml));self.assertNotEqual(bars[1]['content_hash'],old_hash)
        set_measure_clef(doc,'P1',0,2,'F',4,position='1/2')
        marks=[c for at,_,attrs in measure_data(doc,'P1',0)['other'] if at==F(1,2) for c in attrs.findall('clef') if c.get('number')=='2']
        self.assertEqual(len(marks),1);self.assertEqual(marks[0].findtext('sign'),'F')
        set_measure_key(doc,'P1',0,3)
        key=xml_root(doc.current_xml).find('part/measure/attributes/key')
        self.assertIsNotNone(key);self.assertEqual((key.findtext('fifths'),key.findtext('mode')),('3','minor'))
        self.assertEqual(pitches(doc.compile(device_constraints=False)),pitches(before))

    def test_invalid_context_change_is_atomic(self):
        doc=from_song(Song(notes=[Note(0,480,60)]));pid=xml_root(doc.current_xml).find('part').get('id');before=copy.deepcopy(doc)
        for change in (lambda:set_measure_clef(doc,pid,0,1,'G',2,position='-1/9'),
                       lambda:set_measure_key(doc,pid,0,8),lambda:set_measure_key(doc,pid,0,2,position=5)):
            with self.assertRaises(ValueError):change()
            self.assertEqual(doc,before)

if __name__=='__main__':unittest.main()
