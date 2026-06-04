import QtQuick
import "../../services" as Services

// Segmented mode button used by the launcher/control/settings switcher.
Rectangle {
    id: root

    property string label: ""
    property bool selected: false
    property bool firstSegment: false
    property bool lastSegment: false

    signal clicked()

    radius: 16
    topLeftRadius: firstSegment ? radius : 10
    bottomLeftRadius: firstSegment ? radius : 10
    topRightRadius: lastSegment ? radius : 10
    bottomRightRadius: lastSegment ? radius : 10
    color: root.selected
        ? Qt.rgba(Services.Color.mPrimary.r, Services.Color.mPrimary.g, Services.Color.mPrimary.b, 0.22)
        : "transparent"
    border.color: root.selected
        ? Qt.rgba(Services.Color.mPrimary.r, Services.Color.mPrimary.g, Services.Color.mPrimary.b, 0.8)
        : "transparent"
    border.width: root.selected ? 1 : 0

    Behavior on color {
        ColorAnimation { duration: Services.Motion.color.transitionDuration; easing.type: Services.Motion.color.transitionEasing }
    }

    // Keep the label centered and easy to scan at a glance.
    Text {
        anchors.centerIn: parent
        text: root.label
        color: root.selected ? Services.Color.mPrimary : Services.Color.mOnSurface
        font.pixelSize: 13
        font.bold: root.selected
    }

    // Handle hover and selection clicks without pulling in a controls dependency.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
