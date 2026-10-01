import QtQuick
import "./services" as Services
import "./modules/bar" as Bar

// Headless harness for the bar content's mod-hint anchor. BarContent is a
// plain Item, so it mounts on the offscreen platform: that covers the anchor
// the window hint popup is placed from, which the window-only popup harness
// cannot reach.
//
// No PanelWindow is declared here, so this never maps a surface.
Item {
    id: root

    property int failures: 0
    property int _checks: 0

    function check(label, actual, expected) {
        root._checks += 1
        if (actual === expected) {
            console.log("PASS:", label)
            return
        }
        failures++
        console.log("FAIL:", label, "expected", expected, "got", actual)
    }

    // The host subtracts half the popup width from the anchor and clamps the
    // result to the screen, so "centred" means the anchor is the bar's own
    // midpoint - and stays that way whatever the layout does.
    Component.onCompleted: {
        Qt.callLater(function() {
            root.check("anchor is the bar midpoint",
                content.hintAnchorX(), content.width / 2)
            root.check("anchor is a usable screen coordinate",
                isFinite(content.hintAnchorX()) && content.hintAnchorX() >= 0, true)

            // The panel must never be pinned to the left screen edge; an anchor
            // of 0 is what that failure looks like from the outside.
            root.check("anchor is not the screen edge",
                content.hintAnchorX() > 0, true)

            // Centring follows from the anchor alone, so it has to hold in the
            // state this harness actually runs in: no widgets mounted at all.
            root.check("anchor stays centred with no widgets",
                content.hintAnchorX(), content.width / 2)

            // Moving the content must move the anchor with it - that is what
            // keeps the menu centred after a screen resize.
            content.width = 1280
            root.check("anchor follows a bar width change",
                content.hintAnchorX(), 640)

            // No widget is hovered in this harness, so the hint's release path
            // must report that there is nothing to hand the popup back to.
            root.check("no live widget intent to restore",
                content.reemitHoverIntent(), false)

            console.log("Totals:", root._checks - root.failures, "passed,", root.failures, "failed")
            // Quickshell's Qt.quit() takes no arguments, and it is dropped unless
            // the shell has finished loading - so exit one event-loop turn later.
            Qt.callLater(function() { Qt.quit() })
        })
    }

    // Mounted at a realistic bar size so the anchor arithmetic runs against
    // geometry like the real bar's.
    Bar.BarContent {
        id: content
        objectName: "barContent"
        width: 1920
        height: 48
        screenName: "HEADLESS-1"
    }
}