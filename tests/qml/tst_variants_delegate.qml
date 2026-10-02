import QtQuick
import QtTest

// Structural contract for every `Variants` in the shell: its first child must be
// the per-screen `Scope`.
//
// `Variants.delegate` defaults to the first declared child
// (https://quickshell.org/docs/v0.3.1/types/Quickshell/Variants/), so a stray
// object placed above the `Scope` does not get dropped for being the wrong type —
// it becomes the delegate. The per-screen `Scope` is then never instantiated, so
// every window that component owns silently never reaches the compositor, while
// the rest of the shell mounts normally and nothing logs an error.
//
// That is exactly how the wallpaper surface disappeared once: a `Connections`
// added above the `Scope` in `WallpaperBackground` made the delegate a
// Connections, so no screen got a wallpaper window and the desktop fell through
// to niri's own background colour.
//
// Static by necessity: these files import Quickshell and declare surfaces, so
// qmltestrunner cannot mount them. Regenerate the file list after adding a
// component with `rg -l '^[[:space:]]*Variants[[:space:]]*\{' --glob '*.qml'`.
Item {
    id: root

    function readText(path) {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", Qt.resolvedUrl(path), false)
        xhr.send(null)
        return xhr.status === 200 ? xhr.responseText : ""
    }

    readonly property var variantsFiles: [
        "../../modules/bar/TopBar.qml",
        "../../modules/lazerbar/NotificationHost.qml",
        "../../modules/lazerbar/OverviewBackgroundWindow.qml",
        "../../modules/lazerbar/ScreenRoundedCorners.qml",
        "../../modules/lazerbar/TopBar.qml",
        "../../modules/lazerbar/WallpaperBackground.qml"
    ]

    // Name of the first object declared directly inside this file's `Variants`,
    // or "" when the file declares none. Comments, property assignments and
    // attached-style declarations never match, so the first match in document
    // order is the first child.
    function firstVariantsChild(path) {
        var text = root.readText(path)
        if (!text)
            return ""
        var lines = text.split("\n")
        var inside = false
        for (var index = 0; index < lines.length; index++) {
            var line = lines[index]
            if (!inside) {
                if (/^\s*Variants\s*\{/.test(line))
                    inside = true
                continue
            }
            // The `Variants` is the root object in every one of these files, so
            // its own closing brace is the one at column zero.
            if (/^\}/.test(line))
                return ""
            var match = /^\s*([A-Z][A-Za-z0-9_]*)\s*\{/.exec(line)
            if (match)
                return match[1]
        }
        return ""
    }

    TestCase {
        name: "VariantsDelegate"
        when: windowShown

        function test_everyVariantsTakesAScopeAsItsDelegate() {
            for (var index = 0; index < root.variantsFiles.length; index++) {
                var path = root.variantsFiles[index]
                compare(root.firstVariantsChild(path), "Scope", path
                        + ": the first child of Variants is its delegate, so nothing"
                        + " may be declared above the per-screen Scope")
            }
        }

        function test_wallpaperScopeIsTheDelegateAgain() {
            // The component that lost its surfaces, asserted directly so the
            // failure names the surface that went missing.
            verify(root.readText("../../modules/lazerbar/WallpaperBackground.qml")
                   .indexOf('WlrLayershell.namespace: "afloat:wallpaper"') >= 0)
        }
    }
}
