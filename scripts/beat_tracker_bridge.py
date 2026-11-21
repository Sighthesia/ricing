#!/usr/bin/env python3
"""Beat tracker bridge: PipeWire monitor capture -> aubio tempo -> beat lines.

Spawns `pw-record` against the default sink monitor, feeds the raw PCM to
aubio's tempo tracker, and prints one line per detected beat:

    {"t": 12.3456, "bpm": 142.1}

`t` is the stream timestamp in seconds; `bpm` is the tracker's current tempo
estimate. Lines are flushed immediately so the shell can pulse visuals on
each beat.

Capture is re-opened when `pw-record` ends: a Bluetooth sink that drops (or a
suspend) closes the monitor stream, and the tracker must survive that instead
of exiting and leaving the shell with a silent, dead bridge.
"""

from __future__ import annotations

import json
import os
import queue
import re
import shutil
import signal
import struct
import subprocess
import sys
import threading
import time

import aubio

SAMPLE_RATE = 44100
HOP_SIZE = 512
BUF_SIZE = 1024

# Re-open the capture after this long when the monitor stream ends; doubling
# up to the cap keeps a permanently broken audio graph from spinning.
RECONNECT_MIN_S = 1.0
RECONNECT_MAX_S = 5.0

_stopping = threading.Event()
# Set when PipeWire's default sink changes; the capture must move to the new
# monitor, otherwise it keeps recording a sink that no longer plays the music.
_sink_changed = threading.Event()


def _watch_default_sink() -> None:
    """Follow PipeWire's default sink and flag every new one."""
    pw_metadata = shutil.which("pw-metadata")
    if not pw_metadata:
        return

    current = None
    while not _stopping.is_set():
        try:
            watcher = subprocess.Popen(
                [pw_metadata, "-n", "default", "-m"],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
            )
        except OSError:
            return

        try:
            assert watcher.stdout is not None
            for line in watcher.stdout:
                if _stopping.is_set():
                    break
                if "key:'default.audio.sink'" not in line:
                    continue
                match = re.search(r'"name"\s*:\s*"([^"]*)"', line)
                if not match:
                    continue
                name = match.group(1)
                if current is not None and name != current:
                    _sink_changed.set()
                current = name
        finally:
            watcher.terminate()
            try:
                watcher.wait(timeout=2)
            except subprocess.TimeoutExpired:
                watcher.kill()

        # pw-metadata exited (server restart): re-arm rather than give up.
        _stopping.wait(1.0)


def _record_command() -> list[str]:
    override = os.environ.get("AFLOAT_BEAT_RECORD_CMD", "").strip()
    if override:
        return [part for part in override.split() if part]
    pw_record = shutil.which("pw-record")
    if not pw_record:
        raise RuntimeError("pw-record not found")
    return [
        pw_record,
        "--raw",
        "--target", "@DEFAULT_MONITOR@",
        "--format", "f32",
        "--rate", str(SAMPLE_RATE),
        "--channels", "1",
        "-",
    ]


def _report_error(message: str) -> None:
    print(json.dumps({"error": message}), file=sys.stderr, flush=True)


def _stream_once(recorder: subprocess.Popen, tempo) -> None:
    """Feed every captured hop to the tracker until the recorder stops."""
    bytes_per_hop = HOP_SIZE * 4  # f32le mono

    # Reader thread with a deep queue: PipeWire capture must never block on
    # the analysis/consumer side, or the graph xruns and drops samples —
    # which silently compresses beat timestamps and corrupts tempo.
    chunks: "queue.Queue[bytes | None]" = queue.Queue(maxsize=4096)

    def read_pcm() -> None:
        try:
            while not _stopping.is_set():
                chunk = recorder.stdout.read(bytes_per_hop)
                if not chunk or len(chunk) < bytes_per_hop:
                    break
                chunks.put(chunk)
        except OSError:
            pass
        finally:
            chunks.put(None)

    reader = threading.Thread(target=read_pcm, daemon=True)
    reader.start()

    while not _stopping.is_set():
        if _sink_changed.is_set():
            break
        try:
            chunk = chunks.get(timeout=0.5)
        except queue.Empty:
            continue
        if chunk is None:
            break
        samples = aubio.fvec(struct.unpack(f"<{HOP_SIZE}f", chunk))
        is_beat = tempo(samples)
        if is_beat:
            payload = {
                "t": round(float(tempo.get_last_s()), 6),
                "bpm": round(float(tempo.get_bpm()), 2),
                "conf": round(float(tempo.get_confidence()), 4),
            }
            print(json.dumps(payload), flush=True)


def main() -> int:
    def request_stop(_signum=None, _frame=None) -> None:
        _stopping.set()

    for signum in (signal.SIGTERM, signal.SIGINT):
        signal.signal(signum, request_stop)

    try:
        record_cmd = _record_command()
    except RuntimeError as error:
        _report_error(str(error))
        return 1

    watcher = threading.Thread(target=_watch_default_sink, daemon=True)
    watcher.start()

    delay = RECONNECT_MIN_S
    while not _stopping.is_set():
        try:
            recorder = subprocess.Popen(
                record_cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
            )
        except OSError as error:
            _report_error(f"spawn failed: {error}")
            _stopping.wait(delay)
            delay = min(delay * 2, RECONNECT_MAX_S)
            continue

        # A fresh tracker per capture session: after a long gap the old
        # tracker would keep reporting its stale tempo into the new audio.
        tempo = aubio.tempo("default", BUF_SIZE, HOP_SIZE, SAMPLE_RATE)
        session_start = time.monotonic()
        _stream_once(recorder, tempo)

        recorder.terminate()
        try:
            recorder.wait(timeout=2)
        except subprocess.TimeoutExpired:
            recorder.kill()

        if _stopping.is_set():
            break

        if _sink_changed.is_set():
            # The default sink moved; open a fresh capture immediately.
            _sink_changed.clear()
            _report_error("default sink changed, reopening")
            delay = RECONNECT_MIN_S
            continue

        _report_error("monitor capture ended, reopening")
        # Only a capture that died quickly should back off; a long, healthy
        # session that ended on a device change deserves an immediate retry.
        if time.monotonic() - session_start > 5.0:
            delay = RECONNECT_MIN_S
        _stopping.wait(delay)
        delay = min(delay * 2, RECONNECT_MAX_S)

    return 0


if __name__ == "__main__":
    sys.exit(main())
