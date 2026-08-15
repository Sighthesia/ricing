pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "./" as Services

// Invoke Python color extraction from wallpaper images, writing results to colors.json.
QtObject {
    id: root

    property bool isExtracting: false
    readonly property string requestedMode: {
        const value = String(Services.SettingsService.appearance.colorScheme || "auto")
        return value === "dark" || value === "light" ? value : "auto"
    }

    // Debounce rapid wallpaper changes
    property string _pendingPath: ""

    function extractColors(wallpaperPath) {
        if (!wallpaperPath) return
        _pendingPath = wallpaperPath
        _debounce.restart()
    }

    function commandFor(wallpaperPath, outputPath, mode) {
        const modeFlag = mode === "dark" ? " --dark" : mode === "light" ? " --light" : ""
        const scriptPath = Quickshell.shellDir + "/scripts/theming/template-processor.py"
        return 'mkdir -p "' + Quickshell.cacheDir + '" && python3 "' + scriptPath
                + '" "' + wallpaperPath + '"' + modeFlag + ' -o "' + outputPath + '"'
    }

    // Regenerate the current wallpaper palette whenever the requested scheme changes.
    property Connections _schemeConnection: Connections {
        target: Services.SettingsService.appearance
        function onColorSchemeChanged() {
            root.extractColors(Services.SettingsService.appearance.wallpaperPath)
        }
    }

    property Timer _debounce: Timer {
        interval: 150
        onTriggered: {
            if (extractProcess.running) {
                extractProcess.running = false
            } else {
                root._execute()
            }
        }
    }

    function _execute() {
        if (!_pendingPath) return
        var outputPath = Quickshell.cacheDir + "/colors.json"
        var cmd = commandFor(_pendingPath, outputPath, requestedMode)
        _pendingPath = ""
        extractProcess.command = ["sh", "-c", cmd]
        isExtracting = true
        extractProcess.running = true
    }

    property Process _proc: Process {
        id: extractProcess
        running: false

        onExited: function(exitCode, exitStatus) {
            root.isExtracting = false
            if (root._pendingPath) {
                root._execute()
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                var text = this.text.trim()
                if (text) console.warn("ColorService:", text)
            }
        }
    }
}
