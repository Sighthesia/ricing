pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "spectrum/BeatDetect.js" as BeatDetect

// Provide shared PipeWire spectrum data for lightweight background visualizers.
Singleton {
    id: root

    property var _registeredComponents: ({})
    property int _crashCount: 0
    property var values: []
    property bool isIdle: true

    // Bass-onset BPM estimate derived from the same cava frames (0 when unknown).
    // The tracker is a plain JS object, so its fields carry no change
    // notifications — these mirrors are assigned per frame to make the
    // values reactive for QML consumers.
    readonly property real bpm: _reportedBpm
    // Decaying 0..1 beat pulse for visual accents; spikes to 1 on each onset.
    readonly property real beatPulse: _reportedPulse
    signal beat()

    property real _reportedBpm: 0
    property real _reportedPulse: 0
    property var _beatTracker: BeatDetect.createTracker({})
    // Debug logging for beat tracking, gated by AFLOAT_SPECTRUM_DEBUG=1.
    readonly property bool _debugBeat: (Quickshell.env("AFLOAT_SPECTRUM_DEBUG") || "").trim() === "1"
    property int _lastLoggedBpm: 0
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
        BeatDetect.resetTracker(root._beatTracker)
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

        // Bass-onset BPM tracking rides the same frames as the visualizers.
        const fired = BeatDetect.feedFrame(root._beatTracker, buffer)
        root._reportedBpm = root._beatTracker.bpm
        root._reportedPulse = root._beatTracker.pulse
        if (fired)
            root.beat()
    }

    // Debug beat log: one line per onset plus a line when the settled BPM
    // readout moves by a whole BPM, so tempo drift stays visible.
    onBeat: {
        if (!root._debugBeat)
            return

        const bpm = root._reportedBpm
        const rounded = Math.round(bpm)
        console.log("[afloat:SpectrumBeat]", JSON.stringify({
            event: "beat",
            bpm: Math.round(bpm * 10) / 10,
            pulse: Math.round(root._reportedPulse * 100) / 100,
            bassAverage: Math.round(root._beatTracker.average * 1000) / 1000
        }))
        if (rounded !== root._lastLoggedBpm) {
            root._lastLoggedBpm = rounded
            console.log("[afloat:SpectrumBeat]", JSON.stringify({
                event: "bpm-settle",
                bpm: rounded,
                pendingSwitches: root._beatTracker.pendingCount
            }))
        }
    }

    on_ShouldRunChanged: {
        if (root._shouldRun && !cavaProcess.running) {
            cavaProcess.running = true
            return
        }

        if (!root._shouldRun && cavaProcess.running)
            cavaProcess.running = false
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
}
