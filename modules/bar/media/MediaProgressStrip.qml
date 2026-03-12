import QtQuick
import qs.config

// Thin progress strip that hugs the bottom edge of the widget surface.
Item {
    id: root

    property real progress: 0
    property bool expanded: false
    property bool interactive: false
    property color trackColor: Colors.border
    property color fillColor: Colors.highlight
    property int thickness: Theme.barWidget.mediaProgressThickness
    property int expandedThickness: Theme.barWidget.mediaExpandedProgressThickness

    signal progressCommitted(real progressValue)

    property real _dragProgress: root.progress
    readonly property real _displayProgress: _dragArea.pressed ? root._dragProgress : root.progress

    implicitWidth: Theme.barWidget.mediaFlashProgressMinWidth
    implicitHeight: root.expanded ? root.expandedThickness : root.thickness

    function _clampProgress(xPosition) {
        if (width <= 0)
            return 0

        return Math.max(0, Math.min(1, xPosition / width))
    }

    Behavior on implicitHeight {
        NumberAnimation {
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }
    }

    // Progress track.
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.trackColor
        opacity: 0.32
    }

    // Progress fill.
    Rectangle {
        width: Math.round(parent.width * root._displayProgress)
        height: parent.height
        radius: height / 2
        color: root.fillColor
    }

    // Progress handle.
    Rectangle {
        visible: root.expanded || root.interactive
        width: parent.height
        height: width
        radius: width / 2
        x: Math.round((parent.width - width) * root._displayProgress)
        y: Math.round((parent.height - height) / 2)
        color: Colors.text
        border.color: Colors.background
        border.width: 1
        opacity: root.interactive ? 0.95 : 0.7
    }

    // Progress drag area.
    MouseArea {
        id: _dragArea
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: root.interactive
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onPressed: mouse => {
            root._dragProgress = root._clampProgress(mouse.x)
        }
        onPositionChanged: mouse => {
            if (!pressed)
                return

            root._dragProgress = root._clampProgress(mouse.x)
        }
        onReleased: mouse => {
            root._dragProgress = root._clampProgress(mouse.x)
            root.progressCommitted(root._dragProgress)
        }
    }
}