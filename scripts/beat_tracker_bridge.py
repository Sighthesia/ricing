#!/usr/bin/env python3
"""Beat tracker bridge: PipeWire monitor capture -> aubio tempo -> beat lines.

Spawns `pw-record` against the default sink monitor, feeds the raw PCM to
aubio's tempo tracker, and prints one line per detected beat:

    {"t": 12.3456, "bpm": 142.1}

`t` is the stream timestamp in seconds; `bpm` is the tracker's current tempo
estimate. Lines are flushed immediately so the shell can pulse visuals on
each beat.
"""

from __future__ import annotations

import json
import os
import shutil
import struct
import subprocess
import sys

import aubio

SAMPLE_RATE = 44100
HOP_SIZE = 512
BUF_SIZE = 1024


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


def main() -> int:
    try:
        record_cmd = _record_command()
    except RuntimeError as error:
        print(json.dumps({"error": str(error)}), file=sys.stderr, flush=True)
        return 1

    try:
        recorder = subprocess.Popen(
            record_cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
        )
    except OSError as error:
        print(json.dumps({"error": f"spawn failed: {error}"}), file=sys.stderr, flush=True)
        return 1

    tempo = aubio.tempo("default", BUF_SIZE, HOP_SIZE, SAMPLE_RATE)
    bytes_per_hop = HOP_SIZE * 4  # f32le mono

    try:
        while True:
            chunk = recorder.stdout.read(bytes_per_hop)
            if not chunk or len(chunk) < bytes_per_hop:
                break
            samples = aubio.fvec(struct.unpack(f"<{HOP_SIZE}f", chunk))
            is_beat = tempo(samples)
            if is_beat:
                payload = {
                    "t": round(float(tempo.get_last_s()), 6),
                    "bpm": round(float(tempo.get_bpm()), 2),
                }
                print(json.dumps(payload), flush=True)
    except KeyboardInterrupt:
        pass
    finally:
        recorder.terminate()
        try:
            recorder.wait(timeout=2)
        except subprocess.TimeoutExpired:
            recorder.kill()
    return 0


if __name__ == "__main__":
    sys.exit(main())
