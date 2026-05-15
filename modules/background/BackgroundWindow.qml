import Quickshell
import Quickshell.Wayland
import QtQuick
import "../../services" as Services

// Render the wallpaper on each screen as a background-layer PanelWindow with crossfade transitions.
Variants {
    id: root

    model: Quickshell.screens

    // Per-screen wallpaper surface
    PanelWindow {
        id: wallpaperWindow

        required property var modelData

        screen: modelData
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // Solid color fallback when no wallpaper is set
        Rectangle {
            anchors.fill: parent
            color: Services.Color.mSurface
            visible: !currentImage.source.toString() && !nextImage.source.toString()
        }

        // Currently displayed wallpaper
        Image {
            id: currentImage
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            source: Services.WallpaperService.currentWallpaper ? "file://" + Services.WallpaperService.currentWallpaper : ""
        }

        // Next wallpaper for crossfade transition
        Image {
            id: nextImage
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: 0
            visible: opacity > 0

            onStatusChanged: {
                if (status === Image.Ready && _pendingTransition) {
                    _pendingTransition = false
                    fadeIn.start()
                }
            }
        }

        property bool _pendingTransition: false

        // Crossfade: fade in next, then swap to current
        NumberAnimation {
            id: fadeIn
            target: nextImage
            property: "opacity"
            from: 0; to: 1
            duration: 400
            easing.type: Easing.OutCubic
            onFinished: {
                currentImage.source = nextImage.source
                nextImage.opacity = 0
                nextImage.source = ""
            }
        }

        Connections {
            target: Services.WallpaperService
            function onWallpaperChanged(path) {
                if (!path) return
                var newSource = "file://" + path
                // Skip if this is the same as what's already showing (e.g. initial load)
                if (newSource === currentImage.source.toString()) return
                nextImage.source = newSource
                wallpaperWindow._pendingTransition = true
            }
        }
    }
}
