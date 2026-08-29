import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../../services" as Services

// Per-screen surface that niri places inside its overview backdrop (below the
// scaled workspace tiles) via the managed `place-within-backdrop` layer-rule.
// Visible only while niri's overview is open — niri controls that automatically.
Variants {
    id: root

    model: Quickshell.screens

    // Per-screen overview-backdrop surface
    Scope {
        id: screenScope

        required property var modelData

        PanelWindow {
            id: backdropWindow

            readonly property var cfg: Services.SettingsService.appearance
            readonly property string wallpaperPath: cfg.wallpaperPath || ""
            readonly property string wallpaperSource: {
                if (!wallpaperPath)
                    return ""
                return wallpaperPath.startsWith("file://") ? wallpaperPath : "file://" + wallpaperPath
            }

            screen: screenScope.modelData
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

            // Keep the window click-through; overview backdrop owns interaction.
            mask: Region {}

            // Solid-color method — fallback when no wallpaper or solid toggle on.
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
                cache: false
                source: backdropWindow.wallpaperSource
                layer.enabled: backdropWindow.cfg.overviewBackgroundBlur > 0
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blurMax: 64
                    blur: backdropWindow.cfg.overviewBackgroundBlur

                    Behavior on blur {
                        NumberAnimation {
                            duration: MotionTokens.fast
                            easing.type: Easing.OutCubic
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
                        duration: MotionTokens.fast
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }
}
