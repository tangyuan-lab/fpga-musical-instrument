"""高云电子乐器二进制串口协议。

上位机只发送完整 MIDI 文件和合成参数；播放期间不发送 PCM 或逐音符串流。
"""

from __future__ import annotations

from dataclasses import dataclass
import struct

SYNC = b"\x55\xaa"
VERSION = 1
MAX_PAYLOAD = 132

PING = 0x01
ACK = 0x81
NACK = 0x82
FILE_BEGIN = 0x10
FILE_DATA = 0x11
FILE_END = 0x12
PLAY = 0x13
STOP = 0x14
TIMBRE_BEGIN = 0x20
TIMBRE_DATA = 0x21
TIMBRE_COMMIT = 0x22
STATUS = 0x90
MAX_FILE_BYTES = 64 * 1024


def crc16_ccitt(data: bytes, initial: int = 0xFFFF) -> int:
    """计算 CRC-CCITT，生成多项式 0x1021，结果范围 0..65535。"""

    crc = initial & 0xFFFF
    for value in data:
        crc ^= value << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) & 0xFFFF if crc & 0x8000 else (crc << 1) & 0xFFFF
    return crc


@dataclass(frozen=True)
class Frame:
    """一帧已经去掉同步字和 CRC 的协议数据。"""

    version: int
    message_type: int
    sequence: int
    payload: bytes


def encode_frame(message_type: int, sequence: int, payload: bytes = b"") -> bytes:
    """编码一帧，长度和序号采用小端序。"""

    if not 0 <= message_type <= 0xFF:
        raise ValueError("message_type must fit in one byte")
    if not 0 <= sequence <= 0xFFFF:
        raise ValueError("sequence must fit in uint16")
    if len(payload) > 0xFFFF:
        raise ValueError("payload is too large")
    body = struct.pack("<BBHH", VERSION, message_type, sequence, len(payload)) + payload
    return SYNC + body + struct.pack("<H", crc16_ccitt(body))


class FrameDecoder:
    """可处理任意串口分块的帧解码器，坏帧会丢弃并重新寻找同步字。"""

    def __init__(self, max_payload: int = 0xFFFF) -> None:
        self.max_payload = max_payload
        self._buffer = bytearray()

    def feed(self, data: bytes) -> list[Frame]:
        self._buffer.extend(data)
        frames: list[Frame] = []
        while True:
            sync_index = self._buffer.find(SYNC)
            if sync_index < 0:
                self._buffer[:] = self._buffer[-1:]
                break
            if sync_index:
                del self._buffer[:sync_index]
            if len(self._buffer) < 10:
                break
            version, message_type, sequence, length = struct.unpack_from("<BBHH", self._buffer, 2)
            if length > self.max_payload:
                del self._buffer[:2]
                continue
            total = 2 + 6 + length + 2
            if len(self._buffer) < total:
                break
            body = bytes(self._buffer[2 : 8 + length])
            received_crc = struct.unpack_from("<H", self._buffer, 8 + length)[0]
            del self._buffer[:total]
            if crc16_ccitt(body) != received_crc:
                continue
            frames.append(Frame(version, message_type, sequence, body[6:]))
        return frames


def make_ping(sequence: int, nonce: int) -> bytes:
    return encode_frame(PING, sequence, struct.pack("<I", nonce & 0xFFFFFFFF))


def parse_ack(frame: Frame) -> tuple[int, int, int]:
    """返回 (原消息类型, 状态码, nonce)，不符合 ACK 格式时抛出 ValueError。"""

    if frame.message_type not in (ACK, NACK) or len(frame.payload) < 2:
        raise ValueError("invalid ACK/NACK frame")
    original_type, status = frame.payload[:2]
    nonce = struct.unpack_from("<I", frame.payload, 2)[0] if len(frame.payload) >= 6 else 0
    return original_type, status, nonce


def file_begin_payload(file_data: bytes) -> bytes:
    """构造 MIDI Type 0 文件声明：MID0、字节数、文件 CRC32。"""

    import zlib

    return struct.pack("<4sII", b"MID0", len(file_data), zlib.crc32(file_data) & 0xFFFFFFFF)


def file_data_payload(offset: int, chunk: bytes) -> bytes:
    if len(chunk) > 128:
        raise ValueError("FILE_DATA chunk must be <= 128 bytes")
    return struct.pack("<I", offset) + chunk


def file_end_payload(file_data: bytes) -> bytes:
    import zlib

    return struct.pack("<I", zlib.crc32(file_data) & 0xFFFFFFFF)


def timbre_begin_payload(ftb_data: bytes) -> bytes:
    """构造单周期 FTB 音色声明；FPGA 只接收波表和参数，不接收长 PCM。"""

    import zlib

    return struct.pack("<4sII", b"FTB1", len(ftb_data), zlib.crc32(ftb_data) & 0xFFFFFFFF)


def timbre_data_payload(offset: int, chunk: bytes) -> bytes:
    if len(chunk) > 128:
        raise ValueError("TIMBRE_DATA chunk must be <= 128 bytes")
    return struct.pack("<I", offset) + chunk


def timbre_commit_payload(ftb_data: bytes) -> bytes:
    import zlib

    return struct.pack("<I", zlib.crc32(ftb_data) & 0xFFFFFFFF)
