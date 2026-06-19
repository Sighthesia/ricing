import QtQuick
import "../bar/MenuVisuals.js" as MenuVisuals
import "../../services" as Services

// Bold clock card for the overview control-center collage.
// Dominant time with supporting date and a subtle call-to-action hint.
// Click navigates to calendar detail page. Uses a glass layered
// background with a subtle gradient and top-edge sheen.
Rectangle {
    id: root

    signal clicked()

    radius: 16
    color: clockMouse.containsMouse
        ? Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, MenuVisuals.listHoverOpacity)
        : Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, MenuVisuals.hoverOpacity)
    border.color: Qt.rgba(Services.Color.mOutline.r, Services.Color.mOutline.g, Services.Color.mOutline.b, 0.4)
    border.width: 1

    Behavior on color {
        ColorAnimation { duration: Services.Motion.color.transitionDuration; easing.type: Services.Motion.color.transitionEasing }
    }

    Behavior on border.color {
        ColorAnimation { duration: Services.Motion.color.transitionDuration; easing.type: Services.Motion.color.transitionEasing }
    }

    // Subtle gradient overlay for glass depth.
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, 0.03) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // Top-edge glass highlight strip.
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Qt.rgba(1, 1, 1, 0.08)
    }

    // Top-aligned time and date; bold time leads the hierarchy.
    Column {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 14
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 2

        Services.FluidText {
            text: Qt.formatTime(new Date(), "hh:mm")
            color: Services.Color.mOnSurface
            basePixelSize: 36
            font.bold: true
        }

        Services.FluidText {
            text: Qt.formatDate(new Date(), "ddd") + " \u00B7 " + Qt.formatDate(new Date(), "MMM d")
            color: Services.Color.mOnSurfaceVariant
            basePixelSize: 11
        }
    }

    // Subtle bottom hint suggesting the card's tap action.
    Services.FluidText {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 14
        text: "\u70B9\u51FB\u67E5\u770B\u65E5\u5386"
        color: Services.Color.mOnSurfaceVariant
        basePixelSize: 9
        opacity: 0.6
        horizontalAlignment: Text.AlignLeft
    }

    MouseArea {
        id: clockMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
