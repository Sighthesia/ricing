import QtQuick

// Present osu-style page identity as a flat continuation of the overlay body.
Rectangle {
    id: root
    property string title: ""
    property string description: ""
    property string breadcrumb: ""
    property var palette: ({})
    signal closeRequested()

    implicitHeight: 96
    color: palette.header || "#7C4D9E"

    Column {
        anchors.left: parent.left
        anchors.leftMargin: 34
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Text { text: root.breadcrumb; color: root.palette.muted || "#DDD"; font.pixelSize: 11 }
        Text { text: root.title; color: root.palette.text || "white"; font.pixelSize: 27; font.bold: true }
        Text { visible: text !== ""; text: root.description; color: root.palette.muted || "#DDD"; font.pixelSize: 12 }
    }

    Rectangle {
        id: closeButton
        width: 44; height: 44
        anchors.right: parent.right; anchors.rightMargin: 24
        anchors.verticalCenter: parent.verticalCenter
        radius: 22
        color: closeHover.hovered ? "#32FFFFFF" : "#18FFFFFF"
        Text { anchors.centerIn: parent; text: "x"; color: root.palette.text || "white"; font.pixelSize: 18; font.bold: true }
        HoverHandler { id: closeHover }
        TapHandler { onTapped: root.closeRequested() }
        Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
    }
}
