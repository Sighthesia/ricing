import QtQuick
import "../bar/MenuVisuals.js" as MenuVisuals
import "../../services" as Services

// Compact action button used by island detail pages.
Rectangle {
    id: root

    property string text: ""
    property bool enabled: true

    signal clicked()

    width: 88
    height: 36
    radius: 12
    color: enabled && actionMouse.containsMouse
        ? Qt.rgba(Services.Color.mPrimary.r, Services.Color.mPrimary.g, Services.Color.mPrimary.b, 0.24)
        : Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, MenuVisuals.hoverOpacity)
    border.color: Qt.rgba(Services.Color.mOutline.r, Services.Color.mOutline.g, Services.Color.mOutline.b, 0.55)
    border.width: 1
    opacity: enabled ? 1 : 0.45

    Behavior on color {
        ColorAnimation { duration: Services.Motion.color.transitionDuration; easing.type: Services.Motion.color.transitionEasing }
    }

    Services.FluidText {
        anchors.centerIn: parent
        text: root.text
        color: Services.Color.mOnSurface
        basePixelSize: 11
    }

    MouseArea {
        id: actionMouse
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
