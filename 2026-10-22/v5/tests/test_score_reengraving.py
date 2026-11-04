"""重新记谱的精确时值与连音组回归；不将时间线往返等同于PDF识谱准确。"""
from collections import Counter
from fractions import Fraction
import copy
import unittest

from host_app.music_project import Note,Song
from host_app.score_document import from_song,xml_root


def events(song):
    return Counter((Fraction(n.start,song.ppqn),Fraction(n.end,song.ppqn),n.pitch,n.velocity,n.part) for n in song.notes)


class ReengravingTests(unittest.TestCase):
    def test_mixed_grid_and_cross_bar_ties_preserve_performance(self):
        # 同一拍既有十分拍起止又有三连音；另有18等分的起止及跨小节长音。
        song=Song(ppqn=1440,numerator=3,denominator=4,notes=[
            Note(0,9600,75,velocity=79,uncertain=True),Note(144,864,60,velocity=65),
            Note(960,1440,62,velocity=88),Note(1440,1520,64,velocity=96),
            Note(1520,1600,65,velocity=97),Note(0,4320,48,velocity=80,part=2)])
        previous=copy.deepcopy(song.notes);document=from_song(song);compiled=document.compile()
        self.assertEqual(events(song),events(compiled));self.assertFalse(document.errors)
        self.assertEqual(song.notes,previous);self.assertTrue(song.notes[0].uncertain)
        self.assertEqual(document.notation_schema,3);self.assertTrue(document.reconstructed)
        root=xml_root(document.current_xml)
        for part in root.findall('part'):
            for measure in part.findall('measure'):
                cursor=0;maximum=0
                for item in measure:
                    if item.tag=='backup':cursor-=int(item.findtext('duration'))
                    elif item.tag=='note':cursor+=int(item.findtext('duration'));maximum=max(maximum,cursor)
                    self.assertGreaterEqual(cursor,0)
                self.assertEqual(maximum,4320)
        starts=[t for t in root.iter('tuplet') if t.get('type')=='start']
        self.assertTrue(starts);self.assertEqual(len(starts),len([t for t in root.iter('tuplet') if t.get('type')=='stop']))
        self.assertTrue(any(t.findtext('tuplet-actual/tuplet-number')=='18' for t in starts))

    def test_half_quarter_bar_keeps_exact_timing(self):
        song=Song(ppqn=480,numerator=3,denominator=8,notes=[Note(240,1680,60,velocity=55)])
        document=from_song(song);self.assertEqual(events(song),events(document.compile()))

    def test_unsupported_notational_grid_is_reported_without_quantization(self):
        song=Song(ppqn=1000,notes=[Note(1,2,60)])
        previous=copy.deepcopy(song.notes)
        with self.assertRaisesRegex(ValueError,'1024'):from_song(song)
        self.assertEqual(song.notes,previous)

    def test_unrepresentable_measure_length_is_reported(self):
        with self.assertRaisesRegex(ValueError,'小节长度'):from_song(Song(ppqn=1,numerator=3,denominator=8,notes=[Note(0,1,60)]))


if __name__=='__main__':unittest.main()
