import unittest
import numpy as np
from host_app.stream_synth import BlockMixer,ModelSynth
from host_app.music_project import Song


class StreamMixTests(unittest.TestCase):
    def test_gain_changes_audio_without_normalization(self):
        mixer=BlockMixer(['track'],48000);planes=np.ones((1,2,256),np.float32)*.25
        mixer.set({'track':{'db':0}});mixer.process(planes)
        original=mixer.process(planes)
        mixer.set({'track':{'db':-12}});mixer.process(planes);changed=mixer.process(planes)
        np.testing.assert_allclose(changed/original,10**(-12/20),rtol=1e-6)
        self.assertEqual(mixer.clipped,0)

    def test_mute_wins_solo_and_preserves_other_track(self):
        mixer=BlockMixer(['a','b'],48000);planes=np.ones((2,2,256),np.float32)*.25
        mixer.set({'a':{'solo':True,'mute':True},'b':{'solo':True}});mixer.process(planes)
        np.testing.assert_allclose(mixer.process(planes),.25)

    def test_sostenuto_captures_only_held_notes(self):
        synth=ModelSynth(4,48000,Song(),[])
        synth.on(synth,0,60,100);synth.cc(synth,0,66,127);synth.on(synth,0,64,100)
        synth.off(synth,0,60);synth.off(synth,0,64)
        self.assertIsNone(synth.voices[0,60]['off']);self.assertIsNotNone(synth.voices[0,64]['off'])
        synth.cc(synth,0,66,0);self.assertIsNotNone(synth.voices[0,60]['off'])

    def test_two_pedals_release_independently(self):
        synth=ModelSynth(4,48000,Song(),[]);synth.on(synth,0,60,100)
        synth.cc(synth,0,64,127);synth.cc(synth,0,66,127);synth.off(synth,0,60)
        synth.cc(synth,0,64,0);self.assertIsNone(synth.voices[0,60]['off'])
        synth.cc(synth,0,121,0);self.assertIsNotNone(synth.voices[0,60]['off'])

if __name__=='__main__':unittest.main()
