pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Persist user-facing shell settings (bar, appearance, notifications) to settings.json.
QtObject {
    id: root

    readonly property alias bar: adapter.bar
    readonly property alias appearance: adapter.appearance
    readonly property alias notifications: adapter.notifications

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
            }

            property JsonObject notifications: JsonObject {
                property int maxVisible: 3
                property int timeout: 5000
                property string position: "top-right"
                property bool dnd: false
            }
        }
    }
}
