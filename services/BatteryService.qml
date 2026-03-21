pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Tracks battery state from sysfs and keeps override-safe widget-facing values.
Singleton {
    id: root

    readonly property var _effectiveState:
        root._stateOverride !== null ? root._stateOverride : root._state
    readonly property var batterySnapshot: ({
        available: root.available,
        level: root.level,
        charging: root.charging,
        status: root.status,
        percentLabel: root.percentLabel
    })
    readonly property bool available: !!root._effectiveState.available
    readonly property real level: root.available ? root._effectiveState.level : 0
    readonly property bool charging: !!root._effectiveState.charging
    readonly property string status: root._effectiveState.status
    readonly property string percentLabel: root.available ? Math.round(root.level * 100) + "%" : "--"

    property var _state: root._normalizeState({
        available: false,
        level: 0,
        charging: false,
        status: "missing"
    })
    property var _stateOverride: null
    property string _scanBuffer: ""
    property string _lastStateSignature: ""

    signal batteryStateChanged(var state)

    function refresh() {
        if (root._stateOverride !== null)
            return

        root._scanBuffer = ""
        _scanProcess.running = false
        _scanProcess.running = true
    }

    function _setStateOverride(state) {
        root._stateOverride = state === null || state === undefined ? null : root._normalizeState(state)
        root._maybeEmitStateChanged()
    }

    function _normalizeState(state) {
        const source = state || {}
        const available = !!source.available
        const level = available ? root._clampRatio(source.level) : 0
        const charging = available ? !!source.charging : false
        const status = available ? root._normalizeStatus(source.status, charging) : "missing"

        return {
            available: available,
            level: level,
            charging: charging,
            status: status
        }
    }

    function _normalizeStatus(status, charging) {
        const value = (status || "").toString().trim().toLowerCase()
        if (value === "charging")
            return "charging"
        if (value === "discharging")
            return "discharging"
        if (value === "full")
            return "full"
        if (value === "not charging")
            return "not charging"

        return charging ? "charging" : (value !== "" ? value : "unknown")
    }

    function _clampRatio(value) {
        const numericValue = Number(value)
        if (!Number.isFinite(numericValue))
            return 0

        return Math.max(0, Math.min(1, numericValue))
    }

    function _clampPercent(value) {
        return root._clampRatio(Number(value) / 100)
    }

    function _stateSignature(state) {
        return [
            state.available ? "1" : "0",
            state.level.toFixed(3),
            state.charging ? "1" : "0",
            state.status,
            state.percentLabel
        ].join("|")
    }

    function _maybeEmitStateChanged() {
        const signature = root._stateSignature(root.batterySnapshot)
        if (signature === root._lastStateSignature)
            return

        root._lastStateSignature = signature
        root.batteryStateChanged(root.batterySnapshot)
    }

    function _applyScanOutput(output) {
        const text = (output || "").trim()
        if (text === "") {
            root._state = root._normalizeState({
                available: false,
                level: 0,
                charging: false,
                status: "missing"
            })
            root._maybeEmitStateChanged()
            return false
        }

        const fields = text.split("|")
        if (fields.length < 4 || fields[0] !== "battery") {
            root._state = root._normalizeState({
                available: false,
                level: 0,
                charging: false,
                status: "missing"
            })
            root._maybeEmitStateChanged()
            return false
        }

        root._state = root._normalizeState({
            available: true,
            level: root._clampPercent(fields[1]),
            charging: fields[2] === "1",
            status: fields[3]
        })
        root._maybeEmitStateChanged()
        return true
    }

    Component.onCompleted: {
        root._maybeEmitStateChanged()
        root.refresh()
        _pollTimer.start()
    }

    Timer {
        id: _pollTimer
        interval: 30000
        repeat: true
        running: false
        onTriggered: root.refresh()
    }

    Process {
        id: _scanProcess
        command: [
            "sh",
            "-c",
            "for dir in $(printf '%s\\n' /sys/class/power_supply/* 2>/dev/null | sort); do [ -d \"$dir\" ] || continue; type=$(cat \"$dir/type\" 2>/dev/null || printf ''); [ \"$type\" = Battery ] || continue; capacity=$(cat \"$dir/capacity\" 2>/dev/null || printf '0'); status=$(cat \"$dir/status\" 2>/dev/null || printf 'Unknown'); case ${status} in Charging) charging=1 ;; *) charging=0 ;; esac; printf 'battery|%s|%s|%s\\n' \"$capacity\" \"$charging\" \"$status\"; exit 0; done; printf 'missing\\n'; exit 0"
        ]

        stdout: SplitParser {
            onRead: (line) => {
                root._scanBuffer += line + "\n"
            }
        }

        onExited: () => {
            root._applyScanOutput(root._scanBuffer)
            root._scanBuffer = ""
        }
    }
}
