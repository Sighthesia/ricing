import QtQuick
import "../../services" as Services

// Animated island body: expands from collapsed clock to full launcher panel.
Item {
    id: root

    // Geometry constants.
    readonly property int collapsedW: 220
    readonly property int collapsedH: Services.BarLayoutService.barHeight
    readonly property int expandedW: 480
    readonly property int expandedH: 420
    readonly property int earRadius: 24

    // Animated dimensions driven by IslandService state.
    property int targetW: Services.IslandService.expanded ? expandedW : collapsedW
    property int targetH: Services.IslandService.expanded ? expandedH : collapsedH
    property int targetR: Services.IslandService.expanded ? 24 : 14

    width: targetW + earRadius * 2
    height: targetH
    implicitWidth: width
    implicitHeight: height

    property real bodyRadius: targetR

    // SpringAnimation for organic feel (reference project values).
    Behavior on width {
        SpringAnimation { spring: 5.0; mass: 3.6; damping: 0.75; epsilon: 0.5 }
    }
    Behavior on height {
        SpringAnimation { spring: 5.0; mass: 3.6; damping: 0.75; epsilon: 0.5 }
    }
    Behavior on bodyRadius {
        SpringAnimation { spring: 5.0; mass: 3.6; damping: 0.75; epsilon: 0.1 }
    }

    // --- Left ear (connects body to screen top-left) ---
    Canvas {
        id: leftEar
        x: bodyRect.x - earRadius
        y: 0
        width: earRadius
        height: earRadius
        antialiasing: true
        visible: root.height > 0

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.fillStyle = Services.Color.mSurface
            ctx.beginPath()
            ctx.moveTo(0, 0)
            ctx.lineTo(width, 0)
            ctx.lineTo(width, height)
            ctx.arc(0, height, width, 0, -Math.PI / 2, true)
            ctx.closePath()
            ctx.fill()
        }

        Connections {
            target: Services.Color
            function onMSurfaceChanged() { leftEar.requestPaint() }
        }
    }

    // --- Body rectangle ---
    Rectangle {
        id: bodyRect
        x: root.earRadius
        y: 0
        width: root.width - root.earRadius * 2
        height: root.height
        color: Services.Color.mSurface
        radius: root.bodyRadius
        clip: true

        // Flatten top corners (body connects to screen edge via ears).
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: parent.radius
            color: parent.color
        }

        // --- Collapsed content: clock ---
        Item {
            id: collapsedContent
            anchors.fill: parent
            opacity: Services.IslandService.expanded ? 0 : 1
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            IslandClock {
                anchors.centerIn: parent
            }
        }

        // --- Expanded content: search + results ---
        Item {
            id: expandedContent
            anchors.fill: parent
            anchors.margins: 16
            anchors.topMargin: 12
            opacity: Services.IslandService.expanded ? 1 : 0
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            IslandLauncher {
                anchors.fill: parent
                visible: parent.visible
            }
        }

        // Click to toggle (only when collapsed).
        MouseArea {
            anchors.fill: parent
            enabled: !Services.IslandService.expanded
            cursorShape: Qt.PointingHandCursor
            onClicked: Services.IslandService.toggle()
        }
    }

    // --- Right ear (connects body to screen top-right) ---
    Canvas {
        id: rightEar
        x: bodyRect.x + bodyRect.width
        y: 0
        width: earRadius
        height: earRadius
        antialiasing: true
        visible: root.height > 0

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.fillStyle = Services.Color.mSurface
            ctx.beginPath()
            ctx.moveTo(width, 0)
            ctx.lineTo(0, 0)
            ctx.lineTo(0, height)
            ctx.arc(width, height, width, Math.PI, Math.PI * 1.5, false)
            ctx.closePath()
            ctx.fill()
        }

        Connections {
            target: Services.Color
            function onMSurfaceChanged() { rightEar.requestPaint() }
        }
    }
}
