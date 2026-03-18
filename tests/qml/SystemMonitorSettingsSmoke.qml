import Quickshell
import QtQuick
import qs.services

// Smoke harness for SystemMonitor settings schema availability.
ShellRoot {
    id: root

    function _assert(condition, message) {
        if (!condition)
            throw new Error(message)
    }

    Component.onCompleted: {
        root._assert(typeof SettingsService.data.systemMonitor.enabled === "boolean",
            "systemMonitor.enabled should exist in settings schema")
        root._assert(SettingsService.data.systemMonitor.enabled === true,
            "systemMonitor.enabled should default to true")
        root._assert(typeof SettingsService.data.systemMonitor.hoverReveal === "boolean",
            "systemMonitor.hoverReveal should exist in settings schema")
        root._assert(SettingsService.data.systemMonitor.hoverReveal === true,
            "systemMonitor.hoverReveal should default to true")
        root._assert(typeof SettingsService.data.systemMonitor.panelEnabled === "boolean",
            "systemMonitor.panelEnabled should exist in settings schema")
        root._assert(SettingsService.data.systemMonitor.panelEnabled === true,
            "systemMonitor.panelEnabled should default to true")
        root._assert(typeof SettingsService.data.systemMonitor.flashEnabled === "boolean",
            "systemMonitor.flashEnabled should exist in settings schema")
        root._assert(SettingsService.data.systemMonitor.flashEnabled === true,
            "systemMonitor.flashEnabled should default to true")
        root._assert(Array.isArray(SettingsService.data.systemMonitor.pinnedMetrics),
            "systemMonitor.pinnedMetrics should exist as an array")
        root._assert(SettingsService.data.systemMonitor.pinnedMetrics.length === 3,
            "systemMonitor.pinnedMetrics should expose three default metrics")
        root._assert(SettingsService.data.systemMonitor.pinnedMetrics[0] === "cpu",
            "systemMonitor.pinnedMetrics should start with cpu")
        root._assert(SettingsService.data.systemMonitor.pinnedMetrics[1] === "memory",
            "systemMonitor.pinnedMetrics should include memory")
        root._assert(SettingsService.data.systemMonitor.pinnedMetrics[2] === "temperature",
            "systemMonitor.pinnedMetrics should include temperature")
        root._assert(typeof SettingsService.data.systemMonitor.showVolume === "boolean",
            "systemMonitor.showVolume should exist in settings schema")
        root._assert(SettingsService.data.systemMonitor.showVolume === true,
            "systemMonitor.showVolume should default to true")
        root._assert(typeof SettingsService.data.systemMonitor.showBrightness === "boolean",
            "systemMonitor.showBrightness should exist in settings schema")
        root._assert(SettingsService.data.systemMonitor.showBrightness === true,
            "systemMonitor.showBrightness should default to true")
        root._assert(typeof SettingsService.data.systemMonitor.showMicrophone === "boolean",
            "systemMonitor.showMicrophone should exist in settings schema")
        root._assert(SettingsService.data.systemMonitor.showMicrophone === true,
            "systemMonitor.showMicrophone should default to true")
        root._assert(SettingsService.data.systemMonitor.warningCpuPercent === 85,
            "systemMonitor.warningCpuPercent should default to 85")
        root._assert(SettingsService.data.systemMonitor.warningMemoryPercent === 85,
            "systemMonitor.warningMemoryPercent should default to 85")
        root._assert(SettingsService.data.systemMonitor.warningTempC === 75,
            "systemMonitor.warningTempC should default to 75")
        root._assert(SettingsService.data.systemMonitor.criticalTempC === 90,
            "systemMonitor.criticalTempC should default to 90")
        root._assert(typeof SettingsService.data.systemMonitor.superIslandEscalation === "boolean",
            "systemMonitor.superIslandEscalation should exist in settings schema")
        root._assert(SettingsService.data.systemMonitor.superIslandEscalation === true,
            "systemMonitor.superIslandEscalation should default to true")

        console.log("SystemMonitorSettings smoke test passed")
        Qt.callLater(Qt.quit)
    }
}
