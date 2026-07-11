import QtQuick
import "../../../services" as Services

// Reusable circular badge that triggers detail reveal in the unified expand host.
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
    // Detail component for the unified expand host to render.
    // Widgets should assign a Component wrapping their CompactHoverDetail.
    property Component detailComponent: null
    // Desired detail expand dimensions. Defaults fit CompactHoverDetail with
    // secondary text; override in widget instances as needed.
    property real detailRequestWidth: 198
    property real detailRequestHeight: 74

    readonly property bool expanded: badgeArea.containsMouse
    readonly property real clampedProgress: progressValue < 0 ? -1 : Math.max(0, Math.min(1, progressValue))

    // Badge-active signal for BarSection ownership tracking.
    readonly property bool badgeActive: badgeArea.containsMouse

    // Badge-only hover state: true when the pointer is over the stable badge hit
    // target (root-level HoverHandler, not inside the scaled badgeSlot).
    readonly property bool badgeContainsMouse: badgeHover.hovered

    // Report detail dimensions for expand height computation.
    readonly property real dockzoneExpandHeight: root.detailComponent && root.expanded
        ? root.detailRequestHeight
        : 0
    readonly property real dockzoneExpandWidth: root.detailComponent && root.expanded
        ? root.detailRequestWidth
        : 0

    signal activated()
    signal wheel(var event)

    implicitWidth: (root.sidePadding * 2) + badgeSlot.width
    implicitHeight: 30

    onProgressValueChanged: ringCanvas.requestPaint()
    onProgressColorChanged: ringCanvas.requestPaint()
    onTrackColorChanged: ringCanvas.requestPaint()

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

    // Stable badge-only hover detection at the root level (not inside the
    // scaled badgeSlot) so the hit target does not wobble during the
    // 1.0→1.04 badge scale animation.
    HoverHandler {
        id: badgeHover
    }

    // Track hover and optional click activation over the compact badge surface.
    // The hit target has a fixed height (implicitHeight only) so it never grows
    // or shrinks with animated ownership changes.
    MouseArea {
        id: badgeArea

        x: 0
        y: 0
        width: parent.width
        height: root.implicitHeight
        hoverEnabled: true
        acceptedButtons: root.clickable ? root.activationButtons : Qt.NoButton
        cursorShape: root.showPointerCursor ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.activated()
        onWheel: root.wheel(wheel)
    }
}
