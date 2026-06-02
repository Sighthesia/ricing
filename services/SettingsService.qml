pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "WidgetSettingsRegistry.js" as WidgetSettingsRegistry

// Persist user-facing shell settings (bar, appearance, notifications) to settings.json.
QtObject {
    id: root

    readonly property alias bar: adapter.bar
    readonly property alias appearance: adapter.appearance
    readonly property alias notifications: adapter.notifications
    readonly property alias widgetSettings: adapter.widgetSettings
    readonly property real panelSurfaceOpacity: appearance.enableBlur
        ? Math.min(appearance.panelOpacity, 0.62)
        : appearance.panelOpacity
    // Blur-region edge inset for attached surfaces (bar dockzones, island).
    // Zero so the hard-edged wl_region reaches the painted arc/edge and the
    // acrylic covers the fill completely, with no un-blurred transparent rim.
    readonly property int blurRegionInset: 0

    // Panel visibility state (driven by bar widget, consumed by SettingsWindow)
    property bool panelVisible: false
    function togglePanel() { panelVisible = !panelVisible }
    function closePanel() { panelVisible = false }

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
        onLoaded: root.ensureWidgetSettingDefaults("clock")
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
                property JsonObject clock: JsonObject {
                    property bool showDate: true
                    property string timeFormat: "12h"
                    property bool showDateWhenSimplified: false
                }
            }
        }
    }
}
