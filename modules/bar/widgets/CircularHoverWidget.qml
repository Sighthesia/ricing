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
    property bool _exitHoldRunning: false
    // Stable detail viewport hover: section-level fixed hit area.
    // Only meaningful when dockzoneActualExpandHeight > 0 (active owner).
    property bool detailViewportHovered: false
    property int activationButtons: Qt.LeftButton
    // Actual spring-applied expand height of the host dockzone, passed down
    // so detail reveal tracks the glass body at every frame instead of using
    // an independent easing (which can dephase from the host spring).
    property real dockzoneActualExpandHeight: 0
    property real dockzoneRevealCenterX: -1
    property real dockzoneRevealTargetCenterX: -1
    property real dockzoneRevealViewportWidth: -1
    // Ownership from two fixed hit layers only: the stable badge hit area and
    // the section-level fixed detail viewport. Animated geometry (scaled badge,
    // sliding detailSlot) never directly drives hover ownership.
    readonly property bool expanded: badgeArea.containsMouse
        || (dockzoneActualExpandHeight > 0 && root.detailViewportHovered)
        || _exitHoldRunning
    readonly property real clampedProgress: progressValue < 0 ? -1 : Math.max(0, Math.min(1, progressValue))
    readonly property real detailCenterXInViewport: {
        if (dockzoneRevealTargetCenterX >= 0)
            return dockzoneRevealTargetCenterX

        if (dockzoneRevealCenterX < 0 || dockzoneRevealViewportWidth <= 0)
            return root.width / 2

        return dockzoneRevealViewportWidth / 2
    }
    // Use the viewport reference center when valid viewport geometry is available,
    // falling back to the widget's own center only when viewport is uninitialized.
    // DO NOT check dockzoneRevealCenterX < 0 — that catches legitimate cases where
    // a widget's center lies left of the sectionClip origin (e.g. overflow or early
    // layout), and the math still resolves to the correct viewport center.
    readonly property real detailCenterXInWidget: {
        if (dockzoneRevealViewportWidth <= 0)
            return root.width / 2

        return root.width / 2 + (root.detailCenterXInViewport - dockzoneRevealCenterX)
    }

    // Reference center for detail horizontal placement within the widget.
    // Maps the viewport center into widget-local coordinates.
    readonly property real _detailHorizontalRef: root.width / 2
        + (root.detailCenterXInViewport - dockzoneRevealCenterX)

    // Reveal progress derived from the host's spring-applied expand height
    // so detail height/y/opacity stay phase-tight with the glass body at
    // every frame.  No independent easing — the host spring drives both.
    readonly property real _revealProgress: detailSlot.expandedHeight > 0
        ? Math.min(1, Math.max(0, root.dockzoneActualExpandHeight / detailSlot.expandedHeight))
        : 0

    // Direct pointer interest: the cursor is on this widget's fixed badge hit
    // target or the section-level fixed detail viewport. Animated geometry never
    // participates. Used by BarSection to decide which widget may consume
    // dockzoneActualExpandHeight for its detail.
    readonly property bool pointerActive: badgeArea.containsMouse
        || (dockzoneActualExpandHeight > 0 && root.detailViewportHovered)

    // Badge-active signal for BarSection ownership tracking.
    readonly property bool badgeActive: pointerActive

    // Badge-only hover state: true when the pointer is over the stable badge hit
    // target (root-level HoverHandler, not inside the scaled badgeSlot).
    readonly property bool badgeContainsMouse: badgeHover.hovered

    // Report only binary target height to break the old feedback loop where
    // the widget's own smooth _revealProgress drove the host target, causing
    // the host spring to chase a 180ms eased value (frame-by-frame aggregation).
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

    // Safety bridge for the minimal gap between the fixed badge hit target
    // and the section-level fixed detail viewport. The gap is typically 3-5px
    // (badge bottom to topBandHeight), so the hold interval is kept short.
    Timer {
        id: hoverExitHoldTimer

        interval: 150
        repeat: false
        onTriggered: _exitHoldRunning = false
    }

    Connections {
        target: badgeArea
        function onContainsMouseChanged() { _updateExitHold() }
    }

    // Track the detail viewport hover at the root level so the exit hold
    // timer is cancelled when the pointer is over the fixed detail area,
    // even though detailHover no longer lives inside the animated detailSlot.
    Connections {
        target: root
        function onDetailViewportHoveredChanged() { _updateExitHold() }
    }

    function _updateExitHold() {
        var detailActive = dockzoneActualExpandHeight > 0 && root.detailViewportHovered
        if (badgeArea.containsMouse || detailActive) {
            hoverExitHoldTimer.stop()
            _exitHoldRunning = false
        } else {
            hoverExitHoldTimer.restart()
            _exitHoldRunning = true
        }
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

    // Stable badge-only hover detection at the root level (not inside the
    // scaled badgeSlot) so the hit target does not wobble during the
    // 1.0→1.04 badge scale animation.
    HoverHandler {
        id: badgeHover
    }

    // Reveal the detail row below the bar line inside the expanded dockzone viewport.
    Item {
        id: detailSlot

        property real expandedHeight: root.contentSpacing + detailRow.implicitHeight + 8
        property real expandedWidth: detailRow.implicitWidth + 24
        property real revealHeight: root._revealProgress * expandedHeight

        z: 2
        x: root._detailHorizontalRef - width / 2  // centered in viewport
        // Slide up from the host's visible bottom edge as the glass expands.
        y: root.implicitHeight + root.contentSpacing
            + (1 - root._revealProgress) * expandedHeight * 0.3
        width: detailRow.implicitWidth
        height: revealHeight
        // Squared progress: content fades in late (arrives with the glass)
        // but fades out early (leaves before the glass retracts).
        opacity: root._revealProgress * root._revealProgress
        clip: true
        visible: height > 0 || opacity > 0
        transformOrigin: Item.Top

        // Host the expanded text row after the top reveal gap without replacing the badge.
        Row {
            id: detailRow

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: root.contentSpacing
            spacing: 6
        }

    }

    // Track hover and optional click activation over the compact badge surface.
    // The hit target has a fixed height (implicitHeight only) so it never grows
    // or shrinks with the animated detail — ownership stays stable. Detail
    // hover is tracked by the section-level fixed detail viewport instead.
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
