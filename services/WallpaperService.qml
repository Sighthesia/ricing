pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.services
import "ThemeSchedule.js" as ThemeSchedule

// Owns wallpaper changes and the repo-local matugen export/apply pipeline.
Singleton {
    id: root

    readonly property string matugenConfigPath: Quickshell.shellDir + "/matugen/config.toml"
    readonly property string matugenWorkingDir: Quickshell.shellDir + "/matugen"
    readonly property string matugenApplyScriptPath: Quickshell.shellDir + "/scripts/apply-matugen-targets.sh"
    property string pendingTargetMode: SettingsService.data.appearance.darkMode ? "dark" : "light"
    property bool applyQueued: false
    property bool applyQueuedSystemOnly: false
    property string darkModeScheduleStatus: root._computeScheduleStatus()

    function _computeScheduleStatus() {
        const appearance = SettingsService.data.appearance
        const mode = appearance.darkModeScheduleMode || "manual"

        if (mode === "manual") {
            return appearance.darkMode ? "深色模式 (手动)" : "浅色模式 (手动)"
        }

        const now = new Date()
        const schedule = ThemeSchedule.resolveDarkModeSchedule(appearance, now)

        if (!schedule.available) {
            return "无法计算: " + (schedule.reason || "未知错误")
        }

        const currentMode = schedule.targetDark ? "深色" : "浅色"
        let status = currentMode + "模式"

        if (mode === "sunrise-sunset") {
            if (schedule.sunrise && schedule.sunset) {
                const sunriseStr = _formatTime(schedule.sunrise)
                const sunsetStr = _formatTime(schedule.sunset)
                status += " | 日出 " + sunriseStr + " / 日落 " + sunsetStr
            }
        } else if (mode === "custom-time") {
            status += " | " + (schedule.darkStart || "--:--") + " ~ " + (schedule.lightStart || "--:--")
        }

        if (schedule.nextTransition) {
            const nextStr = _formatTime(schedule.nextTransition)
            status += " | 下次切换 " + nextStr
        }

        return status
    }

    function _formatTime(date) {
        if (!date || typeof date.getTime !== "function")
            return "--:--"
        const hours = date.getHours()
        const mins = date.getMinutes()
        return (hours < 10 ? "0" : "") + hours + ":" + (mins < 10 ? "0" : "") + mins
    }

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

    Timer {
        id: scheduleTimer
        repeat: false
        onTriggered: root._applyScheduledDarkMode()
    }

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

        stdout: SplitParser {
            onRead: data => console.log("[DymicShell:WallpaperService] matugen stdout:", data.trim())
        }

        stderr: SplitParser {
            onRead: data => console.warn("[DymicShell:WallpaperService] matugen stderr:", data.trim())
        }

        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                root.matugenFailed("matugen exited with code " + exitCode)
                Qt.callLater(root._flushQueuedApply)
                return
            }

            Qt.callLater(function() {
                root._runMatugenApply(root.pendingTargetMode)
            })
        }
    }

    Process {
        id: matugenApplyProcess

        stdout: SplitParser {
            onRead: data => console.log("[DymicShell:WallpaperService] matugen-apply stdout:", data.trim())
        }

        stderr: SplitParser {
            onRead: data => console.warn("[DymicShell:WallpaperService] matugen-apply stderr:", data.trim())
        }

        onExited: function(exitCode, exitStatus) {
            console.log("[DymicShell:WallpaperService] matugen-apply exited", exitCode, exitStatus, "mode=", root.pendingTargetMode)
            if (exitCode !== 0) {
                root.matugenFailed("matugen target wiring exited with code " + exitCode)
                Qt.callLater(root._flushQueuedApply)
                return
            }

            root.matugenCompleted()
            Qt.callLater(root._flushQueuedApply)
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
        if (!SettingsService.data.appearance.matugenEnabled) return

        const mode = SettingsService.data.appearance.darkMode ? "dark" : "light"
        if (path === "") {
            root.matugenFailed("matugen requires a wallpaper before dynamic theming can be applied")
            return
        }

        debounceTimer.restart()
    }

    function syncAppearanceMode() {
        if (SettingsService.data.appearance.matugenEnabled) return

        const mode = SettingsService.data.appearance.darkMode ? "dark" : "light"
        root._runMatugenApply(mode, true)
    }

    function refreshDarkModeSchedule() {
        root._applyScheduledDarkMode()
        root.darkModeScheduleStatus = root._computeScheduleStatus()
    }

    function _applyScheduledDarkMode() {
        const appearance = SettingsService.data.appearance
        const schedule = ThemeSchedule.resolveDarkModeSchedule(appearance, new Date())

        if (!schedule.available) {
            console.warn("[DymicShell:WallpaperService] dark mode schedule unavailable:", schedule.reason)
            scheduleTimer.stop()
            return
        }

        if (appearance.darkModeScheduleMode === "manual") {
            scheduleTimer.stop()
            return
        }

        if (appearance.darkMode !== schedule.targetDark) {
            appearance.darkMode = schedule.targetDark
            SettingsService.save()

            if (appearance.matugenEnabled)
                root.triggerMatugen()
            else
                root.syncAppearanceMode()
        }

        if (!schedule.nextTransition) {
            scheduleTimer.stop()
            return
        }

        var delay = schedule.nextTransition.getTime() - (new Date()).getTime()
        if (delay < 1000)
            delay = 1000

        scheduleTimer.interval = delay
        scheduleTimer.restart()
    }

    Connections {
        target: SettingsService
        function onSettingsLoaded() {
            root.refreshDarkModeSchedule()
        }

        function onSettingsReloaded() {
            root.refreshDarkModeSchedule()
        }
    }

    Connections {
        target: GeocodingService
        function onCityResolved(city, latitude, longitude, displayName) {
            if (SettingsService.data.appearance.darkModeScheduleLocationMode !== "city")
                return

            SettingsService.data.appearance.darkModeScheduleLatitude = latitude
            SettingsService.data.appearance.darkModeScheduleLongitude = longitude
            SettingsService.save()
            root.refreshDarkModeSchedule()
        }

        function onCityResolveFailed(city, reason) {
            console.warn("[DymicShell:WallpaperService] city lookup failed:", city, reason)
        }
    }

    function _runMatugenApply(mode, systemOnly) {
        root.pendingTargetMode = mode
        if (root.matugenRunning) {
            root.applyQueuedSystemOnly = root.applyQueued ? (root.applyQueuedSystemOnly && !!systemOnly) : !!systemOnly
            root.applyQueued = true
            console.log("[DymicShell:WallpaperService] matugen-apply queued", mode, systemOnly)
            return
        }

        root.applyQueued = false
        root.applyQueuedSystemOnly = false
        console.log("[DymicShell:WallpaperService] starting matugen-apply", mode, systemOnly ? "system-only" : "full")
        matugenApplyProcess.command = systemOnly
            ? ["bash", root.matugenApplyScriptPath, mode, "--system-only"]
            : ["bash", root.matugenApplyScriptPath, mode]
        matugenApplyProcess.running = true
    }

    function _flushQueuedApply() {
        if (!root.applyQueued || root.matugenRunning) return

        const mode = root.pendingTargetMode
        const systemOnly = root.applyQueuedSystemOnly
        root.applyQueued = false
        root.applyQueuedSystemOnly = false
        root._runMatugenApply(mode, systemOnly)
    }

    function _runMatugen(wallpaperPath) {
        if (!SettingsService.data.appearance.matugenEnabled) return
        const mode = SettingsService.data.appearance.darkMode ? "dark" : "light"
        if (wallpaperPath === "") {
            root.matugenFailed("matugen requires a wallpaper before dynamic theming can be applied")
            return
        }
        if (root.matugenRunning) {
            // Still running — reschedule after current job finishes
            console.log("[DymicShell:WallpaperService] triggerMatugen deferred while matugen is already running")
            debounceTimer.restart()
            return
        }
        // Let matugen render against the repo-owned config.toml template set.
        // -m dark/light controls which palette node the templates receive.
        // -t applies the selected MD3 scheme algorithm (tonal-spot, vibrant…).
        // --source-color-index 0 bypasses dialoguer's interactive TTY prompt
        // that fails when matugen is invoked from a non-terminal context.
        root.pendingTargetMode = mode
        const scheme = SettingsService.data.appearance.matugenScheme || "scheme-tonal-spot"
        matugenProcess.command = [
            "bash", "-lc",
            "[ -r \"" + wallpaperPath + "\" ] || { printf '%s\\n' 'wallpaper path missing or unreadable: " + wallpaperPath + "' >&2; exit 2; }; mkdir -p \"$HOME/.config/yazi/flavors/dymicshell.yazi\"; cd \"" + root.matugenWorkingDir + "\" && matugen image \"" + wallpaperPath + "\" -c \"" + root.matugenConfigPath + "\" -m \"" + mode + "\" -t \"" + scheme + "\" --source-color-index 0 -q"
        ]
        matugenProcess.running = true
    }

    Component.onCompleted: {
        // Run matugen once at startup so color scheme is current.
        const path = SettingsService.data.appearance.wallpaperPath
        if (path !== "") _runMatugen(path)
        root.refreshDarkModeSchedule()
    }
}
