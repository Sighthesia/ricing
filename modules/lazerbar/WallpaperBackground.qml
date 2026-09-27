import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../services" as Services
import "WallpaperReveal.js" as RevealLogic

// Paint each screen's desktop with the configured wallpaper behind every surface.
// A switch reveals the incoming wallpaper through a circle that grows from the
// point that triggered it, then settles onto the base image.
Variants {
    id: root
    model: Quickshell.screens

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
            // Live reveal circle radius, driven by revealAnimation.
            property real revealRadius: 0
            // Circle centre captured when the reveal starts. It is snapshotted
            // because the service clears its trigger point right after the
            // change, and a live binding would move the circle mid-animation.
            property point activeRevealOrigin: Qt.point(0, 0)
            // Screen centre, used whenever no click triggered the switch.
            readonly property point centrePoint: Qt.point(width / 2, height / 2)
            // The reveal circle is sized from the surface, so nothing can grow
            // until the window has been measured.
            readonly property bool surfaceReady: width > 0 && height > 0

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

                onFinished: wallpaperWindow.settle(wallpaperWindow.pendingWallpaper)
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
                revealAnimation.stop()
                hideAnimation.stop()
                // The trigger point is consumed once so a later key write cannot
                // inherit a stale origin; every screen reads it before this runs.
                Qt.callLater(function() { Services.WallpaperService.revealOrigin = null })
                if (!path) {
                    wallpaperWindow.pendingWallpaper = ""
                    wallpaperWindow.revealRadius = 0
                    hideAnimation.restart()
                    return
                }
                baseImage.opacity = 1
                if (path === String(baseImage.source))
                    return
                if (MotionTokens.reducedMotion) {
                    wallpaperWindow.settle(path)
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
                revealAnimation.restart()
            }

            // Route live wallpaper changes into the shared reveal path.
            Connections {
                target: Services.SettingsService.appearance

                function onWallpaperPathChanged() {
                    wallpaperWindow.showWallpaper(Services.SettingsService.appearance.wallpaperPath)
                }
            }

            // The reveal decodes synchronously, so a failure is the only reason
            // the circle would never grow.
            Connections {
                target: reveal

                function onImageFailedChanged() {
                    if (!reveal.imageFailed)
                        return
                    console.warn("WallpaperBackground: failed to load", reveal.source)
                    wallpaperWindow.settle("")
                }
            }

            // Pick up a wallpaper restored from persisted settings on startup.
            Component.onCompleted: {
                wallpaperWindow.showWallpaper(Services.SettingsService.appearance.wallpaperPath)
            }
        }
    }
}
