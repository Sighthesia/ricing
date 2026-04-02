pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.services

Singleton {
    id: root

    readonly property string matugenConfigPath: Quickshell.shellDir + "/matugen/config.toml"
    readonly property string matugenWorkingDir: Quickshell.shellDir + "/matugen"
    readonly property string matugenApplyScriptPath: Quickshell.shellDir + "/scripts/apply-matugen-targets.sh"

    // Emitted after setWallpaper() is called — listeners (e.g., BackgroundWindow)
    // should react to this rather than polling swww.
    signal wallpaperChanged(string path)
    // Emitted after matugen writes colors successfully.
    signal matugenCompleted()
    // Emitted when matugen execution fails (not installed, bad exit code, etc.).
    signal matugenFailed(string error)

    // Mirrors SettingsService so QML bindings can observe wallpaper changes.
    property string currentWallpaper: SettingsService.data.appearance.wallpaperPath

    readonly property bool matugenRunning: matugenProcess.running || matugenApplyProcess.running

    // Debounce rapid setWallpaper() calls before invoking matugen.
    Timer {
        id: debounceTimer
        interval: 500
        repeat: false
        onTriggered: _runMatugen(SettingsService.data.appearance.wallpaperPath)
    }

    // ── matugen invocation ───────────────────────────────────────────────────
    // Use the repo-owned matugen config so DymicShell controls all exported
    // theme targets instead of depending on the user's global matugen setup.
    Process {
        id: matugenProcess

        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                root.matugenFailed("matugen exited with code " + exitCode)
                return
            }

            matugenApplyProcess.command = ["bash", root.matugenApplyScriptPath]
            matugenApplyProcess.running = true
        }
    }

    Process {
        id: matugenApplyProcess

        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                root.matugenFailed("matugen target wiring exited with code " + exitCode)
                return
            }

            root.matugenCompleted()
        }
    }

    // Public: set the active wallpaper path and trigger a matugen run.
    // Called by BackgroundWindow (and any other consumer) instead of invoking swww.
    function setWallpaper(path) {
        SettingsService.data.appearance.wallpaperPath = path
        SettingsService.save()
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
        if (root.matugenRunning) {
            // Still running — reschedule after current job finishes
            debounceTimer.restart()
            return
        }
        // Let matugen render against the repo-owned config.toml template set.
        // -m dark/light controls which palette node the templates receive.
        // -t applies the selected MD3 scheme algorithm (tonal-spot, vibrant…).
        // --source-color-index 0 bypasses dialoguer's interactive TTY prompt
        // that fails when matugen is invoked from a non-terminal context.
        const mode = SettingsService.data.appearance.darkMode ? "dark" : "light"
        const scheme = SettingsService.data.appearance.matugenScheme || "scheme-tonal-spot"
        matugenProcess.command = [
            "bash", "-lc",
            "cd \"" + root.matugenWorkingDir + "\" && matugen image \"" + wallpaperPath + "\" -c \"" + root.matugenConfigPath + "\" -m \"" + mode + "\" -t \"" + scheme + "\" --source-color-index 0 -q"
        ]
        matugenProcess.running = true
    }

    Component.onCompleted: {
        // Run matugen once at startup so color scheme is current.
        const path = SettingsService.data.appearance.wallpaperPath
        if (path !== "") _runMatugen(path)
    }
}
