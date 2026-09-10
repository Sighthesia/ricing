pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "./" as Services

// Apply the shell's active palette to system apps (noctalia/DymicShell
// model): renders kitty/GTK/qtct templates from the palette for the
// effective light/dark mode and syncs the system color-scheme preference.
// Triggered on scheme flips, palette source changes and wallpaper
// extraction writes; opt-in via appearance.syncAppThemes.
//
// Deliberately resolves preset paths inside the helper script: passing a
// scheme NAME keeps this service free of cross-singleton registry state,
// whose lazy instantiation can fork stale copies under Quickshell.
Singleton {
    id: root

    readonly property bool enabled: Services.SettingsService.appearance.syncAppThemes === true
    readonly property bool presetActive: {
        const appearance = Services.SettingsService.appearance
        return appearance.themeAdaptation === false
            && String(appearance.presetScheme || "") !== ""
    }
    readonly property string presetName: presetActive
        ? String(Services.SettingsService.appearance.presetScheme || "")
        : ""

    // Test seam: prefix redirected sandbox + hook skip (see script).
    readonly property string homePrefix: Quickshell.env("AFLOAT_APP_THEME_PREFIX") || ""

    function apply() {
        if (!root.enabled)
            return
        const mode = Services.SettingsService.effectiveColorScheme
        if (mode === "")
            return
        let target
        if (root.presetName !== "") {
            target = "--scheme-name '" + root.presetName + "'"
        } else {
            // Wallpaper palette may not exist yet (fresh cache); the watch
            // triggers a re-apply once extraction lands.
            if (!root._colorsWatch.loaded)
                return
            target = "--palette '" + Quickshell.cacheDir + "/colors.json'"
        }
        const prefix = root.homePrefix !== "" ? " --home-prefix '" + root.homePrefix + "'" : ""
        const cmd = "python3 " + Quickshell.shellDir
            + "/scripts/theming/apply_app_themes.py " + target
            + " --mode '" + mode + "'" + prefix
        applyProcess.command = ["sh", "-c", cmd]
        // Restart-safe: bounce so a run while running re-fires after exit.
        applyProcess.running = false
        applyProcess.running = true
    }

    property Process applyProcess: Process {
        id: applyProcess

        stdout: SplitParser {
            onRead: data => console.log("AppTheme:", data)
        }
        stderr: SplitParser {
            onRead: data => console.warn("AppTheme:", data)
        }
    }

    // Scheme flips and palette source changes re-apply immediately.
    property Connections _settingsConnection: Connections {
        target: Services.SettingsService
        function onEffectiveColorSchemeChanged() { root.apply() }
    }

    property Connections _appearanceConnection: Connections {
        target: Services.SettingsService.appearance
        function onPresetSchemeChanged() { root.apply() }
        function onThemeAdaptationChanged() { root.apply() }
        function onSyncAppThemesChanged() { root.apply() }
    }

    // Wallpaper extraction writes colors.json asynchronously; re-apply on
    // its file changes (debounced like Color.qml).
    property Timer _reloadTimer: Timer {
        interval: 400
        onTriggered: root.apply()
    }

    property FileView _colorsWatch: FileView {
        path: Quickshell.cacheDir + "/colors.json"
        watchChanges: true
        printErrors: false
        // The initial load can land after the startup apply attempt: treat
        // it like a change so the first apply is never lost to the race.
        onLoaded: root._reloadTimer.restart()
        onFileChanged: root._reloadTimer.restart()
    }

    Component.onCompleted: Qt.callLater(root.apply)
}
