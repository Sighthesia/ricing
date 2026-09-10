import QtQuick
import "./services" as Services
import "./modules/lazerbar" as Lazer

// Regression harness for scheme-aware bar theming: flips the color scheme
// and verifies LazerTheme.barIcon/bgLight plus real BarIcon and
// BarPopupIdentity instances follow it (dark glyphs on the light bar, white
// glyphs on the dark bar; tinted identity icons; scheme-tinted bar surface).
Item {
    id: root

    property int failures: 0
    property int phase: 0
    property int ticks: 0
    property string savedScheme: ""
    property var iconInstance: null
    property var identityInstance: null

    function check(label, cond, extra) {
        if (cond) {
            console.log("PASS:", label)
            return
        }
        root.failures++
        console.log("FAIL:", label, extra !== undefined ? "| " + extra : "")
    }

    function overlayOf(icon) {
        if (!icon)
            return null
        var kids = []
        try {
            kids = icon.children || []
        } catch (e) {
            return null
        }
        for (var i = 0; i < kids.length; i++) {
            var c = kids[i]
            if (!c)
                continue
            var hasColor = false
            try {
                hasColor = c.color !== undefined
            } catch (e2) {
            }
            if (hasColor)
                return c
        }
        return null
    }

    function colorizerOf(item) {
        if (!item)
            return null
        var kids = []
        try {
            kids = item.children || []
        } catch (e3) {
            return null
        }
        for (var i = 0; i < kids.length; i++) {
            var c = kids[i]
            if (!c)
                continue
            var isColorizer = false
            try {
                isColorizer = c.colorizationColor !== undefined
            } catch (e4) {
            }
            if (isColorizer)
                return c
            var nested = root.colorizerOf(c)
            if (nested)
                return nested
        }
        return null
    }

    function accentStripOf(item) {
        if (!item)
            return null
        var kids = []
        try {
            kids = item.children || []
        } catch (e5) {
            return null
        }
        for (var i = 0; i < kids.length; i++) {
            var c = kids[i]
            if (!c)
                continue
            var isStrip = false
            try {
                isStrip = c.width === 4 && c.height === 24
                    && c.color !== undefined
                    && String(c.color) === String(Lazer.LazerTheme.settingsAccent)
            } catch (e6) {
            }
            if (isStrip)
                return c
            var nested = root.accentStripOf(c)
            if (nested)
                return nested
        }
        return null
    }

    function finish() {
        try {
            if (root.savedScheme !== "")
                Services.SettingsService.appearance.colorScheme = root.savedScheme
        } catch (e) {
        }
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
        if (root.ticks > 200) {
            root.check("harness completes before deadline (phase " + root.phase + ")", false)
            root.finish()
            return
        }
        switch (root.phase) {
        case 0: {
            Lazer.LazerTheme.settingsService = Services.SettingsService
            try {
                root.savedScheme = String(Services.SettingsService.appearance.colorScheme || "")
            } catch (e) {
            }
            var comp = Qt.createComponent("modules/bar/BarIcon.qml")
            if (comp.status !== Component.Ready) {
                root.check("BarIcon component loads", false, String(comp.errorString()))
                root.finish()
                return
            }
            root.iconInstance = comp.createObject(root, {
                width: 24,
                height: 24,
                source: Qt.resolvedUrl("modules/lazerbar/icons/bell.svg")
            })
            root.check("BarIcon instance created", !!root.iconInstance)
            if (!root.iconInstance)
                return
            var idComp = Qt.createComponent("modules/bar/BarPopupIdentity.qml")
            if (idComp.status !== Component.Ready) {
                root.check("BarPopupIdentity component loads", false, String(idComp.errorString()))
                root.finish()
                return
            }
            root.identityInstance = idComp.createObject(root, {
                title: "Volume",
                iconSource: Qt.resolvedUrl("modules/lazerbar/icons/bell.svg"),
                tintIcon: true
            })
            root.check("BarPopupIdentity instance created", !!root.identityInstance)
            if (!root.identityInstance)
                return
            try {
                Services.SettingsService.appearance.colorScheme = "light"
            } catch (e2) {
                root.check("colorScheme writable", false, String(e2))
                root.finish()
                return
            }
            root.phase = 1
            break
        }
        case 1: {
            // Light scheme: token and live overlay must read dark; bar
            // surface and rail take their scheme branches (palette-free
            // fallbacks here since colorService is not injected).
            if (!Lazer.LazerTheme.lightScheme)
                return
            var wantDark = "#1d1b20"
            if (String(Lazer.LazerTheme.barIcon) !== wantDark)
                return
            var overlay = root.overlayOf(root.iconInstance)
            if (!overlay)
                return
            // Tint cross-fades (100ms); wait for it to land before judging.
            if (String(overlay.color) !== wantDark)
                return
            root.check("light scheme flips barIcon dark", true)
            root.check("BarIcon overlay follows to dark", true)
            if (String(Lazer.LazerTheme.bgLight) !== "#f2f0f5")
                return
            root.check("light bar surface falls back to #F2F0F5", true)
            if (String(Lazer.LazerTheme.settingsRail) !== "#131217")
                return
            var colorizer = root.colorizerOf(root.identityInstance)
            if (!colorizer)
                return
            if (String(colorizer.colorizationColor) !== wantDark)
                return
            root.check("identity colorizer follows barIcon (dark)", true)
            var strip = root.accentStripOf(root.identityInstance)
            if (!strip || Math.abs(strip.height - 24) > 0.5 || Math.abs(strip.width - 4) > 0.5)
                return
            root.check("identity header carries accent tab", true)
            try {
                Services.SettingsService.appearance.colorScheme = "dark"
            } catch (e3) {
            }
            root.phase = 2
            break
        }
        case 2: {
            // Dark scheme: back to white glyphs.
            if (Lazer.LazerTheme.lightScheme)
                return
            var wantWhite = "#ffffff"
            if (String(Lazer.LazerTheme.barIcon) !== wantWhite)
                return
            var overlay2 = root.overlayOf(root.iconInstance)
            if (!overlay2 || String(overlay2.color) !== wantWhite)
                return
            root.check("dark scheme restores barIcon white", true)
            root.check("BarIcon overlay follows to white", true)
            if (String(Lazer.LazerTheme.bgDark) !== "#18171c")
                return
            root.check("dark bar surface falls back to bgDark", true)
            var colorizer2 = root.colorizerOf(root.identityInstance)
            if (!colorizer2 || String(colorizer2.colorizationColor) !== wantWhite)
                return
            root.check("identity colorizer follows barIcon (white)", true)
            root.finish()
            break
        }
        }
    }
}
