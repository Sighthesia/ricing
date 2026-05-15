import QtQuick
import "../../services" as Services

// Right-click context menu for the bar.
// Shows layout mode toggle, widget picker, and per-widget actions.
Item {
    id: root

    property Item anchorTarget: null
    property real _clickX: 0
    property string _targetWidgetKey: ""
    property string _targetWidgetId: ""
    visible: _active
    z: 1000

    property bool _active: false

    // Open the menu at bar-local x. Optional widget context for widget right-click.
    function showAt(x, instanceKey, widgetId) {
        _clickX = x
        _targetWidgetKey = instanceKey || ""
        _targetWidgetId = widgetId || ""
        _active = true
    }

    function dismiss() {
        _active = false
        _targetWidgetKey = ""
        _targetWidgetId = ""
    }

    // Click-away area to dismiss.
    MouseArea {
        anchors.fill: parent ? parent : undefined
        visible: root._active
        onClicked: root.dismiss()
        z: -1
    }

    // Menu surface positioned at click X.
    Rectangle {
        id: menuSurface

        x: Math.max(4, Math.min(root._clickX - width / 2,
            (root.anchorTarget ? root.anchorTarget.width : 300) - width - 4))
        y: Services.BarLayoutService.barHeight + 4
        width: 180
        height: menuColumn.implicitHeight + 16
        radius: 10
        color: "#1a1a1a"
        border.color: "#3a3a3a"
        border.width: 1
        opacity: root._active ? 1 : 0
        scale: root._active ? 1 : 0.92
        transformOrigin: Item.Top

        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 0.3 } }

        Column {
            id: menuColumn

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 8
            spacing: 2

            // Layout mode toggle.
            ContextMenuRow {
                label: Services.BarLayoutService.settingsMode ? "Exit Layout Mode" : "Layout Mode"
                icon: "\u2630"
                highlighted: Services.BarLayoutService.settingsMode
                onClicked: {
                    Services.BarLayoutService.toggleSettingsMode()
                    root.dismiss()
                }
            }

            // Widget picker entry.
            ContextMenuRow {
                label: "Add Widget"
                icon: "+"
                onClicked: {
                    Services.BarLayoutService.openWidgetPicker("center")
                    root.dismiss()
                }
            }

            // Divider before widget-specific actions.
            Rectangle {
                width: parent.width - 8
                anchors.horizontalCenter: parent.horizontalCenter
                height: 1
                color: "#333333"
                visible: root._targetWidgetKey !== ""
            }

            // Remove widget (only when right-clicked on a widget).
            ContextMenuRow {
                visible: root._targetWidgetKey !== ""
                label: "Remove Widget"
                icon: "\u2212"
                destructive: true
                onClicked: {
                    Services.BarLayoutService.removeWidget(root._targetWidgetKey)
                    root.dismiss()
                }
            }
        }
    }
}
