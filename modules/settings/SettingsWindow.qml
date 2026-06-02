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

        implicitWidth: 480
        implicitHeight: 600

        // Panel open state — driven by SettingsService
        visible: Services.SettingsService.panelVisible

        BackgroundEffect.blurRegion: Services.SettingsService.appearance.enableBlur ? settingsBlurRegion : null

        // Match compositor blur to the rounded settings panel.
        Region {
            id: settingsBlurRegion

            item: Services.SettingsService.panelVisible ? settingsSurfaceBlurSource : null
            radius: settingsSurface.radius
        }

        function toggle() { Services.SettingsService.togglePanel() }
        function close() { Services.SettingsService.closePanel() }

        // Semi-transparent rounded panel surface
        Rectangle {
            id: settingsSurface

            anchors.fill: parent
            anchors.margins: 8
            radius: 12
            color: Qt.alpha(Services.Color.mSurface, Services.SettingsService.panelSurfaceOpacity)

            // Full-size blur source — covers the entire visible fill geometry.
            Item {
                id: settingsSurfaceBlurSource

                anchors.fill: parent
            }

            // Inner padding wrapper
            Item {
                anchors.fill: parent
                anchors.margins: 16

                focus: Services.SettingsService.panelVisible

                Keys.onEscapePressed: settingsWindow.close()

                SettingsContent {
                    anchors.fill: parent
                }
            }

            // Border overlay rendered above all content.
            Rectangle {
                anchors.fill: parent
                radius: settingsSurface.radius
                color: "transparent"
                border.color: Services.Color.mOutline
                border.width: 1
            }
        }
    }
}
