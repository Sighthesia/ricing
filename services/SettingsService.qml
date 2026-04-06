pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Persists user settings and exposes the shared settings adapter to QML.
Singleton {
    id: root

    // Public API: access settings via SettingsService.data.bar.height etc.
    readonly property alias data: adapter

    // Keep settings in the user's ~/.config/dymicshell/ directory.
    readonly property string configDir:
        ((Quickshell.env("HOME") && Quickshell.env("HOME") !== "null")
            ? Quickshell.env("HOME") + "/.config"
            : "/tmp")
        + "/dymicshell/"
    readonly property string settingsFile: configDir + "settings.json"
    readonly property real barMotionIntensityMin: 0.0
    readonly property real barMotionIntensityMax: 2.0
    property bool isLoaded: false
    property bool _sanitizingBarMotion: false

    // Emitted once on initial load, after each debounced write, and on hot-reload
    signal settingsLoaded
    signal settingsSaved
    signal settingsReloaded

    function save() {
        console.info("[DymicShell:SettingsService] Save requested", settingsFile)
        saveTimer.restart()
    }

    function _mergeSettings(source, target) {
        for (let key in source) {
            if (!Object.prototype.hasOwnProperty.call(source, key))
                continue

            const value = source[key]
            if (value === null || value === undefined)
                continue

            if (typeof value === "object" && !Array.isArray(value) && typeof target[key] === "object") {
                _mergeSettings(value, target[key])
                continue
            }

            // Only write to existing properties to avoid triggering QML engine bugs.
            if (target[key] !== undefined) {
                try {
                    target[key] = value
                } catch (_) {
                    // Ignore non-writable or incompatible properties.
                }
            }
        }
    }

    function _loadFromText(text) {
        try {
            const parsed = JSON.parse(text)
            _mergeSettings(parsed, adapter)
            _sanitizeBarMotion()
            console.info("[DymicShell:SettingsService] Settings loaded", settingsFile)
        } catch (e) {
            console.warn("[DymicShell:SettingsService] Settings load failed", settingsFile, e)
        }

        if (!root.isLoaded) {
            root.isLoaded = true
            root.settingsLoaded()
        } else {
            root.settingsReloaded()
        }
    }

    function _writeSettings() {
        _sanitizeBarMotion()

        console.info("[DymicShell:SettingsService] Writing settings", settingsFile)

        const settingsObject = {
            appearance: {
                accentColor: adapter.appearance.accentColor,
                backgroundColor: adapter.appearance.backgroundColor,
                surfaceColor: adapter.appearance.surfaceColor,
                textColor: adapter.appearance.textColor,
                textMutedColor: adapter.appearance.textMutedColor,
                borderColor: adapter.appearance.borderColor,
                cornerRadius: adapter.appearance.cornerRadius,
                screenCornerRadius: adapter.appearance.screenCornerRadius,
                uiScale: adapter.appearance.uiScale,
                fontFamily: adapter.appearance.fontFamily,
                fontMono: adapter.appearance.fontMono,
                fontSizeBody: adapter.appearance.fontSizeBody,
                fontSizeSmall: adapter.appearance.fontSizeSmall,
                fontSizeIcon: adapter.appearance.fontSizeIcon,
                wallpaperPath: adapter.appearance.wallpaperPath,
                wallpaperDirectory: adapter.appearance.wallpaperDirectory,
                matugenEnabled: adapter.appearance.matugenEnabled,
                matugenScheme: adapter.appearance.matugenScheme,
                darkMode: adapter.appearance.darkMode
            },
            bar: {
                height: adapter.bar.height,
                position: adapter.bar.position,
                backgroundOpacity: adapter.bar.backgroundOpacity,
                padding: adapter.bar.padding,
                widgetSpacing: adapter.bar.widgetSpacing
            },
            barBehavior: {
                autoHide: adapter.barBehavior.autoHide,
                autoHideDelay: adapter.barBehavior.autoHideDelay,
                autoShowDelay: adapter.barBehavior.autoShowDelay
            },
            barMotion: {
                preset: adapter.barMotion.preset,
                intensity: adapter.barMotion.intensity,
                speedMultiplier: adapter.barMotion.speedMultiplier,
                pulseEnabled: adapter.barMotion.pulseEnabled
            },
            animation: {
                speedFactor: adapter.animation.speedFactor,
                staggerLevel1BaseDelay: adapter.animation.staggerLevel1BaseDelay,
                staggerLevel1Step: adapter.animation.staggerLevel1Step,
                staggerLevel2BaseDelay: adapter.animation.staggerLevel2BaseDelay,
                staggerLevel2Step: adapter.animation.staggerLevel2Step,
                staggerExitStep: adapter.animation.staggerExitStep,
                staggerEnterDuration: adapter.animation.staggerEnterDuration,
                staggerExitDuration: adapter.animation.staggerExitDuration,
                staggerEnterOffsetY: adapter.animation.staggerEnterOffsetY,
                staggerExitOffsetY: adapter.animation.staggerExitOffsetY
            },
            notifications: {
                position: adapter.notifications.position,
                maxVisible: adapter.notifications.maxVisible,
                lowDuration: adapter.notifications.lowDuration,
                normalDuration: adapter.notifications.normalDuration,
                criticalDuration: adapter.notifications.criticalDuration,
                persistHistory: adapter.notifications.persistHistory,
                maxHistory: adapter.notifications.maxHistory
            },
            workspaceWidget: {
                defaultMode: adapter.workspaceWidget.defaultMode,
                titleMaxWidth: adapter.workspaceWidget.titleMaxWidth,
                revertDelay: adapter.workspaceWidget.revertDelay,
                hoverEnabled: adapter.workspaceWidget.hoverEnabled
            },
            superIsland: {
                enabled: adapter.superIsland.enabled,
                idleContent: adapter.superIsland.idleContent,
                expandedDefaultPage: adapter.superIsland.expandedDefaultPage,
                defaultTimeout: adapter.superIsland.defaultTimeout,
                importantTimeout: adapter.superIsland.importantTimeout,
                criticalTimeout: adapter.superIsland.criticalTimeout,
                workspaceTimeout: adapter.superIsland.workspaceTimeout,
                notificationTimeout: adapter.superIsland.notificationTimeout,
                mediaTimeout: adapter.superIsland.mediaTimeout,
                cooldownMs: adapter.superIsland.cooldownMs,
                maxQueue: adapter.superIsland.maxQueue,
                showMedia: adapter.superIsland.showMedia,
                showNotifications: adapter.superIsland.showNotifications,
                showWorkspaceEvents: adapter.superIsland.showWorkspaceEvents
            },
            mediaControl: {
                enabled: adapter.mediaControl.enabled,
                showWhenIdle: adapter.mediaControl.showWhenIdle,
                announcementEnabled: adapter.mediaControl.announcementEnabled,
                hoverRevealControls: adapter.mediaControl.hoverRevealControls,
                announcementDuration: adapter.mediaControl.announcementDuration,
                cavaEnabled: adapter.mediaControl.cavaEnabled,
                cavaBars: adapter.mediaControl.cavaBars,
                cavaAsciiMaxRange: adapter.mediaControl.cavaAsciiMaxRange,
                cavaFramerate: adapter.mediaControl.cavaFramerate
            },
            systemMonitor: {
                enabled: adapter.systemMonitor.enabled,
                hoverReveal: adapter.systemMonitor.hoverReveal,
                panelEnabled: adapter.systemMonitor.panelEnabled,
                flashEnabled: adapter.systemMonitor.flashEnabled,
                pinnedMetrics: adapter.systemMonitor.pinnedMetrics,
                showVolume: adapter.systemMonitor.showVolume,
                showBrightness: adapter.systemMonitor.showBrightness,
                showMicrophone: adapter.systemMonitor.showMicrophone,
                warningCpuPercent: adapter.systemMonitor.warningCpuPercent,
                warningMemoryPercent: adapter.systemMonitor.warningMemoryPercent,
                warningTempC: adapter.systemMonitor.warningTempC,
                criticalTempC: adapter.systemMonitor.criticalTempC,
                superIslandEscalation: adapter.systemMonitor.superIslandEscalation
            },
            systemTray: {
                enabled: adapter.systemTray.enabled,
                hoverReveal: adapter.systemTray.hoverReveal,
                flashEnabled: adapter.systemTray.flashEnabled,
                pinnedItems: adapter.systemTray.pinnedItems
            }
        }

        fileWriter.running = false
        fileWriter.stdinEnabled = true
        fileWriter.running = true
        fileWriter.write(JSON.stringify(settingsObject, null, 2) + "\n")
        fileWriter.stdinEnabled = false
    }

    function _sanitizeBarMotionReal(value, fallbackValue, minimumValue, maximumValue) {
        const numericValue = Number(value)

        if (!isFinite(numericValue))
            return fallbackValue

        return Math.min(maximumValue, Math.max(minimumValue, numericValue))
    }

    function _sanitizeBarMotionPreset(value) {
        switch (value) {
        case "soft":
        case "gentle":
            return "soft"
        case "balanced":
            return "balanced"
        case "snappy":
        case "expressive":
            return "snappy"
        default:
            return "balanced"
        }
    }

    function _sanitizeBarMotion() {
        if (root._sanitizingBarMotion)
            return

        root._sanitizingBarMotion = true

        const sanitizedPreset = _sanitizeBarMotionPreset(adapter.barMotion.preset)
        const sanitizedIntensity = _sanitizeBarMotionReal(
            adapter.barMotion.intensity,
            1.0,
            root.barMotionIntensityMin,
            root.barMotionIntensityMax)
        const sanitizedSpeedMultiplier = _sanitizeBarMotionReal(
            adapter.barMotion.speedMultiplier,
            1.0,
            0.01,
            Number.POSITIVE_INFINITY)

        if (adapter.barMotion.preset !== sanitizedPreset)
            adapter.barMotion.preset = sanitizedPreset

        if (adapter.barMotion.intensity !== sanitizedIntensity)
            adapter.barMotion.intensity = sanitizedIntensity

        if (adapter.barMotion.speedMultiplier !== sanitizedSpeedMultiplier)
            adapter.barMotion.speedMultiplier = sanitizedSpeedMultiplier

        root._sanitizingBarMotion = false
    }

    Component.onCompleted: {
        console.info("[DymicShell:SettingsService] Initializing", configDir, settingsFile)
        // Ensure config directory exists before attempting to read or write
        Quickshell.execDetached(["mkdir", "-p", configDir])
        settingsFileView.reload()
    }

    // Batch rapid property writes (e.g. slider drag) into a single disk flush
    Timer {
        id: saveTimer
        interval: 500
        onTriggered: {
            console.info("[DymicShell:SettingsService] Save debounce triggered", settingsFile)
            _writeSettings()
        }
    }

    FileView {
        id: settingsFileView
        path: root.settingsFile
        watchChanges: true
        onFileChanged: reload()
        onLoaded: _loadFromText(text())
        onLoadFailed: {
            console.warn("[DymicShell:SettingsService] Settings file missing or invalid", settingsFile)
            _writeSettings()
        }
    }

    Process {
        id: fileWriter
        stdinEnabled: true
        command: ["sh", "-c", "mkdir -p '" + root.configDir + "' && tmp=$(mktemp \"" + root.settingsFile + ".XXXXXX\") && cat > \"$tmp\" && mv \"$tmp\" '" + root.settingsFile + "'"]

        onExited: (exitCode) => {
            if (exitCode === 0) {
                console.info("[DymicShell:SettingsService] Settings write completed", settingsFile)
                root.settingsSaved()
            } else {
                console.warn("[DymicShell:SettingsService] Settings write failed", settingsFile, "exitCode=", exitCode)
            }
        }
    }

    JsonAdapter {
        id: adapter

        property JsonObject appearance: JsonObject {
            property string accentColor:     "#7aa2f7"
            property string backgroundColor: "#1a1a1a"
            property string surfaceColor:    "#252525"
            property string textColor:       "#c0caf5"
            property string textMutedColor:  "#565f89"
            property string borderColor:     "#3b4261"
            property real   cornerRadius:    10
            property real   screenCornerRadius: 10
            property real   uiScale:         1.0
            property string fontFamily:      "Noto Sans Black"
            property string fontMono:        "JetBrains Mono ExtraBold"
            property int    fontSizeBody:    14
            property int    fontSizeSmall:   10
            property int    fontSizeIcon:    16
            property string wallpaperPath:   ""
            property bool   matugenEnabled:  false
            property string matugenScheme:   "scheme-tonal-spot"
            property bool   darkMode:        true
            property string wallpaperDirectory: ""
        }

        property JsonObject bar: JsonObject {
            property real   height:            36
            property string position:          "top"
            property real   backgroundOpacity: 0.85
            property real   padding:           8
            property real   widgetSpacing:     6
        }

        property JsonObject barBehavior: JsonObject {
            property bool autoHide:      false
            property int  autoHideDelay: 500
            property int  autoShowDelay: 150
        }

        property JsonObject barMotion: JsonObject {
            property string preset: "balanced"
            property real intensity: 1.0
            property real speedMultiplier: 1.0
            property bool pulseEnabled: true

            onPresetChanged: root._sanitizeBarMotion()
            onIntensityChanged: root._sanitizeBarMotion()
            onSpeedMultiplierChanged: root._sanitizeBarMotion()
        }

        property JsonObject animation: JsonObject {
            property real speedFactor: 1.0
            property int  staggerLevel1BaseDelay: 60
            property int  staggerLevel1Step:      50
            property int  staggerLevel2BaseDelay: 120
            property int  staggerLevel2Step:      50
            property int  staggerExitStep:        15
            property int  staggerEnterDuration:   280
            property int  staggerExitDuration:    100
            property real staggerEnterOffsetY:    30
            property real staggerExitOffsetY:     10
        }

        property JsonObject notifications: JsonObject {
            property string position:         "top_right"
            property int    maxVisible:       5
            property int    lowDuration:      3000
            property int    normalDuration:   5000
            property int    criticalDuration: 0
            property bool   persistHistory:   true
            property int    maxHistory:       100
        }

        property JsonObject workspaceWidget: JsonObject {
            property string defaultMode:  "focus"
            property int    titleMaxWidth: 240
            property int    revertDelay:   1500
            property bool   hoverEnabled:  true
        }

        property JsonObject superIsland: JsonObject {
            property bool enabled: true
            property string idleContent: "time"
            property string expandedDefaultPage: "launcher"
            property int defaultTimeout: 1500
            property int importantTimeout: 1500
            property int criticalTimeout: 1500
            property int workspaceTimeout: 1500
            property int notificationTimeout: 1500
            property int mediaTimeout: 1500
            property int cooldownMs: 1800
            property int maxQueue: 5
            property bool showMedia: true
            property bool showNotifications: true
            property bool showWorkspaceEvents: true
        }

        property JsonObject mediaControl: JsonObject {
            property bool enabled: true
            property bool showWhenIdle: true
            property bool announcementEnabled: true
            property bool hoverRevealControls: true
            property int announcementDuration: 1500
            property bool cavaEnabled: true
            property int cavaBars: 20
            property int cavaAsciiMaxRange: 1000
            property int cavaFramerate: 60
        }

        property JsonObject systemMonitor: JsonObject {
            property bool enabled: true
            property bool hoverReveal: true
            property bool panelEnabled: true
            property bool flashEnabled: true
            property var pinnedMetrics: ["cpu", "memory", "temperature"]
            property bool showVolume: true
            property bool showBrightness: true
            property bool showMicrophone: true
            property int warningCpuPercent: 85
            property int warningMemoryPercent: 85
            property int warningTempC: 75
            property int criticalTempC: 90
            property bool superIslandEscalation: true
        }

        property JsonObject systemTray: JsonObject {
            property bool enabled: true
            property bool hoverReveal: true
            property bool flashEnabled: true
            property var pinnedItems: []
        }
    }
}
