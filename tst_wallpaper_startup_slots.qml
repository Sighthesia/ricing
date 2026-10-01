import QtQuick
import "./modules/lazerbar" as LazerBar

// Harness for the production wallpaper slot handover. It mounts the real
// WallpaperBackground, hands it a synthetic data-URL wallpaper, and checks that
// the reveal promotes the slot it was decoded into instead of decoding the same
// wallpaper a second time into the settled layer.
//
// The wallpaper is handed to the component's own public entry point
// (the PanelWindow's showWallpaper) rather than through SettingsService: writing
// wallpaperPath would persist a data URL into the session's settings.json, and a
// test run must not be able to leave the desktop without a wallpaper.
//
// A data URL is used so the assertion is about the *slot's own* source and its
// own decoded status, with nothing on disk that a second assignment could
// re-read. Qt re-encodes a data URL when it parses it, so the wallpaper is
// identified by a unique marker in it rather than by string equality.
//
// Window-only by construction — WallpaperBackground declares a PanelWindow and
// offscreen has no layer-shell backend, so `qs` cannot load this file headless.
// The runner classifies that as window-only and skips it; run it from the repo
// root only when a real session is acceptable:
//   qs -p tst_wallpaper_startup_slots.qml
Item {
    id: root

    property int failures: 0
    property int checks: 0
    // The wallpaper under test. A solid SVG needs no file on disk and decodes
    // everywhere. It carries a unique marker so the promoted slot's source can be
    // identified even after Qt has re-encoded the URL.
    readonly property string wallpaperSource: "data:image/svg+xml,"
        + encodeURIComponent(
            '<svg xmlns="http://www.w3.org/2000/svg" width="320" height="200">'
            + '<desc>afloat-slot-marker-3355aa</desc>'
            + '<rect width="320" height="200" fill="rgb(51,85,170)"/></svg>')
    readonly property string wallpaperMarker: "afloat-slot-marker-3355aa"
    // The WallpaperBackground instance, held for its per-screen windows.
    property var background: null
    // The PanelWindow, once the delegate has registered it.
    property var window: null
    // The settled role before the switch, and the slot the reveal was already
    // masking. Promotion must move the role off this value and land on the very
    // slot that was lent.
    property int bootSettledSlot: -1
    property var revealedSlot: null

    function check(label, condition, detail) {
        root.checks++
        if (condition) {
            console.log("PASS:", label)
            return
        }
        root.failures++
        console.log("FAIL:", label, detail !== undefined ? "| " + detail : "")
    }

    function finish() {
        awaitIdle.stop()
        awaitPromotion.stop()
        giveUp.stop()
        console.log("Totals: " + (root.failures === 0
            ? root.checks + " passed, 0 failed"
            : root.failures + " failed"))
        Qt.quit()
    }

    // The component publishes its windows; a Variants scope cannot be walked
    // from QML at all, so this is the only way in.
    function findWallpaperWindow() {
        if (!root.background || !root.background.screenWindows)
            return null
        var windows = root.background.screenWindows
        return windows.length > 0 ? windows[0] : null
    }

    // The reveal that owns the mask, found by capability: the slots are plain
    // images and the floor is a rectangle, so the reveal is the only child that
    // carries a sourceItem.
    function findReveal() {
        if (!root.window || !root.window.children)
            return null
        for (var index = 0; index < root.window.children.length; index++) {
            if (root.window.children[index].sourceItem !== undefined)
                return root.window.children[index]
        }
        return null
    }

    // Locate the surface. Whether it is idle is a separate, repeatable step: a
    // session that already has a wallpaper is mid-boot-reveal when the harness
    // starts, and capturing roles underneath a reveal in flight would compare
    // against a role that is about to move.
    function begin() {
        root.window = root.findWallpaperWindow()
        if (!root.window) {
            root.check("wallpaper window mounted", false,
                       "no window in the registered screen windows")
            root.finish()
            return
        }
        root.check("wallpaper window mounted", true)

        // The circle is sized from the surface, so a wallpaper cannot switch
        // before the window has a size.
        root.check("surface is ready for a reveal", root.window.surfaceReady === true,
                   "width=" + root.window.width + " height=" + root.window.height)
        awaitIdleStep()
    }

    // Idle means: the boot outcome is terminal, nothing is waiting on a decode,
    // and no circle is growing. Only then are the roles stable enough to read.
    function awaitIdleStep() {
        if (!root.window.bootCompletionReported
                || root.window.pendingWallpaper !== ""
                || root.window.revealRadius !== 0) {
            awaitIdle.restart()
            return
        }
        // Stop before reading anything: this timer repeats, and letting it run
        // past the gate would re-enter here, see the window go non-idle again
        // under the switch it just triggered, and keep triggering more.
        awaitIdle.stop()
        root.bootSettledSlot = root.window.settledSlot
        var reveal = root.findReveal()
        root.revealedSlot = reveal ? reveal.sourceItem : null
        // The reveal must be masking the *incoming* slot: promoting it is only
        // the same image if the reveal and the handover agreed on which slot was
        // in flight.
        root.check("reveal masks the incoming slot, not the settled one",
                   !!root.revealedSlot
                       && root.revealedSlot === root.window.incomingImage
                       && root.revealedSlot !== root.window.settledImage,
                   "sourceItem=" + root.revealedSlot)
        // Whatever this screen booted with, the slot about to be filled is empty:
        // the outgoing one is released on every promotion.
        root.check("incoming slot starts empty",
                   !!root.revealedSlot && String(root.revealedSlot.source) === "",
                   "incoming source=" + (root.revealedSlot ? root.revealedSlot.source : "no slot"))

        // The window has been measured for a turn now, so the switch can go
        // through the same entry point startup and a panel commit both use.
        Qt.callLater(function() {
            root.window.showWallpaper(root.wallpaperSource)
            awaitPromotion.restart()
        })
    }

    // Poll rather than trusting a fixed delay: a boot image decodes
    // asynchronously and the circle then animates for MotionTokens.wallpaperSwap.
    function checkPromotion() {
        // Promotion is done once the role moved and the reveal retired.
        if (root.window.settledSlot === root.bootSettledSlot
                || root.window.pendingWallpaper !== "") {
            awaitPromotion.restart()
            return
        }
        var settled = root.window.settledImage
        var incoming = root.window.incomingImage

        // The whole point of the change: the settled slot *is* the slot the
        // reveal decoded, it still holds that wallpaper as its own source, and
        // it is already decoded — nothing had to be assigned to make it ready.
        root.check("settled slot is the slot the reveal sampled",
                   settled === root.revealedSlot,
                   "settled=" + settled + " revealed=" + root.revealedSlot)
        root.check("settled slot kept the incoming wallpaper as its own source",
                   String(settled.source).indexOf(root.wallpaperMarker) >= 0
                       && String(settled.source).indexOf("data:image/svg") === 0,
                   "source=" + settled.source)
        root.check("promoted slot is decoded without a second source assignment",
                   settled.status === Image.Ready, "status=" + settled.status)
        // Roles are a pair: the promoted one is settled and the other is now the
        // incoming slot, whichever pair this screen started from.
        root.check("slot roles swapped to the promoted pair",
                   root.window.settledSlot !== root.bootSettledSlot
                       && root.window.incomingSlot === root.bootSettledSlot
                       && root.window.settledSlot !== root.window.incomingSlot,
                   "settled=" + root.window.settledSlot
                       + " incoming=" + root.window.incomingSlot
                       + " was=" + root.bootSettledSlot)
        // The outgoing slot is released only after the swap, so the slot that is
        // now incoming is the empty one.
        root.check("outgoing slot released its source after promotion",
                   String(incoming.source) === "", "incoming source=" + incoming.source)
        root.check("only the promoted slot is painted",
                   settled.visible === true && incoming.visible === false,
                   "settled visible=" + settled.visible
                       + " incoming visible=" + incoming.visible)
        root.check("reveal retired with the circle closed", root.window.revealRadius === 0)
        root.check("boot outcome reported", root.window.bootCompletionReported === true)
        root.finish()
    }

    // The window may still be running its own boot reveal when this harness
    // starts, so the pre-switch state is polled rather than sampled.
    Timer {
        id: awaitIdle
        interval: 60
        repeat: true
        onTriggered: root.awaitIdleStep()
    }

    Timer {
        id: awaitPromotion
        interval: 60
        repeat: true
        onTriggered: root.checkPromotion()
    }

    // A ceiling, so a reveal that never promotes reports what it was doing
    // instead of hanging until the runner's own timeout.
    Timer {
        id: giveUp
        interval: 9000
        repeat: false
        onTriggered: {
            root.check("wallpaper switch promoted a slot", false,
                       "settledSlot=" + root.window.settledSlot
                           + " was=" + root.bootSettledSlot
                           + " pending=" + JSON.stringify(root.window.pendingWallpaper)
                           + " radius=" + root.window.revealRadius
                           + " bootReported=" + root.window.bootCompletionReported)
            root.finish()
        }
    }

    // The production surface under test, mounted exactly as the shell does.
    LazerBar.WallpaperBackground {
        id: wallpaperBackground
    }

    // The delegate registers its window from its own completion handler, so
    // mounting is observed rather than assumed.
    Component.onCompleted: {
        root.background = wallpaperBackground
        mountProbe.restart()
        giveUp.restart()
    }

    Timer {
        id: mountProbe
        interval: 400
        repeat: false
        onTriggered: root.begin()
    }
}