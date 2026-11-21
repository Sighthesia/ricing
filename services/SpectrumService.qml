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
    // The period the visuals run on, in ms, and the one thing on this side that
    // is allowed to drive an animation.
    //
    // aubio's beat grid is not the music: it re-sits on neighbouring periods
    // while a track plays (measured on one steady 143 BPM track: three 7-8s
    // stretches at 1.27x and 0.74x, with no musical ratio between them), and its
    // individual beat times carry their own jitter. Deriving a period from that
    // directly put every one of those decisions on screen as irregular flicker,
    // so the accents run off a clock at this period rather than off the beats
    // themselves. The period itself is allowed to follow the music.
    readonly property int visualBeatIntervalMs: _visualIntervalMs
    // Decaying 0..1 beat pulse for visual accents; spikes to 1 on each beat.
    readonly property real beatPulse: _reportedPulse
    signal beat()

    property real _reportedBpm: 0
    property real _reportedPulse: 0
    property int _beatIntervalMs: 0
    property int _visualIntervalMs: 0
    // Consecutive gaps rejected by the window's own median; see _onBeatLine.
    property int _beatRejected: 0
    // Wall clock of the last arriving beat, for the clock's watchdog.
    property double _lastBeatWallAt: -1
    // Wall clock of the last cava frame. The pulse decay lives in _parseFrame, so
    // a dead cava would otherwise leave the pulse latched at 1 with the highlight
    // burning until the shell restarts.
    property double _lastFrameAt: -1
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
        root._lastFrameAt = Date.now()
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
        if (!isFinite(ms) || !(ms > 0))
            return 0
        var folded = ms
        while (folded < 280)
            folded *= 2
        while (folded > 1000)
            folded /= 2
        return Math.round(folded)
    }

    // The period the accents run at, from the median of the last few gaps.
    //
    // A longer, mode-voting window was tried here and did not pay for itself: it
    // held a stale period through a real change of arrangement for up to twelve
    // seconds, which on material whose beat weighting changes with the
    // instrumentation is most of the time. The window is short and follows, and
    // the accents no longer inherit aubio's jitter because they run off a clock
    // at this period instead of off the beats.
    function setVisualPeriod(periodMs) {
        var folded = root.foldVisualInterval(periodMs)
        if (folded > 0)
            root._visualIntervalMs = folded
    }

    function stopVisualClock() {
        visualClock.running = false
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
            // The accent cadence belongs to the tracker and to the spectrum: when
            // either stops, the bars must not keep pulsing into silence, and the
            // pulse must not stay latched (its decay runs in _parseFrame).
            const now = Date.now()
            if ((root._lastBeatWallAt > 0 && now - root._lastBeatWallAt > 3 * interval)
                    || (root._lastFrameAt > 0 && now - root._lastFrameAt > 2000)) {
                root.stopVisualClock()
                return
            }
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
                if (intervals.length > 6)
                    intervals.shift()
                root._beatRejected = 0
                var sorted = intervals.slice().sort((a, b) => a - b)
                root._beatIntervalMs = sorted[Math.floor(sorted.length / 2)]
                // Three gaps before the accents may be re-timed: one gap is not
                // a period, and a wrong first lock is now followed immediately
                // rather than confirmed.
                if (intervals.length >= 3)
                    root.setVisualPeriod(root._beatIntervalMs)
            } else {
                // A run of disagreements is a different tune, not a run of skipped
                // beats. Without giving up on the window, it could only ever
                // describe the tempo it was built on: every later gap would keep
                // being rejected against it, for the rest of the session.
                root._beatRejected += 1
                if (root._beatRejected >= 8) {
                    root._beatRejected = 0
                    root._beatIntervals = []
                }
            }
        }
        root._lastBeatAt = timestamp
        root._lastBeatWallAt = Date.now()
        root._beatCrashCount = 0

        // Whole BPM only: the stabiliser follows the median continuously, and
        // passing that creep on re-evaluates every consumer twice a second for
        // a digit nobody reads.
        root._reportedBpm = isFinite(bpm) && bpm > 0 ? Math.round(bpm) : root._reportedBpm

        if (root._visualIntervalMs <= 0) {
            // No period yet - the first seven seconds of a track, or a window
            // that was just thrown away. Accent the beat itself, or the spectrum
            // sits silent instead of merely unsteady.
            root._reportedPulse = 1
            root.beat()
            return
        }
        if (!visualClock.running) {
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
            root._beatRejected = 0
            root._beatIntervals = []
            root._lastBeatAt = -1
            root._lastBeatWallAt = -1
            root._lastFrameAt = -1
            root._beatCrashCount = 0
            beatProcess.running = true
        } else if (!root._shouldRun && beatProcess.running) {
            beatProcess.running = false
        }
        if (!root._shouldRun)
            root.stopVisualClock()
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
