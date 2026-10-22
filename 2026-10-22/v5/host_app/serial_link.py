"""板载 USB-C COM 口的可靠串口封装。"""

from __future__ import annotations

import random
import struct
import time
from typing import Callable, Iterable

import serial
from serial.tools import list_ports

from .protocol import (
    ACK,
    FILE_BEGIN,
    FILE_DATA,
    FILE_END,
    Frame,
    FrameDecoder,
    PLAY,
    STOP,
    STATUS,
    encode_frame,
    file_begin_payload,
    file_data_payload,
    file_end_payload,
    make_ping,
    parse_ack,
    TIMBRE_BEGIN,
    TIMBRE_DATA,
    TIMBRE_COMMIT,
    timbre_begin_payload,
    timbre_data_payload,
    timbre_commit_payload,
)


def list_serial_ports() -> list[tuple[str, str]]:
    """列出电脑当前可见的串口，返回 (设备名, 描述)。"""

    return [(port.device, port.description or "") for port in list_ports.comports()]


class FpgaSerialLink:
    """115200/8N1 链路；每个命令默认等待 ACK 并支持有限重试。"""

    def __init__(self, port: str, baudrate: int = 115200, timeout: float = 0.1) -> None:
        self.port = serial.Serial(port, baudrate=baudrate, timeout=timeout)
        # 新会话先清除上一次打开端口时残留的半帧或旧 ACK，避免序号重新从 0
        # 开始后把旧响应误认为当前命令的响应。GUI 会尽量保持连接长时间打开，
        # 这里仍保留清理动作，便于命令行工具和重新插拔设备后的第一次通信。
        self.port.reset_input_buffer()
        self.port.reset_output_buffer()
        self.decoder = FrameDecoder()
        self.sequence = 0
        from .serial_executor import SerialExecutor
        self.executor = SerialExecutor(self.port)

    def close(self) -> None:
        self.executor.close()

    def __enter__(self) -> "FpgaSerialLink":
        return self

    def __exit__(self, *_: object) -> None:
        self.close()

    def _next_sequence(self) -> int:
        value = self.sequence
        self.sequence = (self.sequence + 1) & 0xFFFF
        return value

    def _read_frames(self, deadline: float) -> Iterable[Frame]:
        while time.monotonic() < deadline:
            data = self.port.read(self.port.in_waiting or 1)
            if data:
                yield from self.decoder.feed(data)

    def send_and_wait_ack(
        self,
        message_type: int,
        payload: bytes = b"",
        *,
        timeout: float = 1.0,
        retries: int = 3,
        urgent: bool = False,
        abort: bool = False,
    ) -> Frame:
        if hasattr(self,'executor'):
            return self.executor.request(message_type,payload,timeout=timeout,retries=retries,urgent=urgent,abort=abort)
        sequence = self._next_sequence()
        frame = encode_frame(message_type, sequence, payload)
        for attempt in range(retries):
            self.port.write(frame)
            deadline = time.monotonic() + timeout
            for response in self._read_frames(deadline):
                if response.sequence != sequence or response.message_type not in (ACK, 0x82):
                    continue
                original, status, _ = parse_ack(response)
                if original != message_type:
                    continue
                if response.message_type != ACK or status != 0:
                    raise RuntimeError(f"FPGA rejected message type 0x{message_type:02X}, status {status}")
                return response
            if attempt + 1 < retries:
                time.sleep(0.02 * (attempt + 1))
        raise TimeoutError(f"no ACK for message type 0x{message_type:02X}")

    def ping(self, nonce: int | None = None) -> int:
        if nonce is None:
            nonce = random.getrandbits(32)
        response = self.send_and_wait_ack(0x01, struct.pack("<I", nonce), timeout=1.0)
        _, _, echoed_nonce = parse_ack(response)
        if echoed_nonce != nonce:
            raise RuntimeError("FPGA ACK nonce mismatch")
        return echoed_nonce

    def send_midi_file(
        self,
        file_data: bytes,
        *,
        timbre_id: int = 0,
        start_play: bool = False,
        progress: Callable[[int, int], None] | None = None,
    ) -> None:
        """上传完整 MIDI 文件；默认只上传，由独立 PLAY 命令启动 FPGA 解析。

        progress(done, total) 在 FILE_BEGIN 后先报告 0，随后在每个数据块收到
        FPGA ACK 后更新，便于 GUI 显示实际已经写入片内 RAM 的字节数。
        """

        if len(file_data) == 0 or len(file_data) > 64 * 1024:
            raise ValueError("MIDI Type 0 file must be 1..65536 bytes")
        validate_midi_type0(file_data)
        self.send_and_wait_ack(FILE_BEGIN, file_begin_payload(file_data), timeout=2.0)
        if progress:
            progress(0, len(file_data))
        for offset in range(0, len(file_data), 128):
            chunk = file_data[offset : offset + 128]
            self.send_and_wait_ack(
                FILE_DATA,
                file_data_payload(offset, chunk),
                timeout=2.0,
            )
            if progress:
                progress(offset + len(chunk), len(file_data))
        self.send_and_wait_ack(FILE_END, file_end_payload(file_data), timeout=2.0)
        if start_play:
            self.play(timbre_id)

    def play(self, timbre_id: int = 0) -> None:
        """请求 FPGA 解析已接收的文件并开始播放。"""

        self.send_and_wait_ack(PLAY, bytes((timbre_id & 0xFF,)), timeout=1.0)

    def upload_ftb(
        self,
        ftb_data: bytes,
        *,
        progress: Callable[[int, int], None] | None = None,
    ) -> None:
        """上传 FTB 单周期波表；不允许把歌曲或长录音当作音色。"""

        if len(ftb_data) != 552 or ftb_data[:4] != b"FTB1":
            raise ValueError("FTB must be a 552-byte FTB1 file with 256 int16 samples")
        self.send_and_wait_ack(TIMBRE_BEGIN, timbre_begin_payload(ftb_data), timeout=2.0)
        if progress:
            progress(0, len(ftb_data))
        for offset in range(0, len(ftb_data), 128):
            chunk = ftb_data[offset : offset + 128]
            self.send_and_wait_ack(
                TIMBRE_DATA,
                timbre_data_payload(offset, chunk),
                timeout=2.0,
            )
            if progress:
                progress(offset + len(chunk), len(ftb_data))
        self.send_and_wait_ack(TIMBRE_COMMIT, timbre_commit_payload(ftb_data), timeout=2.0)

    def stop(self) -> None:
        self.send_and_wait_ack(STOP, b"", timeout=1.0)

    def status(self) -> dict[str, int | bool]:
        """读取 FPGA 当前状态；只读命令不会参与音符调度。"""

        response = self.send_and_wait_ack(STATUS, b"", timeout=1.0)
        if len(response.payload) < 7:
            raise RuntimeError("FPGA STATUS response is too short")
        flags = response.payload[2]
        return {
            "playing": bool(flags & 0x01),
            "parser_ready": bool(flags & 0x02),
            "parser_busy": bool(flags & 0x04),
            "file_ready": bool(flags & 0x08),
            "audio_ready": bool(flags & 0x10),
            "timbre_ready": bool(flags & 0x20),
            "voice_count": response.payload[3],
            "timbre": response.payload[4] & 0x03,
            "parser_error": bool(response.payload[4] & 0x04),
            "parser_error_code": response.payload[4] >> 4,
            "event_count": int.from_bytes(response.payload[5:7], "little"),
        }


def validate_midi_type0(data: bytes) -> None:
    """只做文件结构校验，不解析音符；解析工作留在 FPGA。"""

    if data[:4] != b"MThd" or len(data) < 22:
        raise ValueError("not a MIDI file")
    header_length = struct.unpack_from(">I", data, 4)[0]
    if header_length != 6:
        raise ValueError("MIDI header length must be 6")
    fmt, tracks, division = struct.unpack_from(">HHH", data, 8)
    if fmt != 0 or tracks != 1:
        raise ValueError("only standard MIDI Type 0 with one track is supported")
    if division & 0x8000:
        raise ValueError("SMPTE MIDI division is not supported")
    if data[14:18] != b"MTrk":
        raise ValueError("MIDI track chunk is missing")
    track_length = struct.unpack_from(">I", data, 18)[0]
    if 22 + track_length > len(data):
        raise ValueError("MIDI track is truncated")
