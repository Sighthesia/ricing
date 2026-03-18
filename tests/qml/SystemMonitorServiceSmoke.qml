import Quickshell
import QtQuick
import qs.services

// Smoke harness for SystemMonitorService aggregation, fallback, and flash behavior.
ShellRoot {
    id: root

    function _metricByKey(metrics, key) {
        for (let index = 0; index < metrics.length; index++) {
            if (metrics[index].key === key)
                return metrics[index]
        }

        return null
    }

    function _resetSuperIsland() {
        SuperIslandService._queue = []
        SuperIslandService._baselineState = ({})
        SuperIslandService._snoozedGroups = ({})
        SuperIslandService._suppressExternalSources = true
        SuperIslandService._lastMediaSignature = ""
        SuperIslandService._lastNotificationId = ""
        SuperIslandService._lastWorkspaceId = ""
        SuperIslandService._lastFocusedWindowId = ""
        SuperIslandService.mainState = SuperIslandService._idleEvent()
        SuperIslandService.flashEvent = ({})
        SuperIslandService.mode = "idle"
        SuperIslandService.activeEvent = SuperIslandService._idleEvent()
    }

    function _assert(condition, message) {
        if (!condition)
            throw new Error(message)
    }

    Component.onCompleted: {
        root._resetSuperIsland()
        SettingsService.data.systemMonitor.pinnedMetrics = ["temperature", "unknown", "cpu"]
        SettingsService.data.systemMonitor.flashEnabled = true
        SettingsService.data.systemMonitor.panelEnabled = true
        SettingsService.data.systemMonitor.superIslandEscalation = true

        root._assert(typeof SystemMonitorService.togglePanel === "function",
            "SystemMonitorService should expose togglePanel()")
        root._assert(typeof SystemMonitorService.openPanel === "function",
            "SystemMonitorService should expose openPanel()")
        root._assert(typeof SystemMonitorService.closePanel === "function",
            "SystemMonitorService should expose closePanel()")
        root._assert(typeof SystemMonitorService.setVolumeLevel === "function",
            "SystemMonitorService should expose setVolumeLevel()")
        root._assert(typeof SystemMonitorService.setBrightnessLevel === "function",
            "SystemMonitorService should expose setBrightnessLevel()")
        root._assert(typeof SystemMonitorService.toggleMicrophoneMute === "function",
            "SystemMonitorService should expose toggleMicrophoneMute()")
        root._assert(typeof SystemMonitorService.acknowledgeFlash === "function",
            "SystemMonitorService should expose acknowledgeFlash()")
        root._assert(typeof SystemMonitorService._setFlashOverride === "function",
            "SystemMonitorService should expose a flash override hook for smoke coverage")
        root._assert(typeof SystemMonitorService._clearFlashOverride === "function",
            "SystemMonitorService should expose _clearFlashOverride() for smoke coverage")

        SystemMetricsService._setSnapshotOverride({
            available: true,
            cpuAvailable: true,
            cpuUsage: 0.92,
            memoryAvailable: true,
            memoryUsage: 0.88,
            temperatureAvailable: true,
            temperatureC: 95
        })
        AudioDeviceService._setStateOverride({
            volumeLevel: 0.42,
            volumeMuted: true,
            microphoneMuted: false,
            sinkAvailable: true,
            sourceAvailable: true
        })
        BrightnessService._setStateOverride({
            available: true,
            level: 0.37
        })

        root._assert(Array.isArray(SystemMonitorService.metrics),
            "SystemMonitorService should expose metrics as an array")
        root._assert(SystemMonitorService.metrics.length === 3,
            "SystemMonitorService should expose three widget-facing metric entries")

        const cpuMetric = root._metricByKey(SystemMonitorService.metrics, "cpu")
        const memoryMetric = root._metricByKey(SystemMonitorService.metrics, "memory")
        const temperatureMetric = root._metricByKey(SystemMonitorService.metrics, "temperature")

        root._assert(!!cpuMetric, "SystemMonitorService metrics should include cpu")
        root._assert(!!memoryMetric, "SystemMonitorService metrics should include memory")
        root._assert(!!temperatureMetric, "SystemMonitorService metrics should include temperature")
        root._assert(SystemMonitorService.metrics[0].key === "temperature",
            "SystemMonitorService should keep available pinned metrics first")
        root._assert(SystemMonitorService.metrics[1].key === "cpu",
            "SystemMonitorService should replace unknown pinned metrics with available fallbacks")
        root._assert(SystemMonitorService.metrics[2].key === "memory",
            "SystemMonitorService should append the remaining available fallback metric")

        root._assert(cpuMetric.severity === "warning",
            "SystemMonitorService should derive warning severity for CPU usage above threshold")
        root._assert(memoryMetric.severity === "warning",
            "SystemMonitorService should derive warning severity for memory usage above threshold")
        root._assert(temperatureMetric.severity === "critical",
            "SystemMonitorService should derive critical severity for temperature above threshold")
        root._assert(SystemMonitorService.highestSeverity === "critical",
            "SystemMonitorService should expose the highest derived severity")
        root._assert(SystemMonitorService.volumeMuted === true,
            "SystemMonitorService should surface volumeMuted from AudioDeviceService")
        root._assert(SystemMonitorService.microphoneMuted === false,
            "SystemMonitorService should surface microphoneMuted from AudioDeviceService")
        root._assert(Math.abs(SystemMonitorService.volumeLevel - 0.42) < 0.001,
            "SystemMonitorService should surface volumeLevel from AudioDeviceService")
        root._assert(Math.abs(SystemMonitorService.brightnessLevel - 0.37) < 0.001,
            "SystemMonitorService should surface brightnessLevel from BrightnessService")
        root._assert(SuperIslandService.activeEvent.groupKey === "system-monitor:critical",
            "SystemMonitorService should mirror critical alerts into SuperIslandService")

        SystemMonitorService.togglePanel()
        root._assert(SystemMonitorService.panelOpen === true,
            "SystemMonitorService should open the panel when togglePanel() is called")
        SystemMonitorService.closePanel()
        root._assert(SystemMonitorService.panelOpen === false,
            "SystemMonitorService should close the panel when closePanel() is called")
        SystemMonitorService.openPanel()
        root._assert(SystemMonitorService.panelOpen === true,
            "SystemMonitorService should open the panel when openPanel() is called")

        SystemMonitorService.setVolumeLevel(0.18)
        root._assert(Math.abs(AudioDeviceService.volumeLevel - 0.18) < 0.001,
            "SystemMonitorService should forward setVolumeLevel() to AudioDeviceService")
        SystemMonitorService.setBrightnessLevel(0.64)
        root._assert(Math.abs(BrightnessService.level - 0.64) < 0.001,
            "SystemMonitorService should forward setBrightnessLevel() to BrightnessService")
        SystemMonitorService.toggleMicrophoneMute()
        root._assert(AudioDeviceService.microphoneMuted === true,
            "SystemMonitorService should forward toggleMicrophoneMute() to AudioDeviceService")

        SystemMonitorService.acknowledgeFlash()
        root._assert(SystemMonitorService.flashVisible === false,
            "SystemMonitorService should clear the active flash slot when acknowledged")

        SystemMetricsService._setSnapshotOverride({
            available: true,
            cpuAvailable: true,
            cpuUsage: 0.12,
            memoryAvailable: true,
            memoryUsage: 0.23,
            temperatureAvailable: true,
            temperatureC: 54
        })
        root._assert(SystemMonitorService.highestSeverity === "normal",
            "SystemMonitorService should fall back to normal when all metrics are below thresholds")

        SystemMonitorService._setFlashOverride({
            id: "override:flash",
            title: "Override Flash"
        })
        root._assert(SystemMonitorService.flashVisible === true,
            "SystemMonitorService should let smoke override force flash visibility")
        root._assert(SystemMonitorService.flashEvent.id === "override:flash",
            "SystemMonitorService should surface the override flash event")
        SystemMonitorService._setFlashOverride(null)
        root._assert(SystemMonitorService.flashVisible === false,
            "SystemMonitorService should let smoke override clear flash visibility")
        SystemMonitorService._clearFlashOverride()

        console.log("SystemMonitorService smoke test passed")
        Qt.callLater(Qt.quit)
    }
}
