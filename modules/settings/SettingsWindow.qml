import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "../../services" as Services

// One settings overlay window per screen; only the primary screen shows content.
Variants {
    id: root

    model: Quickshell.screens

    PanelWindow {
        id: settingsWindow

        required property var modelData

        screen: modelData
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            right: true
        }

        width: 480
        height: 600

        // Panel open state — driven by SettingsService
        visible: Services.SettingsService.panelVisible

        BackgroundEffect.blurRegion: Services.SettingsService.appearance.enableBlur ? settingsBlurRegion : null

        // Match compositor blur to the rounded settings panel.
        Region {
            id: settingsBlurRegion

            item: Services.SettingsService.panelVisible ? settingsSurfaceBlurInset : null
            radius: Math.max(0, settingsSurface.radius - Services.SettingsService.blurRegionInset)
        }

        function toggle() { Services.SettingsService.togglePanel() }
        function close() { Services.SettingsService.closePanel() }

        // Close on Escape
        Keys.onEscapePressed: close()

        // Semi-transparent rounded panel surface
        Rectangle {
            id: settingsSurface

            anchors.fill: parent
            anchors.margins: 8
            radius: 12
            color: Qt.alpha(Services.Color.mSurface, Services.SettingsService.panelSurfaceOpacity)
            border.color: Services.Color.mOutline
            border.width: 1

            Item {
                id: settingsSurfaceBlurInset

                anchors.fill: parent
                anchors.margins: Services.SettingsService.blurRegionInset
            }

            // Inner padding wrapper
            Item {
                anchors.fill: parent
                anchors.margins: 16

                SettingsContent {
                    anchors.fill: parent
                }
            }
        }
    }
}
