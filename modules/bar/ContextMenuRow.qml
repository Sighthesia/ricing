import QtQuick
import "../../services" as Services

// Reusable interactive row for the bar context menu.
Item {
    id: root

    property string label: ""
    property string icon: ""
    property bool highlighted: false
    property bool destructive: false
    property bool enabled: true

    signal clicked()

    width: parent ? parent.width : 160
    height: 32
    readonly property real contentInset: 8
    readonly property real iconWidth: 16
    readonly property real contentSpacing: 8
    readonly property real idealContentWidth: 180
    readonly property color hoverColor: Qt.rgba(
        Services.Color.mOnSurface.r,
        Services.Color.mOnSurface.g,
        Services.Color.mOnSurface.b,
        0.08
    )
    readonly property real contentBandWidth: Math.max(
        0,
        Math.min(root.width - root.contentInset * 2, root.idealContentWidth)
    )

    // Hover highlight background.
    Rectangle {
        anchors.fill: parent
        radius: 6
        color: rowMouse.containsMouse && root.enabled ? root.hoverColor : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: Services.Motion.number.shortDuration
                easing.type: Services.Motion.number.shortEasing
            }
        }
    }

    Item {
        width: root.contentBandWidth
        height: parent.height
        anchors.horizontalCenter: parent.horizontalCenter

        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            spacing: root.contentSpacing

            // Action icon.
            Text {
                text: root.icon
                color: !root.enabled ? "#666666"
                    : root.destructive ? "#ff6666"
                    : root.highlighted ? "#88aaff" : "#aaaaaa"
                font.pixelSize: 14
                width: root.iconWidth
                horizontalAlignment: Text.AlignHCenter
            }

            // Action label.
            Text {
                text: root.label
                color: !root.enabled ? "#666666" : root.destructive ? "#ff6666" : "#dddddd"
                font.pixelSize: 12
                width: Math.max(0, parent.parent.width - root.iconWidth - root.contentSpacing)
                horizontalAlignment: Text.AlignLeft
                elide: Text.ElideRight
            }
        }
    }

    MouseArea {
        id: rowMouse

        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
