import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../services" as Services
import "WallpaperReveal.js" as RevealLogic
import "WallpaperBootLogic.js" as BootLogic

// Paint each screen's desktop with the configured wallpaper behind every surface.
// A switch reveals the incoming wallpaper through a circle that grows from the
// point that triggered it, then settles onto the base image.
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
    // Boot-completion keys, one per screen that already reported, in the
    // "<name>@<x>,<y>,<w>x<h>" form produced by WallpaperBootLogic.
    property var finishedBootScreens: []

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

            // Wallpaper that is decoded but not settled yet.
            property string pendingWallpaper: ""
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

            // Settled wallpaper that stays painted between swaps. Decoding is
            // synchronous so handing a wallpaper over never leaves a gap where
            // only the theme floor is painted.
            Image {
                id: baseImage
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: false
                cache: false
            }

            // Incoming wallpaper spreading out of the switch point.
            WallpaperReveal {
                id: reveal
                anchors.fill: parent
                source: wallpaperWindow.pendingWallpaper
                origin: wallpaperWindow.activeRevealOrigin
                radius: wallpaperWindow.revealRadius
            }

            // Grow the circle from the trigger point, then hand the wallpaper
            // over to the settled layer in the same synchronous step.
            NumberAnimation {
                id: revealAnimation
                target: wallpaperWindow
                property: "revealRadius"
                to: reveal.coverRadius
                duration: MotionTokens.wallpaperSwap
                easing.type: Easing.OutCubic

                onFinished: {
                    // Read the boot flag before settle() retires this reveal.
                    var wasBootReveal = wallpaperWindow.bootRevealActive
                    wallpaperWindow.settle(wallpaperWindow.pendingWallpaper)
                    // The transition is over, so the palette may catch up.
                    Services.ColorService.revealCompleted()
                    if (wasBootReveal)
                        wallpaperWindow.reportBootOutcome()
                }
            }

            // Fade the settled layer away when the wallpaper is cleared.
            NumberAnimation {
                id: hideAnimation
                target: baseImage
                property: "opacity"
                to: 0
                duration: MotionTokens.wallpaperSwap
                easing.type: Easing.OutCubic
            }

            // Adopt a wallpaper as settled and retire the reveal. Both source
            // assignments are synchronous, so no frame is ever left without a
            // wallpaper painted.
            function settle(path) {
                revealAnimation.stop()
                hideAnimation.stop()
                wallpaperWindow.pendingWallpaper = ""
                wallpaperWindow.revealRadius = 0
                // Nothing is waiting for a boot image anymore, so a late decode
                // must not start a reveal for a wallpaper that is already gone.
                wallpaperWindow.bootRevealWaitingForImage = false
                if (path)
                    baseImage.source = path
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
                var failed = reveal.imageFailed && String(reveal.source) === String(path)
                return BootLogic.bootOutcome(path, baseImage.source, failed,
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
                    wallpaperWindow.settle("")
                } else if (outcome === "reduced-motion") {
                    // A direct settle still owns the settled layer, exactly like
                    // the live branch it replaces.
                    baseImage.opacity = 1
                    wallpaperWindow.settle(path)
                } else {
                    // "unchanged": the settled layer already shows this path, so
                    // the only thing left to do is take the floor back from a
                    // previous fade-out.
                    baseImage.opacity = 1
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
                baseImage.opacity = 1
                if (path === String(baseImage.source)) {
                    wallpaperWindow.reportBootIfActive()
                    return
                }
                if (MotionTokens.reducedMotion) {
                    wallpaperWindow.settle(path)
                    // No animation will hold the palette back.
                    Services.ColorService.revealCompleted()
                    wallpaperWindow.reportBootIfActive()
                    return
                }
                // An interrupted reveal hands its wallpaper over before the new
                // one starts, so a rapid second switch never drops a frame.
                if (wallpaperWindow.pendingWallpaper !== "")
                    wallpaperWindow.settle(wallpaperWindow.pendingWallpaper)
                // The reveal image decodes synchronously, so the pixels are
                // already in place by the time the circle starts growing.
                wallpaperWindow.activeRevealOrigin = wallpaperWindow.resolveRevealOrigin()
                wallpaperWindow.pendingWallpaper = path
                wallpaperWindow.revealRadius = 0
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

            // The reveal decodes synchronously, so a failure is the only reason
            // the circle would never grow.
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
                    console.warn("WallpaperBackground: failed to load", reveal.source)
                    // A live switch keeps its own failure handling: return to the
                    // floor and free the palette, with no boot report.
                    if (!wallpaperWindow.bootRevealActive) {
                        wallpaperWindow.settle("")
                        Services.ColorService.revealCompleted()
                        return
                    }
                    // A boot wallpaper that never decodes is classified by the same
                    // seam the boot tests assert, so this path reports through the
                    // "error" outcome instead of waiting on a circle that cannot
                    // open. The theme floor is what stays up.
                    wallpaperWindow.settleWithoutReveal(
                        wallpaperWindow.bootOutcomeFor(reveal.source), "")
                }
            }

            // Pick up a wallpaper restored from persisted settings on startup.
            Component.onCompleted: {
                wallpaperWindow.showWallpaper(Services.SettingsService.appearance.wallpaperPath)
            }
        }
    }
}
