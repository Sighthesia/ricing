import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../services" as Services
import "../../services/WidgetSettingsRegistry.js" as WidgetSettingsRegistry
import "widgetsettings" as WidgetPanels

// Floating per-widget settings panel anchored below the bar.
Variants {
    id: root

    model: Quickshell.screens

    // Keep one overlay window per screen and only show the active target screen.
    PanelWindow {
        id: settingsWindow

        required property var modelData

        readonly property string activeWidgetId: Services.BarLayoutService.activeWidgetSettingsId
        readonly property string panelTitle: WidgetSettingsRegistry.title(activeWidgetId)
        readonly property string panelType: WidgetSettingsRegistry.panelKey(activeWidgetId)

        screen: modelData
        visible: Services.BarLayoutService.widgetSettingsVisible
            && (Services.BarLayoutService.widgetSettingsScreenName === ""
                || Services.BarLayoutService.widgetSettingsScreenName === modelData.name)
        color: "transparent"
        implicitWidth: 320
        implicitHeight: panelCard.height + 16
        exclusiveZone: -1
        WlrLayershell.layer: WlrLayer.Overlay

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        BackgroundEffect.blurRegion: Services.SettingsService.appearance.enableBlur ? panelBlurRegion : null

        // Match blur to the visible settings card only.
        Region {
            id: panelBlurRegion

            item: Services.BarLayoutService.widgetSettingsVisible ? panelBlurSource : null
            radius: panelCard.radius
        }

        // Keep the floating settings card centered on the selected widget.
        Rectangle {
            id: panelCard

            x: Math.max(8, Math.min(
                Services.BarLayoutService.widgetSettingsX - width / 2,
                parent.width - width - 8
            ))
            y: Services.BarLayoutService.barHeight + 8
            width: 320
            height: contentColumn.implicitHeight + 24
            radius: 12
            color: Qt.alpha(Services.Color.mSurface, Services.SettingsService.panelSurfaceOpacity)
            opacity: Services.BarLayoutService.widgetSettingsVisible ? 1 : 0
            scale: Services.BarLayoutService.widgetSettingsVisible ? 1 : 0.96
            transformOrigin: Item.Top

            // Full-size blur source for the rounded card.
            Item {
                id: panelBlurSource

                anchors.fill: parent
            }

            Behavior on opacity { NumberAnimation { duration: Services.Motion.popup.opacityDuration; easing.type: Services.Motion.popup.opacityEasing } }
            Behavior on scale { NumberAnimation { duration: Services.Motion.popup.scaleDuration; easing.type: Services.Motion.popup.scaleEasing; easing.overshoot: Services.Motion.popup.scaleOvershoot } }

            // Keep settings content grouped in a compact floating column.
            Column {
                id: contentColumn

                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                // Header row for the active widget settings.
                Row {
                    width: parent.width
                    spacing: 8

                    Services.FluidText {
                        text: settingsWindow.panelTitle
                        color: Services.Color.mOnSurface
                        basePixelSize: 14
                        font.bold: true
                    }

                    Item {
                        width: parent.width - closeButton.width - 8 - childrenRect.width
                        height: 1
                    }

                    Rectangle {
                        id: closeButton

                        width: 22
                        height: 22
                        radius: 11
                        color: closeArea.containsMouse ? Qt.alpha(Services.Color.mSurfaceVariant, 0.9) : "transparent"
                        border.color: Services.Color.mOutline
                        border.width: 1

                        Services.FluidText {
                            anchors.centerIn: parent
                            text: "\u00d7"
                            color: Services.Color.mOnSurface
                            basePixelSize: 11
                            font.bold: true
                        }

                        MouseArea {
                            id: closeArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Services.BarLayoutService.closeWidgetSettings()
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Services.Color.mOutline
                    opacity: 0.5
                }

                // Load the registered settings panel for the active widget.
                Loader {
                    width: parent.width
                    active: settingsWindow.panelType !== ""
                    sourceComponent: settingsWindow.panelComponentForType(settingsWindow.panelType)
                }
            }

            // Border overlay rendered above the card content.
            Rectangle {
                anchors.fill: parent
                radius: panelCard.radius
                color: "transparent"
                border.color: Services.Color.mOutline
                border.width: 1
            }
        }

        Component {
            id: clockPanelComponent

            WidgetPanels.ClockSettingsPanel {
                width: parent ? parent.width : 0
            }
        }

        Component {
            id: activeWindowPanelComponent

            WidgetPanels.ActiveWindowSettingsPanel {
                width: parent ? parent.width : 0
            }
        }

        Component {
            id: batteryPanelComponent

            WidgetPanels.BatterySettingsPanel {
                width: parent ? parent.width : 0
            }
        }

        Component {
            id: systemMonitorPanelComponent

            WidgetPanels.SystemMonitorSettingsPanel {
                width: parent ? parent.width : 0
            }
        }

        Component {
            id: mediaPanelComponent

            WidgetPanels.MediaSettingsPanel {
                width: parent ? parent.width : 0
            }
        }

        function panelComponentForType(panelType) {
            switch (panelType) {
            case "clock":
                return clockPanelComponent
            case "active-window":
                return activeWindowPanelComponent
            case "battery":
                return batteryPanelComponent
            case "media":
                return mediaPanelComponent
            case "system-monitor":
                return systemMonitorPanelComponent
            default:
                return null
            }
        }

        // Close on click-away outside the floating card.
        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: Services.BarLayoutService.closeWidgetSettings()
        }
    }
}
