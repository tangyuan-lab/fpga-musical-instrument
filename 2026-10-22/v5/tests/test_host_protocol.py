import struct
import unittest
from unittest.mock import Mock

from host_app.protocol import FrameDecoder, crc16_ccitt, encode_frame, make_ping
from host_app.serial_link import FpgaSerialLink, validate_midi_type0


class HostProtocolTests(unittest.TestCase):
    def test_crc_known_vector(self) -> None:
        self.assertEqual(crc16_ccitt(b"123456789"), 0x29B1)

    def test_decoder_handles_fragments(self) -> None:
        raw = encode_frame(0x01, 7, struct.pack("<I", 0x12345678))
        decoder = FrameDecoder()
        frames = []
        for value in raw:
            frames.extend(decoder.feed(bytes((value,))))
        self.assertEqual(len(frames), 1)
        self.assertEqual(frames[0].sequence, 7)
        self.assertEqual(frames[0].payload, struct.pack("<I", 0x12345678))

    def test_bad_crc_is_ignored(self) -> None:
        raw = bytearray(make_ping(1, 2))
        raw[-1] ^= 0x80
        self.assertEqual(FrameDecoder().feed(bytes(raw)), [])

    def test_midi_type0_header(self) -> None:
        track = b"\x00\xff\x2f\x00"
        data = b"MThd" + struct.pack(">IHHH", 6, 0, 1, 480)
        data += b"MTrk" + struct.pack(">I", len(track)) + track
        validate_midi_type0(data)

    def test_midi_upload_defaults_to_upload_only_and_reports_progress(self) -> None:
        track = b"\x00\xff\x2f\x00"
        data = b"MThd" + struct.pack(">IHHH", 6, 0, 1, 480)
        data += b"MTrk" + struct.pack(">I", len(track)) + track
        link = FpgaSerialLink.__new__(FpgaSerialLink)
        link.send_and_wait_ack = Mock(return_value=None)
        link.play = Mock()
        progress = []

        link.send_midi_file(data, progress=lambda done, total: progress.append((done, total)))

        link.play.assert_not_called()
        self.assertEqual(progress[0], (0, len(data)))
        self.assertEqual(progress[-1], (len(data), len(data)))

        link.send_midi_file(data, timbre_id=1, start_play=True)
        link.play.assert_called_once_with(1)


if __name__ == "__main__":
    unittest.main()
