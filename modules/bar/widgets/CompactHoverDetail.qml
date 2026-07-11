import QtQuick
import "../../../services" as Services

// Compact two-line detail surface for dockzone-hosted hover reveals.
Item {
    id: root

    property string iconText: ""
    property string labelText: ""
    property string valueText: ""
    property string secondaryText: ""
    property real progressValue: 0
    property color accentColor: Services.Color.mPrimary
    property bool interactive: false
    property real hostRevealProgress: 1
    property real hostRevealHeight: -1
    property bool hostIsInteractive: true

    signal moved(real value)

    readonly property real clampedProgress: Math.max(0, Math.min(1, root.progressValue))

    implicitWidth: 174
    implicitHeight: secondaryLabel.visible ? 58 : 48
    opacity: hostRevealProgress
    enabled: hostIsInteractive

    // Align the header tightly so the expanded body does not feel hollow.
    Row {
        id: headerRow

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 20
        spacing: 6

        Services.FluidText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.iconText
            explicitFontFamily: root.iconText !== "" ? "Symbols Nerd Font" : ""
            color: root.accentColor
            basePixelSize: 11
            width: root.iconText !== "" ? 16 : 0
            visible: root.iconText !== ""
            horizontalAlignment: Text.AlignHCenter
        }

        Services.FluidText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.labelText
            color: Services.Color.mOnSurface
            basePixelSize: 11
            width: Math.max(0, parent.width - parent.spacing - valueLabel.width - (root.iconText !== "" ? 16 + parent.spacing : 0))
            elide: Text.ElideRight
        }

        Services.FluidText {
            id: valueLabel

            anchors.verticalCenter: parent.verticalCenter
            text: root.valueText
            color: root.accentColor
            basePixelSize: 11
            horizontalAlignment: Text.AlignRight
            width: Math.max(38, implicitWidth)
        }
    }

    // Draw the progress track as the primary interactive affordance.
    Item {
        id: progressTrack

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: headerRow.bottom
        anchors.topMargin: 6
        height: 18

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 7
            radius: height / 2
            color: Qt.rgba(Services.Color.mOutline.r, Services.Color.mOutline.g, Services.Color.mOutline.b, 0.28)
        }

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * root.clampedProgress
            height: 7
            radius: height / 2
            color: root.accentColor

            Behavior on width {
                enabled: !dragArea.pressed
                NumberAnimation { duration: Services.Motion.number.snugDuration; easing.type: Services.Motion.number.snugEasing }
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(parent.width - width, parent.width * root.clampedProgress - width / 2))
            width: root.interactive ? 12 : 0
            height: width
            radius: width / 2
            color: Services.Color.mSurface
            border.color: root.accentColor
            border.width: root.interactive ? 2 : 0
            opacity: root.interactive ? 1 : 0

            Behavior on x {
                enabled: !dragArea.pressed
                NumberAnimation { duration: Services.Motion.number.snugDuration; easing.type: Services.Motion.number.snugEasing }
            }

            Behavior on opacity {
                NumberAnimation { duration: Services.Motion.number.shortDuration; easing.type: Services.Motion.number.shortEasing }
            }
        }

        MouseArea {
            id: dragArea

            anchors.fill: parent
            enabled: root.interactive
            hoverEnabled: enabled
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            preventStealing: true

            function valueFromX(localX) {
                return Math.max(0, Math.min(1, localX / Math.max(1, width)))
            }

            onPressed: mouse => root.moved(valueFromX(mouse.x))
            onPositionChanged: mouse => {
                if (pressed)
                    root.moved(valueFromX(mouse.x))
            }
        }
    }

    // Keep optional secondary telemetry close to the bar instead of adding side padding.
    Services.FluidText {
        id: secondaryLabel

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: progressTrack.bottom
        anchors.topMargin: 4
        text: root.secondaryText
        color: Services.Color.mOnSurfaceVariant
        basePixelSize: 10
        visible: text !== ""
        elide: Text.ElideRight
    }
}
