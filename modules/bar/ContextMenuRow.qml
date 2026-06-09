import QtQuick
import "MenuVisuals.js" as MenuVisuals
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
    height: MenuVisuals.rowHeight
    readonly property real contentInset: MenuVisuals.contentInset
    readonly property real iconWidth: MenuVisuals.iconWidth
    readonly property real contentSpacing: MenuVisuals.contentSpacing
    readonly property real idealContentWidth: MenuVisuals.idealContextContentWidth
    readonly property color hoverColor: Qt.rgba(
        Services.Color.mOnSurface.r,
        Services.Color.mOnSurface.g,
        Services.Color.mOnSurface.b,
        MenuVisuals.hoverOpacity
    )
    readonly property color disabledColor: Services.Color.mOutline
    readonly property color iconColor: highlighted ? Services.Color.mPrimary : Services.Color.mOnSurfaceVariant
    readonly property color destructiveColor: Qt.rgba(
        Services.Color.mError.r,
        Services.Color.mError.g,
        Services.Color.mError.b,
        0.92
    )
    readonly property color labelColor: destructive ? destructiveColor : Services.Color.mOnSurface
    readonly property real contentBandWidth: Math.max(
        0,
        Math.min(root.width - root.contentInset * 2, root.idealContentWidth)
    )

    // Hover highlight background.
    Rectangle {
        anchors.fill: parent
        radius: MenuVisuals.rowRadius
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
                color: !root.enabled ? root.disabledColor
                    : root.destructive ? root.destructiveColor
                    : root.iconColor
                font.pixelSize: 14
                width: root.iconWidth
                horizontalAlignment: Text.AlignHCenter
            }

            // Action label.
            Text {
                text: root.label
                color: !root.enabled ? root.disabledColor : root.labelColor
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
