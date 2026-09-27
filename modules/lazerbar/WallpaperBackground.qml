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
            // Live reveal circle radius, driven by revealAnimation.
            property real revealRadius: 0
            // Circle centre captured when the reveal starts. It is snapshotted
            // because the service clears its trigger point right after the
            // change, and a live binding would move the circle mid-animation.
            property point activeRevealOrigin: Qt.point(0, 0)
            // Screen centre, used whenever no click triggered the switch.
            readonly property point centrePoint: Qt.point(width / 2, height / 2)

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

            // Settled wallpaper that stays painted between swaps.
            Image {
                id: baseImage
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
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
            // over to the settled layer.
            NumberAnimation {
                id: revealAnimation
                target: wallpaperWindow
                property: "revealRadius"
                to: reveal.coverRadius
                duration: MotionTokens.wallpaperSwap
                easing.type: Easing.OutCubic

                onFinished: wallpaperWindow.handOverReveal()
            }

            // The settled layer is filled asynchronously, so the reveal has to
            // stay up until it really has pixels. Bailing out early would show
            // the bare theme colour right at the end of the transition, which
            // reads as a flash before the wallpaper snaps in.
            Timer {
                id: handoverTimeout
                interval: MotionTokens.wallpaperSwap * 2
                onTriggered: wallpaperWindow.endReveal()
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

            // Adopt a wallpaper as settled without any transition.
            function settle(path) {
                revealAnimation.stop()
                hideAnimation.stop()
                handoverTimeout.stop()
                wallpaperWindow.pendingWallpaper = ""
                wallpaperWindow.revealRadius = 0
                baseImage.opacity = 1
                baseImage.source = path
            }

            // Start the settled layer decoding, then drop the reveal once its
            // pixels are in place (or once the fallback timer gives up).
            function handOverReveal() {
                if (wallpaperWindow.pendingWallpaper === "")
                    return
                baseImage.source = wallpaperWindow.pendingWallpaper
                if (baseImage.status === Image.Ready) {
                    wallpaperWindow.endReveal()
                    return
                }
                handoverTimeout.restart()
            }

            // Retire the reveal; the settled layer now shows the same wallpaper.
            function endReveal() {
                handoverTimeout.stop()
                wallpaperWindow.pendingWallpaper = ""
                wallpaperWindow.revealRadius = 0
            }

            // Single entry point so startup, panel commits, and file edits all
            // follow the same reveal path.
            function showWallpaper(path) {
                revealAnimation.stop()
                hideAnimation.stop()
                handoverTimeout.stop()
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
                // Decode the incoming wallpaper first, then grow the circle once
                // the pixels are ready.
                wallpaperWindow.activeRevealOrigin = wallpaperWindow.resolveRevealOrigin()
                wallpaperWindow.pendingWallpaper = path
                wallpaperWindow.revealRadius = 0
                if (reveal.imageReady)
                    revealAnimation.restart()
            }

            // Route live wallpaper changes into the shared reveal path.
            Connections {
                target: Services.SettingsService.appearance

                function onWallpaperPathChanged() {
                    wallpaperWindow.showWallpaper(Services.SettingsService.appearance.wallpaperPath)
                }
            }

            // Start growing only once the incoming image can actually be shown.
            Connections {
                target: reveal

                function onImageReadyChanged() {
                    if (reveal.imageReady && wallpaperWindow.pendingWallpaper !== "")
                        revealAnimation.restart()
                }

                function onImageFailedChanged() {
                    if (!reveal.imageFailed)
                        return
                    console.warn("WallpaperBackground: failed to load", reveal.source)
                    wallpaperWindow.endReveal()
                }
            }

            // Retire the reveal as soon as the settled layer has the pixels.
            Connections {
                target: baseImage

                function onStatusChanged() {
                    if (baseImage.status === Image.Ready && wallpaperWindow.pendingWallpaper !== "")
                        wallpaperWindow.endReveal()
                }
            }

            // Pick up a wallpaper restored from persisted settings on startup.
            Component.onCompleted: {
                wallpaperWindow.showWallpaper(Services.SettingsService.appearance.wallpaperPath)
            }
        }
    }
}
