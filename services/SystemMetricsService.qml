pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Samples coarse system metrics with graceful fallbacks for widget-facing display.
Singleton {
    id: root

    readonly property var _effectiveSnapshot:
        root._snapshotOverride !== null ? root._normalizedSnapshot(root._snapshotOverride) : root._snapshot

    readonly property bool available: !!root._effectiveSnapshot.available
    readonly property bool cpuAvailable: !!root._effectiveSnapshot.cpuAvailable
    readonly property bool memoryAvailable: !!root._effectiveSnapshot.memoryAvailable
    readonly property real cpuUsage: root._effectiveSnapshot.cpuUsage
    readonly property real memoryUsage: root._effectiveSnapshot.memoryUsage
    readonly property real temperatureC: root._effectiveSnapshot.temperatureC
    readonly property bool temperatureAvailable: !!root._effectiveSnapshot.temperatureAvailable
    readonly property string cpuLabel: root._formatPercentLabel("CPU", root.cpuUsage)
    readonly property string memoryLabel: root._formatPercentLabel("MEM", root.memoryUsage)
    readonly property string temperatureLabel: root.temperatureAvailable
        ? "TEMP " + Math.round(root.temperatureC) + "C"
        : "TEMP --"
    readonly property var metricsSnapshot: ({
        available: root.available,
        cpuAvailable: root.cpuAvailable,
        memoryAvailable: root.memoryAvailable,
        cpuUsage: root.cpuUsage,
        memoryUsage: root.memoryUsage,
        temperatureC: root.temperatureC,
        temperatureAvailable: root.temperatureAvailable,
        cpuLabel: root.cpuLabel,
        memoryLabel: root.memoryLabel,
        temperatureLabel: root.temperatureLabel
    })

    property var _snapshot: root._normalizedSnapshot({})
    property var _snapshotOverride: null
    property string _procDir: "/proc"
    property var _lastCpuTotals: null
    property bool _cpuValid: false
    property bool _memoryValid: false
    property string _temperatureBuffer: ""

    function _setSnapshotOverride(snapshot) {
        root._snapshotOverride = snapshot
    }

    function _clearSnapshotOverride() {
        root._snapshotOverride = null
    }

    function _normalizedSnapshot(snapshot) {
        const source = snapshot || {}
        const cpuUsage = root._clampRatio(source.cpuUsage)
        const memoryUsage = root._clampRatio(source.memoryUsage)
        const cpuAvailable = source.cpuAvailable !== undefined
            ? !!source.cpuAvailable
            : (!!source.available || cpuUsage > 0)
        const memoryAvailable = source.memoryAvailable !== undefined
            ? !!source.memoryAvailable
            : (!!source.available || memoryUsage > 0)
        const temperatureAvailable = !!source.temperatureAvailable
        const temperatureC = temperatureAvailable ? root._sanitizeTemperature(source.temperatureC) : 0
        const available = source.available !== undefined
            ? !!source.available
            : (cpuAvailable || memoryAvailable || temperatureAvailable)

        return {
            available: available,
            cpuAvailable: cpuAvailable,
            memoryAvailable: memoryAvailable,
            cpuUsage: cpuUsage,
            memoryUsage: memoryUsage,
            temperatureC: temperatureC,
            temperatureAvailable: temperatureAvailable
        }
    }

    function _clampRatio(value) {
        const numericValue = Number(value)
        if (!Number.isFinite(numericValue))
            return 0

        return Math.max(0, Math.min(1, numericValue))
    }

    function _sanitizeTemperature(value) {
        const numericValue = Number(value)
        if (!Number.isFinite(numericValue))
            return 0

        return Math.max(0, numericValue)
    }

    function _formatPercentLabel(prefix, value) {
        return prefix + " " + Math.round(root._clampRatio(value) * 100) + "%"
    }

    function _setPartialSnapshot(patch) {
        const currentSnapshot = root._snapshot || root._normalizedSnapshot({})
        const nextSnapshot = {
            cpuAvailable: patch.cpuAvailable !== undefined ? patch.cpuAvailable : currentSnapshot.cpuAvailable,
            memoryAvailable: patch.memoryAvailable !== undefined ? patch.memoryAvailable : currentSnapshot.memoryAvailable,
            cpuUsage: patch.cpuUsage !== undefined ? patch.cpuUsage : currentSnapshot.cpuUsage,
            memoryUsage: patch.memoryUsage !== undefined ? patch.memoryUsage : currentSnapshot.memoryUsage,
            temperatureC: patch.temperatureC !== undefined ? patch.temperatureC : currentSnapshot.temperatureC,
            temperatureAvailable: patch.temperatureAvailable !== undefined
                ? patch.temperatureAvailable
                : currentSnapshot.temperatureAvailable
        }

        if (patch.available !== undefined)
            nextSnapshot.available = patch.available

        root._snapshot = root._normalizedSnapshot(nextSnapshot)
    }

    function _poll() {
        _cpuStatView.reload()
        _meminfoView.reload()
        root._readTemperature()
    }

    function _readTemperature() {
        root._temperatureBuffer = ""
        _sensorsProcess.running = false
        _sensorsProcess.running = true
    }

    function _resetCpuState() {
        root._cpuValid = false
        root._lastCpuTotals = null
        root._setPartialSnapshot({
            cpuAvailable: false,
            cpuUsage: 0
        })
    }

    function _resetMemoryState() {
        root._memoryValid = false
        root._setPartialSnapshot({
            memoryAvailable: false,
            memoryUsage: 0
        })
    }

    function _applyCpuStat(text) {
        const lines = text ? text.split("\n") : []
        if (lines.length === 0) {
            root._resetCpuState()
            return
        }

        const cpuLine = lines[0].trim()
        if (!cpuLine.startsWith("cpu ")) {
            root._resetCpuState()
            return
        }

        const parts = cpuLine.split(/\s+/)
        if (parts.length < 5) {
            root._resetCpuState()
            return
        }

        let total = 0
        for (let index = 1; index < parts.length; index++) {
            const value = Number(parts[index])
            if (!Number.isFinite(value)) {
                root._resetCpuState()
                return
            }
            total += value
        }

        const idle = Number(parts[4]) + (Number(parts[5]) || 0)
        if (!Number.isFinite(idle)) {
            root._resetCpuState()
            return
        }

        if (root._lastCpuTotals !== null) {
            const totalDelta = total - root._lastCpuTotals.total
            const idleDelta = idle - root._lastCpuTotals.idle
            if (totalDelta > 0) {
                root._cpuValid = true
                root._setPartialSnapshot({
                    cpuAvailable: true,
                    cpuUsage: 1 - Math.max(0, Math.min(1, idleDelta / totalDelta))
                })
            } else {
                root._cpuValid = false
                root._setPartialSnapshot({
                    cpuAvailable: false,
                    cpuUsage: 0
                })
            }
        } else {
            root._cpuValid = false
            root._setPartialSnapshot({
                cpuAvailable: false,
                cpuUsage: 0
            })
        }

        root._lastCpuTotals = {
            total: total,
            idle: idle
        }
    }

    function _applyMeminfo(text) {
        const lines = text ? text.split("\n") : []
        let totalKb = 0
        let availableKb = -1
        let freeKb = -1
        let buffersKb = 0
        let cachedKb = 0

        for (let index = 0; index < lines.length; index++) {
            const match = lines[index].match(/^([A-Za-z()_]+):\s+(\d+)/)
            if (!match)
                continue

            const key = match[1]
            const value = Number(match[2])
            if (!Number.isFinite(value))
                continue

            if (key === "MemTotal")
                totalKb = value
            else if (key === "MemAvailable")
                availableKb = value
            else if (key === "MemFree")
                freeKb = value
            else if (key === "Buffers")
                buffersKb = value
            else if (key === "Cached")
                cachedKb = value
        }

        if (totalKb <= 0) {
            root._resetMemoryState()
            return
        }

        const usableAvailableKb = availableKb >= 0 ? availableKb : (freeKb + buffersKb + cachedKb)
        if (!Number.isFinite(usableAvailableKb) || usableAvailableKb < 0) {
            root._resetMemoryState()
            return
        }

        const usedRatio = 1 - Math.max(0, Math.min(1, usableAvailableKb / totalKb))

        root._memoryValid = true
        root._setPartialSnapshot({
            memoryAvailable: true,
            memoryUsage: usedRatio
        })
    }

    function _applyTemperatureOutput(output) {
        const match = (output || "").match(/([-+]?\d+(?:\.\d+)?)\s*°?C/)
        if (!match) {
            root._setPartialSnapshot({
                temperatureC: 0,
                temperatureAvailable: false
            })
            return false
        }

        root._setPartialSnapshot({
            temperatureC: Number(match[1]),
            temperatureAvailable: true,
            available: true
        })
        return true
    }

    function _applyThermalZoneOutput(output) {
        const trimmed = (output || "").trim()
        if (trimmed === "") {
            root._setPartialSnapshot({
                temperatureC: 0,
                temperatureAvailable: false
            })
            return
        }

        const lines = trimmed.split("\n")
        for (let index = 0; index < lines.length; index++) {
            const rawValue = Number(lines[index].trim())
            if (!Number.isFinite(rawValue))
                continue

            const normalizedValue = rawValue > 1000 ? rawValue / 1000 : rawValue
            root._setPartialSnapshot({
                temperatureC: normalizedValue,
                temperatureAvailable: true,
                available: true
            })
            return
        }

        root._setPartialSnapshot({
            temperatureC: 0,
            temperatureAvailable: false
        })
    }

    Component.onCompleted: root._poll()

    Timer {
        id: _pollTimer
        interval: 2000
        repeat: true
        running: true
        triggeredOnStart: false
        onTriggered: root._poll()
    }

    FileView {
        id: _cpuStatView
        path: root._procDir + "/stat"
        watchChanges: false
        onLoaded: root._applyCpuStat(text())
    }

    FileView {
        id: _meminfoView
        path: root._procDir + "/meminfo"
        watchChanges: false
        onLoaded: root._applyMeminfo(text())
    }

    Process {
        id: _sensorsProcess
        command: [
            "sh",
            "-c",
            "if command -v sensors >/dev/null 2>&1; then sensors 2>/dev/null; fi"
        ]

        stdout: SplitParser {
            onRead: (line) => {
                root._temperatureBuffer += line + "\n"
            }
        }

        onExited: (code) => {
            const handled = code === 0 && root._applyTemperatureOutput(root._temperatureBuffer)
            root._temperatureBuffer = ""

            if (handled)
                return

            _thermalZoneProcess.running = false
            _thermalZoneProcess.running = true
        }
    }

    Process {
        id: _thermalZoneProcess
        command: [
            "sh",
            "-c",
            "for file in /sys/class/thermal/thermal_zone*/temp; do [ -r \"$file\" ] && cat \"$file\" && exit 0; done; exit 1"
        ]

        property string _buffer: ""

        stdout: SplitParser {
            onRead: (line) => {
                _thermalZoneProcess._buffer += line + "\n"
            }
        }

        onExited: () => {
            root._applyThermalZoneOutput(_thermalZoneProcess._buffer)
            _thermalZoneProcess._buffer = ""
        }
    }

    Connections {
        target: _cpuStatView
        function onLoadFailed() {
            root._resetCpuState()
        }
    }

    Connections {
        target: _meminfoView
        function onLoadFailed() {
            root._resetMemoryState()
        }
    }
}
