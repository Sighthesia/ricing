import QtQuick
import "../lazerbar"

// Compact context actions for the bar's second popup layer.
Item {
    id: root

    property string widgetId: ""
    property string instanceKey: ""
    property string section: "center"
    property bool hasSettings: false
    property var payload: null
    property string actionKind: "context"
    signal actionRequested(string action)

    implicitWidth: 260
    implicitHeight: root.visible ? actionColumn.implicitHeight + 16 : 0
    visible: root.actionKind === "context"

    function invoke(action) {
        var callbacks = root.payload || ({})
        var callback = callbacks[action]
        if (typeof callback === "function")
            callback(root.instanceKey, root.widgetId, root.section)
        root.actionRequested(action)
    }

    // Render each context command as a compact settings-style row.
    Column {
        id: actionColumn
        anchors.fill: parent
        anchors.margins: 8
        spacing: 2

        Repeater {
            model: [
                { action: "moveLeft", label: "Move left" },
                { action: "moveRight", label: "Move right" },
                { action: "moveToSection", label: "Move to section" },
                { action: "openSettings", label: "Widget settings", available: root.hasSettings },
                { action: "remove", label: "Remove widget" },
                { action: "close", label: "Close" },
            ]

            delegate: Item {
                required property var modelData
                width: actionColumn.width
                height: modelData.available === false ? 0 : 32
                visible: height > 0

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: actionHover.hovered ? LazerTheme.settingsCardHover : LazerTheme.settingsCard
                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
                }

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    verticalAlignment: Text.AlignVCenter
                    text: modelData.label
                    color: LazerTheme.textPrimary
                    font.pixelSize: 13
                }

                HoverHandler { id: actionHover; blocking: false }
                TapHandler {
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: root.invoke(modelData.action)
                }
            }
        }
    }
}
