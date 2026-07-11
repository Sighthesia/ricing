import QtQuick
import "../../services" as Services

// Reusable glass capsule shell with shared blur, fill, and border layers.
Item {
    id: root

    default property alias contentData: contentHost.data

    property color surfaceColor: Qt.alpha(Services.Color.mSurface, Services.SettingsService.panelSurfaceOpacity)
    property color outlineColor: Services.Color.mOutline
    property real radius: 16
    property real borderWidth: 1
    property bool clipContent: true

    readonly property Item blurSourceItem: blurSource
    readonly property real blurRadius: radius

    Behavior on surfaceColor {
        ColorAnimation {
            duration: Services.Motion.color.transitionDuration
            easing.type: Services.Motion.color.transitionEasing
        }
    }

    Behavior on outlineColor {
        ColorAnimation {
            duration: Services.Motion.color.transitionDuration
            easing.type: Services.Motion.color.transitionEasing
        }
    }

    Behavior on radius {
        NumberAnimation {
            duration: Services.Motion.number.surfaceDuration
            easing.type: Services.Motion.number.surfaceEasing
        }
    }

    // Render the translucent capsule fill.
    Rectangle {
        id: surface

        anchors.fill: parent
        radius: root.radius
        color: root.surfaceColor
        antialiasing: true
    }

    // Expose a full-size blur source over the visible fill.
    Item {
        id: blurSource

        anchors.fill: parent
    }

    // Host capsule contents on top of the shared shell.
    Item {
        id: contentHost

        anchors.fill: parent
        clip: root.clipContent
    }

    // Draw the capsule outline above all content.
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.color: root.outlineColor
        border.width: root.borderWidth
        antialiasing: true
    }
}
