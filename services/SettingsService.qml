pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "./" as Services
import "WidgetSettingsRegistry.js" as WidgetSettingsRegistry

// Persist user-facing shell settings (bar, appearance, notifications) to settings.json.
QtObject {
    id: root

    readonly property alias bar: adapter.bar
    readonly property alias appearance: adapter.appearance
    readonly property alias notifications: adapter.notifications
    readonly property alias controls: adapter.controls
    readonly property alias widgetSettings: adapter.widgetSettings
    readonly property alias widgetInstanceSettings: adapter.widgetInstanceSettings
    // Keep the settings-panel defaults beside the persisted category schemas.
    readonly property var appearanceDefaults: ({
        wallpaperPath: "",
        colorScheme: "auto",
        panelOpacity: 0.9,
        cornerRadius: 12,
        enableBlur: true,
        blurPasses: 2,
        blurOffset: 1.25,
        blurNoise: 0.02,
        blurSaturation: 1.0,
        blurSurfaceOpacity: 0.35,
        glassHighlightWidth: 2,
        glassHighlightIntensity: 0.56,
        glassGlowWidth: 5,
        glassGlowIntensity: 0.22,
        glassThemeAdaptive: true,
        ripplePulseEnabled: true,
        ripplePulseFullscreen: false,
        transientMediaCover: false,
        fontDefault: "",
        fontFixed: "monospace",
        fontDefaultScale: 1.0,
        fontFixedScale: 1.0,
        windowHintMode: "attached-island",
        overviewBackground: false,
        overviewBackgroundSolid: false,
        overviewBackgroundBlur: 0.4,
        overviewBackgroundTint: 0.5,
    })
    readonly property var barDefaults: ({
        height: 48,
        position: "top",
        floating: false,
        floatingMargin: 4,
        cornerRadius: 12,
    })
    readonly property var notificationDefaults: ({
        maxVisible: 3,
        timeout: 5000,
        position: "top-right",
        dnd: false,
    })
    property int widgetSettingsRevision: 0
    readonly property real panelSurfaceOpacity: appearance.enableBlur
        ? appearance.blurSurfaceOpacity
        : appearance.panelOpacity
    // Blur-region edge inset for attached surfaces (bar dockzones, island).
    // Zero so the hard-edged wl_region reaches the painted arc/edge and the
    // acrylic covers the fill completely, with no un-blurred transparent rim.
    readonly property int blurRegionInset: 0

    // Panel visibility state (driven by bar widget, consumed by SettingsWindow)
    property bool panelVisible: false
    function togglePanel() {
        if (Services.IslandService.expanded && Services.IslandService.panelPage === "settings-center")
            Services.IslandService.close()
        else
            Services.IslandService.showSettingsCenter()
    }
    function closePanel() {
        panelVisible = false

        if (Services.IslandService.panelPage === "settings-center")
            Services.IslandService.close()
    }

    // Expose settings visibility over Quickshell IPC for compositor-managed hotkeys.
    property IpcHandler ipc: IpcHandler {
        target: "settings"

        function toggle() { root.togglePanel() }
    }

    function save() {
        debounce.restart()
    }

    function resetCategorySetting(category, key, value) {
        var defaults = category === "appearance" ? appearanceDefaults
                : category === "bar" ? barDefaults
                : category === "notifications" ? notificationDefaults : null
        var target = category === "appearance" ? adapter.appearance
                : category === "bar" ? adapter.bar
                : category === "notifications" ? adapter.notifications : null
        if (!defaults || !target || !key || !(key in defaults) || value !== defaults[key])
            return false

        if (target[key] === defaults[key])
            return false

        target[key] = defaults[key]
        save()
        return true
    }

    function _bumpWidgetSettingsRevision() {
        widgetSettingsRevision += 1
    }

    function ensureWidgetSettingDefaults(widgetId) {
        var registryDefaults = WidgetSettingsRegistry.defaults(widgetId)
        var settingsKey = WidgetSettingsRegistry.settingsKey(widgetId)

        if (!settingsKey)
            return null

        var target = adapter.widgetSettings[settingsKey]
        if (!target)
            return null

        var changed = false
        for (var key in registryDefaults) {
            if (target[key] === undefined) {
                target[key] = registryDefaults[key]
                changed = true
            }
        }

        if (changed) {
            _bumpWidgetSettingsRevision()
            save()
        }

        return target
    }

    // Migrate the clock format away from the old 12h/24h preset values.
    function migrateClockTimeFormat() {
        if (!adapter.widgetSettings || !adapter.widgetSettings.clock)
            return false

        var clockSettings = adapter.widgetSettings.clock
        var currentFormat = clockSettings.timeFormat
        var nextFormat = ""

        if (currentFormat === "12h")
            nextFormat = "yyyy.MM.dd|hh:mm"
        else if (currentFormat === "24h")
            nextFormat = "yyyy.MM.dd|HH:mm"
        else
            return false

        if (currentFormat === nextFormat)
            return false

        clockSettings.timeFormat = nextFormat
        return true
    }

    function ensureWidgetInstanceSettingDefaults(widgetId, instanceKey) {
        if (!WidgetSettingsRegistry.isInstanceScoped(widgetId) || !instanceKey)
            return null

        var registryDefaults = WidgetSettingsRegistry.defaults(widgetId)
        var rootMap = Object.assign({}, adapter.widgetInstanceSettings || ({}))
        var target = Object.assign({}, rootMap[instanceKey] || ({}))
        var changed = false

        for (var key in registryDefaults) {
            if (target[key] === undefined) {
                target[key] = registryDefaults[key]
                changed = true
            }
        }

        if (!rootMap[instanceKey] || changed) {
            rootMap[instanceKey] = target
            adapter.widgetInstanceSettings = rootMap
            _bumpWidgetSettingsRevision()
            save()
        }

        return target
    }

    function ensureWidgetSettings(widgetId, instanceKey) {
        if (WidgetSettingsRegistry.isInstanceScoped(widgetId))
            return ensureWidgetInstanceSettingDefaults(widgetId, instanceKey)

        return ensureWidgetSettingDefaults(widgetId)
    }

    function widgetSettingsObject(widgetId, instanceKey) {
        root.widgetSettingsRevision

        if (WidgetSettingsRegistry.isInstanceScoped(widgetId))
            return WidgetSettingsRegistry.instanceSettingsObject(widgetId, instanceKey, adapter.widgetInstanceSettings)

        return WidgetSettingsRegistry.settingsObject(widgetId, adapter.widgetSettings)
    }

    function setWidgetInstanceSettingValue(widgetId, instanceKey, key, value) {
        if (!WidgetSettingsRegistry.isInstanceScoped(widgetId) || !instanceKey || !key)
            return

        ensureWidgetInstanceSettingDefaults(widgetId, instanceKey)

        var rootMap = Object.assign({}, adapter.widgetInstanceSettings || ({}))
        var target = Object.assign({}, rootMap[instanceKey] || ({}))
        if (target[key] === value)
            return

        target[key] = value
        rootMap[instanceKey] = target
        adapter.widgetInstanceSettings = rootMap
        _bumpWidgetSettingsRevision()
        save()
    }

    function removeWidgetInstanceSettings(instanceKey) {
        if (!instanceKey || !adapter.widgetInstanceSettings || adapter.widgetInstanceSettings[instanceKey] === undefined)
            return

        var rootMap = Object.assign({}, adapter.widgetInstanceSettings)
        delete rootMap[instanceKey]
        adapter.widgetInstanceSettings = rootMap
        _bumpWidgetSettingsRevision()
        save()
    }

    property Timer debounce: Timer {
        interval: 500
        onTriggered: settingsFile.writeAdapter()
    }

    property FileView settingsFile: FileView {
        path: Quickshell.statePath("settings.json")
        watchChanges: true
        blockLoading: true
        onFileChanged: reload()
        onAdapterUpdated: root.save()
        onLoaded: {
            root.ensureWidgetSettingDefaults("clock")
            root.ensureWidgetSettingDefaults("active-window")
            if (root.migrateClockTimeFormat())
                root.save()
            root._bumpWidgetSettingsRevision()
        }
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                settingsFile.writeAdapter()
            } else {
                console.warn("SettingsService: failed to load settings.json, error =", error)
            }
        }

        JsonAdapter {
            id: adapter

            property JsonObject bar: JsonObject {
                // Size scale nudged toward the local quickshell bar reference while
                // keeping afloat's roomier capsule geometry and padding language.
                property int height: 48
                property string position: "top"
                property bool floating: false
                property int floatingMargin: 4
                property int cornerRadius: 12
            }

            property JsonObject appearance: JsonObject {
                property string wallpaperPath: ""
       property string colorScheme: "auto"
   property real panelOpacity: 0.9
             property int cornerRadius: 12
                property bool enableBlur: true
                property int blurPasses: 2
                property real blurOffset: 1.25
                property real blurNoise: 0.02
                property real blurSaturation: 1.0
                property real blurSurfaceOpacity: 0.35
                property real glassHighlightWidth: 2
                property real glassHighlightIntensity: 0.56
                property real glassGlowWidth: 5
                property real glassGlowIntensity: 0.22
                property bool glassThemeAdaptive: true
                property bool ripplePulseEnabled: true
                property bool ripplePulseFullscreen: false
                // Show album art in media transient messages (off by default since
                // the adjacent media widget already displays the cover).
                property bool transientMediaCover: false
                // Font family — empty string means system default (Qt.application.font.family)
                property string fontDefault: ""
                property string fontFixed: "monospace"
                property real fontDefaultScale: 1.0
                property real fontFixedScale: 1.0
                // Window hint layout: "attached-island" extends from the island,
          // "floating-capsule" keeps the legacy independent floating popup.
                property string windowHintMode: "attached-island"
                // niri overview background: master toggle, solid-color method,
                // blur strength (0 = static wallpaper), and theme tint opacity.
                property bool overviewBackground: false
                property bool overviewBackgroundSolid: false
                property real overviewBackgroundBlur: 0.4
                property real overviewBackgroundTint: 0.5
     }

            property JsonObject notifications: JsonObject {
                property int maxVisible: 3
                property int timeout: 5000
                property string position: "top-right"
                property bool dnd: false
            }

            property JsonObject controls: JsonObject {
                property real volumeStep: 0.05
                property real brightnessStep: 0.05
            }

            property JsonObject widgetSettings: JsonObject {
                property JsonObject activeWindow: JsonObject {
                    property bool showIcon: true
                    property int maxTitleWidth: 200
                    property int maxWidth: 240
                    property string desktopLabel: "Desktop"
                }

                property JsonObject clock: JsonObject {
                    property bool showDate: true
                    property string timeFormat: "yyyy.MM.dd|HH:mm"
                    property bool showDateWhenSimplified: false
                }
            }

            property var widgetInstanceSettings: ({})
        }
    }
}
