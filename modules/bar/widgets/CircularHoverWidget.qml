import QtQuick
import "../../../services" as Services

// Reusable circular badge that expands into a compact pill on hover.
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
    readonly property bool expanded: hoverArea.containsMouse
    readonly property real clampedProgress: progressValue < 0 ? -1 : Math.max(0, Math.min(1, progressValue))
    default property alias expandedContent: detailRow.data

    signal activated()
    signal wheel(var event)

    implicitWidth: (root.sidePadding * 2) + badgeSlot.width + detailSlot.width + (detailSlot.width > 0 ? root.contentSpacing : 0)
    implicitHeight: 30

    Behavior on implicitWidth {
        NumberAnimation { duration: Services.Motion.number.contentDuration; easing.type: Services.Motion.number.contentEasing }
    }

    onProgressValueChanged: ringCanvas.requestPaint()
    onProgressColorChanged: ringCanvas.requestPaint()
    onTrackColorChanged: ringCanvas.requestPaint()

    // Keep the badge and expanded details centered as one continuous object.
    Row {
        id: contentRow

        anchors.centerIn: parent
        spacing: detailSlot.width > 0 ? root.contentSpacing : 0

        // Keep the circular badge persistent across collapsed and expanded states.
        Item {
            id: badgeSlot

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

        // Reveal the detail content by widening a clipped slot beside the badge.
        Item {
            id: detailSlot

            width: root.expanded ? detailRow.implicitWidth : 0
            height: detailRow.implicitHeight
            opacity: root.expanded ? 1 : 0
            clip: true
            visible: width > 0 || opacity > 0

            Behavior on width {
                NumberAnimation { duration: Services.Motion.number.contentDuration; easing.type: Services.Motion.number.contentEasing }
            }

            Behavior on opacity {
                NumberAnimation { duration: Services.Motion.number.shortDuration; easing.type: Services.Motion.number.shortEasing }
            }

            // Host the expanded text row without replacing the badge instance.
            Row {
                id: detailRow

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
            }
        }
    }

    // Track hover and optional click activation over the full widget surface.
    MouseArea {
        id: hoverArea

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: root.clickable ? root.activationButtons : Qt.NoButton
        cursorShape: root.showPointerCursor ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.activated()
        onWheel: root.wheel(wheel)
    }
}
