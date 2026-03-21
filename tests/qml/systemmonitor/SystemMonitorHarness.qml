import Quickshell
import QtQuick
import qs.config
import "../../../modules/bar/widgets/systemmonitor" as MonitorParts
import "../../../modules/bar/widgets" as BarWidgets
import qs.services

Item {
    id: root

    function expect(actual, expected, message) {
        if (actual !== expected)
            throw new Error(message + ": expected " + expected + ", got " + actual)
    }

    Component {
        id: gaugeComponent

        MonitorParts.SystemMonitorGauge { }
    }

    Component {
        id: widgetComponent

        BarWidgets.SuperSystemMonitorWidget { }
    }

    function createSizedGauge(metric) {
        const gauge = gaugeComponent.createObject(root, { metric: metric })
        gauge.width = gauge.implicitWidth
        gauge.height = gauge.implicitHeight
        return gauge
    }

    function createWidget() {
        const widget = widgetComponent.createObject(root)
        return widget
    }

    function destroyWidget(widget) {
        if (widget)
            widget.destroy()
    }

    function cleanupGauges(gauges) {
        for (let index = 0; index < gauges.length; index++) {
            const gauge = gauges[index]
            if (gauge)
                gauge.destroy()
        }
    }

    function wait(interval, callback) {
        const timer = Qt.createQmlObject(
            'import QtQuick; Timer { repeat: false }',
            root,
            "systemMonitorHarnessWaitTimer"
        )
        timer.interval = interval
        timer.triggered.connect(() => {
            timer.destroy()
            callback()
        })
        timer.start()
    }

    function _snapshotSystemMonitorSettings() {
        const settings = SettingsService.data.systemMonitor
        return {
            enabled: settings.enabled,
            hoverReveal: settings.hoverReveal,
            panelEnabled: settings.panelEnabled,
            flashEnabled: settings.flashEnabled,
            pinnedMetrics: settings.pinnedMetrics.slice(),
            showVolume: settings.showVolume,
            showBrightness: settings.showBrightness,
            showMicrophone: settings.showMicrophone,
            warningCpuPercent: settings.warningCpuPercent,
            warningMemoryPercent: settings.warningMemoryPercent,
            warningTempC: settings.warningTempC,
            criticalTempC: settings.criticalTempC,
            superIslandEscalation: settings.superIslandEscalation
        }
    }

    function _restoreSystemMonitorSettings(snapshot) {
        const settings = SettingsService.data.systemMonitor
        settings.enabled = snapshot.enabled
        settings.hoverReveal = snapshot.hoverReveal
        settings.panelEnabled = snapshot.panelEnabled
        settings.flashEnabled = snapshot.flashEnabled
        settings.pinnedMetrics = snapshot.pinnedMetrics.slice()
        settings.showVolume = snapshot.showVolume
        settings.showBrightness = snapshot.showBrightness
        settings.showMicrophone = snapshot.showMicrophone
        settings.warningCpuPercent = snapshot.warningCpuPercent
        settings.warningMemoryPercent = snapshot.warningMemoryPercent
        settings.warningTempC = snapshot.warningTempC
        settings.criticalTempC = snapshot.criticalTempC
        settings.superIslandEscalation = snapshot.superIslandEscalation
    }

    function withSystemMonitorSettings(overrides, callback) {
        const snapshot = _snapshotSystemMonitorSettings()
        try {
            const settings = SettingsService.data.systemMonitor
            if (overrides.enabled !== undefined)
                settings.enabled = overrides.enabled
            if (overrides.hoverReveal !== undefined)
                settings.hoverReveal = overrides.hoverReveal
            if (overrides.panelEnabled !== undefined)
                settings.panelEnabled = overrides.panelEnabled
            if (overrides.showVolume !== undefined)
                settings.showVolume = overrides.showVolume
            if (overrides.showBrightness !== undefined)
                settings.showBrightness = overrides.showBrightness
            if (overrides.showMicrophone !== undefined)
                settings.showMicrophone = overrides.showMicrophone
            callback()
        } finally {
            _restoreSystemMonitorSettings(snapshot)
        }
    }

    function _collectByPrefix(node, prefix, results, inheritedVisible) {
        if (!node || !results)
            return

        const isVisible = inheritedVisible !== false && node.visible !== false

        if (isVisible && typeof node.objectName === "string" && node.objectName.indexOf(prefix) === 0)
            results.push(node)

        const children = node.children || []
        for (let index = 0; index < children.length; index++)
            _collectByPrefix(children[index], prefix, results, isVisible)
    }

    function _collectVisibleByPrefix(node, prefix) {
        const results = []
        _collectByPrefix(node, prefix, results, true)
        return results.filter((item) => item.visible !== false)
    }

    function _findByObjectName(node, objectName) {
        if (!node)
            return null

        if (node.objectName === objectName)
            return node

        const children = node.children || []
        for (let index = 0; index < children.length; index++) {
            const found = _findByObjectName(children[index], objectName)
            if (found)
                return found
        }

        return null
    }

    function withCleanOverrides(callback) {
        try {
            callback()
        } finally {
            SystemMetricsService._clearSnapshotOverride()
            AudioDeviceService._setStateOverride(null)
            BrightnessService._setStateOverride(null)
            BatteryService._setStateOverride(null)
            SystemMonitorService.closePanel()
            SystemMonitorService._clearFlashOverride()
            SystemMonitorService._activeFlashEvent = null
            SystemMonitorService._pendingFlashEvent = null
            SystemMonitorService.panelOpen = false
        }
    }

    function mode() {
        const args = typeof Quickshell.args === "undefined" || Quickshell.args === null ? [] : Quickshell.args
        if (args.length > 0)
            return args[0]

        const envMode = Quickshell.env("SYSTEM_MONITOR_HARNESS_MODE")
        return envMode && envMode !== "" ? envMode : "battery-contract"
    }

    function runBatteryContract() {
        withCleanOverrides(() => {
            const liveState = { available: true, level: 0.64, charging: true, status: "charging" }
            const missingState = { available: false, level: 0.93, charging: false, status: "missing" }

            BatteryService._setStateOverride(liveState)
            expect(BatteryService.available, true, "live override should mark the battery available")
            expect(BatteryService.level, 0.64, "live override should expose the configured level")
            expect(BatteryService.charging, true, "live override should preserve charging state")
            expect(BatteryService.percentLabel, "64%", "live override should round percent label")
            expect(BatteryService.status, "charging", "live override should preserve charging status")

            BatteryService._setStateOverride(missingState)
            expect(BatteryService.available, false, "missing override should remain unavailable")
            expect(BatteryService.level, 0, "missing override should expose zero level")
            expect(BatteryService.status, "missing", "missing override should expose missing status")
            expect(BatteryService.percentLabel, "--", "missing override should hide the percent label")
        })

        Qt.callLater(Qt.quit)
    }

    function runServiceContract() {
        withCleanOverrides(() => {
            SystemMetricsService._setSnapshotOverride({
                cpuAvailable: true,
                cpuUsage: 0.92,
                memoryAvailable: true,
                memoryUsage: 0.47,
                temperatureAvailable: true,
                temperatureC: 88
            })
            AudioDeviceService._setStateOverride({
                volumeLevel: 0.35,
                volumeMuted: false,
                microphoneMuted: false,
                sinkAvailable: true,
                sourceAvailable: true
            })
            BrightnessService._setStateOverride({
                available: true,
                level: 0.61
            })
            BatteryService._setStateOverride({
                available: true,
                level: 0.22,
                charging: false,
                status: "discharging"
            })

            expect(SystemMonitorService.persistentMetrics.length, 3, "persistent metrics should stay fixed at three entries")
            expect(SystemMonitorService.expandedMetrics.length, 3, "expanded metrics should stay fixed at three entries")
            expect(SystemMonitorService.persistentMetrics[0].key, "cpu", "persistent metrics should start with cpu")
            expect(SystemMonitorService.expandedMetrics[2].key, "battery", "expanded metrics should end with battery")
            expect(SystemMonitorService.highestSeverity, "warning", "temperature should stay warning below critical threshold")
            expect(SettingsService.data.systemMonitor.pinnedMetrics.length, 3, "legacy pinnedMetrics setting should remain available")
            expect(SettingsService.data.systemMonitor.showVolume, true, "legacy showVolume setting should remain available")
            expect(SettingsService.data.systemMonitor.showBrightness, true, "legacy showBrightness setting should remain available")
            expect(SettingsService.data.systemMonitor.showMicrophone, true, "legacy showMicrophone setting should remain available")

            SystemMonitorService.setVolumeLevel(0.4)
            SystemMonitorService.adjustVolumeByStep(1)
            expect(SystemMonitorService.volumeLevel, 0.45, "volume should step up by 5 percent from a non-zero baseline")
            SystemMonitorService.adjustVolumeByStep(-1)
            expect(SystemMonitorService.volumeLevel, 0.4, "volume should step down by 5 percent from a non-zero baseline")
            
            SystemMonitorService.setVolumeLevel(0)
            SystemMonitorService.adjustVolumeByStep(-1)
            expect(SystemMonitorService.volumeLevel, 0, "volume should clamp at lower bound")
            SystemMonitorService.adjustVolumeByStep(1)
            expect(SystemMonitorService.volumeLevel, 0.05, "volume should step upward by 5 percent from lower bound")
            for (let volumeStep = 0; volumeStep < 40; volumeStep++)
                SystemMonitorService.adjustVolumeByStep(1)
            expect(SystemMonitorService.volumeLevel, 1, "volume should clamp at upper bound")

            SystemMonitorService.setBrightnessLevel(0.6)
            SystemMonitorService.adjustBrightnessByStep(1)
            expect(SystemMonitorService.brightnessLevel, 0.65, "brightness should step up by 5 percent from a non-zero baseline")
            SystemMonitorService.adjustBrightnessByStep(-1)
            expect(SystemMonitorService.brightnessLevel, 0.6, "brightness should step down by 5 percent from a non-zero baseline")

            expect(BrightnessService._stepCommandToken(1, 5), "100%+", "brightness step command should use brightnessctl's positive suffix")
            expect(BrightnessService._stepCommandToken(-1, 5), "1%-", "brightness step command should use brightnessctl's negative suffix")

            const parsedBrightness = BrightnessService._parseBrightnessctl("amdgpu_bl1,backlight,25000,38%,65535")
            expect(parsedBrightness.available, true, "brightnessctl parse should mark parsed output available")
            expect(Math.abs(parsedBrightness.level - (25000 / 65535)) < 0.0001, true, "brightnessctl parse should read the current/max fields in machine output")

            SystemMonitorService.adjustBrightnessByStep(120)
            expect(SystemMonitorService.brightnessLevel, 0.65, "brightness should treat large positive wheel deltas as a single step")
            SystemMonitorService.adjustBrightnessByStep(-240)
            expect(SystemMonitorService.brightnessLevel, 0.6, "brightness should treat large negative wheel deltas as a single step")

            SystemMonitorService.setBrightnessLevel(0)
            SystemMonitorService.adjustBrightnessByStep(-1)
            expect(SystemMonitorService.brightnessLevel, 0, "brightness should clamp at lower bound")
            SystemMonitorService.adjustBrightnessByStep(1)
            expect(SystemMonitorService.brightnessLevel, 0.05, "brightness should step upward by 5 percent from lower bound")
            for (let brightnessStep = 0; brightnessStep < 40; brightnessStep++)
                SystemMonitorService.adjustBrightnessByStep(1)
            expect(SystemMonitorService.brightnessLevel, 1, "brightness should clamp at upper bound")
        })

        Qt.callLater(Qt.quit)
    }

    function runGaugeContract() {
        withCleanOverrides(() => {
            const gauges = []

            try {
                const warningMetric = {
                    key: "cpu",
                    title: "CPU",
                    icon: "cpu",
                    value: 0.82,
                    normalizedProgress: 1.25,
                    displayText: "CPU 82%",
                    severity: "warning",
                    available: true,
                    persistent: true,
                    interactive: false
                }
                const warningGauge = createSizedGauge(warningMetric)
                gauges.push(warningGauge)

                const criticalMetric = {
                    key: "temperature",
                    title: "Temperature",
                    icon: "temperature",
                    value: 0.97,
                    normalizedProgress: -0.2,
                    displayText: "TEMP 97C",
                    severity: "critical",
                    available: true,
                    persistent: true,
                    interactive: false
                }
                const criticalGauge = createSizedGauge(criticalMetric)
                gauges.push(criticalGauge)

                const unavailableMetric = {
                    key: "battery",
                    title: "Battery",
                    icon: "battery",
                    value: 0,
                    normalizedProgress: Number.NaN,
                    displayText: "BAT --",
                    severity: "normal",
                    available: false,
                    persistent: false,
                    interactive: false
                }
                const unavailableGauge = createSizedGauge(unavailableMetric)
                gauges.push(unavailableGauge)

                expect(warningGauge !== null, true, "warning gauge should instantiate")
                expect(warningGauge.normalizedProgress, 1, "warning metric should clamp progress to upper bound")
                expect(warningGauge.semanticColor, Colors.highlight, "warning metric should use highlight color")

                expect(criticalGauge !== null, true, "critical gauge should instantiate")
                expect(criticalGauge.normalizedProgress, 0, "critical metric should clamp progress to lower bound")
                expect(criticalGauge.semanticColor, Colors.destructive, "critical metric should use destructive color")

                expect(unavailableGauge !== null, true, "unavailable gauge should instantiate")
                expect(unavailableGauge.normalizedProgress, 0, "unavailable metric should clamp invalid progress to zero")
                expect(unavailableGauge.semanticColor, Colors.textMuted, "unavailable metric should use muted color")

                expect(unavailableGauge.interactive, false, "gauge should default to non-interactive")

                const warningIconOverlay = _findByObjectName(warningGauge, "systemMonitorGaugeIconOverlay")
                const criticalIconOverlay = _findByObjectName(criticalGauge, "systemMonitorGaugeIconOverlay")
                const unavailableIconOverlay = _findByObjectName(unavailableGauge, "systemMonitorGaugeIconOverlay")

                expect(warningIconOverlay !== null, true, "warning gauge should mount an icon overlay")
                expect(warningIconOverlay.color, Colors.highlight, "warning gauge icon should use the semantic highlight color")
                expect(criticalIconOverlay !== null, true, "critical gauge should mount an icon overlay")
                expect(criticalIconOverlay.color, Colors.destructive, "critical gauge icon should use the semantic destructive color")
                expect(unavailableIconOverlay !== null, true, "unavailable gauge should mount an icon overlay")
                expect(unavailableIconOverlay.color, Colors.textMuted, "unavailable gauge icon should use the muted color")

                let stepCount = 0
                unavailableGauge.stepRequested.connect((direction) => {
                    stepCount += direction
                })

                expect(unavailableGauge._wheelStep(0, 120), 0, "non-interactive gauge should ignore wheel input")
                expect(stepCount, 0, "non-interactive gauge should not emit wheel steps")

                unavailableGauge.interactive = true
                expect(unavailableGauge._wheelStep(0, 120), 1, "vertical wheel delta should map to step up")
                expect(unavailableGauge._wheelStep(240, 10), 1, "dominant horizontal delta should map to step up")
                expect(unavailableGauge._wheelStep(-120, 10), -1, "negative dominant axis delta should map to step down")
                expect(unavailableGauge._wheelStep(0, 0), 0, "zero wheel delta should be ignored")
                expect(stepCount, 1, "wheel steps should emit only for accepted input")

                expect(unavailableGauge._wheelStepAt(-1, 10, 0, 120), 0, "wheel input outside gauge bounds should be ignored")
                expect(stepCount, 1, "outside-bound wheel input should not emit steps")

                expect(unavailableGauge._wheelStepAt(1, 1, 0, 120), 1, "wheel input inside gauge bounds should be accepted")
                expect(stepCount, 2, "inside-bound wheel input should emit a step")
            } finally {
                cleanupGauges(gauges)
            }
        })

        Qt.callLater(Qt.quit)
    }

    function runWidgetCollapsed() {
        withCleanOverrides(() => {
            withSystemMonitorSettings({ enabled: true, hoverReveal: true }, () => {
                SystemMetricsService._setSnapshotOverride({
                    cpuAvailable: true,
                    cpuUsage: 0.42,
                    memoryAvailable: true,
                    memoryUsage: 0.37,
                    temperatureAvailable: true,
                    temperatureC: 61
                })
                AudioDeviceService._setStateOverride({
                    volumeLevel: 0.25,
                    volumeMuted: false,
                    microphoneMuted: false,
                    sinkAvailable: true,
                    sourceAvailable: true
                })
                BrightnessService._setStateOverride({
                    available: true,
                    level: 0.55
                })
                BatteryService._setStateOverride({
                    available: true,
                    level: 0.64,
                    charging: false,
                    status: "discharging"
                })

                const widget = createWidget()
                try {
                    expect(widget.width, widget.implicitWidth, "collapsed widget should keep width bound to implicitWidth")
                    expect(widget.implicitWidth > 0, true, "collapsed widget should reserve width")
                    expect(_collectVisibleByPrefix(widget, "systemMonitorGauge_").length, 3, "collapsed widget should keep only persistent gauges visible")
                    expect(_findByObjectName(widget, "systemMonitorExpandedRow").visible, false, "collapsed widget should keep the expanded group hidden")
                } finally {
                    destroyWidget(widget)
                }
            })
        })

        Qt.callLater(Qt.quit)
    }

    function runWidgetExpanded() {
        withCleanOverrides(() => {
            withSystemMonitorSettings({ enabled: true, hoverReveal: true }, () => {
                SystemMetricsService._setSnapshotOverride({
                    cpuAvailable: true,
                    cpuUsage: 0.91,
                    memoryAvailable: true,
                    memoryUsage: 0.74,
                    temperatureAvailable: true,
                    temperatureC: 89
                })
                AudioDeviceService._setStateOverride({
                    volumeLevel: 0.44,
                    volumeMuted: false,
                    microphoneMuted: false,
                    sinkAvailable: true,
                    sourceAvailable: true
                })
                BrightnessService._setStateOverride({
                    available: true,
                    level: 0.82
                })
                BatteryService._setStateOverride({
                    available: true,
                    level: 0.28,
                    charging: false,
                    status: "discharging"
                })

                const widget = createWidget()
                try {
                    const collapsedWidth = widget.width
                    expect(collapsedWidth, widget.implicitWidth, "expanded widget should start with width bound to implicitWidth")
                    widget._hovered = true
                    expect(widget.implicitWidth > 0, true, "expanded widget should reserve width")
                    expect(widget.width, widget.implicitWidth, "expanded widget should keep width owned by the transition")
                    expect(widget.width >= collapsedWidth, true, "hovering should not shrink the widget while it expands")
                    expect(_collectVisibleByPrefix(widget, "systemMonitorGauge_").length, 6, "expanded widget should show persistent trio and appended gauges")
                    const persistentRow = _findByObjectName(widget, "systemMonitorPersistentRow")
                    const expandedRow = _findByObjectName(widget, "systemMonitorExpandedRow")
                    expect(persistentRow !== null, true, "expanded widget should mount persistent row")
                    expect(expandedRow !== null, true, "expanded widget should mount expanded row")
                    expect(persistentRow.x < expandedRow.x, true, "expanded gauges should append to the right")
                } finally {
                    destroyWidget(widget)
                }
            })
        })

        Qt.callLater(Qt.quit)
    }

    function runWidgetNoBattery() {
        withCleanOverrides(() => {
            withSystemMonitorSettings({ enabled: true, hoverReveal: true }, () => {
                SystemMetricsService._setSnapshotOverride({
                    cpuAvailable: true,
                    cpuUsage: 0.33,
                    memoryAvailable: true,
                    memoryUsage: 0.48,
                    temperatureAvailable: true,
                    temperatureC: 57
                })
                AudioDeviceService._setStateOverride({
                    volumeLevel: 0.39,
                    volumeMuted: false,
                    microphoneMuted: false,
                    sinkAvailable: true,
                    sourceAvailable: true
                })
                BrightnessService._setStateOverride({
                    available: true,
                    level: 0.66
                })
                BatteryService._setStateOverride({
                    available: false,
                    level: 0,
                    charging: false,
                    status: "missing"
                })

                const widget = createWidget()
                try {
                    expect(widget.width, widget.implicitWidth, "battery-unavailable widget should keep width bound to implicitWidth")
                    widget._hovered = true
                    expect(_collectVisibleByPrefix(widget, "systemMonitorGauge_").length, 5, "battery-unavailable widget should skip the battery gauge without collapsing the row")
                    expect(_findByObjectName(widget, "systemMonitorGauge_battery") === null, true, "battery-unavailable widget should not mount the battery gauge")
                    expect(_findByObjectName(widget, "systemMonitorExpandedRow") !== null, true, "battery-unavailable widget should still mount the expanded row container")
                } finally {
                    destroyWidget(widget)
                }
            })
        })

        Qt.callLater(Qt.quit)
    }

    function runWidgetHoverDisabled() {
        withCleanOverrides(() => {
            withSystemMonitorSettings({ enabled: true, hoverReveal: false }, () => {
                SystemMetricsService._setSnapshotOverride({
                    cpuAvailable: true,
                    cpuUsage: 0.73,
                    memoryAvailable: true,
                    memoryUsage: 0.51,
                    temperatureAvailable: true,
                    temperatureC: 64
                })
                AudioDeviceService._setStateOverride({
                    volumeLevel: 0.7,
                    volumeMuted: false,
                    microphoneMuted: false,
                    sinkAvailable: true,
                    sourceAvailable: true
                })
                BrightnessService._setStateOverride({
                    available: true,
                    level: 0.91
                })
                BatteryService._setStateOverride({
                    available: true,
                    level: 0.11,
                    charging: false,
                    status: "discharging"
                })

                const widget = createWidget()
                try {
                    expect(widget.width, widget.implicitWidth, "hoverReveal=false widget should keep width bound to implicitWidth")
                    widget._hovered = true
                    expect(_collectVisibleByPrefix(widget, "systemMonitorGauge_").length, 3, "hoverReveal=false should keep the widget collapsed even while hovered")
                } finally {
                    destroyWidget(widget)
                }
            })
        })

        Qt.callLater(Qt.quit)
    }

    function runWidgetDisabled() {
        withCleanOverrides(() => {
            withSystemMonitorSettings({ enabled: false, hoverReveal: true }, () => {
                SystemMetricsService._setSnapshotOverride({
                    cpuAvailable: true,
                    cpuUsage: 0.2,
                    memoryAvailable: true,
                    memoryUsage: 0.4,
                    temperatureAvailable: true,
                    temperatureC: 48
                })
                AudioDeviceService._setStateOverride({
                    volumeLevel: 0.2,
                    volumeMuted: false,
                    microphoneMuted: false,
                    sinkAvailable: true,
                    sourceAvailable: true
                })
                BrightnessService._setStateOverride({
                    available: true,
                    level: 0.2
                })
                BatteryService._setStateOverride({
                    available: true,
                    level: 0.8,
                    charging: true,
                    status: "charging"
                })

                const widget = createWidget()
                try {
                    expect(widget.width, widget.implicitWidth, "disabled widget should keep width bound to implicitWidth")
                    expect(widget.visible, false, "disabled widget should not be visible")
                    expect(_collectVisibleByPrefix(widget, "systemMonitorGauge_").length, 0, "disabled widget should not mount any visible gauge surface")
                } finally {
                    destroyWidget(widget)
                }
            })
        })

        Qt.callLater(Qt.quit)
    }

    function runWidgetHoverHold() {
        withCleanOverrides(() => {
            withSystemMonitorSettings({ enabled: true, hoverReveal: true }, () => {
                SystemMetricsService._setSnapshotOverride({
                    cpuAvailable: true,
                    cpuUsage: 0.51,
                    memoryAvailable: true,
                    memoryUsage: 0.43,
                    temperatureAvailable: true,
                    temperatureC: 67
                })
                AudioDeviceService._setStateOverride({
                    volumeLevel: 0.4,
                    volumeMuted: false,
                    microphoneMuted: false,
                    sinkAvailable: true,
                    sourceAvailable: true
                })
                BrightnessService._setStateOverride({
                    available: true,
                    level: 0.7
                })
                BatteryService._setStateOverride({
                    available: true,
                    level: 0.5,
                    charging: false,
                    status: "discharging"
                })

                const widget = createWidget()
                widget._hoverExitHoldDuration = 40
                try {
                    widget._hovered = true
                    expect(widget._resolvedExpanded, true, "hovered widget should resolve to expanded")
                    widget._hovered = false
                    expect(widget._resolvedExpanded, true, "widget should keep expanded state during hover hold")
                    expect(_findByObjectName(widget, "systemMonitorExpandedRow").visible, true, "expanded row should remain visible during hover hold")

                    wait(10, () => {
                        try {
                            expect(widget._resolvedExpanded, true, "widget should still be expanded before the hold elapses")
                            expect(_findByObjectName(widget, "systemMonitorExpandedRow").visible, true, "expanded row should still be visible before collapse begins")
                        } catch (error) {
                            destroyWidget(widget)
                            throw error
                        }
                    })

                    wait(70, () => {
                        try {
                            expect(widget._resolvedExpanded, false, "widget should collapse after the hold elapses")
                            expect(widget._transitionRunning, true, "collapse should be driven by the shared transition")
                            expect(_findByObjectName(widget, "systemMonitorExpandedRow").visible, true, "expanded row should stay visible while the collapse animation runs")
                        } catch (error) {
                            destroyWidget(widget)
                            throw error
                        }
                    })

                    const collapseSettleDelay = Theme.anim.barExpandPreloadDuration
                        + Theme.anim.barExpandOvershootDuration
                        + Theme.anim.barExpandSettleDuration
                        + 120

                    wait(70 + collapseSettleDelay, () => {
                        try {
                            expect(widget._transitionRunning, false, "collapse transition should finish cleanly")
                            expect(_findByObjectName(widget, "systemMonitorExpandedRow").visible, false, "expanded row should hide only after collapse finishes")
                        } finally {
                            destroyWidget(widget)
                            Qt.quit()
                        }
                    })

                    return
                } catch (error) {
                    destroyWidget(widget)
                    throw error
                }
            })
        })
    }

    function runMode() {
        const currentMode = mode()

        try {
            if (currentMode === "battery-contract") {
                runBatteryContract()
                return
            }

            if (currentMode === "service-contract") {
                runServiceContract()
                return
            }

            if (currentMode === "gauge-contract") {
                runGaugeContract()
                return
            }

            if (currentMode === "widget-collapsed") {
                runWidgetCollapsed()
                return
            }

            if (currentMode === "widget-expanded") {
                runWidgetExpanded()
                return
            }

            if (currentMode === "widget-no-battery") {
                runWidgetNoBattery()
                return
            }

            if (currentMode === "widget-hover-disabled") {
                runWidgetHoverDisabled()
                return
            }

            if (currentMode === "widget-disabled") {
                runWidgetDisabled()
                return
            }

            if (currentMode === "widget-hover-hold") {
                runWidgetHoverHold()
                return
            }

            throw new Error("unknown mode: " + currentMode)
        } finally {
            SystemMetricsService._clearSnapshotOverride()
            AudioDeviceService._setStateOverride(null)
            BrightnessService._setStateOverride(null)
            BatteryService._setStateOverride(null)
            SystemMonitorService.closePanel()
            SystemMonitorService._clearFlashOverride()
            SystemMonitorService._activeFlashEvent = null
            SystemMonitorService._pendingFlashEvent = null
            SystemMonitorService.panelOpen = false
        }
    }

    Component.onCompleted: runMode()
}
