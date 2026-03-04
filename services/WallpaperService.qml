pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.services

Singleton {
    id: root

    // Emitted after setWallpaper() is called — listeners (e.g., BackgroundWindow)
    // should react to this rather than polling swww.
    signal wallpaperChanged(string path)
    // Emitted after matugen writes colors successfully.
    signal matugenCompleted()
    // Emitted when matugen execution fails (not installed, bad exit code, etc.).
    signal matugenFailed(string error)

    // Mirrors SettingsService so QML bindings can observe wallpaper changes.
    property string currentWallpaper: SettingsService.data.appearance.wallpaperPath

    readonly property bool matugenRunning: matugenProcess.running

    // Debounce rapid setWallpaper() calls before invoking matugen.
    Timer {
        id: debounceTimer
        interval: 500
        repeat: false
        onTriggered: _runMatugen(SettingsService.data.appearance.wallpaperPath)
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

    // Public: set the active wallpaper path and trigger a matugen run.
    // Called by BackgroundWindow (and any other consumer) instead of invoking swww.
    function setWallpaper(path) {
        SettingsService.data.appearance.wallpaperPath = path
        wallpaperChanged(path)
        debounceTimer.restart()
    }

    // Public: trigger matugen manually without changing the wallpaper path
    // (e.g., when the user toggles dark/light mode in the settings UI).
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
        // -t applies the selected MD3 scheme algorithm (tonal-spot, vibrant…).
        // --source-color-index 0 bypasses dialoguer's interactive TTY prompt
        // that fails when matugen is invoked from a non-terminal context.
        const mode = SettingsService.data.appearance.darkMode ? "dark" : "light"
        const scheme = SettingsService.data.appearance.matugenScheme || "scheme-tonal-spot"
        matugenProcess.command = [
            "matugen", "image", wallpaperPath,
            "-m", mode,
            "-t", scheme,
            "--source-color-index", "0", "-q"
        ]
        matugenProcess.running = true
    }

    Component.onCompleted: {
        // Run matugen once at startup so color scheme is current.
        const path = SettingsService.data.appearance.wallpaperPath
        if (path !== "") _runMatugen(path)
    }
}
