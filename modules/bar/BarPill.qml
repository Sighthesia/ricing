import QtQuick
import "../lazerbar"

// Hover-reactive sharp pill surface shared by every bar widget.
Item {
    id: root

    property bool hoverable: true
    property color hoverColor: LazerTheme.hoverFill
    readonly property bool hovered: visible && enabled && hoverable && hoverHandler.hovered
    signal clicked
    signal rightClicked
    signal middleClicked

    implicitHeight: LazerTheme.targetSize

    // Paint the sharp interactive surface without rounding the pill body.
    Rectangle {
        anchors.fill: parent
        radius: 0
        color: root.hovered ? root.hoverColor : "transparent"

        Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
    }

    HoverHandler {
        id: hoverHandler
        enabled: root.hoverable
    }

    // Left click is the primary activation path for every pill.
    TapHandler {
        acceptedButtons: Qt.LeftButton
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: root.clicked()
    }

    // Side buttons stay opt-in: pills without listeners simply ignore them.
    TapHandler {
        acceptedButtons: Qt.RightButton | Qt.MiddleButton
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: (eventPoint, button) => {
            if (button === Qt.RightButton) root.rightClicked()
            else root.middleClicked()
        }
    }
}
