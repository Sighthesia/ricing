import QtQuick
import "../../../services" as Services

// Reusable circular badge that reveals details in the dockzone body on hover.
Item {
    id: root

    property string centerText: ""
    property string centerTextFontFamily: ""
    property int centerTextPixelSize: 9
    property color centerTextColor: Services.Color.mOnSurface
    property color badgeFillColor: Qt.rgba(
        Services.Color.mSurfaceVariant.r,
        Services.Color.mSurfaceVariant.g,
        Services.Color.mSurfaceVariant.b,
        0.9
    )
    property color badgeBorderColor: Qt.rgba(
        Services.Color.mOutline.r,
        Services.Color.mOutline.g,
        Services.Color.mOutline.b,
        0.45
    )
    property color progressColor: Services.Color.mPrimary
    property color trackColor: Qt.rgba(
        Services.Color.mOutline.r,
        Services.Color.mOutline.g,
        Services.Color.mOutline.b,
        0.3
    )
    property real progressValue: -1
    property real badgeSize: 24
    property real contentSpacing: 8
    property real sidePadding: 6
    property bool clickable: false
    property bool showPointerCursor: true
    property int activationButtons: Qt.LeftButton
    readonly property bool expanded: badgeArea.containsMouse || detailHover.hovered || hoverExitHoldTimer.running
    readonly property real clampedProgress: progressValue < 0 ? -1 : Math.max(0, Math.min(1, progressValue))
    readonly property real dockzoneExpandHeight: detailRow.implicitWidth > 0
        ? (root.expanded ? detailSlot.expandedHeight : 0)
        : 0
    readonly property real dockzoneExpandWidth: detailRow.implicitWidth > 0
        ? (root.expanded ? detailSlot.expandedWidth : 0)
        : 0
    default property alias expandedContent: detailRow.data

    signal activated()
    signal wheel(var event)

    implicitWidth: (root.sidePadding * 2) + badgeSlot.width
    implicitHeight: 30

    onProgressValueChanged: ringCanvas.requestPaint()
    onProgressColorChanged: ringCanvas.requestPaint()
    onTrackColorChanged: ringCanvas.requestPaint()

    // Hold the reveal briefly after the pointer leaves so the geometry can
    // settle and the user can travel from the badge into the detail body
    // without the dockzone collapsing mid-transit.
    Timer {
        id: hoverExitHoldTimer

        interval: 220
        repeat: false
    }

    onExpandedChanged: {
        if (expanded)
            hoverExitHoldTimer.stop()
        else
            hoverExitHoldTimer.restart()
    }

    // Keep the circular badge persistent while the dockzone hosts the reveal.
    Item {
        id: badgeSlot

        z: 1
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: root.badgeSize
        height: root.badgeSize
        scale: root.expanded ? 1.04 : 1.0

        Behavior on scale {
            NumberAnimation { duration: Services.Motion.number.snugDuration; easing.type: Services.Motion.number.snugEasing }
        }

        // Draw the circular track and active progress arc around the badge.
        Canvas {
            id: ringCanvas

            anchors.fill: parent
            antialiasing: true

            onPaint: {
                const ctx = getContext("2d")
                const size = Math.min(width, height)
                const center = size / 2
                const radius = (size / 2) - 1.25
                const startAngle = -Math.PI / 2
                const sweep = root.clampedProgress * Math.PI * 2

                ctx.reset()
                ctx.clearRect(0, 0, width, height)
                ctx.lineCap = "round"
                ctx.lineWidth = 2

                ctx.beginPath()
                ctx.strokeStyle = root.trackColor
                ctx.arc(center, center, radius, 0, Math.PI * 2, false)
                ctx.stroke()

                if (root.clampedProgress < 0)
                    return

                if (sweep <= 0)
                    return

                ctx.beginPath()
                ctx.strokeStyle = root.progressColor
                ctx.arc(center, center, radius, startAngle, startAngle + sweep, false)
                ctx.stroke()
            }
        }

        // Fill the badge center with the same glassy circle language as media.
        Rectangle {
            anchors.centerIn: parent
            width: 18
            height: 18
            radius: width / 2
            color: root.badgeFillColor
            border.color: root.badgeBorderColor
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: root.centerText
                font.family: root.centerTextFontFamily !== "" ? root.centerTextFontFamily : font.family
                color: root.centerTextColor
                font.pixelSize: root.centerTextPixelSize
                font.bold: root.centerTextFontFamily === ""
            }
        }
    }

    // Reveal the detail row below the bar line inside the expanded dockzone viewport.
    Item {
        id: detailSlot

        property real expandedHeight: root.contentSpacing + detailRow.implicitHeight + 8
        property real expandedWidth: detailRow.implicitWidth + 24
        property real revealHeight: root.expanded ? expandedHeight : 0

        z: 2
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.implicitHeight + root.contentSpacing - (root.expanded ? 0 : 5)
        width: detailRow.implicitWidth
        height: revealHeight
        opacity: root.expanded ? 1 : 0
        clip: true
        visible: height > 0 || opacity > 0
        transformOrigin: Item.Top

        Behavior on revealHeight {
            NumberAnimation { duration: Services.Motion.number.contentDuration; easing.type: Services.Motion.number.contentEasing }
        }

        Behavior on y {
            NumberAnimation { duration: Services.Motion.number.contentDuration; easing.type: Services.Motion.number.contentEasing }
        }

        Behavior on opacity {
            NumberAnimation { duration: Services.Motion.number.shortDuration; easing.type: Services.Motion.number.shortEasing }
        }

        // Host the expanded text row after the top reveal gap without replacing the badge.
        Row {
            id: detailRow

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: root.contentSpacing
            spacing: 6
        }

        HoverHandler {
            id: detailHover
        }
    }

    // Track hover and optional click activation over the compact badge surface.
    // The hit area spans the badge and the full reveal height below it so the
    // pointer can travel into the detail body without a gap that would close
    // the loop (badge loses hover before the detail HoverHandler engages).
    MouseArea {
        id: badgeArea

        x: 0
        y: 0
        width: parent.width
        height: parent.implicitHeight + detailSlot.expandedHeight
        hoverEnabled: true
        acceptedButtons: root.clickable ? root.activationButtons : Qt.NoButton
        cursorShape: root.showPointerCursor ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.activated()
        onWheel: root.wheel(wheel)
    }
}
