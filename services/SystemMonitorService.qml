pragma Singleton

import Quickshell
import QtQuick
import qs.services

// Aggregates widget-facing system monitor state from metrics, audio, brightness, and alert escalation.
Singleton {
    id: root

    readonly property var _allMetricEntries: root._buildAllMetricEntries()
    readonly property var metrics: root._buildPinnedMetrics()
    readonly property string highestSeverity: root._deriveHighestSeverity(root.metrics)
    readonly property real volumeLevel: AudioDeviceService.volumeLevel
    readonly property bool volumeMuted: AudioDeviceService.volumeMuted
    readonly property bool microphoneMuted: AudioDeviceService.microphoneMuted
    readonly property real brightnessLevel: BrightnessService.level
    readonly property var flashEvent: root._flashOverride !== undefined
        ? (root._flashOverride || ({}))
        : (root.flashVisible ? root._activeFlashEvent : ({}))
    readonly property bool flashVisible: root._flashOverride !== undefined
        ? !!(root._flashOverride && root._flashOverride.id)
        : root._isFlashVisible()

    property bool panelOpen: false

    property var _activeFlashEvent: null
    property var _pendingFlashEvent: null
    property var _flashOverride: undefined
    property string _lastDerivedAlertSignature: ""
    property string _lastEscalationSignature: ""
    property string _lastEscalationId: ""

    function _settings() {
        return SettingsService.data ? (SettingsService.data.systemMonitor || null) : null
    }

    function _isPanelEnabled() {
        const settings = root._settings()
        return !!(settings && settings.panelEnabled)
    }

    function _isFlashVisible() {
        const settings = root._settings()
        return !!(settings && settings.flashEnabled
            && root._activeFlashEvent
            && root._activeFlashEvent.id)
    }

    function togglePanel() {
        if (!root._isPanelEnabled()) {
            root.panelOpen = false
            return
        }

        root.panelOpen = !root.panelOpen
    }

    function openPanel() {
        if (!root._isPanelEnabled()) {
            root.panelOpen = false
            return
        }

        root.panelOpen = true
    }

    function closePanel() {
        root.panelOpen = false
    }

    function setVolumeLevel(level) {
        AudioDeviceService.setVolumeLevel(level)
    }

    function setBrightnessLevel(level) {
        BrightnessService.setLevel(level)
    }

    function toggleMicrophoneMute() {
        AudioDeviceService.toggleMicrophoneMute()
    }

    function acknowledgeFlash() {
        if (root._flashOverride !== undefined) {
            root._flashOverride = null
            return
        }

        root._activeFlashEvent = null
        root._pendingFlashEvent = null
    }

    function _setFlashOverride(event) {
        root._flashOverride = event ? root._cloneEvent(event) : null
    }

    function _clearFlashOverride() {
        root._flashOverride = undefined
    }

    function _canonicalMetricKeys() {
        return ["cpu", "memory", "temperature"]
    }

    function _metricEntry(key, title, available, severity, value, displayValue) {
        return {
            key: key,
            title: title,
            available: !!available,
            severity: severity,
            value: value,
            displayValue: displayValue || ""
        }
    }

    function _buildAllMetricEntries() {
        const snapshot = SystemMetricsService.metricsSnapshot || {}

        return [
            root._metricEntry(
                "cpu",
                "CPU",
                snapshot.cpuAvailable,
                root._severityForCpu(snapshot.cpuAvailable, snapshot.cpuUsage),
                Number(snapshot.cpuUsage) || 0,
                snapshot.cpuLabel || "CPU --"
            ),
            root._metricEntry(
                "memory",
                "Memory",
                snapshot.memoryAvailable,
                root._severityForMemory(snapshot.memoryAvailable, snapshot.memoryUsage),
                Number(snapshot.memoryUsage) || 0,
                snapshot.memoryLabel || "MEM --"
            ),
            root._metricEntry(
                "temperature",
                "Temperature",
                snapshot.temperatureAvailable,
                root._severityForTemperature(snapshot.temperatureAvailable, snapshot.temperatureC),
                Number(snapshot.temperatureC) || 0,
                snapshot.temperatureLabel || "TEMP --"
            )
        ]
    }

    function _buildPinnedMetrics() {
        const settings = root._settings()
        const preferredKeys = []
        const seen = {}
        const pinned = settings && Array.isArray(settings.pinnedMetrics) ? settings.pinnedMetrics : []
        const canonicalKeys = root._canonicalMetricKeys()

        for (let index = 0; index < pinned.length; index++) {
            const key = pinned[index]
            if (canonicalKeys.indexOf(key) === -1 || seen[key])
                continue

            seen[key] = true
            preferredKeys.push(key)
        }

        for (let canonicalIndex = 0; canonicalIndex < canonicalKeys.length; canonicalIndex++) {
            const fallbackKey = canonicalKeys[canonicalIndex]
            if (seen[fallbackKey])
                continue

            preferredKeys.push(fallbackKey)
        }

        const orderedEntries = []
        for (let preferredIndex = 0; preferredIndex < preferredKeys.length; preferredIndex++) {
            const preferredKey = preferredKeys[preferredIndex]
            const entry = root._metricByKey(root._allMetricEntries, preferredKey)
            if (entry)
                orderedEntries.push(entry)
        }

        const availableEntries = orderedEntries.filter((entry) => entry.available)
        const unavailableEntries = orderedEntries.filter((entry) => !entry.available)
        return availableEntries.concat(unavailableEntries).slice(0, 3)
    }

    function _metricByKey(entries, key) {
        for (let index = 0; index < entries.length; index++) {
            if (entries[index].key === key)
                return entries[index]
        }

        return null
    }

    function _severityForCpu(available, usage) {
        if (!available)
            return "normal"

        const settings = root._settings()
        if (!settings)
            return "normal"

        return (Number(usage) || 0) * 100 >= settings.warningCpuPercent ? "warning" : "normal"
    }

    function _severityForMemory(available, usage) {
        if (!available)
            return "normal"

        const settings = root._settings()
        if (!settings)
            return "normal"

        return (Number(usage) || 0) * 100 >= settings.warningMemoryPercent ? "warning" : "normal"
    }

    function _severityForTemperature(available, temperatureC) {
        if (!available)
            return "normal"

        const settings = root._settings()
        if (!settings)
            return "normal"

        const numericTemperature = Number(temperatureC) || 0
        if (numericTemperature >= settings.criticalTempC)
            return "critical"
        if (numericTemperature >= settings.warningTempC)
            return "warning"
        return "normal"
    }

    function _severityRank(severity) {
        if (severity === "critical")
            return 2
        if (severity === "warning")
            return 1
        return 0
    }

    function _deriveHighestSeverity(entries) {
        let highest = "normal"

        for (let index = 0; index < entries.length; index++) {
            if (root._severityRank(entries[index].severity) > root._severityRank(highest))
                highest = entries[index].severity
        }

        return highest
    }

    function _topAlertMetric() {
        let winner = null

        for (let index = 0; index < root.metrics.length; index++) {
            const entry = root.metrics[index]
            if (!entry.available)
                continue

            if (!winner || root._severityRank(entry.severity) > root._severityRank(winner.severity))
                winner = entry
        }

        if (!winner || winner.severity === "normal")
            return null

        return winner
    }

    function _alertSignature(metric) {
        if (!metric)
            return ""

        return [metric.key, metric.severity].join("|")
    }

    function _buildAlertEvent(metric) {
        if (!metric)
            return null

        return {
            id: "system-monitor:" + metric.key + ":" + metric.severity,
            type: "system-monitor",
            groupKey: "system-monitor:" + metric.key,
            priority: metric.severity === "critical" ? "critical" : "important",
            title: metric.title,
            subtitle: metric.displayValue,
            metricKey: metric.key,
            severity: metric.severity
        }
    }

    function _cloneEvent(event) {
        const clone = {}
        for (let key in event)
            clone[key] = event[key]
        return clone
    }

    function _enqueueFlashEvent(event) {
        const normalizedEvent = root._cloneEvent(event)
        if (!root._activeFlashEvent || !root._activeFlashEvent.id) {
            root._activeFlashEvent = normalizedEvent
            root._pendingFlashEvent = null
            return
        }

        root._pendingFlashEvent = normalizedEvent
    }

    function _clearEscalation() {
        if (root._lastEscalationId)
            SuperIslandService.clearEvent(root._lastEscalationId)

        root._lastEscalationId = ""
        root._lastEscalationSignature = ""
    }

    function _reconcileAlerts() {
        const settings = root._settings()
        if (!settings) {
            root._lastDerivedAlertSignature = ""
            root._clearEscalation()
            return
        }

        const metric = root._topAlertMetric()
        const signature = root._alertSignature(metric)

        if (signature === "") {
            root._lastDerivedAlertSignature = ""
            root._clearEscalation()
            return
        }

        if (signature !== root._lastDerivedAlertSignature) {
            root._lastDerivedAlertSignature = signature
            if (settings.flashEnabled)
                root._enqueueFlashEvent(root._buildAlertEvent(metric))
        }

        if (metric.severity === "critical" && settings.superIslandEscalation) {
            if (signature === root._lastEscalationSignature)
                return

            const event = root._buildAlertEvent(metric)
            root._lastEscalationSignature = signature
            root._lastEscalationId = event.id
            SuperIslandService.replaceEvent("system-monitor:critical", event)
            return
        }

        root._clearEscalation()
    }

    Component.onCompleted: root._reconcileAlerts()

    Connections {
        target: SystemMetricsService

        function onAvailableChanged() { root._reconcileAlerts() }
        function onCpuAvailableChanged() { root._reconcileAlerts() }
        function onCpuUsageChanged() { root._reconcileAlerts() }
        function onMemoryAvailableChanged() { root._reconcileAlerts() }
        function onMemoryUsageChanged() { root._reconcileAlerts() }
        function onTemperatureAvailableChanged() { root._reconcileAlerts() }
        function onTemperatureCChanged() { root._reconcileAlerts() }
    }

    // Connections {
    //     target: SettingsService.data ? SettingsService.data.systemMonitor : null

    //     function onPinnedMetricsChanged() { root._reconcileAlerts() }
    //     function onWarningCpuPercentChanged() { root._reconcileAlerts() }
    //     function onWarningMemoryPercentChanged() { root._reconcileAlerts() }
    //     function onWarningTempCChanged() { root._reconcileAlerts() }
    //     function onCriticalTempCChanged() { root._reconcileAlerts() }
    //     function onFlashEnabledChanged() { root._reconcileAlerts() }
    //     function onSuperIslandEscalationChanged() { root._reconcileAlerts() }
    //     function onPanelEnabledChanged() {
    //         if (!root._isPanelEnabled())
    //             root.panelOpen = false
    //     }
    // }
}
