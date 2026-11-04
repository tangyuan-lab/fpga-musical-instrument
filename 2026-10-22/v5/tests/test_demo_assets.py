from pathlib import Path
import tempfile
import unittest

from host_app.serial_link import validate_midi_type0
from host_app.timbre_file import decode_ftb
from scripts.generate_demo_assets import generate_assets


class DemoAssetTests(unittest.TestCase):
    def test_generated_assets_are_valid_and_bounded(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            paths = generate_assets(Path(temporary_directory))
            self.assertEqual({path.name for path in paths}, {
                '01_single_note.mid','02_four_voice_chords.mid','03_tempo_change_scale.mid',
                '04_long_note_10s.mid','soft_sine.ftb','bright_harmonic.ftb'})
            for path in paths:
                data = path.read_bytes()
                if path.suffix == ".mid":
                    validate_midi_type0(data)
                    self.assertLessEqual(len(data), 64 * 1024)
                else:
                    timbre = decode_ftb(data)
                    self.assertEqual(len(data), 552)
                    self.assertEqual(len(timbre.waveform), 256)


if __name__ == "__main__":
    unittest.main()
