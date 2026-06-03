pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Poll a minimal set of /proc stats for a compact bar system monitor.
Singleton {
    id: root

    property real cpuUsage: 0
    property real memPercent: 0
    property real rxSpeed: 0
    property real txSpeed: 0
    property int loadAvgRounded: 0
    readonly property string cpuText: Math.round(root.cpuUsage) + "%"
    readonly property string memText: Math.round(root.memPercent) + "%"
    readonly property string rxText: formatCompactSpeed(root.rxSpeed)
    readonly property string txText: formatCompactSpeed(root.txSpeed)
    readonly property string loadText: String(root.loadAvgRounded)

    property real _prevCpuTotal: 0
    property real _prevCpuIdle: 0
    property real _prevRxBytes: 0
    property real _prevTxBytes: 0
    property double _prevNetStamp: 0

    function formatCompactSpeed(bytesPerSecond) {
        var value = Math.max(0, bytesPerSecond)
        if (value >= 1000000000)
            return (value / 1000000000).toFixed(value >= 10000000000 ? 0 : 1) + "G"
        if (value >= 1000000)
            return (value / 1000000).toFixed(value >= 10000000 ? 0 : 1) + "M"
        if (value >= 1000)
            return (value / 1000).toFixed(value >= 10000 ? 0 : 1) + "K"
        return Math.round(value) + "B"
    }

    function reloadAll() {
        cpuStatFile.reload()
        memInfoFile.reload()
        netDevFile.reload()
        loadAvgFile.reload()
    }

    function parseCpuStat(text) {
        var lines = String(text || "").split("\n")
        if (lines.length === 0)
            return

        var parts = lines[0].trim().split(/\s+/)
        if (parts.length < 5 || parts[0] !== "cpu")
            return

        var values = []
        for (var i = 1; i < parts.length; i += 1)
            values.push(parseFloat(parts[i]) || 0)

        var idle = (values[3] || 0) + (values[4] || 0)
        var total = 0
        for (var index = 0; index < values.length; index += 1)
            total += values[index]

        if (root._prevCpuTotal > 0 && total > root._prevCpuTotal) {
            var totalDiff = total - root._prevCpuTotal
            var idleDiff = idle - root._prevCpuIdle
            root.cpuUsage = Math.max(0, Math.min(100, ((totalDiff - idleDiff) / totalDiff) * 100))
        }

        root._prevCpuTotal = total
        root._prevCpuIdle = idle
    }

    function parseMemInfo(text) {
        var totalMatch = String(text || "").match(/MemTotal:\s+(\d+)/)
        var availableMatch = String(text || "").match(/MemAvailable:\s+(\d+)/)
        if (!totalMatch || !availableMatch)
            return

        var totalKb = parseInt(totalMatch[1], 10)
        var availableKb = parseInt(availableMatch[1], 10)
        if (totalKb <= 0)
            return

        root.memPercent = ((totalKb - availableKb) / totalKb) * 100
    }

    function parseNetDev(text) {
        var lines = String(text || "").split("\n")
        var rxBytes = 0
        var txBytes = 0

        for (var i = 2; i < lines.length; i += 1) {
            var line = lines[i].trim()
            if (!line)
                continue

            var pair = line.split(":")
            if (pair.length !== 2)
                continue

            var iface = pair[0].trim()
            if (iface === "lo")
                continue

            var fields = pair[1].trim().split(/\s+/)
            if (fields.length < 16)
                continue

            rxBytes += parseFloat(fields[0]) || 0
            txBytes += parseFloat(fields[8]) || 0
        }

        var now = Date.now()
        if (root._prevNetStamp > 0 && now > root._prevNetStamp) {
            var seconds = (now - root._prevNetStamp) / 1000
            root.rxSpeed = Math.max(0, (rxBytes - root._prevRxBytes) / seconds)
            root.txSpeed = Math.max(0, (txBytes - root._prevTxBytes) / seconds)
        }

        root._prevRxBytes = rxBytes
        root._prevTxBytes = txBytes
        root._prevNetStamp = now
    }

    function parseLoadAvg(text) {
        var parts = String(text || "").trim().split(/\s+/)
        if (parts.length === 0)
            return

        root.loadAvgRounded = Math.round(parseFloat(parts[0]) || 0)
    }

    Component.onCompleted: root.reloadAll()

    // Read CPU totals for differential usage calculation.
    FileView {
        id: cpuStatFile

        path: "/proc/stat"
        onLoaded: root.parseCpuStat(text())
    }

    // Read aggregate memory info from procfs.
    FileView {
        id: memInfoFile

        path: "/proc/meminfo"
        onLoaded: root.parseMemInfo(text())
    }

    // Read network byte counters for compact throughput display.
    FileView {
        id: netDevFile

        path: "/proc/net/dev"
        onLoaded: root.parseNetDev(text())
    }

    // Read load average and keep only the rounded one-minute value.
    FileView {
        id: loadAvgFile

        path: "/proc/loadavg"
        onLoaded: root.parseLoadAvg(text())
    }

    // Poll procfs periodically without spawning helper commands.
    Timer {
        interval: 2000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.reloadAll()
    }
}
