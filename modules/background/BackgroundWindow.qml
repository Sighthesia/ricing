import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.services

// Per-screen wallpaper window rendered at the background layer.
// One instance is created per monitor via Variants.
// Wallpaper transitions are handled in Task 7 (disc reveal animation).
Variants {
    id: root
    model: Quickshell.screens

    // One PanelWindow per screen
    PanelWindow {
        id: bgRoot

        property var modelData

        screen: modelData

        // Sit below everything — true background layer
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "dymicshell-background"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        // Stretch edge-to-edge
        anchors {
            top: true; bottom: true; left: true; right: true
        }

        color: "black"

        // The single static image — updated when wallpaper changes
        Image {
            id: wallpaperImg
            anchors.fill: parent
            source: SettingsService.data.appearance.wallpaperPath !== ""
                    ? ("file://" + SettingsService.data.appearance.wallpaperPath)
                    : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
        }
    }
}
