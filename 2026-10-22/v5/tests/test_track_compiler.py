import copy
import io
import random
import unittest
import uuid
from collections import Counter

import mido

from host_app.music_project import Song, Note, SourceTrack, Section
from host_app.track_compiler import compile_tracks, decode_metadata


def make_song(count=1):
    tracks = [SourceTrack(str(uuid.uuid4()), f'乐器{i}', device_part=0) for i in range(count)]
    return Song(source_tracks=tracks, sections=[Section(end=10000)])


def decoded_notes(compilation):
    held = {}; notes = []; tick = 0
    for message in mido.MidiFile(file=io.BytesIO(compilation.midi)).tracks[0]:
        tick += message.time
        if message.type == 'note_on':
            key = (message.channel, message.note)
            if key in held:raise AssertionError('MIDI通道中同音重叠')
            held[key] = tick, message.velocity
        elif message.type == 'note_off':
            start, velocity = held.pop((message.channel, message.note))
            notes.append((compilation.channel_owners[message.channel], start, tick, message.note, velocity))
    if held:raise AssertionError('编译产生未配对音符')
    return Counter(notes)


class TrackCompilerTests(unittest.TestCase):
    def test_unison_lanes_share_owner_and_preserve_velocity_and_identity(self):
        song = make_song(2)
        song.source_tracks[0].gain_db = -12
        song.source_tracks[0].reference_volume = 65
        song.source_tracks[1].device_part = 1
        song.notes = [Note(0, 960, 60, 105, track_id=song.source_tracks[0].track_id),
                      Note(480, 1200, 60, 77, track_id=song.source_tracks[0].track_id),
                      Note(480, 960, 64, 88, track_id=song.source_tracks[0].track_id),
                      Note(0, 480, 60, 95, track_id=song.source_tracks[1].track_id)]
        before = copy.deepcopy(song);result = compile_tracks(song)
        self.assertEqual(song, before)
        self.assertEqual(decoded_notes(result), Counter([(0, 0, 960, 60, 105), (0, 480, 1200, 60, 77),
                                                        (0, 480, 960, 64, 88), (1, 0, 480, 60, 95)]))
        self.assertEqual(result.channel_owners[:3], (0, 0, 1))
        self.assertEqual(result.owners[0].gain, 8231)
        owners, channels, notes, duration = decode_metadata(result.metadata())
        self.assertEqual(owners[0].legacy_velocity, 65)
        self.assertEqual(owners[0].track_id, song.source_tracks[0].track_id)
        self.assertEqual(owners[1].role, 1)
        self.assertEqual(channels, result.channel_owners)
        self.assertEqual((notes, duration), (4, song.duration))
        with self.assertRaisesRegex(ValueError, '重叠'):song.midi()  # 旧路径仍拒绝，不能误发到旧固件。

    def test_sixteen_sources_and_melodic_channel_nine_are_retained(self):
        song = make_song(16)
        song.notes = [Note(0, 480, 60+i, 60+i, track_id=t.track_id) for i,t in enumerate(song.source_tracks)]
        result = compile_tracks(song)
        self.assertEqual(len(result.owners), 16)
        self.assertEqual(result.channel_owners, tuple(range(16)))
        self.assertEqual(result.owners[9].role, 0)
        self.assertEqual(len(decoded_notes(result)), 16)
        song.notes.append(Note(240, 720, 60, track_id=song.source_tracks[0].track_id))
        original = copy.deepcopy(song)
        with self.assertRaisesRegex(ValueError, '17.*乐器0需2通道.*240'):compile_tracks(song)
        self.assertEqual(song, original)

    def test_adjacent_equal_pitch_reuses_channel_and_random_intervals_roundtrip(self):
        rng = random.Random(729);song = make_song(3)
        for index, track in enumerate(song.source_tracks):
            for n in range(30):
                start = rng.randrange(0, 100)*60
                song.notes.append(Note(start, start+rng.randrange(1, 5)*60, 60+rng.randrange(3),
                                       rng.randrange(1, 128), track_id=track.track_id))
        result = compile_tracks(song)
        owner_ids = {t.track_id: i for i,t in enumerate(song.source_tracks)}
        self.assertEqual(decoded_notes(result), Counter((owner_ids[n.track_id], n.start, n.end, n.pitch, n.velocity) for n in song.notes))
        adjacent=make_song();t=adjacent.source_tracks[0]
        adjacent.notes=[Note(0,480,60,track_id=t.track_id),Note(480,960,60,track_id=t.track_id)]
        self.assertEqual(compile_tracks(adjacent).channel_owners.count(0),1)

    def test_reserves_four_real_time_voices_and_does_not_count_builtin_drums(self):
        song=make_song();t=song.source_tracks[0]
        song.notes=[Note(0,480,40+i,track_id=t.track_id) for i in range(29)]
        with self.assertRaisesRegex(ValueError,'29.*保留4'):compile_tracks(song)
        t.device_part=3
        result=compile_tracks(song)
        self.assertEqual((result.peak_notes,result.peak_melodic_notes),(29,0))
        song.sections[0].timbres[3]=2
        with self.assertRaisesRegex(ValueError,'29.*保留4'):compile_tracks(song)

    def test_invalid_notes_controls_identity_and_metadata_are_not_silently_dropped(self):
        song=make_song();t=song.source_tracks[0];song.notes=[Note(0,480,60,track_id=t.track_id)]
        note=copy.deepcopy(song.notes[0]);note.pitch=64;song.notes.append(note)
        with self.assertRaisesRegex(ValueError,'ID重复'):compile_tracks(song)
        song.notes.pop();song.source_midi_events=[dict(tick=0,message=dict(type='control_change',control=64,value=127,channel=0))]
        with self.assertRaisesRegex(ValueError,'控制事件'):compile_tracks(song)
        song.source_midi_events=[];result=compile_tracks(song);data=bytearray(result.metadata())
        data[16]=16
        with self.assertRaisesRegex(ValueError,'归属'):decode_metadata(data)
        data=bytearray(result.metadata());data[-1]=1
        with self.assertRaisesRegex(ValueError,'参数'):decode_metadata(data)
        t.gain_db=float('nan')
        with self.assertRaisesRegex(ValueError,'音量'):compile_tracks(song)


if __name__ == '__main__':unittest.main()
