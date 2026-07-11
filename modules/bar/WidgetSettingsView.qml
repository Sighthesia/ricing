import "./MenuVisuals.js" as MenuVisuals
import "./widgetsettings" as WidgetPanels
import "../../services" as Services
import "../../services/WidgetSettingsRegistry.js" as WidgetSettingsRegistry
import QtQuick

// Render the active widget settings inside an expanded dockzone body.
Item {
    id: root

    readonly property real idealContentWidth: 320
    readonly property real outerPadding: MenuVisuals.outerPadding
    readonly property real rowEdgeInset: MenuVisuals.rowEdgeInset
    readonly property real headerHeight: MenuVisuals.rowHeight
    readonly property real rowGap: MenuVisuals.compactSpacing
    property real viewportWidth: idealContentWidth
    property real viewportHeight: contentHeight
    property real hostRevealHeight: -1
    property real hostRevealProgress: 1
    property bool hostIsInteractive: true
    readonly property string activeWidgetId: Services.BarLayoutService.activeWidgetSettingsId
    readonly property string panelTitle: WidgetSettingsRegistry.title(activeWidgetId)
    readonly property string panelType: WidgetSettingsRegistry.panelKey(activeWidgetId)
    readonly property real contentWidth: Math.max(0, Math.min(viewportWidth, idealContentWidth))
    readonly property real contentHeight: panelColumn.implicitHeight + outerPadding * 2
    readonly property real revealHeight: hostRevealHeight >= 0
        ? Math.max(0, hostRevealHeight - 1)
        : Math.max(0, height - 1)

    implicitWidth: idealContentWidth
    implicitHeight: contentHeight
    width: Math.max(0, viewportWidth)
    height: Math.min(viewportHeight, contentHeight)
    opacity: hostRevealProgress
    enabled: hostIsInteractive

    // Clip the settings surface to the live expanded viewport.
    Item {
        anchors.fill: parent
        clip: true

        // Keep the settings content aligned like the tray/context menu surfaces.
        Column {
            id: panelColumn

            width: Math.max(0, root.width - root.rowEdgeInset * 2)
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: root.outerPadding
            spacing: root.rowGap

            // Header row for the active widget settings.
            Row {
                id: headerRow

                width: parent.width
                height: root.headerHeight
                spacing: 0

            Item {
                width: MenuVisuals.contentInset
                height: 1
            }

                Services.FluidText {
                    width: Math.max(0, parent.width - closeButton.width - MenuVisuals.contentInset * 2 - MenuVisuals.contentSpacing)
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.panelTitle
                    color: Services.Color.mOnSurface
                    basePixelSize: MenuVisuals.bodyFontSize
                    font.bold: true
                }

                Item { width: MenuVisuals.contentSpacing; height: 1 }

                Rectangle {
                    id: closeButton

                    width: 20
                    height: 20
                    radius: 10
                    anchors.verticalCenter: parent.verticalCenter
                    color: closeArea.containsMouse ? Qt.alpha(Services.Color.mOnSurface, MenuVisuals.hoverOpacity) : "transparent"

                    Services.FluidText {
                        anchors.centerIn: parent
                        text: "\u00d7"
                        color: Services.Color.mOnSurface
                        basePixelSize: MenuVisuals.iconFontSize
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
                width: parent.width - root.rowEdgeInset * 2
                anchors.horizontalCenter: parent.horizontalCenter
                height: 1
                color: Qt.alpha(Services.Color.mOutline, MenuVisuals.dividerOpacity)
            }

            // Load the active widget settings panel.
            Loader {
                width: parent.width
                anchors.horizontalCenter: parent.horizontalCenter
                active: root.panelType !== ""
                sourceComponent: root.panelComponentForType(root.panelType)
            }
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

    Component {
        id: bluetoothPanelComponent

        WidgetPanels.BluetoothSettingsPanel {
            width: parent ? parent.width : 0
        }
    }

    Component {
        id: networkPanelComponent

        WidgetPanels.NetworkSettingsPanel {
            width: parent ? parent.width : 0
        }
    }

    Component {
        id: volumePanelComponent

        WidgetPanels.VolumeSettingsPanel {
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
        case "bluetooth":
            return bluetoothPanelComponent
        case "network":
            return networkPanelComponent
        case "volume":
            return volumePanelComponent
        default:
            return null
        }
    }
}
