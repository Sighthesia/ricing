import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import "../../services" as Services

// Per-screen surface that niri places inside its overview backdrop (below the
// scaled workspace tiles) via the managed `place-within-backdrop` layer-rule.
// Visible only while niri's overview is open — niri controls that automatically.
Variants {
    id: root

    model: Quickshell.screens

    // Per-screen overview-backdrop surface
    PanelWindow {
        id: backdropWindow

        required property var modelData
        readonly property var cfg: Services.SettingsService.appearance

        screen: modelData
        color: "transparent"
        // Only map the surface when the feature is enabled; niri's layer-rule
        // matches the namespace and renders it in the overview backdrop.
        visible: cfg.overviewBackground
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "afloat-overview-backdrop"

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // Solid-color method
        Rectangle {
            anchors.fill: parent
            visible: backdropWindow.cfg.overviewBackgroundSolid
            color: Services.Color.mSurface
        }

        // Wallpaper method: static when blur is 0, GPU-blurred when > 0
        Image {
            id: backdropImage
            anchors.fill: parent
            visible: !backdropWindow.cfg.overviewBackgroundSolid
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            source: Services.WallpaperService.currentWallpaper ? "file://" + Services.WallpaperService.currentWallpaper : ""
            layer.enabled: backdropWindow.cfg.overviewBackgroundBlur > 0
            layer.effect: MultiEffect {
                blurEnabled: true
                blurMax: 48
                blur: backdropWindow.cfg.overviewBackgroundBlur
                Behavior on blur {
                    NumberAnimation {
                        duration: Services.Motion.number.crossfadeDuration
                        easing.type: Services.Motion.number.crossfadeEasing
                    }
                }
            }
        }

        // Theme tint shared by all methods
        Rectangle {
            anchors.fill: parent
            color: Services.Color.mSurface
            opacity: backdropWindow.cfg.overviewBackgroundTint
            Behavior on opacity {
                NumberAnimation {
                    duration: Services.Motion.number.crossfadeDuration
                    easing.type: Services.Motion.number.crossfadeEasing
                }
            }
        }
    }
}
