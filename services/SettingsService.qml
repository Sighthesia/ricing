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
    readonly property alias widgetSettings: adapter.widgetSettings
    readonly property alias widgetInstanceSettings: adapter.widgetInstanceSettings
    readonly property real panelSurfaceOpacity: appearance.enableBlur
        ? Math.min(appearance.panelOpacity, 0.62)
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

        if (changed)
            save()

        return target
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
        save()
    }

    function removeWidgetInstanceSettings(instanceKey) {
        if (!instanceKey || !adapter.widgetInstanceSettings || adapter.widgetInstanceSettings[instanceKey] === undefined)
            return

        var rootMap = Object.assign({}, adapter.widgetInstanceSettings)
        delete rootMap[instanceKey]
        adapter.widgetInstanceSettings = rootMap
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
                property real backgroundOpacity: 0.85
                property int cornerRadius: 12
            }

            property JsonObject appearance: JsonObject {
                property string wallpaperPath: ""
       property string colorScheme: "auto"
   property real panelOpacity: 0.9
             property int cornerRadius: 12
                property bool enableBlur: true
                property bool ripplePulseEnabled: true
                property bool ripplePulseFullscreen: false
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

            property JsonObject widgetSettings: JsonObject {
                property JsonObject activeWindow: JsonObject {
                    property bool showIcon: true
                    property int maxTitleWidth: 200
                    property string desktopLabel: "Desktop"
                }

                property JsonObject clock: JsonObject {
                    property bool showDate: true
                    property string timeFormat: "12h"
                    property bool showDateWhenSimplified: false
                }
            }

            property var widgetInstanceSettings: ({})
        }
    }
}
