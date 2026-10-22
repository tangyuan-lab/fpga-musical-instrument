# V5 implementation checkpoint — 2026-10-18

## Verified in this checkpoint

- Per-track post-synthesis gain, mute/solo and meters use the streaming preview path. Original note velocity is retained. Gain changes ramp over approximately 5 ms.
- Device deployment receipts include song content and referenced patch content, including ADSR. Publication revisions are independent of editor undo revisions. A reconnect invalidates local receipts.
- Project format 5 reads formats 2–4; the GUI upgrades to a separate V5 filename.
- OMR runs in a separate background queue. Windows Job cancellation terminates this invocation's process tree and preserves logs. This does not yet make FPGA upload interruptible.
- Edit → 逐小节校正 edits rational start/duration, voice/staff, pitch/rest, written duration, dots, tuplet ratio and tie markers. Applying edits preserves stable note IDs and regenerates the selected measure's XML cursor; other measures retain their musical events.
- The editor displays structural audit results. Structural validity is not evidence of PDF recognition accuracy or manual review.
- Source baseline: `build/refactor_v5/before.zip`.

## Evidence

- `python -m unittest discover -s tests -q`: **90 tests passed**.
- `python -m compileall -q host_app`: passed.
- `python scripts/verify_streaming_audio.py`: muted Qt output completed at 48 kHz with actual 1024-frame buffering; no reported errors; position did not exceed song duration. `build/tests/realtime_audio.json`.
- New tests cover gain ratio, mute/solo, separate pedals, rational local edits, invalid edits, deployment dependencies/undo/reconnect, and real subprocess cancellation.
- Editor screenshot: `build/tests/measure_editor.png`. This is an offscreen layout check, not a full DPI acceptance test.

## Outstanding — do not mark the full plan complete

- Transcoda bridge/inference evaluation and Nocturne's 102-bar source review.
- Complete measure review/confirmation workflow, contextual clef/key/meter editing, and richer batch/clip operations.
- Serial priority executor and FPGA PANIC/ABORT during upload/validation: source and directed tests completed on 2026-10-19; new synthesis/PnR and full-top UART regression in progress. See `EMERGENCY_PROTOCOL.md`.
- Sixteen source owners, channel allocation, FPGA continuous track/role gain, owned drums, MIX_SET/SNAPSHOT and screen acknowledgement.
- Transactional resource replacement and device subset/delete workflows.
- Full voice/FX load verification, PnR, new bitstream release, official HMI compilation and hardware measurements.
- Sound-card response/underrun stress measurements and 1366×768/1920×1080 DPI acceptance.

The working FPGA bitstream has not been replaced by this checkpoint. No claim is made that PDF recognition is now accurate or that the complete hardware requirements have passed.

## 2026-10-19 continuation

- Added a single-owner serial executor with separate urgent dispatch while an ordinary ACK is outstanding. ABORT cancels outstanding resource/control requests and prevents upload retry/COMMIT. Late ACKs remain isolated by sequence/type.
- Added capability bit2 and 0x3B in the V2 FPGA source, plus resource abort, immediate player/synth stop and pending-command clearing. Old firmware retains its original capability bits and ordinary protocol.
- GUI stop/panic uses the urgent queue when advertised; reconnect/disconnect cannot close the port during pending emergency acknowledgement.
- Host tests: **97 passed**. All 11 V2 RTL testbenches and key-pipeline top elaboration passed, including 32-voice stop/restart and command queue clearing.
- Gowin synthesis completed; placement/routing and the real-UART full-top regression are still running at this checkpoint. No new hardware bitstream has yet been declared verified.
- Preserved the prior V2 ready artifacts in `build/verified_baselines/v2_before_emergency` before starting the new build.
- Installed a separate kern bridge environment (`converter21 4.0.2`, `music21 10.5.0`), with lockfile and licenses; main application dependencies are unchanged.
- `python scripts/verify_omr_bridge.py`: exact 23-note synthetic comparison passed, including quintuplets, nonuplets, mixed 1/6–4/9–1/18 durations, ties, two staves, key and clef changes. This is not a PDF inference result. Kern durations cannot uniquely recover original printed tuplet grouping.
- Added the 小节疑点 tab, per-measure review hashes, full tie-chain confirmation and undo. Unit rescaling alone does not invalidate unmodified bars. The editor can set local quarter-note BPM and meter; missing unconfirmed tempo/meter blocks device deployment while computer preview remains available.
- Latest full host suite: **104 tests passed**. Compact editor and 1366×768 review layouts inspected; screenshots are in `build/tests/measure_editor_compact.png` and `build/tests/score_review.png`.
- First emergency build failed PnR with **2751 unrouted nets** (CLS 86%, registers 21820). It was not published. Failure log/report preserved as `build/instrument_workstation_v2_emergency_route_failed.*`.
- Optimized the urgent arbiter to borrow the ordinary resource response buffer and enforce an ingress lock instead of adding two 768-bit buffers. Directed locked-buffer/overtaking tests and the 11-testbench V2 suite pass. New synthesis reports 20243 registers; second PnR and full-top regression are in progress.
- Transcoda source checked out at `d4e2e687d5679ae96ca4aa6f01e06a5b338cd488`, independent Python3.12 environment preparing. Official model revision is `b529f8aa5d996d9224df3395b5b92d0867343c91`. Config/model downloads are currently blocked by TLS/connection failures; no Transcoda PDF inference has run, and no candidate was promoted.

## Latest checkpoint — model download deferred by user

- Transcoda Python3.12 dependencies now import successfully (`torch 2.9.1+cpu`, CUDA unavailable). Lockfile, source license and manifest saved. Model/config download deferred at user's request; no inference or Nocturne accuracy claim.
- Optimized emergency full-top regression **passed**: 32 voices, four physical keys, delay/reverb, 699 audio samples, 217 screen UART bytes and nine CRC-checked host responses. Emergency ACK, no retrigger of held keys, and post-stop state verified. The 3.22446ms measurement is control-to-voice allocation, not analog latency.
- Second whole-FPGA PnR remains in Routing Phase0. No new bitstream published; existing V2 ready hash remains `C286B9BC0D9A366C9E320227ADD06964BC6B198E124A629CB5969B8CC3BE1FD7`.
- New source-track compiler preserves note identities and velocity, allocates unison overlaps to separate channels sharing one owner, and reports exact track/tick capacity failures. Sixteen channels share up to sixteen owners; normal music reserves four of the 32 melodic slots for real-time play. The read-only capacity command is available in the Device menu.
- Independent 16-channel RTL parser passes 13 test groups, including 2048 events, exact64KiB, 64 tempos, running status, malformed paired notes and overflow rejection. Serial BRAM clearing avoids 2048 reset flags. Single tempo write port reduced synthesis from 3949 to309 registers; final footprint14 BSRAM, 796 LUT, 309 registers.
- Independent gain bank passes exact128-sample ramps, retarget, mute, independent owners and fixed-frame tests. Synthesized to3 BSRAM and42 registers.
- Independent32-voice candidate applies gain after waveform/envelope/velocity multiplication. Long-note ratio, unchanged phase/envelope/velocity, independent mute/unmute and full32-slot tests pass; frame latency325 clocks. Isolated synthesis:2022 registers,8 BSRAM, pre-PnR Fmax75.236MHz. It is **not integrated** into the current whole design. See `experiments/workstation_tracks/README.md` for remaining protocol/player/drum work.
- Added local midmeasure clef and key editing; absolute pitches remain explicit. Context edits invalidate affected note confirmation even when pitches are unchanged. Original scores are not rewritten from a new four-role transcription.
- Six offscreen layout cases pass:1366×768 and1920×1080 at100/125/150%. Real Chinese fonts loaded; editor footer remains accessible, optional notation context collapses, and playback target stays visible. These are automated geometry/render checks, not physical Windows/DPI interaction measurements.
- Switching away from FPGA preview requests stop and waits for ACK before computer sound. Failed stop keeps the computer preview blocked until retry or deliberate offline disconnect. FPGA target disables the currently PC-only faders.
- Final host regression: **114 tests passed**; host and new scripts compile successfully. Parser cases also verify abort with an active note followed by a fresh successful parse. The board image was not programmed in this checkpoint.
