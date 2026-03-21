pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Tracks brightnessctl state with safe fallbacks and smoke-safe overrides.
Singleton {
    id: root

    readonly property var _effectiveState:
        root._stateOverride !== null ? root._stateOverride : root._state
    readonly property bool available: !!root._effectiveState.available
    readonly property real level: root._effectiveState.level
    readonly property string percentLabel:
        root.available ? Math.round(root.level * 100) + "%" : "--"
    readonly property var brightnessSnapshot: ({
        available: root.available,
        level: root.level,
        percentLabel: root.percentLabel
    })

    property var _state: root._normalizeState({})
    property var _stateOverride: null
    property string _readBuffer: ""
    property string _lastStateSignature: ""

    signal brightnessStateChanged(var state)
    signal brightnessCommandIssued(string kind, var payload)

    function refresh() {
        if (root._stateOverride !== null)
            return

        root._readBuffer = ""
        _readProcess.running = false
        _readProcess.running = true
    }

    function setLevel(level) {
        const clampedLevel = root._clampRatio(level)
        const percentValue = Math.round(clampedLevel * 100)

        if (root._stateOverride !== null) {
            root._stateOverride = root._normalizeState({
                available: root._stateOverride.available,
                level: clampedLevel
            })
            root._maybeEmitStateChanged()
            return
        }

        root.brightnessCommandIssued("setLevel", {
            level: clampedLevel,
            percent: percentValue
        })
        _writeProcess.command = ["brightnessctl", "set", percentValue + "%"]
        _writeProcess.running = false
        _writeProcess.running = true
    }

    function stepLevel(direction, stepSize) {
        const normalizedDirection = root._stepDirection(direction)
        const stepPercent = Math.max(1, Math.round(root._clampRatio(stepSize) * 100))

        if (normalizedDirection === 0)
            return

        if (root._stateOverride !== null) {
            root._stateOverride = root._normalizeState({
                available: root._stateOverride.available,
                level: root._stateOverride.level + normalizedDirection * (stepPercent / 100)
            })
            root._maybeEmitStateChanged()
            return
        }

        if (!root.available) {
            root.refresh()
            return
        }

        root.brightnessCommandIssued("stepLevel", {
            direction: normalizedDirection,
            percent: stepPercent
        })
        _writeProcess.command = ["brightnessctl", "set", root._stepCommandToken(normalizedDirection, stepPercent)]
        _writeProcess.running = false
        _writeProcess.running = true
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

    function _stepDirection(value) {
        const numericValue = Number(value)
        if (!Number.isFinite(numericValue) || numericValue === 0)
            return 0

        return numericValue > 0 ? 1 : -1
    }

    function _stepCommandToken(direction, stepPercent) {
        const normalizedDirection = root._stepDirection(direction)
        const normalizedPercent = Math.max(1, Math.round(root._clampRatio(stepPercent) * 100))

        if (normalizedDirection === 0)
            return "0%"

        return normalizedDirection > 0
            ? "100%+"
            : "1%-"
    }

    function _normalizeState(state) {
        const source = state || {}

        return {
            available: !!source.available,
            level: root._clampRatio(source.level)
        }
    }

    function _stateSignature(state) {
        return [
            state.available ? "1" : "0",
            state.level.toFixed(3),
            state.percentLabel
        ].join("|")
    }

    function _maybeEmitStateChanged() {
        const signature = root._stateSignature(root.brightnessSnapshot)
        if (signature === root._lastStateSignature)
            return

        root._lastStateSignature = signature
        root.brightnessStateChanged(root.brightnessSnapshot)
    }

    function _parseBrightnessctl(output) {
        const text = (output || "").trim()
        if (text === "")
            return null

        const line = text.split(/\r?\n/)[0]
        const fields = line.split(",")
        if (fields.length < 4)
            return null

        const currentValue = Number(fields[2])
        const percentField = fields.length > 3 ? fields[3].trim() : ""
        const maxValue = Number(fields.length > 4 ? fields[4] : "")
        let parsedLevel = null

        if (Number.isFinite(currentValue) && Number.isFinite(maxValue) && maxValue > 0)
            parsedLevel = currentValue / maxValue
        else if (/^-?\d+(?:\.\d+)?%$/.test(percentField))
            parsedLevel = Number(percentField.slice(0, -1)) / 100

        if (!Number.isFinite(parsedLevel))
            return null

        return {
            available: true,
            level: root._clampRatio(parsedLevel)
        }
    }

    function _applyReadOutput(output) {
        const parsed = root._parseBrightnessctl(output)
        if (!parsed) {
            root._state = root._normalizeState({
                available: false,
                level: 0
            })
            root._maybeEmitStateChanged()
            return false
        }

        root._state = root._normalizeState(parsed)
        root._maybeEmitStateChanged()
        return true
    }

    Component.onCompleted: {
        root._maybeEmitStateChanged()
        root.refresh()
    }

    Timer {
        id: _pollTimer
        interval: 5000
        repeat: true
        running: true
        triggeredOnStart: false
        onTriggered: root.refresh()
    }

    Process {
        id: _readProcess
        command: ["brightnessctl", "-m"]

        stdout: SplitParser {
            onRead: (line) => {
                root._readBuffer += line + "\n"
            }
        }

        onExited: () => {
            root._applyReadOutput(root._readBuffer)
            root._readBuffer = ""
        }
    }

    Process {
        id: _writeProcess
        onExited: () => root.refresh()
    }
}
