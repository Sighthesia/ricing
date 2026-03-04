pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.services

Singleton {
    id: root

    // Emitted after a wallpaper path change is detected or set manually.
    signal wallpaperChanged(string path)
    // Emitted after matugen writes colors successfully.
    signal matugenCompleted()
    // Emitted when matugen execution fails (not installed, bad exit code, etc.).
    signal matugenFailed(string error)

    readonly property bool matugenRunning: matugenProcess.running

    // Debounce rapid wallpaper changes (e.g., slideshows) before invoking matugen.
    Timer {
        id: debounceTimer
        interval: 800
        onTriggered: _runMatugen(SettingsService.data.appearance.wallpaperPath)
    }

    // Poll swww every 5 s to detect externally changed wallpapers.
    Timer {
        id: swwwPollTimer
        interval: 5000
        repeat: true
        running: SettingsService.data.appearance.matugenEnabled
        triggeredOnStart: true
        onTriggered: swwwQueryProcess.running = true
    }

    // ── swww query ──────────────────────────────────────────────────────────
    Process {
        id: swwwQueryProcess
        command: ["swww", "query"]

        stdout: StdioCollector {
            id: swwwCollector
            onStreamFinished: {
                const buf = text.trim()
                if (buf === "") return

                // swww query output example:
                //   eDP-1: image: /path/to/wallpaper.jpg
                // Take the last non-empty line; parse path after "image: ".
                const lines = buf.split("\n").filter(l => l.trim() !== "")
                const last = lines[lines.length - 1]
                const match = last.match(/image:\s+(.+)$/)
                if (!match) return

                const detected = match[1].trim()
                if (detected !== SettingsService.data.appearance.wallpaperPath) {
                    SettingsService.data.appearance.wallpaperPath = detected
                    root.wallpaperChanged(detected)
                    debounceTimer.restart()
                }
            }
        }
    }

    // ── matugen invocation ───────────────────────────────────────────────────
    // matugen uses ~/.config/matugen/config.toml to write output files — we do
    // NOT capture stdout. Colors.qml watches the generated colors.json directly.
    Process {
        id: matugenProcess

        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                root.matugenFailed("matugen exited with code " + exitCode)
                return
            }
            root.matugenCompleted()
        }
    }

    // Public: trigger matugen manually (e.g., when user changes the path in UI).
    function triggerMatugen() {
        const path = SettingsService.data.appearance.wallpaperPath
        if (path === "") return
        debounceTimer.restart()
    }

    function _runMatugen(wallpaperPath) {
        if (!SettingsService.data.appearance.matugenEnabled) return
        if (wallpaperPath === "") return
        if (matugenProcess.running) {
            // Still running — reschedule after current job finishes
            debounceTimer.restart()
            return
        }
        // Let matugen use its own config.toml for template output.
        // -m dark/light controls which palette node the templates receive.
        // --source-color-index 0 bypasses dialoguer's interactive TTY prompt
        // that fails when matugen is invoked from a non-terminal context.
        const mode = SettingsService.data.appearance.darkMode ? "dark" : "light"
        matugenProcess.command = [
            "matugen", "image", wallpaperPath, "-m", mode,
            "--source-color-index", "0", "-q"
        ]
        matugenProcess.running = true
    }
}
