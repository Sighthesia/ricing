import Quickshell
import QtQuick
import qs.services
import "../../modules/bar/widgets" as BarWidgets

// Smoke harness for SuperSystemMonitorWidget service-backed rendering and severity visuals.
ShellRoot {
    id: root

    function _assert(condition, message) {
        if (!condition) {
            console.error("SuperSystemMonitorWidgetSmoke assertion failed:", message)
            throw new Error(message)
        }
    }

    function _setNormalSnapshot() {
        SystemMetricsService._setSnapshotOverride({
            available: true,
            cpuAvailable: true,
            cpuUsage: 0.13,
            memoryAvailable: true,
            memoryUsage: 0.41,
            temperatureAvailable: true,
            temperatureC: 54
        })
    }

    function _setCriticalSnapshot() {
        SystemMetricsService._setSnapshotOverride({
            available: true,
            cpuAvailable: true,
            cpuUsage: 0.91,
            memoryAvailable: true,
            memoryUsage: 0.88,
            temperatureAvailable: true,
            temperatureC: 96
        })
    }

    function _childArray(node) {
        if (!node)
            return []

        if (node.contentChildren !== undefined && node.contentChildren !== null)
            return node.contentChildren
        if (node.children !== undefined && node.children !== null)
            return node.children
        if (node.data !== undefined && node.data !== null)
            return node.data

        return []
    }

    function _collectObjects(object, objects, visited) {
        if (!object || visited.indexOf(object) !== -1)
            return

        visited.push(object)
        objects.push(object)

        const children = root._childArray(object)
        for (let index = 0; index < children.length; index++)
            root._collectObjects(children[index], objects, visited)
    }

    function _allObjects(object) {
        const objects = []
        root._collectObjects(object, objects, [])
        return objects
    }

    function _renderedText(object) {
        const parts = []
        const objects = root._allObjects(object)

        for (let index = 0; index < objects.length; index++) {
            const candidate = objects[index]
            if (typeof candidate.text === "string" && candidate.text !== "")
                parts.push(candidate.text)
        }

        return parts.join(" | ")
    }

    function _colorSignature(object) {
        const parts = []
        const objects = root._allObjects(object)

        for (let index = 0; index < objects.length; index++) {
            const candidate = objects[index]
            if (candidate.color !== undefined)
                parts.push(String(candidate.color))
        }

        return parts.join("|")
    }

    function _runSeverityAssertion(normalVisualSignature) {
        root._assert(SystemMonitorService.highestSeverity === "critical",
            "SystemMonitorService should reach critical severity for the smoke override")

        const criticalVisualSignature = root._colorSignature(widget)
        root._assert(normalVisualSignature !== criticalVisualSignature,
            "SuperSystemMonitorWidget should change a visual color signature when SystemMonitorService.highestSeverity changes")

        console.log("SuperSystemMonitorWidget smoke test passed")
        Qt.callLater(Qt.quit)
    }

    function _runAssertions() {
        const renderedText = root._renderedText(widget)
        console.log("SuperSystemMonitorWidgetSmoke renderedText:", renderedText)
        console.log("SuperSystemMonitorWidgetSmoke expected cpuLabel:", SystemMetricsService.cpuLabel)
        console.log("SuperSystemMonitorWidgetSmoke expected memoryLabel:", SystemMetricsService.memoryLabel)
        console.log("SuperSystemMonitorWidgetSmoke expected temperatureLabel:", SystemMetricsService.temperatureLabel)

        root._assert(renderedText.indexOf(SystemMetricsService.cpuLabel) !== -1,
            "SuperSystemMonitorWidget should render the CPU label from SystemMonitorService metrics instead of placeholder text")
        root._assert(renderedText.indexOf(SystemMetricsService.memoryLabel) !== -1
                || renderedText.indexOf(SystemMetricsService.temperatureLabel) !== -1,
            "SuperSystemMonitorWidget should render memory or temperature labels from SystemMonitorService metrics")

        const normalVisualSignature = root._colorSignature(widget)
        root._assert(SystemMonitorService.highestSeverity === "normal",
            "SystemMonitorService should start at normal severity for the baseline override")

        root._setCriticalSnapshot()
        Qt.callLater(function() {
            root._runSeverityAssertion(normalVisualSignature)
        })
    }

    BarWidgets.SuperSystemMonitorWidget {
        id: widget
        visible: false
    }

     Component.onCompleted: {
         SettingsService.data.systemMonitor.enabled = true
         SettingsService.data.systemMonitor.pinnedMetrics = ["cpu", "memory", "temperature"]
         SettingsService.data.systemMonitor.showVolume = true
         SettingsService.data.systemMonitor.showBrightness = true
         SettingsService.data.systemMonitor.showMicrophone = true
         SettingsService.data.systemMonitor.warningCpuPercent = 85
         SettingsService.data.systemMonitor.warningMemoryPercent = 85
         SettingsService.data.systemMonitor.warningTempC = 75
         SettingsService.data.systemMonitor.criticalTempC = 90

         root._setNormalSnapshot()
         Qt.callLater(root._runAssertions)
     }
}
