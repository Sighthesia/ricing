pragma Singleton

import Quickshell
import QtQuick
import qs.services

// Aggregates widget-facing system monitor state from metrics, audio, brightness, and alert escalation.
Singleton {
    id: root

    readonly property real volumeBrightnessStep: 0.05
    readonly property real temperatureProgressMinC: 30
    readonly property real temperatureProgressMaxC: 100

    readonly property var persistentMetrics: root._buildPersistentMetrics()
    readonly property var expandedMetrics: root._buildExpandedMetrics()
    readonly property var allMetrics: root.persistentMetrics.concat(root.expandedMetrics)
    // Legacy alias for older widgets; new code should prefer persistentMetrics or allMetrics explicitly.
    readonly property var metrics: root.persistentMetrics
    readonly property string highestSeverity: root._deriveHighestSeverity(root.persistentMetrics)
    readonly property real volumeLevel: AudioDeviceService.volumeLevel
    readonly property bool volumeMuted: AudioDeviceService.volumeMuted
    readonly property bool microphoneMuted: AudioDeviceService.microphoneMuted
    readonly property real brightnessLevel: BrightnessService.level
    readonly property var pinnedMetrics: root._settings() ? root._settings().pinnedMetrics : []
    readonly property bool showVolume: !!(root._settings() && root._settings().showVolume)
    readonly property bool showBrightness: !!(root._settings() && root._settings().showBrightness)
    readonly property bool showMicrophone: !!(root._settings() && root._settings().showMicrophone)
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

    function adjustVolumeByStep(step) {
        const direction = root._stepDirection(step)
        if (direction === 0)
            return

        root.setVolumeLevel(root.volumeLevel + direction * root.volumeBrightnessStep)
    }

    function adjustBrightnessByStep(step) {
        const direction = root._stepDirection(step)
        if (direction === 0)
            return

        const currentLevel = BrightnessService.level
        const targetLevel = Math.max(0, Math.min(1, currentLevel + direction * root.volumeBrightnessStep))

        BrightnessService.setLevel(targetLevel)
    }

    function toggleMicrophoneMute() {
        AudioDeviceService.toggleMicrophoneMute()
    }

    function acknowledgeFlash() {
        if (root._flashOverride !== undefined) {
            // Exit override mode cleanly so normal flash lifecycle resumes.
            root._clearFlashOverride()
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

    function _metricEntry(key, title, icon, value, normalizedProgress, displayText, severity, available, persistent, interactive) {
        return {
            key: key,
            title: title,
            icon: icon,
            value: value,
            normalizedProgress: normalizedProgress,
            displayText: displayText,
            displayValue: displayText,
            severity: severity,
            available: !!available,
            persistent: !!persistent,
            interactive: !!interactive
        }
    }

    function _buildPersistentMetrics() {
        const snapshot = SystemMetricsService.metricsSnapshot || {}

        return [
            root._metricEntry(
                "cpu",
                "CPU",
                "cpu",
                Number(snapshot.cpuUsage) || 0,
                root._normalizeProgress(snapshot.cpuUsage),
                snapshot.cpuLabel || "CPU --",
                root._severityForCpu(snapshot.cpuAvailable, snapshot.cpuUsage),
                snapshot.cpuAvailable,
                true,
                false
            ),
            root._metricEntry(
                "memory",
                "Memory",
                "memory",
                Number(snapshot.memoryUsage) || 0,
                root._normalizeProgress(snapshot.memoryUsage),
                snapshot.memoryLabel || "MEM --",
                root._severityForMemory(snapshot.memoryAvailable, snapshot.memoryUsage),
                snapshot.memoryAvailable,
                true,
                false
            ),
            root._metricEntry(
                "temperature",
                "Temperature",
                "temperature",
                Number(snapshot.temperatureC) || 0,
                root._temperatureProgress(snapshot.temperatureC),
                snapshot.temperatureLabel || "TEMP --",
                root._severityForTemperature(snapshot.temperatureAvailable, snapshot.temperatureC),
                snapshot.temperatureAvailable,
                true,
                false
            )
        ]
    }

    function _buildExpandedMetrics() {
        const audio = AudioDeviceService.audioSnapshot || {}
        const brightness = BrightnessService.brightnessSnapshot || {}
        const battery = BatteryService.batterySnapshot || {}

        return [
            root._metricEntry(
                "volume",
                "Volume",
                "volume",
                Number(audio.volumeLevel) || 0,
                root._normalizeProgress(audio.volumeLevel),
                audio.volumeMuted ? "VOL MUTE" : "VOL " + Math.round((Number(audio.volumeLevel) || 0) * 100) + "%",
                "normal",
                !!audio.sinkAvailable,
                false,
                true
            ),
            root._metricEntry(
                "brightness",
                "Brightness",
                "brightness",
                Number(brightness.level) || 0,
                root._normalizeProgress(brightness.level),
                brightness.available ? "BRIGHT " + Math.round((Number(brightness.level) || 0) * 100) + "%" : "BRIGHT --",
                "normal",
                !!brightness.available,
                false,
                true
            ),
            root._metricEntry(
                "battery",
                "Battery",
                "battery",
                Number(battery.level) || 0,
                root._normalizeProgress(battery.level),
                battery.available ? "BAT " + Math.round((Number(battery.level) || 0) * 100) + "%" : "BAT --",
                "normal",
                !!battery.available,
                false,
                false
            )
        ]
    }

    function _normalizeProgress(value) {
        const numericValue = Number(value)
        if (!Number.isFinite(numericValue))
            return 0

        return Math.max(0, Math.min(1, numericValue))
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

    function _temperatureProgress(temperatureC) {
        const numericTemperature = Number(temperatureC)
        if (!Number.isFinite(numericTemperature))
            return 0

        return Math.max(0, Math.min(1, (numericTemperature - root.temperatureProgressMinC)
            / (root.temperatureProgressMaxC - root.temperatureProgressMinC)))
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

    Connections {
        target: AudioDeviceService

        function onAudioStateChanged() { root._reconcileAlerts() }
    }

    Connections {
        target: BrightnessService

        function onBrightnessStateChanged() { root._reconcileAlerts() }
    }

    Connections {
        target: BatteryService

        function onBatteryStateChanged() { root._reconcileAlerts() }
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
