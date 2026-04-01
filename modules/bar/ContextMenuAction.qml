import QtQuick
import qs.config

// Shared interactive row for bar-styled context menus.
Item {
    id: root

    property bool actionEnabled: true
    property real radius: Theme.cornerRadius - 2
    property real highlightOpacity: 0.12
    property color highlightColor: Colors.highlight
    property real leftPadding: Theme.widgetPadding
    property real rightPadding: Theme.widgetPadding
    property real topPadding: 0
    property real bottomPadding: 0
    readonly property bool hovered: pointerArea.containsMouse
    default property alias content: contentItem.data

    signal clicked(var mouse)

    // Hover affordance.
    HoverRevealHighlight {
        anchors.fill: parent
        anchors.margins: 1
        radius: root.radius
        hovered: root.actionEnabled && pointerArea.containsMouse
        highlightColor: root.highlightColor
        highlightOpacity: root.highlightOpacity
    }

    // Content slot.
    Item {
        id: contentItem

        anchors.fill: parent
        anchors.leftMargin: root.leftPadding
        anchors.rightMargin: root.rightPadding
        anchors.topMargin: root.topPadding
        anchors.bottomMargin: root.bottomPadding
    }

    // Click feedback.
    ClickRipple {
        id: ripple

        anchors.fill: parent
        anchors.margins: 1
        radius: root.radius
        rippleColor: root.highlightColor
    }

    // Pointer capture.
    MouseArea {
        id: pointerArea

        anchors.fill: parent
        enabled: root.actionEnabled
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: function(mouse) {
            ripple.triggerRipple(mouse.x, mouse.y)
            root.clicked(mouse)
        }
    }
}
