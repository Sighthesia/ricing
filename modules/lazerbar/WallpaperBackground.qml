import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../services" as Services

// Paint each screen's desktop with the configured wallpaper behind every surface.
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

            // Keep the window fully click-through; the desktop owns pointer input.
            mask: Region {}

            // Theme-colored floor so the screen never flashes black while
            // decoding or when no wallpaper is configured.
            Rectangle {
                anchors.fill: parent
                color: Services.SettingsService.appearance.colorScheme === "light" ? "#F2F0F5" : LazerTheme.bgDark

                Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
            }

            // Settled wallpaper that stays painted between swaps.
            Image {
                id: baseImage
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }

            // Incoming wallpaper decoded offstage, then faded over the base.
            Image {
                id: fadeImage
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                opacity: 0

                onStatusChanged: {
                    if (status === Image.Ready && source !== "") {
                        revealAnimation.restart()
                    } else if (status === Image.Error) {
                        console.warn("WallpaperBackground: failed to load", source)
                        fadeImage.source = ""
                    }
                }
            }

            // Crossfade the decoded image in, then settle it onto the base layer.
            SequentialAnimation {
                id: revealAnimation

                NumberAnimation {
                    target: fadeImage
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: MotionTokens.wallpaperSwap
                    easing.type: Easing.OutCubic
                }
                ScriptAction {
                    script: {
                        baseImage.source = fadeImage.source
                        fadeImage.opacity = 0
                    }
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

            // Single entry point so startup, panel commits, and file edits all
            // follow the same crossfade path.
            function showWallpaper(path) {
                revealAnimation.stop()
                hideAnimation.stop()
                if (!path) {
                    hideAnimation.restart()
                    return
                }
                baseImage.opacity = 1
                if (path === String(baseImage.source)) return
                fadeImage.opacity = 0
                fadeImage.source = path
            }

            // Route live wallpaper changes into the shared transition.
            Connections {
                target: Services.SettingsService.appearance

                function onWallpaperPathChanged() {
                    wallpaperWindow.showWallpaper(Services.SettingsService.appearance.wallpaperPath)
                }
            }

            // Pick up a wallpaper restored from persisted settings on startup.
            Component.onCompleted: {
                wallpaperWindow.showWallpaper(Services.SettingsService.appearance.wallpaperPath)
            }
        }
    }
}
