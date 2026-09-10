import QtQuick
import Quickshell.Io
import "./services" as Services
import "./modules/lazerbar" as Lazer

// Regression harness for app theme sync: runs AppThemeService with a
// sandboxed HOME prefix (AFLOAT_APP_THEME_PREFIX env) and verifies the
// rendered kitty/GTK outputs + include hooks + preset switching, without
// touching the real system config.
Item {
    id: root

    property int failures: 0
    property int phase: 0
    property int ticks: 0
    property string savedPreset: ""
    property string savedAdapt: ""
    property string savedScheme: ""
    property string prefix: ""

    function check(label, cond, extra) {
        if (cond) {
            console.log("PASS:", label)
            return true
        }
        root.failures++
        console.log("FAIL:", label, extra !== undefined ? "| " + extra : "")
        return false
    }

    function finish() {
        console.log("Totals: " + (root.failures === 0 ? "all passed" : root.failures + " failed"))
        // The local Quickshell host exposes Qt.quit() without an exit code.
        Qt.quit()
    }

    Timer {
        interval: 60
        repeat: true
        running: true
        onTriggered: root.tick()
    }

    function tick() {
        root.ticks++
        if (root.ticks > 300) {

            root.check("harness completes before deadline (phase " + root.phase + ")", false)
            root.finish()
            return
        }
        switch (root.phase) {
        case 0: {
            // The prefix must come from the launch env (Quickshell.env).
            root.prefix = Services.AppThemeService.homePrefix
            if (root.prefix === "") {
                root.check("AFLOAT_APP_THEME_PREFIX set at launch", false,
                           "relaunch harness with the env var")
                root.finish()
                return
            }
            if (Services.ColorSchemeService.schemes.length === 0)
                return
            root.savedPreset = Services.SettingsService.appearance.presetScheme
            root.savedAdapt = Services.SettingsService.appearance.themeAdaptation
            root.savedScheme = Services.SettingsService.appearance.colorScheme
            // Pin the scenario BEFORE enabling sync so the first apply
            // already targets the preset palette in a known variant.
            Services.SettingsService.appearance.colorScheme = "dark"
            Services.SettingsService.appearance.themeAdaptation = false
            Services.SettingsService.appearance.presetScheme = "Nord"
            Services.SettingsService.appearance.syncAppThemes = true
            root.phase = 1
            break
        }
        case 1: {

            // Wait for the sandboxed kitty output carrying Nord's surface.
            const f = root.fileText(root.prefix + "/.config/kitty/kitty-colors.conf")
            if (f === null)
                return
            if (f.indexOf("background #2e3440") < 0)
                return
            root.check("kitty colors rendered for Nord dark", true)
            // Include/import lines are appended by the same apply run; wait
            // for their files to carry content before judging.
            const kittyConf = root.fileText(root.prefix + "/.config/kitty/kitty.conf")
            const gtkCss = root.fileText(root.prefix + "/.config/gtk-3.0/gtk.css")
            if (kittyConf === null || kittyConf === "" || gtkCss === null || gtkCss === "")
                return
            root.check("kitty.conf include ensured",
                       kittyConf.indexOf("include kitty-colors.conf") >= 0)
            root.check("gtk css import ensured",
                       gtkCss.indexOf("@import 'colors.css';") >= 0)
            root.phase = 2
            break
        }
        case 2: {
            // Flip the variant: same preset, opposite mode.
            Services.SettingsService.appearance.colorScheme = "light"
            root.phase = 3
            break
        }
        case 3: {
            const path = root.prefix + "/.config/kitty/kitty-colors.conf"
            const f = root.fileText(path)
            if (f === null)
                return
            if (f.indexOf("background #eceff4") >= 0) {
                root.check("scheme flip re-renders app theme variant", true)
                // Restore user's values.
                Services.SettingsService.appearance.presetScheme = root.savedPreset
                Services.SettingsService.appearance.themeAdaptation = root.savedAdapt
                Services.SettingsService.appearance.colorScheme = root.savedScheme
                root.finish()
                return
            }
            // Stale read (apply lands async): drop the reader; the next
            // tick recreates it and picks up the fresh content.
            const entry = root._readers[path]
            if (entry) {
                entry.view.destroy()
                delete root._readers[path]
            }
            break
        }
        }
    }

    // Per-path FileView cache: returns text once loaded, null while pending,
    // "" when the file does not exist.
    property var _readers: ({})

    function fileText(path) {
        let entry = root._readers[path]
        if (!entry) {
            // doneCb is bound at creation: a fast synchronous load must not
            // race the callback assignment (phase 3 stalled on exactly that).
            entry = { done: false, text: "", view: null }
            root._readers[path] = entry
            entry.view = readerComp.createObject(root, {
                path: path,
                doneCb: function(t) {
                    entry.done = true
                    entry.text = t
                }
            })
            return null
        }
        return entry.done ? entry.text : null
    }

    Component {
        id: readerComp

        FileView {
            id: reader
            property var doneCb: null
            printErrors: false
            watchChanges: false
            onLoaded: if (doneCb) doneCb(text())
            // The file may not exist yet on first poll (apply is async):
            // retry until it shows up instead of caching the failure.
            onLoadFailed: reader.retryTimer.restart()
            property Timer retryTimer: Timer {
                interval: 150
                onTriggered: reader.reload()
            }
        }
    }
}
