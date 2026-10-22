import unittest
from host_app.music_project import Song,Note
from host_app.score_document import from_song,xml_root
from host_app.score_review import snapshot,mark_measure
from host_app.measure_editor import measure_data,apply_measure,recompile_song,set_measure_clef


class MeasureReviewTests(unittest.TestCase):
    def setUp(self):
        self.song=Song(notes=[Note(0,2400,60,uncertain=True)])
        self.song.score_document=from_song(self.song)
        self.bars=[m for m in snapshot(self.song.score_document)[1] if m['part']=='P0']
        if not self.bars:self.bars=snapshot(self.song.score_document)[1][:2]
    def test_tie_chain_needs_all_source_bars(self):
        first=mark_measure(self.song,self.bars[0]['id'])
        self.assertTrue(first.notes[0].uncertain);self.assertFalse(self.song.score_document.reviewed_measures)
        second=mark_measure(first,self.bars[1]['id'])
        self.assertFalse(second.notes[0].uncertain)
        revoked=mark_measure(second,self.bars[0]['id'],False);self.assertTrue(revoked.notes[0].uncertain)
    def test_bad_bar_cannot_be_approved(self):
        bar=self.bars[0];rows=measure_data(self.song.score_document,bar['part'],bar['index'])['rows']
        rows[0]['duration']='5';apply_measure(self.song.score_document,bar['part'],bar['index'],rows)
        with self.assertRaisesRegex(ValueError,'结构错误'):mark_measure(self.song,bar['id'])
    def test_xml_edit_invalidates_prior_review_hash(self):
        song=mark_measure(self.song,self.bars[0]['id']);bar=self.bars[0]
        rows=measure_data(song.score_document,bar['part'],bar['index'])['rows'];rows[0]['pitch']=61
        apply_measure(song.score_document,bar['part'],bar['index'],rows)
        self.assertNotIn(bar['id'],snapshot(song.score_document)[3])
    def test_unit_rescaling_keeps_unmodified_bar_review(self):
        song=Song(notes=[Note(0,480,60),Note(1920,2400,64)]);song.score_document=from_song(song)
        measures=snapshot(song.score_document)[1];first,second=measures[:2];song=mark_measure(song,second['id'])
        rows=measure_data(song.score_document,first['part'],0)['rows'];rows[0]['start']='1/6';rows[0]['duration']='4/9';rows[0].update(type='eighth',actual=9,normal=8)
        apply_measure(song.score_document,first['part'],0,rows)
        self.assertIn(second['id'],snapshot(song.score_document)[3])
    def test_context_change_invalidates_note_confirmation_even_if_pitch_is_unchanged(self):
        import copy
        song=Song(notes=[Note(0,480,60),Note(1920,2400,64)]);song.score_document=from_song(song)
        song.score_document.compile(device_constraints=False)
        before=copy.deepcopy(song);document=copy.deepcopy(song.score_document)
        bar=snapshot(document)[1][0]
        set_measure_clef(document,bar['part'],0,1,'F',4)
        after=recompile_song(song,document)
        self.assertEqual([n.pitch for n in after.notes],[n.pitch for n in song.notes])
        self.assertTrue(all(n.uncertain for n in after.notes));self.assertEqual(song,before)

if __name__=='__main__':unittest.main()
