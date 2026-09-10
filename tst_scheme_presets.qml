import QtQuick
import Quickshell.Io
import "./services" as Services
import "./modules/lazerbar" as Lazer

// Regression harness for the preset color scheme system (noctalia model):
// selects a bundled preset with wallpaper adaptation off, verifies Color
// tokens follow the preset's light/dark variants, preset switching, and
// the fallback back to the wallpaper palette.
Item {
    id: root

    property int failures: 0
    property int phase: 0
    property int ticks: 0
    property var saved: ({})
    // Expected surfaces parsed from the scheme files themselves.
    property var catData: null
    property var nordData: null

    function check(label, cond, extra) {
        if (cond) {
            console.log("PASS:", label)
            return true
        }
        root.failures++
        console.log("FAIL:", label, extra !== undefined ? "| " + extra : "")
        return false
    }

    function variantSurface(data) {
        if (!data)
            return ""
        const light = Services.SettingsService.effectiveColorScheme === "light"
        const v = light ? (data.light || data.dark) : (data.dark || data.light)
        return v ? String(v.surface) : ""
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
        if (root.ticks > 250) {
            root.check("harness completes before deadline (phase " + root.phase + ")", false)
            root.finish()
            return
        }
        switch (root.phase) {
        case 0: {
            if (Services.ColorSchemeService.schemes.length === 0)
                return
            if (!Services.ColorSchemeService.hasScheme("Catppuccin")
                    || !Services.ColorSchemeService.hasScheme("Nord"))
                return
            root.check("registry lists bundled presets",
                       Services.ColorSchemeService.schemes.length >= 9,
                       "count=" + Services.ColorSchemeService.schemes.length)
            catFile.path = Services.ColorSchemeService.pathFor("Catppuccin")
            nordFile.path = Services.ColorSchemeService.pathFor("Nord")
            root.saved.adapt = Services.SettingsService.appearance.themeAdaptation
            root.saved.preset = Services.SettingsService.appearance.presetScheme
            root.saved.scheme = Services.SettingsService.appearance.colorScheme
            root.phase = 1
            break
        }
        case 1: {
            if (!root.catData || !root.nordData)
                return
            Lazer.LazerTheme.settingsService = Services.SettingsService
            Services.SettingsService.appearance.themeAdaptation = false
            Services.SettingsService.appearance.presetScheme = "Catppuccin"
            root.phase = 2
            break
        }
        case 2: {
            // Preset active: tokens must equal the preset's variant surface.
            if (!root.catData)
                return
            const want = root.variantSurface(root.catData)
            if (want === "" || String(Services.Color.mSurface) !== want)
                return
            root.check("preset surface applied (variant-matched)", true, "surface=" + Services.Color.mSurface)
            root.check("LazerTheme follows preset palette", Lazer.LazerTheme.adapt === true)
            Services.SettingsService.appearance.colorScheme =
                Services.SettingsService.effectiveColorScheme === "light" ? "dark" : "light"
            root.phase = 3
            break
        }
        case 3: {
            // Variant flip without re-extraction.
            const want2 = root.variantSurface(root.catData)
            if (want2 === "" || String(Services.Color.mSurface) !== want2)
                return
            root.check("scheme flip switches preset variant", true, "surface=" + Services.Color.mSurface)
            Services.SettingsService.appearance.presetScheme = "Nord"
            root.phase = 4
            break
        }
        case 4: {
            // Preset switch.
            const want3 = root.variantSurface(root.nordData)
            if (want3 === "" || String(Services.Color.mSurface) !== want3)
                return
            root.check("preset switch applies Nord", true, "surface=" + Services.Color.mSurface)
            Services.SettingsService.appearance.themeAdaptation = true
            root.phase = 5
            break
        }
        case 5: {
            // Back to wallpaper: surface must no longer be Nord's.
            if (root.variantSurface(root.nordData) === "")
                return
            if (String(Services.Color.mSurface) === root.variantSurface(root.nordData))
                return
            root.check("wallpaper adaptation displaces preset", true,
                       "surface=" + Services.Color.mSurface)
            // Restore the user's original values.
            Services.SettingsService.appearance.themeAdaptation = root.saved.adapt
            Services.SettingsService.appearance.presetScheme = root.saved.preset
            Services.SettingsService.appearance.colorScheme = root.saved.scheme
            root.finish()
            break
        }
        }
    }

    function parseScheme(raw, key) {
        try {
            const data = JSON.parse(raw)
            if (key === "cat") root.catData = data
            else if (key === "nord") root.nordData = data
        } catch (e) {
        }
    }

    FileView {
        id: catFile
        path: ""
        watchChanges: false
        printErrors: false
        onLoaded: root.parseScheme(this.text(), "cat")
    }

    FileView {
        id: nordFile
        path: ""
        watchChanges: false
        printErrors: false
        onLoaded: root.parseScheme(this.text(), "nord")
    }
}
