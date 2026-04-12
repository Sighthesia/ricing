pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Tracks default audio sink/source state with command fallbacks and smoke-safe overrides.
Singleton {
    id: root

    readonly property var _effectiveState:
        root._stateOverride !== null ? root._stateOverride : root._state
    readonly property real volumeLevel: root._effectiveState.volumeLevel
    readonly property bool volumeMuted: root._effectiveState.volumeMuted
    readonly property bool microphoneMuted: root._effectiveState.microphoneMuted
    readonly property bool sinkAvailable: root._effectiveState.sinkAvailable
    readonly property bool sourceAvailable: root._effectiveState.sourceAvailable
    readonly property bool available: root.sinkAvailable || root.sourceAvailable
    readonly property var audioSnapshot: ({
        volumeLevel: root.volumeLevel,
        volumeMuted: root.volumeMuted,
        microphoneMuted: root.microphoneMuted,
        sinkAvailable: root.sinkAvailable,
        sourceAvailable: root.sourceAvailable,
        available: root.available
    })

    property var _state: root._normalizeState({})
    property var _stateOverride: null
    property string _sinkBuffer: ""
    property string _sourceBuffer: ""
    property string _sourceFallbackBuffer: ""
    property string _lastStateSignature: ""

    signal audioStateChanged(var state)
    signal audioCommandIssued(string kind, var payload)

    function refresh() {
        root._sinkBuffer = ""
        root._sourceBuffer = ""
        root._sourceFallbackBuffer = ""

        _sinkReadProcess.running = false
        _sourceReadProcess.running = false
        _sourceFallbackProcess.running = false

        _sinkReadProcess.running = true
        _sourceReadProcess.running = true
    }

    function setVolumeLevel(level) {
        const clampedLevel = root._clampRatio(level)

        if (root._stateOverride !== null) {
            root._stateOverride = root._normalizeState({
                volumeLevel: clampedLevel,
                volumeMuted: root._stateOverride.volumeMuted,
                microphoneMuted: root._stateOverride.microphoneMuted,
                sinkAvailable: root._stateOverride.sinkAvailable,
                sourceAvailable: root._stateOverride.sourceAvailable
            })
            root._maybeEmitStateChanged()
            return
        }

        root.audioCommandIssued("setVolumeLevel", { level: clampedLevel })
        _writeProcess.command = [
            "sh",
            "-c",
            "if command -v wpctl >/dev/null 2>&1; then exec wpctl \"$@\"; else exit 1; fi",
            "sh",
            "set-volume",
            "@DEFAULT_AUDIO_SINK@",
            clampedLevel.toFixed(3)
        ]
        _writeProcess.running = false
        _writeProcess.running = true
    }

    function setVolumeMuted(muted) {
        const nextMuted = !!muted

        if (root._stateOverride !== null) {
            root._stateOverride = root._normalizeState({
                volumeLevel: root._stateOverride.volumeLevel,
                volumeMuted: nextMuted,
                microphoneMuted: root._stateOverride.microphoneMuted,
                sinkAvailable: root._stateOverride.sinkAvailable,
                sourceAvailable: root._stateOverride.sourceAvailable
            })
            root._maybeEmitStateChanged()
            return
        }

        root.audioCommandIssued("setVolumeMuted", { muted: nextMuted })
        _writeProcess.command = [
            "sh",
            "-c",
            "if command -v wpctl >/dev/null 2>&1; then exec wpctl \"$@\"; else exit 1; fi",
            "sh",
            "set-mute",
            "@DEFAULT_AUDIO_SINK@",
            nextMuted ? "1" : "0"
        ]
        _writeProcess.running = false
        _writeProcess.running = true
    }

    function toggleVolumeMute() {
        root.setVolumeMuted(!root.volumeMuted)
    }

    function setMicrophoneMuted(muted) {
        const nextMuted = !!muted

        if (root._stateOverride !== null) {
            root._stateOverride = root._normalizeState({
                volumeLevel: root._stateOverride.volumeLevel,
                volumeMuted: root._stateOverride.volumeMuted,
                microphoneMuted: nextMuted,
                sinkAvailable: root._stateOverride.sinkAvailable,
                sourceAvailable: root._stateOverride.sourceAvailable
            })
            root._maybeEmitStateChanged()
            return
        }

        root.audioCommandIssued("setMicrophoneMuted", { muted: nextMuted })
        _writeProcess.command = [
            "sh",
            "-c",
            "if command -v wpctl >/dev/null 2>&1; then exec wpctl \"$@\"; else exit 1; fi",
            "sh",
            "set-mute",
            "@DEFAULT_AUDIO_SOURCE@",
            nextMuted ? "1" : "0"
        ]
        _writeProcess.running = false
        _writeProcess.running = true
    }

    function toggleMicrophoneMute() {
        root.setMicrophoneMuted(!root.microphoneMuted)
    }

    function increaseVolume(step) {
        const amount = Number(step)
        const delta = Number.isFinite(amount) && amount > 0 ? amount : 0.05
        root.setVolumeLevel(root.volumeLevel + delta)
    }

    function decreaseVolume(step) {
        const amount = Number(step)
        const delta = Number.isFinite(amount) && amount > 0 ? amount : 0.05
        root.setVolumeLevel(root.volumeLevel - delta)
    }

    function _setStateOverride(state) {
        root._stateOverride = state === null ? null : root._normalizeState(state)
        root._maybeEmitStateChanged()
    }

    function _clampRatio(value) {
        const numericValue = Number(value)
        if (!Number.isFinite(numericValue))
            return 0

        return Math.max(0, Math.min(1, numericValue))
    }

    function _normalizeState(state) {
        const source = state || {}

        return {
            volumeLevel: root._clampRatio(source.volumeLevel),
            volumeMuted: !!source.volumeMuted,
            microphoneMuted: !!source.microphoneMuted,
            sinkAvailable: !!source.sinkAvailable,
            sourceAvailable: !!source.sourceAvailable
        }
    }

    function _setPartialState(patch) {
        const currentState = root._state || root._normalizeState({})

        root._state = root._normalizeState({
            volumeLevel: patch.volumeLevel !== undefined ? patch.volumeLevel : currentState.volumeLevel,
            volumeMuted: patch.volumeMuted !== undefined ? patch.volumeMuted : currentState.volumeMuted,
            microphoneMuted: patch.microphoneMuted !== undefined ? patch.microphoneMuted : currentState.microphoneMuted,
            sinkAvailable: patch.sinkAvailable !== undefined ? patch.sinkAvailable : currentState.sinkAvailable,
            sourceAvailable: patch.sourceAvailable !== undefined ? patch.sourceAvailable : currentState.sourceAvailable
        })
        root._maybeEmitStateChanged()
    }

    function _stateSignature(state) {
        return [
            state.volumeLevel.toFixed(3),
            state.volumeMuted ? "1" : "0",
            state.microphoneMuted ? "1" : "0",
            state.sinkAvailable ? "1" : "0",
            state.sourceAvailable ? "1" : "0"
        ].join("|")
    }

    function _maybeEmitStateChanged() {
        const signature = root._stateSignature(root.audioSnapshot)
        if (signature === root._lastStateSignature)
            return

        root._lastStateSignature = signature
        root.audioStateChanged(root.audioSnapshot)
    }

    function _parseWpctlState(output) {
        const text = (output || "").trim()
        if (text === "")
            return null

        const levelMatch = text.match(/([0-9]+(?:\.[0-9]+)?)/)
        if (!levelMatch)
            return null

        return {
            level: root._clampRatio(Number(levelMatch[1])),
            muted: /\bMUTED\b/i.test(text)
        }
    }

    function _parsePactlSourceState(output) {
        const text = (output || "").trim()
        if (text === "")
            return null

        const volumeMatch = text.match(/(\d+)%/)
        const muteMatch = text.match(/Mute:\s*(yes|no)/i)
        if (!volumeMatch && !muteMatch)
            return null

        return {
            level: volumeMatch ? root._clampRatio(Number(volumeMatch[1]) / 100) : 0,
            muted: muteMatch ? muteMatch[1].toLowerCase() === "yes" : false
        }
    }

    function _applySinkOutput(output) {
        const parsed = root._parseWpctlState(output)
        if (!parsed) {
            root._setPartialState({
                volumeLevel: 0,
                volumeMuted: false,
                sinkAvailable: false
            })
            return false
        }

        root._setPartialState({
            volumeLevel: parsed.level,
            volumeMuted: parsed.muted,
            sinkAvailable: true
        })
        return true
    }

    function _applySourceOutput(output) {
        const parsed = root._parseWpctlState(output)
        if (!parsed)
            return false

        root._setPartialState({
            microphoneMuted: parsed.muted,
            sourceAvailable: true
        })
        return true
    }

    function _applySourceFallbackOutput(output) {
        const parsed = root._parsePactlSourceState(output)
        if (!parsed) {
            root._setPartialState({
                microphoneMuted: false,
                sourceAvailable: false
            })
            return false
        }

        root._setPartialState({
            microphoneMuted: parsed.muted,
            sourceAvailable: true
        })
        return true
    }

    Component.onCompleted: {
        root._maybeEmitStateChanged()
        root.refresh()
    }

    Timer {
        id: _pollTimer
        interval: 3000
        repeat: true
        running: true
        triggeredOnStart: false
        onTriggered: root.refresh()
    }

    Process {
        id: _sinkReadProcess
        command: [
            "sh",
            "-c",
            "if command -v wpctl >/dev/null 2>&1; then wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null; else exit 1; fi"
        ]

        stdout: SplitParser {
            onRead: (line) => {
                root._sinkBuffer += line + "\n"
            }
        }

        onExited: () => {
            root._applySinkOutput(root._sinkBuffer)
            root._sinkBuffer = ""
        }
    }

    Process {
        id: _sourceReadProcess
        command: [
            "sh",
            "-c",
            "if command -v wpctl >/dev/null 2>&1; then wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null; else exit 1; fi"
        ]

        stdout: SplitParser {
            onRead: (line) => {
                root._sourceBuffer += line + "\n"
            }
        }

        onExited: (code) => {
            const handled = code === 0 && root._applySourceOutput(root._sourceBuffer)
            root._sourceBuffer = ""

            if (handled)
                return

            _sourceFallbackProcess.running = false
            _sourceFallbackProcess.running = true
        }
    }

    Process {
        id: _sourceFallbackProcess
        command: [
            "sh",
            "-c",
            "if command -v pactl >/dev/null 2>&1; then pactl get-source-mute @DEFAULT_SOURCE@ 2>/dev/null && pactl get-source-volume @DEFAULT_SOURCE@ 2>/dev/null; else exit 1; fi"
        ]

        stdout: SplitParser {
            onRead: (line) => {
                root._sourceFallbackBuffer += line + "\n"
            }
        }

        onExited: () => {
            root._applySourceFallbackOutput(root._sourceFallbackBuffer)
            root._sourceFallbackBuffer = ""
        }
    }

    Process {
        id: _writeProcess
        onExited: () => root.refresh()
    }

    IpcHandler {
        target: "audio"

        function volumeUp() { root.increaseVolume() }
        function volumeDown() { root.decreaseVolume() }
        function muteOutput() { root.toggleVolumeMute() }
        function muteInput() { root.toggleMicrophoneMute() }
    }
}
