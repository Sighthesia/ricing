pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "./" as Services

// Apply the shell's active palette to system apps (noctalia/DymicShell
// model): renders kitty/GTK/qtct templates from the palette for the
// effective light/dark mode. The system color-scheme preference (portals,
// libadwaita, Electron) is pushed independently via appearance.syncSystemTheme
// so mode flips reach Electron even when template sync stays off.
// Triggered on scheme flips, palette source changes and wallpaper
// extraction writes; templates opt-in via appearance.syncAppThemes.
//
// Deliberately resolves preset paths inside the helper script: passing a
// scheme NAME keeps this service free of cross-singleton registry state,
// whose lazy instantiation can fork stale copies under Quickshell.
Singleton {
    id: root

    readonly property bool enabled: Services.SettingsService.appearance.syncAppThemes === true
    // System light/dark push stays on for configs written before the key
    // existed, so Electron/portal apps follow mode flips out of the box.
    readonly property bool systemEnabled: Services.SettingsService.appearance.syncSystemTheme !== false
    readonly property bool presetActive: {
        const appearance = Services.SettingsService.appearance
        return appearance.themeAdaptation === false
            && String(appearance.presetScheme || "") !== ""
    }
    readonly property string presetName: presetActive
        ? String(Services.SettingsService.appearance.presetScheme || "")
        : ""

    // Transparent-terminal clear text (kitty dim_opacity/background_tint).
    // Defaults on so settings.json written before the key existed keeps
    // the compensation instead of silently dropping it.
    readonly property bool terminalClearText: Services.SettingsService.appearance.terminalClearText !== false

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
        const textFlag = root.terminalClearText ? "" : " --no-terminal-clear-text"
        const cmd = "python3 " + Quickshell.shellDir
            + "/scripts/theming/apply_app_themes.py " + target
            + " --mode '" + mode + "'" + textFlag + prefix
        applyProcess.command = ["sh", "-c", cmd]
        // Restart-safe: bounce so a run while running re-fires after exit.
        applyProcess.running = false
        applyProcess.running = true
    }

    // Push light/dark to the system without touching templates.
    // Runs on its own Process: onEffectiveColorSchemeChanged fires apply()
    // and pushSystemTheme() back-to-back, and sharing one Process let the
    // second command kill the full template render before it finished —
    // kitty/KDE outputs then only refreshed on restart (via the colors.json
    // reload timer). Separate processes let both run to completion.
    function pushSystemTheme() {
        if (!root.systemEnabled)
            return
        const mode = Services.SettingsService.effectiveColorScheme
        if (mode === "")
            return
        const prefix = root.homePrefix !== "" ? " --home-prefix '" + root.homePrefix + "'" : ""
        const cmd = "python3 " + Quickshell.shellDir
            + "/scripts/theming/apply_app_themes.py"
            + " --mode '" + mode + "' --only-system-theme" + prefix
        systemProcess.command = ["sh", "-c", cmd]
        // Restart-safe: bounce so a run while running re-fires after exit.
        systemProcess.running = false
        systemProcess.running = true
    }

    // The clear-text toggle only touches kitty.conf: sync it immediately
    // even when full app-theme sync is disabled (fast path, no rendering).
    // Own Process for the same reason as pushSystemTheme: never steal the
    // full-render slot (or vice versa) when the two fire together.
    function syncTerminalText() {
        const mode = Services.SettingsService.effectiveColorScheme || "dark"
        const textFlag = root.terminalClearText ? "" : " --no-terminal-clear-text"
        const prefix = root.homePrefix !== "" ? " --home-prefix '" + root.homePrefix + "'" : ""
        const cmd = "python3 " + Quickshell.shellDir
            + "/scripts/theming/apply_app_themes.py"
            + " --mode '" + mode + "' --only-kitty-text" + textFlag + prefix
        kittyTextProcess.command = ["sh", "-c", cmd]
        kittyTextProcess.running = false
        kittyTextProcess.running = true
    }

    // Full template render (kitty/GTK/KDE/niri). Never shares a Process
    // with the fast paths above.
    property Process applyProcess: Process {
        id: applyProcess

        stdout: SplitParser {
            onRead: data => console.log("AppTheme:", data)
        }
        stderr: SplitParser {
            onRead: data => console.warn("AppTheme:", data)
        }
    }

    // Light/dark-only push (gsettings color-scheme + gtk-theme).
    property Process systemProcess: Process {
        id: systemProcess

        stdout: SplitParser {
            onRead: data => console.log("AppTheme:", data)
        }
        stderr: SplitParser {
            onRead: data => console.warn("AppTheme:", data)
        }
    }

    // kitty.conf clear-text block only.
    property Process kittyTextProcess: Process {
        id: kittyTextProcess

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
        function onEffectiveColorSchemeChanged() { root.apply(); root.pushSystemTheme() }
    }

    property Connections _appearanceConnection: Connections {
        target: Services.SettingsService.appearance
        function onPresetSchemeChanged() { root.apply() }
        function onThemeAdaptationChanged() { root.apply() }
        function onSyncAppThemesChanged() { root.apply() }
        function onSyncSystemThemeChanged() { root.pushSystemTheme() }
        function onTerminalClearTextChanged() { root.syncTerminalText() }
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

    Component.onCompleted: Qt.callLater(function() { root.apply(); root.pushSystemTheme() })
}
