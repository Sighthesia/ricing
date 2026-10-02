pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../services" as Services
import "WallpaperReveal.js" as RevealLogic
import "WallpaperBootLogic.js" as BootLogic
import "WallpaperSlotLogic.js" as SlotLogic

// Paint each screen's desktop with the configured wallpaper behind every surface.
// A switch reveals the incoming wallpaper through a circle that grows from the
// point that triggered it, then settles by promoting the slot it was decoded
// into, so the handover paints pixels that are already there.
Variants {
    id: root
    model: Quickshell.screens

    // True once every screen currently present has reported its first wallpaper
    // outcome. This surface stays the shell's bootstrap layer, so the rest of
    // the shell waits behind this flag instead of racing the wallpaper.
    //
    // The flag is a binding over the live screen list instead of a stored bool:
    // Variants drops every child that is not a Scope, so a Connections object
    // here would never be instantiated and the flag would only ever move when
    // a screen reported. Reading Quickshell.screens inside the binding is what
    // makes a hotplug, an added screen, or a resolution change recompute it, and
    // it keeps bootReady false while no screen exists at all.
    readonly property bool bootReady: BootLogic.isReady(
        root.finishedBootScreens, root.currentBootKeys())
        && Services.SettingsService.settingsReady
    // True once the first wallpaper request has started. Chrome uses this as
    // the parallel bootstrap cue; bootReady remains the later lock-wave gate.
    property bool bootStarted: false
    // Boot-completion keys, one per screen that already reported, in the
    // "<name>@<x>,<y>,<w>x<h>" form produced by WallpaperBootLogic.
    property var finishedBootScreens: []
    // The per-screen windows this component owns, in mount order. `Variants`
    // instantiates its delegate inside a Scope whose `children` list cannot be
    // read from QML at all — asking it for a count throws "List doesn't define a
    // Count function" — so the delegate publishes its window here instead. That
    // makes it the only supported way in, and it is what
    // tst_wallpaper_startup_slots.qml asserts the slot handover through.
    property var screenWindows: []

    // Record or drop one screen's window. The array is replaced rather than
    // mutated in place, because a QML binding cannot see an in-place JS
    // mutation — that would leave every reader frozen on the first value.
    function registerScreenWindow(window) {
        if (!window || root.screenWindows.indexOf(window) >= 0)
            return
        root.screenWindows = root.screenWindows.concat([window])
    }

    function unregisterScreenWindow(window) {
        if (!window)
            return
        var index = root.screenWindows.indexOf(window)
        if (index < 0)
            return
        var retained = root.screenWindows.slice()
        retained.splice(index, 1)
        root.screenWindows = retained
    }

    // Screen keys as they exist right now, so a resolution change invalidates
    // the completion recorded for the old geometry.
    function currentBootKeys() {
        return BootLogic.currentKeys(Quickshell.screens)
    }

    // Drop completions for screens that are gone, so unplugging a screen does
    // not leave its key behind to satisfy a later screen of the same name.
    // Readiness itself is the binding above; this is only housekeeping.
    function refreshBootReady() {
        var current = currentBootKeys()
        var retained = []
        for (var index = 0; index < root.finishedBootScreens.length; index++) {
            if (current.indexOf(root.finishedBootScreens[index]) >= 0)
                retained.push(root.finishedBootScreens[index])
        }
        if (retained.length === root.finishedBootScreens.length)
            return
        root.finishedBootScreens = retained
    }

    // Record one screen's boot completion. Duplicate keys are ignored, so a
    // screen that reports twice cannot make the others' work count twice.
    function reportBootFinished(screenKey) {
        root.finishedBootScreens = BootLogic.markFinished(root.finishedBootScreens, screenKey)
        root.refreshBootReady()
    }

    function reportBootStarted() {
        if (root.bootStarted)
            return
        root.bootStarted = true
    }

    // The JsonAdapter starts with an empty wallpaper path before settings.json
    // lands. That empty default is not a terminal boot outcome when persisted
    // settings may still provide a wallpaper; wait for the adapter's readiness
    // signal instead of mounting chrome into a false empty boot.
    Connections {
        target: Services.SettingsService
        function onSettingsReadyChanged() {
            if (Services.SettingsService.settingsReady)
                root.refreshBootReady()
        }
    }

    Scope {
        id: screenScope
        required property var modelData

        PanelWindow {
            id: wallpaperWindow
            screen: screenScope.modelData
            color: "transparent"
            implicitWidth: Math.max(1, screenScope.modelData.width)
            implicitHeight: Math.max(1, screenScope.modelData.height)
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "afloat:wallpaper"
            anchors { top: true; bottom: true; left: true; right: true }

            // Wallpaper that is decoded into the incoming slot but not settled
            // yet.
            property string pendingWallpaper: ""
            // Which of the two fixed image slots is painted between swaps, and
            // which one is waiting for a wallpaper. Roles only: promotion moves
            // these two values and never assigns a source, because the incoming
            // slot already holds the decoded wallpaper the reveal just showed.
            property int settledSlot: 0
            property int incomingSlot: 1
            // Fade of the settled wallpaper, so clearing it still wipes to the
            // theme floor instead of snapping there.
            property real settledOpacity: 1
            // Request that arrived before the surface had a size.
            property string deferredWallpaper: ""
            // Boot choreography: the session's first wallpaper waits for its
            // own pixels instead of a fixed delay, so the circle never opens on
            // an empty surface and the rest of the shell never waits on a
            // guessed number of frames.
            property bool bootRevealActive: false
            // The boot wallpaper is assigned but not decoded yet; the reveal
            // starts from onImageReadyChanged.
            property bool bootRevealWaitingForImage: false
            // Whether this screen already told the root about its first outcome.
            property bool bootCompletionReported: false
            // Live reveal circle radius, driven by revealAnimation.
            property real revealRadius: 0
            // Circle centre captured when the reveal starts. It is snapshotted
            // because the service clears its trigger point right after the
            // change, and a live binding would move the circle mid-animation.
            property point activeRevealOrigin: Qt.point(0, 0)
            // Whether this screen already took its first wallpaper transition;
            // that one is the boot reveal.
            property bool settledOnce: false
            property bool bootWaitingForSettings: !Services.SettingsService.settingsReady
            // Decode budget for one wallpaper slot, in pixels. A wallpaper is
            // cropped to fill the screen, so decoding far past the screen's own
            // resolution is invisible, while two slots are live at once and each
            // full-screen RGBA8888 texture costs four bytes per pixel. 8 Mi
            // pixels is ~33 MB per slot and still covers a 4K panel whole at
            // DPR 1 (3840x2160 = 7.91 Mi px); anything larger is scaled down
            // proportionally by WallpaperSlotLogic.sourceSize().
            property int maxDecodePixels: 8 * 1024 * 1024

            // Screen centre, used whenever no click triggered the switch.
            readonly property point centrePoint: Qt.point(width / 2, height / 2)
            // The reveal circle is sized from the surface, so nothing can grow
            // until the window has been measured.
            readonly property bool surfaceReady: width > 0 && height > 0
            // Boot-completion key for this screen, built exactly like the root
            // builds it from Quickshell.screens so both sides always match.
            readonly property string bootScreenKey: BootLogic.screenKey(
                        screenScope.modelData.name, screenScope.modelData.x,
                        screenScope.modelData.y, screenScope.modelData.width,
                        screenScope.modelData.height)
            // Decode size for both slots, computed once from the stable screen
            // geometry rather than from the window: the surface can be laid out
            // and resized while a wallpaper is being decoded, and re-asking for
            // a different size mid-reveal would throw the decode away. A screen
            // resize does change it, which is when a re-decode is wanted.
            readonly property size wallpaperDecodeSize: {
                var decode = SlotLogic.sourceSize(screenScope.modelData.width,
                                                 screenScope.modelData.height,
                                                 screenScope.modelData.devicePixelRatio,
                                                 wallpaperWindow.maxDecodePixels)
                return Qt.size(decode.width, decode.height)
            }
            // The two slots, addressed by role. A role is only ever 0 or 1, so
            // neither read can fall through to "no slot" and leave a wallpaper
            // unpainted; the pair stays distinct because promotion swaps roles
            // rather than collapsing them.
            readonly property Image settledImage:
                        wallpaperWindow.settledSlot === 1 ? wallpaperSlot1 : wallpaperSlot0
            readonly property Image incomingImage:
                        wallpaperWindow.incomingSlot === 1 ? wallpaperSlot1 : wallpaperSlot0

            // The click that asked for this wallpaper, mapped onto this screen.
            // Screens the click did not land on reveal from their own centre.
            function resolveRevealOrigin() {
                var trigger = Services.WallpaperService.revealOrigin
                if (!trigger)
                    return wallpaperWindow.centrePoint
                var local = RevealLogic.localOrigin(trigger.x, trigger.y,
                    screenScope.modelData.x, screenScope.modelData.y, width, height)
                return local ? Qt.point(local.x, local.y) : wallpaperWindow.centrePoint
            }

            // Keep the window fully click-through; the desktop owns pointer input.
            mask: Region {}

            // Theme-colored floor so the screen never flashes black while
            // decoding or when no wallpaper is configured.
            Rectangle {
                anchors.fill: parent
                color: Services.SettingsService.effectiveColorScheme === "light" ? "#F2F0F5" : LazerTheme.bgDark

                Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
            }

            // The two wallpaper slots. Both are declared once for the life of the
            // screen, so a switch is a role swap plus a source assignment to the
            // incoming one — never a new full-screen image. Promotion keeps the
            // decoded pixels, which is what removes the second decode (and the
            // gap it used to risk) at handover.
            //
            // `cache: false` is deliberate: a wallpaper is far larger than
            // QPixmapCache's 10 MB limit, so a cached full-screen image never
            // gets a cache hit and would only hold a second copy in memory.
            Image {
                id: wallpaperSlot0
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                sourceSize: wallpaperWindow.wallpaperDecodeSize
                asynchronous: false
                cache: false
                visible: wallpaperWindow.settledSlot === 0
                opacity: wallpaperWindow.settledSlot === 0
                        ? wallpaperWindow.settledOpacity : 1
            }

            Image {
                id: wallpaperSlot1
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                sourceSize: wallpaperWindow.wallpaperDecodeSize
                asynchronous: false
                cache: false
                visible: wallpaperWindow.settledSlot === 1
                // Only the settled slot follows the fade. The incoming one is
                // sampled by the reveal's mask, which reads this item's opacity,
                // so it stays fully opaque even mid-fade-out.
                opacity: wallpaperWindow.settledSlot === 1
                        ? wallpaperWindow.settledOpacity : 1
            }

            // Incoming wallpaper spreading out of the switch point. It borrows
            // the incoming slot as its mask source rather than owning a private
            // image, so the wallpaper that is revealed is the very wallpaper
            // that gets promoted afterwards.
            WallpaperReveal {
                id: reveal
                anchors.fill: parent
                sourceItem: wallpaperWindow.incomingImage
                origin: wallpaperWindow.activeRevealOrigin
                radius: wallpaperWindow.revealRadius
            }

            // Grow the circle from the trigger point, then promote the slot it
            // was showing, in the same synchronous step.
            NumberAnimation {
                id: revealAnimation
                target: wallpaperWindow
                property: "revealRadius"
                to: reveal.coverRadius
                duration: MotionTokens.wallpaperSwap
                easing.type: Easing.OutCubic

                onFinished: {
                    // Read the boot flag before promotion retires this reveal.
                    var wasBootReveal = wallpaperWindow.bootRevealActive
                    wallpaperWindow.promoteIncoming()
                    // The transition is over, so the palette may catch up.
                    Services.ColorService.revealCompleted()
                    if (wasBootReveal)
                        wallpaperWindow.reportBootOutcome()
                }
            }

            // Fade the settled layer away when the wallpaper is cleared. Targets
            // the shared opacity so whichever slot holds the role fades with it.
            NumberAnimation {
                id: hideAnimation
                target: wallpaperWindow
                property: "settledOpacity"
                to: 0
                duration: MotionTokens.wallpaperSwap
                easing.type: Easing.OutCubic
            }

            // Hand the reveal's wallpaper over by swapping slot roles. The
            // promoted slot keeps the pixels the circle was already showing, so
            // there is no second source assignment here and no frame in which no
            // wallpaper is painted. The outgoing slot's source is only cleared
            // after the swap, because that is when it stops being the one on
            // screen.
            function promoteIncoming() {
                revealAnimation.stop()
                hideAnimation.stop()
                // Promotion only means something for a slot that actually decoded.
                // A direct settle fails inside its own source assignment and the
                // failure handler releases the slot, so promoting after that would
                // put an empty slot on screen and wipe the wallpaper that was
                // painted a moment ago.
                if (wallpaperWindow.incomingImage.status !== Image.Ready) {
                    wallpaperWindow.discardIncoming()
                    return
                }
                // Read before the swap: `settledImage` is role-derived, so after
                // the swap it names the slot that was incoming.
                var released = wallpaperWindow.settledImage
                var roles = SlotLogic.promote(wallpaperWindow.settledSlot, wallpaperWindow.incomingSlot)
                wallpaperWindow.pendingWallpaper = ""
                // Nothing is waiting for a boot image anymore, so a late decode
                // must not start a reveal for a wallpaper that is already gone.
                wallpaperWindow.bootRevealWaitingForImage = false
                wallpaperWindow.settledOpacity = 1
                wallpaperWindow.settledSlot = roles.settledSlot
                wallpaperWindow.incomingSlot = roles.incomingSlot
                wallpaperWindow.revealRadius = 0
                // Only now is the outgoing wallpaper's decode pointless. The
                // promoted slot is untouched: its pixels are what the circle was
                // already showing, which is the whole point of promoting.
                //
                // A collapsed pair is the one promotion cannot do: `released` is
                // then the very image that was just promoted, so releasing it
                // would wipe the wallpaper that is on screen. Fail closed instead
                // — keep the pixels, and hand the pair back distinct so the next
                // switch still has a spare slot. Everything above already
                // settled, so the transition is over either way.
                if (roles.settledSlot === roles.incomingSlot) {
                    console.warn("WallpaperBackground: refusing to promote a collapsed slot pair",
                                 wallpaperWindow.settledSlot, wallpaperWindow.incomingSlot)
                    wallpaperWindow.incomingSlot = SlotLogic.otherSlot(roles.settledSlot)
                    return
                }
                released.source = ""
            }

            // Give up on the incoming wallpaper without promoting it: a failed
            // decode is released and the settled slot keeps painting whatever it
            // already had.
            function discardIncoming() {
                revealAnimation.stop()
                hideAnimation.stop()
                wallpaperWindow.pendingWallpaper = ""
                wallpaperWindow.revealRadius = 0
                wallpaperWindow.bootRevealWaitingForImage = false
                wallpaperWindow.incomingImage.source = ""
            }

            // Settle a wallpaper with no circle at all (reduced motion). The
            // incoming slot decodes it synchronously and is promoted at once,
            // which is the same handover as an animated reveal minus the
            // animation — and still only one decode.
            function settleDirectly(path) {
                if (!path) {
                    wallpaperWindow.discardIncoming()
                    return
                }
                wallpaperWindow.incomingImage.asynchronous = false
                wallpaperWindow.incomingImage.source = path
                wallpaperWindow.promoteIncoming()
            }

            // Retry a request that landed before the first layout. Startup and
            // the settings file both land in that window, and a circle sized
            // from a zero-sized surface would simply never grow.
            Timer {
                id: layoutRetry
                interval: MotionTokens.fast
                onTriggered: {
                    if (wallpaperWindow.deferredWallpaper === "")
                        return
                    var path = wallpaperWindow.deferredWallpaper
                    wallpaperWindow.deferredWallpaper = ""
                    wallpaperWindow.showWallpaper(path)
                }
            }

            // Single entry point so startup, panel commits, and file edits all
            // follow the same reveal path.
            function showWallpaper(path) {
                if (!Services.SettingsService.settingsReady) {
                    wallpaperWindow.bootWaitingForSettings = true
                    return
                }
                wallpaperWindow.bootWaitingForSettings = false
                if (!wallpaperWindow.surfaceReady) {
                    wallpaperWindow.deferredWallpaper = path
                    layoutRetry.restart()
                    return
                }
                // The first wallpaper transition of a session is the boot
                // reveal and is reported to the root; everything after it
                // switches straight away and is never reported.
                if (!wallpaperWindow.settledOnce) {
                    wallpaperWindow.settledOnce = true
                    root.reportBootStarted()
                    wallpaperWindow.beginWallpaper(path, true)
                    return
                }
                wallpaperWindow.beginWallpaper(path, false)
            }

            // Tell the root this screen is done booting, at most once per key.
            // A boot outcome that never animates (empty path, unchanged source,
            // reduced motion, failed image) reports from here too, so the shell
            // behind the loader can never be stranded.
            function reportBootOutcome() {
                if (wallpaperWindow.bootCompletionReported)
                    return
                wallpaperWindow.bootCompletionReported = true
                root.reportBootFinished(wallpaperWindow.bootScreenKey)
            }

            // Report only when the transition in flight is this screen's boot
            // reveal, so a later live wallpaper switch never reports again.
            function reportBootIfActive() {
                if (wallpaperWindow.bootRevealActive)
                    wallpaperWindow.reportBootOutcome()
            }

            // A resolution change re-keys this screen, and the root drops the
            // completion it recorded for the old geometry, so re-arm it. The
            // wallpaper is already painted here, so this reports again without
            // animating anything.
            onBootScreenKeyChanged: {
                if (!wallpaperWindow.bootCompletionReported)
                    return
                if (wallpaperWindow.pendingWallpaper !== "")
                    return
                wallpaperWindow.bootCompletionReported = false
                wallpaperWindow.reportBootOutcome()
            }

            // How the boot reveal resolves, decided by the shared classifier the
            // boot tests assert. Only the boot path consults it, so a wallpaper
            // change after startup keeps deciding for itself.
            function bootOutcomeFor(path) {
                // Only a failure of *this* path counts: the previous wallpaper's
                // error must not turn a healthy incoming one into a direct settle.
                var failed = reveal.imageFailed
                        && String(wallpaperWindow.incomingImage.source) === String(path)
                return BootLogic.bootOutcome(path, wallpaperWindow.settledImage.source, failed,
                                             MotionTokens.reducedMotion)
            }

            // End the boot reveal on an outcome that has no circle to show. Every
            // outcome that completes immediately is a finished boot, so the screen
            // reports here instead of waiting on an animation that will never run.
            function settleWithoutReveal(outcome, path) {
                if (!BootLogic.bootOutcomeCompletesImmediately(outcome))
                    return
                if (outcome === "empty") {
                    wallpaperWindow.pendingWallpaper = ""
                    wallpaperWindow.revealRadius = 0
                    hideAnimation.restart()
                } else if (outcome === "error") {
                    wallpaperWindow.discardIncoming()
                } else if (outcome === "reduced-motion") {
                    // A direct settle still owns the settled slot, exactly like
                    // the live branch it replaces.
                    wallpaperWindow.settledOpacity = 1
                    wallpaperWindow.settleDirectly(path)
                } else {
                    // "unchanged": the settled slot already shows this path, so
                    // the only thing left to do is take the floor back from a
                    // previous fade-out.
                    wallpaperWindow.settledOpacity = 1
                }
                // No animation ran, so nothing holds the palette back.
                if (outcome === "error" || outcome === "reduced-motion")
                    Services.ColorService.revealCompleted()
                wallpaperWindow.reportBootIfActive()
            }

            // Everything past the boot reveal: switch immediately.
            function beginWallpaper(path, isBootReveal) {
                revealAnimation.stop()
                hideAnimation.stop()
                // The trigger point is consumed once so a later key write cannot
                // inherit a stale origin; every screen reads it before this runs.
                Qt.callLater(function() { Services.WallpaperService.revealOrigin = null })
                // A live switch that cuts an unreported boot reveal short still
                // completes that screen, otherwise an early wallpaper change
                // would leave the loader waiting forever.
                if (!isBootReveal && wallpaperWindow.bootRevealActive)
                    wallpaperWindow.reportBootOutcome()
                wallpaperWindow.bootRevealActive = !!isBootReveal
                // The boot reveal resolves through the shared classifier, so the
                // empty, unchanged, reduced-motion, and image-error branches are
                // one tested decision instead of three inline copies. A live
                // switch skips this and keeps its own branches below unchanged.
                if (wallpaperWindow.bootRevealActive) {
                    var boot = wallpaperWindow.bootOutcomeFor(path)
                    if (boot !== "reveal") {
                        wallpaperWindow.settleWithoutReveal(boot, path)
                        return
                    }
                }
                if (!path) {
                    wallpaperWindow.pendingWallpaper = ""
                    wallpaperWindow.revealRadius = 0
                    hideAnimation.restart()
                    wallpaperWindow.reportBootIfActive()
                    return
                }
                wallpaperWindow.settledOpacity = 1
                if (path === String(wallpaperWindow.settledImage.source)) {
                    wallpaperWindow.reportBootIfActive()
                    return
                }
                if (MotionTokens.reducedMotion) {
                    wallpaperWindow.settleDirectly(path)
                    // No animation will hold the palette back.
                    Services.ColorService.revealCompleted()
                    wallpaperWindow.reportBootIfActive()
                    return
                }
                // An interrupted reveal hands its wallpaper over before the new
                // one starts, so a rapid second switch never drops a frame. The
                // interrupted wallpaper is already decoded in its slot, so this
                // is a promotion and not another decode.
                if (wallpaperWindow.pendingWallpaper !== "")
                    wallpaperWindow.promoteIncoming()
                // The reveal circle starts from the click that asked for it.
                wallpaperWindow.activeRevealOrigin = wallpaperWindow.resolveRevealOrigin()
                // Only the initial boot image decodes asynchronously. Live
                // switches remain synchronous so their no-gap handover stays
                // unchanged. The flag is set before the source, because changing
                // `asynchronous` on an Image re-arms its load.
                wallpaperWindow.incomingImage.asynchronous = !!wallpaperWindow.bootRevealActive
                wallpaperWindow.pendingWallpaper = path
                wallpaperWindow.revealRadius = 0
                wallpaperWindow.incomingImage.source = path
                // The boot reveal waits for its own pixels; a live switch keeps
                // starting right away, which is what it always did.
                if (wallpaperWindow.bootRevealActive && !reveal.imageReady) {
                    wallpaperWindow.bootRevealWaitingForImage = true
                    return
                }
                wallpaperWindow.startRevealAnimation()
            }

            // Open the circle. Kept in one place so the boot path and the live
            // path share the palette gate and the animation restart.
            function startRevealAnimation() {
                wallpaperWindow.bootRevealWaitingForImage = false
                // Palette extraction is a ~1.6s CPU-bound job, so it waits for
                // the circle to finish growing.
                Services.ColorService.revealStarted()
                revealAnimation.restart()
            }

            // Route live wallpaper changes into the shared reveal path.
            Connections {
                target: Services.SettingsService.appearance

                function onWallpaperPathChanged() {
                    wallpaperWindow.showWallpaper(Services.SettingsService.appearance.wallpaperPath)
                }
            }

            // Housekeeping for the root's boot record: drop completions whose
            // screen is gone. Readiness itself is a root binding, so this only
            // has to run from inside a screen instance.
            Connections {
                target: Quickshell

                function onScreensChanged() {
                    root.refreshBootReady()
                }
            }

            // Readiness and failure now come from the injected slot rather than from
            // an image the reveal owns, and they still drive the host: a boot
            // wallpaper that never decodes is the only reason the circle would
            // never grow.
            Connections {
                target: reveal

                function onImageReadyChanged() {
                    // The boot reveal parks here until its own pixels exist.
                    if (reveal.imageReady && wallpaperWindow.bootRevealWaitingForImage)
                        wallpaperWindow.startRevealAnimation()
                }

                function onImageFailedChanged() {
                    if (!reveal.imageFailed)
                        return
                    console.warn("WallpaperBackground: failed to load",
                                 wallpaperWindow.incomingImage.source)
                    // A live switch keeps its own failure handling: release the
                    // failed decode and free the palette, with no boot report.
                    if (!wallpaperWindow.bootRevealActive) {
                        wallpaperWindow.discardIncoming()
                        Services.ColorService.revealCompleted()
                        return
                    }
                    // A boot wallpaper that never decodes is classified by the same
                    // seam the boot tests assert, so this path reports through the
                    // "error" outcome instead of waiting on a circle that cannot
                    // open. The theme floor is what stays up. The path comes from
                    // the slot that failed, not from a separate `source` property:
                    // the slot is where the wallpaper was assigned.
                    wallpaperWindow.settleWithoutReveal(
                        wallpaperWindow.bootOutcomeFor(String(wallpaperWindow.incomingImage.source)), "")
                }
            }

            // Pick up a wallpaper restored from persisted settings on startup.
            Component.onCompleted: {
                if (Services.SettingsService.settingsReady)
                    wallpaperWindow.showWallpaper(Services.SettingsService.appearance.wallpaperPath)
            }

            Connections {
                target: Services.SettingsService
                function onSettingsReadyChanged() {
                    if (!Services.SettingsService.settingsReady
                            || !wallpaperWindow.bootWaitingForSettings)
                        return
                    wallpaperWindow.showWallpaper(Services.SettingsService.appearance.wallpaperPath)
                }
            }
        }

        // Publish this screen's window on the root, and drop it again when the
        // screen goes away. It lives on the scope rather than the window because
        // the scope is the object `Variants` owns: a scope that is torn down
        // cannot leave a window behind in the registry.
        Component.onCompleted: root.registerScreenWindow(wallpaperWindow)
        Component.onDestruction: root.unregisterScreenWindow(wallpaperWindow)
    }
}
