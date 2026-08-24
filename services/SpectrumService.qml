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

    // Beat tracking (aubio bridge over the default monitor), mirroring
    // caelestia's approach: pass aubio's own get_bpm straight through.
    readonly property real bpm: _reportedBpm
    // Decaying 0..1 beat pulse for visual accents; spikes to 1 on each beat.
    readonly property real beatPulse: _reportedPulse
    signal beat()

    property real _reportedBpm: 0
    property real _reportedPulse: 0
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

        // Decay the beat pulse on every visual frame so flash effects fade.
        root._reportedPulse *= 0.85
        if (root._reportedPulse < 0.01)
            root._reportedPulse = 0

        root._bufToggle = !root._bufToggle
        root.values = buffer
    }

    // One line per aubio-detected beat: {"t": seconds, "bpm": estimate}.
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

        // Caelestia-style passthrough: trust aubio's own tempo estimate.
        const bpm = Number(payload.bpm)
        root._reportedBpm = isFinite(bpm) && bpm > 0 ? bpm : root._reportedBpm
        root._reportedPulse = 1
        root.beat()
    }

    on_ShouldRunChanged: {
        if (root._shouldRun && !cavaProcess.running) {
            cavaProcess.running = true
        } else if (!root._shouldRun && cavaProcess.running) {
            cavaProcess.running = false
        }

        if (root._shouldRun && !beatProcess.running) {
            root._reportedBpm = 0
            beatProcess.running = true
        } else if (!root._shouldRun && beatProcess.running) {
            beatProcess.running = false
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

        onExited: {
            root._reportedPulse = 0
            root._reportedBpm = 0
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
