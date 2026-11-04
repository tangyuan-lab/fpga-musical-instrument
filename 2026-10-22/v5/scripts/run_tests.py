"""运行压力控制、音源和 PT8211 的 RTL 自检，不连接或烧写开发板。"""
from pathlib import Path
import os
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build" / "tests"
TOOLS = Path(r"C:\msys64\ucrt64\bin")

TESTS = {
    "tb_poly_synth_pipeline": ["rtl/audio/poly_synth_voice.sv"],
    "tb_key_router_events": ["rtl/control/instrument_key_router.sv"],
    "tb_workstation_services": ["rtl/control/instrument_mode_control.sv", "rtl/control/instrument_key_router.sv", "rtl/control/drum_sequencer.sv", "rtl/audio/pcm_source_mixer.sv"],
    "tb_workstation_latency": [
        "rtl/io/uart_rx.sv", "rtl/io/screen_touch_keys_rx.sv", "rtl/io/mcp3208_dual_scan.sv",
        "rtl/control/pressure_key_matrix.sv", "rtl/control/live_touch_key_merge.sv", "rtl/control/instrument_mode_control.sv",
        "rtl/control/instrument_key_router.sv", "rtl/audio/voice_allocator_4.sv", "rtl/audio/poly_synth_voice.sv",
        "rtl/audio/poly_synth_4voice.sv", "rtl/audio/drum_synth.sv", "rtl/audio/pcm_source_mixer.sv",
        "rtl/audio/pt8211_tx.sv", "rtl/audio/i2s_tx.sv", "tests/mcp3208_dynamic_model.sv",
    ],
    "tb_workstation_screen_tx": ["rtl/io/uart_tx.sv", "rtl/io/uart_rx.sv", "rtl/io/workstation_screen_tx.sv"],
    "tb_drum_synth": ["rtl/audio/drum_synth.sv"],
    "tb_key_sound_mapping": ["rtl/audio/voice_allocator_4.sv", "rtl/audio/poly_synth_voice.sv", "rtl/audio/poly_synth_4voice.sv"],
    "tb_screen_performance_controls": [
        "rtl/io/uart_rx.sv", "rtl/io/screen_touch_keys_rx.sv",
        "rtl/control/live_touch_key_merge.sv", "rtl/audio/voice_allocator_4.sv",
        "rtl/audio/poly_synth_voice.sv", "rtl/audio/poly_synth_4voice.sv",
    ],
    "tb_instrument_latency": [
        "rtl/io/uart_rx.sv", "rtl/io/screen_touch_keys_rx.sv", "rtl/io/mcp3208_dual_scan.sv",
        "rtl/control/pressure_key_matrix.sv", "rtl/control/live_touch_key_merge.sv",
        "rtl/audio/voice_allocator_4.sv", "rtl/audio/poly_synth_voice.sv", "rtl/audio/poly_synth_4voice.sv",
        "rtl/audio/pt8211_tx.sv", "rtl/audio/i2s_tx.sv", "tests/mcp3208_dynamic_model.sv",
    ],
    "tb_i2s_tx": ["rtl/audio/i2s_tx.sv"],
    "tb_poly_synth_adsr": ["rtl/audio/poly_synth_voice.sv"],
    "tb_screen_touch16_audio_path": [
        "rtl/io/uart_rx.sv", "rtl/io/screen_touch_keys_rx.sv",
        "rtl/control/live_touch_key_merge.sv", "rtl/audio/voice_allocator_4.sv",
        "rtl/audio/poly_synth_voice.sv", "rtl/audio/poly_synth_4voice.sv",
    ],
    "tb_16key_pressure_audio_path": [
        "rtl/control/pressure_key_matrix.sv", "rtl/audio/voice_allocator_4.sv",
        "rtl/audio/poly_synth_voice.sv", "rtl/audio/poly_synth_4voice.sv",
    ],
    "tb_16key_pressure_rising_audio_path": [
        "rtl/control/pressure_key_matrix.sv", "rtl/audio/voice_allocator_4.sv",
        "rtl/audio/poly_synth_voice.sv", "rtl/audio/poly_synth_4voice.sv",
        "tests/tb_16key_pressure_audio_path.sv",
    ],
    "tb_serial_screen_nextion16_tx": [
        "rtl/io/uart_tx.sv", "rtl/io/uart_rx.sv", "rtl/io/serial_screen_nextion_tx.sv",
    ],
    "tb_screen_touch_keys_rx": [
        "rtl/io/uart_rx.sv",
        "rtl/io/screen_touch_keys_rx.sv",
    ],
    "tb_screen_touch_audio_path": [
        "rtl/io/uart_rx.sv",
        "rtl/io/screen_touch_keys_rx.sv",
        "rtl/control/live_touch_key_merge.sv",
        "rtl/audio/voice_allocator_4.sv",
        "rtl/audio/poly_synth_voice.sv",
        "rtl/audio/poly_synth_4voice.sv",
    ],
    "tb_adc_screen_diag_top": [
        "rtl/common/reset_sync.sv",
        "rtl/common/button_filter.sv",
        "rtl/io/uart_tx.sv",
        "rtl/io/uart_rx.sv",
        "rtl/io/serial_screen_nextion_tx.sv",
        "rtl/io/mcp3208_dual_scan.sv",
        "rtl/control/pressure_key_matrix.sv",
        "rtl/board/adc_screen_diag_top.sv",
        "tests/mcp3208_model.sv",
    ],
    "tb_pressure_control": ["rtl/control/pressure_control.sv"],
    "tb_pressure_key_matrix": ["rtl/control/pressure_key_matrix.sv"],
    "tb_poly_synth_4voice": [
        "rtl/audio/voice_allocator_4.sv",
        "rtl/audio/poly_synth_voice.sv",
        "rtl/audio/poly_synth_4voice.sv",
    ],
    "tb_13key_audio_path": [
        "rtl/control/pressure_key_matrix.sv",
        "rtl/audio/voice_allocator_4.sv",
        "rtl/audio/poly_synth_voice.sv",
        "rtl/audio/poly_synth_4voice.sv",
    ],
    "tb_polyphony_demo_top": [
        "rtl/common/reset_sync.sv",
        "rtl/audio/audio_startup.sv",
        "rtl/audio/voice_allocator_4.sv",
        "rtl/audio/poly_synth_voice.sv",
        "rtl/audio/poly_synth_4voice.sv",
        "rtl/audio/pt8211_tx.sv",
        "rtl/board/polyphony_demo_top.sv",
    ],
    "tb_polyphony_timbre_demo_top": [
        "rtl/common/reset_sync.sv",
        "rtl/common/button_filter.sv",
        "rtl/audio/audio_startup.sv",
        "rtl/audio/voice_allocator_4.sv",
        "rtl/audio/poly_synth_voice.sv",
        "rtl/audio/poly_synth_4voice.sv",
        "rtl/audio/pt8211_tx.sv",
        "rtl/board/polyphony_timbre_demo_top.sv",
    ],
    "tb_pressure_tone": ["rtl/audio/pressure_tone.sv"],
    "tb_pressure_audio_path": [
        "rtl/control/pressure_control.sv",
        "rtl/audio/pressure_tone.sv",
    ],
    "tb_pt8211_tx": ["rtl/audio/pt8211_tx.sv"],
    "tb_snapshot_cdc": ["rtl/common/snapshot_cdc.sv"],
    "tb_mcp3208_dual_scan": [
        "rtl/io/mcp3208_dual_scan.sv",
        "tests/mcp3208_model.sv",
    ],
    "tb_video_1024x600": [
        "rtl/video/video_timing.sv",
        "rtl/video/pressure_audio_ui_1024x600.sv",
        "rtl/video/tmds_encoder.sv",
    ],
    "tb_instrument_ui_1024x600": [
        "rtl/video/instrument_ui_1024x600.sv",
    ],
    "tb_midi_type0_parser": [
        "rtl/midi/midi_type0_parser.sv",
    ],
    "tb_midi_type0_parser_sync": [
        "rtl/midi/midi_type0_parser.sv",
    ],
    "tb_midi_type0_parser_64k": [
        "rtl/midi/midi_type0_parser.sv",
    ],
    "tb_timbre_file_store": [
        "rtl/io/timbre_file_store.sv",
    ],
    "tb_midi_player_scheduler": [
        "rtl/common/u64_divider.sv",
        "rtl/midi/midi_player_scheduler.sv",
    ],
    "tb_midi_player_top": [
        "rtl/common/reset_sync.sv",
        "rtl/common/u64_divider.sv",
        "rtl/io/uart_tx.sv",
        "rtl/io/uart_rx.sv",
        "rtl/io/uart_frame_protocol.sv",
        "rtl/io/uart_frame_tx.sv",
        "rtl/io/midi_file_store.sv",
        "rtl/io/midi_file_ram_sdp.sv",
        "rtl/io/timbre_file_store.sv",
        "rtl/midi/midi_type0_parser.sv",
        "rtl/midi/midi_player_scheduler.sv",
        "rtl/audio/audio_startup.sv",
        "rtl/audio/pt8211_tx.sv",
        "rtl/audio/midi_voice_allocator_4.sv",
        "rtl/audio/midi_poly_synth_4voice.sv",
        "rtl/audio/custom_wavetable_reader.sv",
        "rtl/board/midi_player_top.sv",
    ],
    "tb_uart_ping_echo_top": [
        "rtl/common/reset_sync.sv",
        "rtl/io/uart_tx.sv",
        "rtl/io/uart_rx.sv",
        "rtl/io/uart_ping_protocol.sv",
        "rtl/io/uart_ping_ack.sv",
        "rtl/board/uart_ping_echo_top.sv",
    ],
    "tb_serial_screen_nextion_tx": [
        "rtl/io/uart_tx.sv",
        "rtl/io/uart_rx.sv",
        "rtl/io/serial_screen_nextion_tx.sv",
    ],
}

# 同一 MIDI 文件协议，工作站仅把独立 DAC 输出替换成共享采样时钟的 PCM 接口。
TESTS["tb_midi_player_engine"] = [
    source for source in TESTS["tb_midi_player_top"]
    if source not in ("rtl/board/midi_player_top.sv", "rtl/audio/audio_startup.sv", "rtl/audio/pt8211_tx.sv")
] + ["rtl/board/midi_player_engine.sv"]


def main() -> int:
    BUILD.mkdir(parents=True, exist_ok=True)
    environment = os.environ.copy()
    environment["PATH"] = str(TOOLS) + os.pathsep + environment.get("PATH", "")

    selected = sys.argv[1:] or list(TESTS)
    for name in selected:
        sources = TESTS[name]
        executable = BUILD / f"{name}.vvp"
        compile_command = [
            str(TOOLS / "iverilog.exe"),
            "-g2012",
            "-Wall",
            "-s",
            name,
            "-o",
            str(executable),
            *[str(ROOT / source) for source in sources],
            str(ROOT / "tests" / f"{name}.sv"),
        ]
        run_command = [str(TOOLS / "vvp.exe"), str(executable)]
        logs = []

        for command in (compile_command, run_command):
            try:
                result = subprocess.run(
                    command,
                    cwd=ROOT,
                    env=environment,
                    capture_output=True,
                    text=True,
                    encoding="utf-8",
                    errors="replace",
                    timeout=600 if name == "tb_workstation_latency" else 360 if name == "tb_instrument_latency" else 90,
                )
            except subprocess.TimeoutExpired as error:
                partial = error.stdout or b""
                errors = error.stderr or b""
                if isinstance(partial, bytes): partial = partial.decode("utf-8", errors="replace")
                if isinstance(errors, bytes): errors = errors.decode("utf-8", errors="replace")
                logs.append(partial + errors + "\nFAIL: simulator timed out\n")
                (BUILD / f"{name}.log").write_text("\n".join(logs), encoding="utf-8")
                print(f"Timed out: {name}; partial output saved in build/tests/{name}.log")
                return 1
            logs.append(result.stdout + result.stderr)
            if result.returncode:
                (BUILD / f"{name}.log").write_text("\n".join(logs), encoding="utf-8")
                print("Failed:", " ".join(command))
                print("\n".join(logs))
                return 1

        (BUILD / f"{name}.log").write_text("\n".join(logs), encoding="utf-8")
        if f"PASS {name}" not in logs[-1]:
            print(f"Missing PASS marker: {name}")
            return 1
        print(logs[-1].strip())

    return 0


if __name__ == "__main__":
    sys.exit(main())
