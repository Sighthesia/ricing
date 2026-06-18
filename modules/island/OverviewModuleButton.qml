import QtQuick
import "../bar/MenuVisuals.js" as MenuVisuals
import "../../services" as Services

// Glanceable overview tile that expands into a full island detail page.
Rectangle {
    id: root

    property string title: ""
    property string subtitle: ""
    property string detail: ""

    signal clicked()

    radius: 16
    color: tileMouse.containsMouse
        ? Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, MenuVisuals.listHoverOpacity)
        : Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, MenuVisuals.hoverOpacity)
    border.color: Qt.rgba(Services.Color.mOutline.r, Services.Color.mOutline.g, Services.Color.mOutline.b, 0.55)
    border.width: 1

    Behavior on color {
        ColorAnimation { duration: Services.Motion.color.transitionDuration; easing.type: Services.Motion.color.transitionEasing }
    }

    // Keep text baselines aligned across all overview modules.
    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 4

        Services.FluidText {
            text: root.title
            color: Services.Color.mOnSurface
            basePixelSize: 15
            font.bold: true
            elide: Text.ElideRight
            width: parent.width
        }

        Services.FluidText {
            text: root.subtitle
            color: Services.Color.mOnSurfaceVariant
            basePixelSize: 11
            elide: Text.ElideRight
            width: parent.width
        }

        Services.FluidText {
            text: root.detail
            color: Services.Color.mPrimary
            basePixelSize: 10
            elide: Text.ElideRight
            width: parent.width
        }
    }

    // Route tile clicks to the island page state machine.
    MouseArea {
        id: tileMouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
