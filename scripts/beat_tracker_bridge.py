#!/usr/bin/env python3
"""Beat tracker bridge: PipeWire monitor capture -> aubio tempo -> beat lines.

Spawns `pw-record` against the default sink monitor, feeds the raw PCM to
aubio's tempo tracker, and prints one line per detected beat:

    {"t": 12.3456, "bpm": 142.1, "conf": 0.31, "raw": 142.1}

`t` is the stream timestamp in seconds. `raw` is aubio's own candidate tempo
and `conf` its confidence; `bpm` is the stabilised readout described below.
Lines are flushed immediately so the shell can pulse visuals on each beat.

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

# Tempo readout stabilisation.
#
# aubio's `get_bpm()` is not a BPM reading: it is the comb filter bank's
# current candidate, and it hops between metrical neighbours whenever the music
# stops having a firm pulse. Measured on this machine over 120s per track: a
# track with a clear kick stayed inside 125.7-128.2 BPM, while a beatless
# ambient track flipped 135.8 <-> 107 at least six times. The detected beat
# *positions* are good in both cases, so the displayed number is derived from
# the beats themselves and locked with hysteresis, while aubio's beats continue
# to drive the visual pulse.
TEMPO_WINDOW = 12            # inter-beat intervals kept for the median
TEMPO_MIN_INTERVALS = 4      # intervals required before any tempo is shown
TEMPO_TOLERANCE = 0.03       # within 3% counts as the same tempo
TEMPO_SWITCH_BEATS = 8       # consecutive beats on a new tempo before switching
TEMPO_MIN_BPM = 70.0         # the readout is folded into this range, which
TEMPO_MAX_BPM = 180.0        # keeps octave errors off the display
TEMPO_MIN_CONFIDENCE = 0.20  # below this aubio is guessing (beatless music
                             # measured 0.09-0.15, a firm kick 0.31)
TEMPO_MAX_INTERVAL_S = 2.0   # a longer gap means playback stopped

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


def _fold_octave(bpm: float) -> float:
    """Move a tempo into the display range by whole octaves only."""
    while bpm < TEMPO_MIN_BPM:
        bpm *= 2.0
    while bpm > TEMPO_MAX_BPM:
        bpm /= 2.0
    return bpm


class TempoStabilizer:
    """Turn aubio's per-beat candidate tempo into a number that holds still.

    Runs once per detected beat (2-3 Hz) and never per hop, so it adds nothing
    measurable to the tracker's own per-hop cost.
    """

    def __init__(self) -> None:
        self._intervals: list[float] = []
        self._last_t: float | None = None
        self._locked = 0.0
        self._candidate = 0.0
        self._candidate_beats = 0

    def _median_interval(self) -> float:
        intervals = self._intervals
        return sorted(intervals)[len(intervals) // 2]

    def _estimate(self, confidence: float) -> float:
        """Median-interval tempo, folded into range; 0.0 until it is earned.

        An unsure tracker has to earn its first lock over the whole window: the
        readout then starts on a median of twelve beats instead of four.
        """
        needed = TEMPO_MIN_INTERVALS if confidence >= TEMPO_MIN_CONFIDENCE else TEMPO_WINDOW
        if len(self._intervals) < needed:
            return 0.0
        return _fold_octave(60.0 / self._median_interval())

    def _drop_candidate(self) -> None:
        self._candidate = 0.0
        self._candidate_beats = 0

    def push(self, t: float, confidence: float) -> float:
        """Feed one detected beat; return the BPM to show (0.0 = nothing yet)."""
        if self._last_t is not None:
            interval = t - self._last_t
            if interval > TEMPO_MAX_INTERVAL_S:
                # Playback stopped or the capture stalled: these intervals
                # describe music that is no longer playing.
                self._intervals.clear()
                self._drop_candidate()
            elif interval > 0.0:
                # A single skipped beat doubles the interval, so reject one
                # that lands far outside the window's own median.
                if self._intervals:
                    median = self._median_interval()
                    if not 0.5 * median <= interval <= 2.0 * median:
                        interval = 0.0
                if interval > 0.0:
                    self._intervals.append(interval)
                    if len(self._intervals) > TEMPO_WINDOW:
                        del self._intervals[0]
        # The rejected beat is still the anchor for the next interval.
        self._last_t = t

        estimate = self._estimate(confidence)
        if estimate <= 0.0:
            return self._locked

        if self._locked <= 0.0:
            # The first lock is a guess by construction, but a locked guess is
            # still better than a readout that repaints itself every beat: the
            # confidence gate below protects it from here on.
            self._locked = estimate
            return self._locked

        deviation = estimate - self._locked
        if abs(deviation) <= TEMPO_TOLERANCE * self._locked:
            # Same tempo: follow it slowly so the readout converges on the
            # median instead of freezing on whichever beat locked it first.
            self._locked += 0.25 * deviation
            self._drop_candidate()
            return self._locked

        if confidence < TEMPO_MIN_CONFIDENCE:
            # An unsure beat is not evidence for a new tempo; drop the streak
            # instead of letting it creep over the line.
            self._drop_candidate()
            return self._locked

        # A real tempo change is accepted only after a run of beats lands on
        # the same new value; a stray plateau must not repaint the readout.
        if self._candidate > 0.0 and abs(estimate - self._candidate) <= 0.02 * self._candidate:
            self._candidate_beats += 1
        else:
            self._candidate = estimate
            self._candidate_beats = 1
        if self._candidate_beats >= TEMPO_SWITCH_BEATS:
            self._locked = self._candidate
            self._drop_candidate()
        return self._locked


def _report_error(message: str) -> None:
    print(json.dumps({"error": message}), file=sys.stderr, flush=True)


def _stream_once(recorder: subprocess.Popen, tempo, stabilizer: TempoStabilizer) -> None:
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
            last_s = float(tempo.get_last_s())
            confidence = float(tempo.get_confidence())
            payload = {
                "t": round(last_s, 6),
                "bpm": round(stabilizer.push(last_s, confidence), 2),
                "conf": round(confidence, 4),
                "raw": round(float(tempo.get_bpm()), 2),
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
        stabilizer = TempoStabilizer()
        session_start = time.monotonic()
        _stream_once(recorder, tempo, stabilizer)

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
