import Quickshell
import QtQuick
import qs.services

// Smoke harness for SystemMetricsService snapshot exposure and stale availability regression coverage.
ShellRoot {
    id: root

    function _assert(condition, message) {
        if (!condition)
            throw new Error(message)
    }

    function _resetSnapshotForPartialRegression() {
        SystemMetricsService._clearSnapshotOverride()
        SystemMetricsService._snapshot = SystemMetricsService._normalizedSnapshot({})
    }

    Component.onCompleted: {
        root._assert(typeof SystemMetricsService.available === "boolean",
            "SystemMetricsService should expose available as a boolean property")
        root._assert(typeof SystemMetricsService.cpuUsage === "number",
            "SystemMetricsService should expose cpuUsage as a numeric property")
        root._assert(typeof SystemMetricsService.memoryUsage === "number",
            "SystemMetricsService should expose memoryUsage as a numeric property")
        root._assert(typeof SystemMetricsService.temperatureC === "number",
            "SystemMetricsService should expose temperatureC as a numeric property")
        root._assert(typeof SystemMetricsService.temperatureAvailable === "boolean",
            "SystemMetricsService should expose temperatureAvailable as a boolean property")
        root._assert(typeof SystemMetricsService.metricsSnapshot === "object",
            "SystemMetricsService should expose metricsSnapshot as an object snapshot")
        root._assert(typeof SystemMetricsService._setSnapshotOverride === "function",
            "SystemMetricsService should expose _setSnapshotOverride() for smoke coverage")
        root._assert(typeof SystemMetricsService._setPartialSnapshot === "function",
            "SystemMetricsService should expose _setPartialSnapshot() for partial snapshot updates")

        const snapshot = {
            available: true,
            cpuUsage: 0.42,
            memoryUsage: 0.73,
            temperatureC: 61.5,
            temperatureAvailable: true
        }

        SystemMetricsService._setSnapshotOverride(snapshot)

        root._assert(Math.abs(SystemMetricsService.cpuUsage - 0.42) < 0.001,
            "SystemMetricsService should surface cpuUsage from the override snapshot")
        root._assert(Math.abs(SystemMetricsService.memoryUsage - 0.73) < 0.001,
            "SystemMetricsService should surface memoryUsage from the override snapshot")
        root._assert(Math.abs(SystemMetricsService.temperatureC - 61.5) < 0.001,
            "SystemMetricsService should surface temperatureC from the override snapshot")
        root._assert(SystemMetricsService.temperatureAvailable === true,
            "SystemMetricsService should surface temperatureAvailable from the override snapshot")
        root._assert(SystemMetricsService.available === true,
            "SystemMetricsService should surface available from the override snapshot")
        root._assert(SystemMetricsService.metricsSnapshot.available === true,
            "SystemMetricsService should include available inside metricsSnapshot")
        root._assert(Math.abs(SystemMetricsService.metricsSnapshot.cpuUsage - 0.42) < 0.001,
            "SystemMetricsService should include cpuUsage inside metricsSnapshot")
        root._assert(Math.abs(SystemMetricsService.metricsSnapshot.memoryUsage - 0.73) < 0.001,
            "SystemMetricsService should include memoryUsage inside metricsSnapshot")
        root._assert(Math.abs(SystemMetricsService.metricsSnapshot.temperatureC - 61.5) < 0.001,
            "SystemMetricsService should include temperatureC inside metricsSnapshot")
        root._assert(SystemMetricsService.metricsSnapshot.temperatureAvailable === true,
            "SystemMetricsService should include temperatureAvailable inside metricsSnapshot")
        root._assert(typeof SystemMetricsService.cpuLabel === "string"
                && SystemMetricsService.cpuLabel !== "",
            "SystemMetricsService should expose a non-empty CPU usage label")
        root._assert(typeof SystemMetricsService.memoryLabel === "string"
                && SystemMetricsService.memoryLabel !== "",
            "SystemMetricsService should expose a non-empty memory usage label")
        root._assert(typeof SystemMetricsService.temperatureLabel === "string"
                && SystemMetricsService.temperatureLabel !== "",
            "SystemMetricsService should expose a non-empty temperature label")
        root._assert(SystemMetricsService.metricsSnapshot.cpuUsage === snapshot.cpuUsage,
            "SystemMetricsService should preserve the override CPU value in metricsSnapshot")

        root._resetSnapshotForPartialRegression()
        SystemMetricsService._setPartialSnapshot({
            cpuAvailable: true,
            cpuUsage: 0.34
        })

        root._assert(SystemMetricsService.cpuAvailable === true,
            "SystemMetricsService should mark CPU availability true after a later partial snapshot")
        root._assert(SystemMetricsService.available === true,
            "SystemMetricsService should derive available from later partial snapshots when CPU availability becomes true")

        root._resetSnapshotForPartialRegression()
        SystemMetricsService._setPartialSnapshot({
            memoryAvailable: true,
            memoryUsage: 0.58
        })

        root._assert(SystemMetricsService.memoryAvailable === true,
            "SystemMetricsService should mark memory availability true after a later partial snapshot")
        root._assert(SystemMetricsService.available === true,
            "SystemMetricsService should derive available from later partial snapshots when memory availability becomes true")

        root._resetSnapshotForPartialRegression()
        SystemMetricsService._setPartialSnapshot({
            temperatureAvailable: true,
            temperatureC: 67
        })

        root._assert(SystemMetricsService.temperatureAvailable === true,
            "SystemMetricsService should mark temperature availability true after a later partial snapshot")
        root._assert(SystemMetricsService.available === true,
            "SystemMetricsService should derive available from later partial snapshots when temperature availability becomes true")

        console.log("SystemMetricsService smoke test passed")
        Qt.callLater(Qt.quit)
    }
}
