pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Provide shared PipeWire spectrum data for lightweight background visualizers.
Singleton {
    id: root

    property var _registeredComponents: ({})
    property int _crashCount: 0
    property var values: []
    property bool isIdle: true

    // Beat tracking (aubio bridge over the default monitor). The bridge derives
    // the displayed tempo from the beat intervals and locks it with hysteresis,
    // because aubio's own candidate tempo hops between metrical neighbours.
    readonly property real bpm: _reportedBpm
    // Measured gap between the last two detected beats, in ms.
    //
    // Kept apart from `bpm` on purpose: the readout is smoothed and locked, so
    // it does NOT follow the beat. Anything that has to finish exactly when the
    // next beat fires (the spectrum's wave front) has to be timed from the beats
    // themselves, or it overruns and is cut off by the next trigger.
    readonly property int beatIntervalMs: _beatIntervalMs
    // The period the visuals run on, in ms, and the one thing on this side that
    // is allowed to drive an animation.
    //
    // aubio's beat grid is not the music: it re-sits on neighbouring periods
    // while a track plays (measured on one steady 143 BPM track: three 7-8s
    // stretches at 1.27x and 0.74x, with no musical ratio between them), and its
    // individual beat times carry their own jitter. Deriving a period from that
    // directly puts every one of those decisions on screen as irregular
    // flicker, so the period is taken from the most frequent recent gap and has
    // to persist before it may change, and the accents run off a clock at that
    // period rather than off the beats themselves.
    readonly property int visualBeatIntervalMs: _visualIntervalMs
    // Decaying 0..1 beat pulse for visual accents; spikes to 1 on each beat.
    readonly property real beatPulse: _reportedPulse
    signal beat()

    property real _reportedBpm: 0
    property real _reportedPulse: 0
    property int _beatIntervalMs: 0
    property int _visualIntervalMs: 0
    property int _visualCandidateMs: 0
    property double _visualCandidateSince: -1
    // Wall-clock time of the last clock tick, for the phase check below.
    property double _lastTickAt: -1
    property double _lastBeatWallAt: -1
    property real _lastBeatAt: -1
    // Recent accepted beat gaps, in ms (most recent last).
    property var _beatIntervals: []
    // Consecutive bridge exits without a single beat in between; a crash loop
    // must stop retrying, but a device change must not disable BPM for the
    // rest of the session.
    property int _beatCrashCount: 0
    // Dockzone spectrum override — set by the active media widget.
    property real dockzoneHeightScale: 1.0
    property real dockzoneMaxHeightRatio: 1.0
    property real dockzoneGain: 1.0
    property bool dockzoneExpandWithHeight: false
    property real dockzoneBarWidthRatio: 0.42
    property real dockzoneSpacing: 0
    property string dockzoneStyle: ""
    property bool dockzoneMirror: true
    property color dockzoneBarColor: Qt.rgba(0.78, 0.75, 1.0, 0.34)
    readonly property int barsCount: 24
    readonly property int _registeredCount: Object.keys(root._registeredComponents).length
    readonly property bool _shouldRun: root._registeredCount > 0
    readonly property int _idleThreshold: 18
    readonly property string _configPath: Quickshell.cacheDir + "/spectrum-cava.conf"
    readonly property string _configText: [
        "[general]",
        "bars=" + root.barsCount,
        "framerate=30",
        "autosens=1",
        "sensitivity=100",
        "lower_cutoff_freq=50",
        "higher_cutoff_freq=12000",
        "",
        "[smoothing]",
        "monstercat=1",
        "noise_reduction=77",
        "",
        "[output]",
        "method=raw",
        "data_format=ascii",
        "ascii_max_range=100",
        "bit_format=8bit",
        "channels=mono",
        "mono_option=average",
        ""
    ].join("\n")
    property int _idleFrameCount: 0
    property var _buf0: new Array(root.barsCount).fill(0)
    property var _buf1: new Array(root.barsCount).fill(0)
    property bool _bufToggle: false

    function registerComponent(componentId) {
        if (!componentId || root._registeredComponents[componentId])
            return

        root._registeredComponents[componentId] = true
        root._registeredComponents = Object.assign({}, root._registeredComponents)
    }

    function unregisterComponent(componentId) {
        if (!componentId || !root._registeredComponents[componentId])
            return

        delete root._registeredComponents[componentId]
        root._registeredComponents = Object.assign({}, root._registeredComponents)
    }

    function _resetValues() {
        root.values = new Array(root.barsCount).fill(0)
        root.isIdle = true
        root._idleFrameCount = 0
        root._reportedPulse = 0
    }

    function _parseFrame(data) {
        const buffer = root._bufToggle ? root._buf0 : root._buf1
        let index = 0
        let number = 0
        let hasDigit = false
        let allZero = true

        for (let charIndex = 0; charIndex < data.length; charIndex += 1) {
            const code = data.charCodeAt(charIndex)
            if (code >= 48 && code <= 57) {
                number = (number * 10) + (code - 48)
                hasDigit = true
                continue
            }

            if (code !== 59)
                continue

            const value = number * 0.01
            if (index < buffer.length)
                buffer[index] = value
            index += 1
            if (value >= 0.01)
                allZero = false
            number = 0
            hasDigit = false
        }

        if (hasDigit && index < buffer.length) {
            const trailingValue = number * 0.01
            buffer[index] = trailingValue
            index += 1
            if (trailingValue >= 0.01)
                allZero = false
        }

        for (let fillIndex = index; fillIndex < buffer.length; fillIndex += 1)
            buffer[fillIndex] = 0

        // Decay the beat pulse on every visual frame — including idle-stable
        // frames that skip the publish below — so a beat arriving after the
        // spectrum idled still fades instead of freezing flash highlights on.
        root._reportedPulse *= 0.85
        if (root._reportedPulse < 0.01)
            root._reportedPulse = 0

        if (allZero) {
            root._idleFrameCount += 1
            if (root._idleFrameCount >= root._idleThreshold) {
                if (!root.isIdle)
                    root._resetValues()
                return
            }
        } else {
            root._idleFrameCount = 0
            root.isIdle = false
        }

        root._bufToggle = !root._bufToggle
        root.values = buffer
    }

    // One line per aubio-detected beat: {"t": seconds, "bpm": readout}.
    // `bpm` is 0 until the bridge has locked a tempo from enough beats.
    // Move a period into the range the visuals run on by whole octaves only, so
    // a metrical flip changes which beats are accented, not how fast they are.
    function foldVisualInterval(ms) {
        if (!(ms > 0))
            return 0
        var folded = ms
        while (folded < 280)
            folded *= 2
        while (folded > 1000)
            folded /= 2
        return Math.round(folded)
    }

    // The most frequent recent gap, in 12ms buckets, refined to the mean of the
    // gaps in the winning bucket.
    //
    // The median of a short window follows a tracker excursion within a few
    // beats, which is exactly the flicker to remove. The most frequent value
    // does not: measured over one track's 679 gaps, the median of six took 31
    // distinct values and changed 134 times per 622 beats, while this took 2
    // and changed once. The bucket is only a vote - reporting the bucket centre
    // instead of the bucket would bias the period by up to 6ms, which accumulates
    // into a phase correction every ~15s.
    function bucketMode(gaps) {
        // Sixteen gaps (about seven seconds of music) before the first lock: the
        // mode of a handful of gaps is a coin toss, and the persistence rule
        // below would then hold that coin toss for twelve seconds. Measured on a
        // live session where the lock was taken after four gaps: it locked at
        // 567ms on music whose grid was 413ms.
        if (!gaps || gaps.length < 16)
            return 0
        var counts = ({})
        var best = 0
        var bestCount = 0
        for (var i = 0; i < gaps.length; i++) {
            var bucket = Math.round(gaps[i] / 12) * 12
            counts[bucket] = (counts[bucket] || 0) + 1
            if (counts[bucket] > bestCount) {
                bestCount = counts[bucket]
                best = bucket
            }
        }
        var sum = 0
        var n = 0
        for (var j = 0; j < gaps.length; j++) {
            if (Math.round(gaps[j] / 12) * 12 === best) {
                sum += gaps[j]
                n += 1
            }
        }
        return n > 0 ? Math.round(sum / n) : best
    }

    // Accept a new visual period only once it has held for long enough that a
    // tracker excursion cannot produce it. Measured excursions on real tracks
    // last 6-8s; a tempo change lasts the rest of the track.
    function noteVisualPeriod(periodMs) {
        var folded = root.foldVisualInterval(periodMs)
        if (folded <= 0)
            return
        if (root._visualIntervalMs <= 0) {
            root._visualIntervalMs = folded
            return
        }
        var now = Date.now() / 1000
        if (Math.abs(folded - root._visualIntervalMs) <= 0.12 * root._visualIntervalMs) {
            root._visualCandidateMs = 0
            root._visualCandidateSince = -1
            return
        }
        if (root._visualCandidateMs > 0
                && Math.abs(folded - root._visualCandidateMs) <= 0.12 * root._visualCandidateMs) {
            if (now - root._visualCandidateSince >= 12.0) {
                root._visualIntervalMs = root._visualCandidateMs
                root._visualCandidateMs = 0
                root._visualCandidateSince = -1
            }
            return
        }
        root._visualCandidateMs = folded
        root._visualCandidateSince = now
    }

    function stopVisualClock() {
        visualClock.running = false
        root._lastTickAt = -1
        root._reportedPulse = 0
    }

    // The accents themselves. A clock, not the beat stream: what the eye reads as
    // irregular is the spacing between accents changing, and no amount of
    // filtering makes aubio's spacing hold still.
    Timer {
        id: visualClock

        running: false
        repeat: true
        interval: root._visualIntervalMs > 0 ? root._visualIntervalMs : 500
        onTriggered: {
            // The accent cadence belongs to the tracker: when beats stop
            // arriving, the bars must not keep pulsing into silence.
            if (root._lastBeatWallAt > 0
                    && Date.now() - root._lastBeatWallAt > 3 * interval) {
                root.stopVisualClock()
                return
            }
            root._lastTickAt = Date.now()
            root._reportedPulse = 1
            root.beat()
        }
    }

    function _onBeatLine(data) {
        const text = String(data || "").trim()
        if (!text.startsWith("{"))
            return

        let payload
        try {
            payload = JSON.parse(text)
        } catch (e) {
            return
        }
        const timestamp = Number(payload.t)
        if (!isFinite(timestamp) || timestamp < 0)
            return

        // Aubio keeps hallucinating a steady tempo in silence (observed
        // conf 0.0-0.26 with no audio), which would re-spike the beat
        // pulse forever. Only trust beats while cava reports actual
        // sound; quiet passages then stay visually calm as well.
        if (root.isIdle)
            return

        // The bridge already folded this against the beat intervals; a 0 means
        // it has not locked yet, and the previous readout stands.
        const bpm = Number(payload.bpm)

        // Beat-to-beat gap, in ms. The timestamps are aubio's own stream times,
        // so the difference is sample-accurate; a value outside 240-1200 ms is a
        // gap (pause, sink change, tracker restart) and a value that disagrees
        // with the recent window is a skipped or spliced beat. Neither may
        // become a period.
        if (root._lastBeatAt >= 0) {
            const interval = Math.round((timestamp - root._lastBeatAt) * 1000)
            const intervals = root._beatIntervals
            const median = intervals.length >= 3
                ? intervals.slice().sort((a, b) => a - b)[Math.floor(intervals.length / 2)] : 0
            const agrees = median <= 0 || (interval >= 0.7 * median && interval <= 1.5 * median)
            if (isFinite(interval) && interval >= 240 && interval <= 1200 && agrees) {
                intervals.push(interval)
                if (intervals.length > 64)
                    intervals.shift()
                root._beatIntervalMs = bucketMode(intervals)
                root.noteVisualPeriod(root._beatIntervalMs)
            }
        }
        root._lastBeatAt = timestamp
        root._lastBeatWallAt = Date.now()
        root._beatCrashCount = 0

        // Whole BPM only: the stabiliser follows the median continuously, and
        // passing that creep on re-evaluates every consumer twice a second for
        // a digit nobody reads.
        root._reportedBpm = isFinite(bpm) && bpm > 0 ? Math.round(bpm) : root._reportedBpm

        if (root._visualIntervalMs <= 0)
            return
        if (!visualClock.running) {
            root._lastTickAt = root._lastBeatWallAt
            visualClock.start()
            root._reportedPulse = 1
            root.beat()
        }
        // No phase correction here on purpose. Restarting the clock to line up
        // with a beat changes the spacing between accents, which is the one thing
        // this clock exists to keep constant: measured with a per-beat re-phase,
        // a live session restarted it 198 times in five minutes and the tick
        // spacing ran 255-847ms. The period is corrected instead, and the clock
        // re-aligns when the timer's interval changes.
    }

    on_ShouldRunChanged: {
        if (root._shouldRun && !cavaProcess.running) {
            cavaProcess.running = true
        } else if (!root._shouldRun && cavaProcess.running) {
            cavaProcess.running = false
        }

        if (root._shouldRun && !beatProcess.running) {
            root._reportedBpm = 0
            root._beatIntervalMs = 0
            root._visualIntervalMs = 0
            root._visualCandidateMs = 0
            root._visualCandidateSince = -1
            root._beatIntervals = []
            root._lastBeatAt = -1
            root._lastBeatWallAt = -1
            root._beatCrashCount = 0
            beatProcess.running = true
        } else if (!root._shouldRun && beatProcess.running) {
            beatProcess.running = false
            root.stopVisualClock()
        }
    }

    Component.onCompleted: root._resetValues()

    // Spawn cava only while at least one dockzone needs live spectrum data.
    Process {
        id: cavaProcess

        running: false
        command: [
            "sh",
            "-c",
            "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$3\" && exec cava -p \"$3\"",
            "sh",
            Quickshell.cacheDir,
            root._configText,
            root._configPath
        ]

        stdout: SplitParser {
            onRead: data => {
                root._crashCount = 0
                root._parseFrame(String(data || ""))
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const text = this.text.trim()
                if (text)
                    console.warn("SpectrumService:", text)
            }
        }

        onExited: exitCode => {
            root._resetValues()

            if (!root._shouldRun)
                return

            root._crashCount += 1
            if (root._crashCount <= 3)
                restartTimer.restart()
            else
                console.warn("SpectrumService: cava exited repeatedly, code =", exitCode)
        }
    }

    // Aubio tempo tracker over the default monitor; prints one JSON beat per line.
    Process {
        id: beatProcess

        running: false
        command: {
            const override = (Quickshell.env("AFLOAT_BEAT_TRACKER_CMD") || "").trim()
            return override !== ""
                ? ["sh", "-c", override]
                : ["python3", Quickshell.shellDir + "/scripts/beat_tracker_bridge.py"]
        }

        stdout: SplitParser {
            onRead: data => root._onBeatLine(String(data || ""))
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const text = this.text.trim()
                if (text)
                    console.warn("SpectrumService beat:", text)
            }
        }

        // The bridge survives monitor loss on its own, so reaching this handler
        // means a real failure (missing python/aubio, bad override). Without a
        // retry, BPM stayed dead for the whole session after a single exit.
        onExited: exitCode => {
            root._reportedPulse = 0
            root._reportedBpm = 0

            if (!root._shouldRun)
                return

            root._beatCrashCount += 1
            if (root._beatCrashCount <= 5)
                beatRestartTimer.restart()
            else
                console.warn("SpectrumService: beat tracker exited repeatedly, code =", exitCode)
        }
    }

    // Retry a few times so transient startup races do not permanently disable the effect.
    Timer {
        id: restartTimer

        interval: 1500
        repeat: false
        onTriggered: {
            if (root._shouldRun && !cavaProcess.running)
                cavaProcess.running = true
        }
    }

    // Bridge restarts are rarer than cava's (it reconnects its own capture),
    // so give a failed spawn more room before retrying.
    Timer {
        id: beatRestartTimer

        interval: 2000
        repeat: false
        onTriggered: {
            if (root._shouldRun && !beatProcess.running)
                beatProcess.running = true
        }
    }
}
