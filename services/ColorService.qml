pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Invoke Python color extraction from wallpaper images, writing results to colors.json.
QtObject {
    id: root

    property bool isExtracting: false

    // Debounce rapid wallpaper changes
    property string _pendingPath: ""

    function extractColors(wallpaperPath) {
        if (!wallpaperPath) return
        _pendingPath = wallpaperPath
        _debounce.restart()
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
        var scriptPath = Quickshell.shellDir + "/scripts/theming/template-processor.py"
        var cmd = 'mkdir -p "' + Quickshell.cacheDir + '" && python3 "' + scriptPath + '" "' + _pendingPath + '" --dark -o "' + outputPath + '"'
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
