import QtQuick
import Quickshell
import Quickshell.Io

// Adapt the wallpaper scan into a non-blocking lock-surface layout provider.
Item {
    id: root

    property string wallpaperPath: ""
    property int screenWidth: 0
    property int screenHeight: 0
    property real centerX: 0.5
    property real centerY: 0.5
    property real luminance: 0.5
    property bool ready: false

    signal analysisApplied()

    function clamp(value, minimum, maximum) {
        return Math.max(minimum, Math.min(maximum, Number(value)))
    }

    function analyze(): void {
        root.ready = false
        if (!root.wallpaperPath || root.screenWidth <= 0 || root.screenHeight <= 0)
            return
        analysisProcess.running = false
        analysisProcess.command = [
            "python3",
            Quickshell.shellDir + "/scripts/wallpaper_clock_layout.py",
            "--image", root.wallpaperPath,
            "--screen-width", String(root.screenWidth),
            "--screen-height", String(root.screenHeight),
        ]
        analysisProcess.running = true
    }

    function applyResult(raw): void {
        try {
            const result = JSON.parse(String(raw || "").trim())
            if (!result || result.ok !== true)
                return
            root.centerX = root.clamp(result.center_x, 0.06, 0.94)
            root.centerY = root.clamp(result.center_y, 0.10, 0.90)
            root.luminance = root.clamp(result.luminance, 0, 1)
            root.ready = true
            root.analysisApplied()
        } catch (error) {
            console.warn("WallpaperClockLayout: invalid analyzer output", error)
        }
    }

    onWallpaperPathChanged: analyzeTimer.restart()
    onScreenWidthChanged: analyzeTimer.restart()
    onScreenHeightChanged: analyzeTimer.restart()

    // Debounce resize and wallpaper changes so one lock surface cannot queue
    // several obsolete image scans during startup.
    Timer {
        id: analyzeTimer
        interval: 120
        repeat: false
        onTriggered: root.analyze()
    }

    // Keep image analysis outside the QML render thread and PAM conversation.
    Process {
        id: analysisProcess

        stdout: StdioCollector {
            onStreamFinished: root.applyResult(this.text)
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const message = this.text.trim()
                if (message)
                    console.warn("WallpaperClockLayout:", message)
            }
        }
    }

    Component.onCompleted: analyzeTimer.restart()
}
