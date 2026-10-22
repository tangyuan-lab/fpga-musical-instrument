"""本机校谱音频：速度、复音、配器、缓存及取消；不连接 FPGA。"""
import copy
import tempfile
import threading
import unittest
import wave
from pathlib import Path

import numpy as np
from host_app.music_project import Song, Note, Section, Patch
from host_app.preview_audio import TempoMap, render_preview


def read_pcm(path):
    with wave.open(str(path),'rb') as stream:
        return stream.getframerate(), np.frombuffer(stream.readframes(stream.getnframes()),dtype='<i2').astype(float)/32768


class PreviewAudioTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);self.folder=Path(self.temp.name)
        self.patch=Patch(attack=4095,decay=4095,sustain=4095,release=4095)
        self.song=Song(notes=[Note(0,960,69,uncertain=True),Note(0,960,81,part=1,uncertain=True)],
                       sections=[Section(end=1920,timbres=[2,2,0,0],volumes=[100]*4)])

    def render(self,song=None,**kwargs):return render_preview(song or self.song,[self.patch],self.folder,sample_rate=22050,**kwargs)

    def test_tempo_changes_and_inverse(self):
        clock=TempoMap(Song(tempos=[[0,500000],[480,1000000],[960,250000]]))
        for tick,seconds in [(0,0),(480,.5),(720,1),(960,1.5),(1920,2)]:
            self.assertAlmostEqual(clock.to_seconds(tick),seconds);self.assertAlmostEqual(clock.to_tick(seconds),tick)

    def test_uncertain_polyphony_audible_without_confirmation(self):
        before=copy.deepcopy(self.song);result=self.render();rate,audio=read_pcm(result.path)
        segment=audio[round(.1*rate):round(.9*rate)];spec=np.abs(np.fft.rfft(segment*np.hanning(len(segment))))
        frequencies=np.fft.rfftfreq(len(segment),1/rate)
        for frequency in (440,880):
            index=np.argmin(np.abs(frequencies-frequency));self.assertGreater(spec[index],50)
        self.assertEqual(self.song,before);self.assertTrue(all(n.uncertain for n in self.song.notes))
        with self.assertRaisesRegex(ValueError,'未确认'):self.song.validate()

    def test_local_mute_solo_and_section_mute(self):
        result=self.render(muted={0,1,2,3});_,audio=read_pcm(result.path);self.assertEqual(np.max(np.abs(audio)),0)
        result=self.render(solo={0});rate,audio=read_pcm(result.path)
        segment=audio[rate//10:rate*9//10];spec=np.abs(np.fft.rfft(segment*np.hanning(len(segment))))
        frequencies=np.fft.rfftfreq(len(segment),1/rate)
        self.assertGreater(spec[np.argmin(abs(frequencies-440))],50)
        self.assertLess(spec[np.argmin(abs(frequencies-880))],.1)
        self.song.sections[0].mute=15;_,audio=read_pcm(self.render().path);self.assertEqual(np.max(np.abs(audio)),0)

    def test_section_transpose_changes_pitch_and_cache(self):
        original=self.render();self.song.sections[0].transpose=12;changed=self.render()
        self.assertNotEqual(original.path,changed.path)
        rate,audio=read_pcm(changed.path);signal=audio[rate//10:rate*9//10]
        spec=abs(np.fft.rfft(signal*np.hanning(len(signal))));freq=np.fft.rfftfreq(len(signal),1/rate)
        self.assertGreater(spec[np.argmin(abs(freq-1760))],50)
        self.assertLess(spec[np.argmin(abs(freq-440))],.1)
        self.assertEqual(self.render().path,changed.path)
        self.song.name='仅改名';self.song.revision+=1
        for n in self.song.notes:n.uncertain=False
        self.assertEqual(self.render().path,changed.path)

    def test_cancellation_and_invalid_input_do_not_publish(self):
        cancel=threading.Event();cancel.set()
        with self.assertRaises(InterruptedError):self.render(cancel=cancel)
        self.assertFalse(list(self.folder.glob('*.wav')))
        self.song.notes[0].end=0
        with self.assertRaisesRegex(ValueError,'无效音符'):self.render()

    def test_missing_custom_patch_is_explicit(self):
        self.song.sections[0].timbres[0]=9
        with self.assertRaisesRegex(ValueError,'缺失'):self.render()


if __name__=='__main__':unittest.main()
