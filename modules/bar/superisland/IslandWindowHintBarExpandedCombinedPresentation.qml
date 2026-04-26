import QtQuick
import qs.config
import "." as IslandParts

// Renders the combined bar-expanded presentation with a shared backdrop.
Item {
    id: root

    required property Item card

    readonly property real titleRowImplicitWidth: _mainPresentation.titleRowImplicitWidth

    implicitWidth: root.card._barExpandedDetachedWidth
    implicitHeight: root.card._barExpandedCombinedHeight
    width: implicitWidth
    height: implicitHeight

    // Shared backdrop keeps the title and workspace lanes readable as one surface.
    Item {
        x: 0
        y: root.card._combinedBackdropOffsetY
        width: parent.width
        height: parent.height
        z: -1

        // Vertical drift keeps the shared backdrop aligned during the title reveal.
        Behavior on y {
            NumberAnimation {
                duration: Theme.anim.moveDuration
                easing.type: Theme.anim.moveType
            }
        }

        // Title lane keeps the seam square.
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: Theme.barHeight
            radius: 0
            color: root.card._stageFill
        }

        // Workspace lane keeps the seam square.
        Rectangle {
            x: 0
            y: Theme.barHeight
            width: parent.width
            height: root.card._barExpandedDetachedContentHeight
            radius: 0
            color: root.card._stageFill
        }

        // Left corner cap sits outside the square seam.
        Canvas {
            x: -root.card._barExpandedNotchRadius
            y: -root.card._barExpandedNotchRadius
            width: root.card._barExpandedNotchRadius
            height: root.card._barExpandedNotchRadius
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.fillStyle = root.card._stageFill
                ctx.beginPath()
                ctx.moveTo(0, 0)
                ctx.lineTo(width, 0)
                ctx.lineTo(width, height)
                ctx.arc(0, height, width, 0, -Math.PI / 2, true)
                ctx.fill()
            }
        }

        // Right corner cap mirrors the same outer arc.
        Canvas {
            x: parent.width
            y: -root.card._barExpandedNotchRadius
            width: root.card._barExpandedNotchRadius
            height: root.card._barExpandedNotchRadius
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.fillStyle = root.card._stageFill
                ctx.beginPath()
                ctx.moveTo(0, 0)
                ctx.lineTo(width, 0)
                ctx.lineTo(width, height)
                ctx.arc(0, height, width, 0, -Math.PI / 2, true)
                ctx.fill()
            }
        }
    }

    // Main bar-expanded presentation is the widened top lane only.
    IslandParts.IslandWindowHintBarExpandedMainPresentation {
        id: _mainPresentation

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        card: root.card
    }

    // Detached lower lane stays below the main host.
    IslandParts.IslandWindowHintBarExpandedDetachedPresentation {
        anchors.top: parent.top
        anchors.topMargin: root.card._padV + root.card._stagePadV
        anchors.horizontalCenter: parent.horizontalCenter
        card: root.card
    }
}
