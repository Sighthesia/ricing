import QtQuick
import qs.config

// Click ripple overlay — renders an expanding circle from the click point.
//
// Z-ordering requirement: declare AFTER content children, BEFORE MouseArea,
// so the ripple appears above content but the mouse events still reach MouseArea.
//
// Usage:
//   Row { ... }                  // content
//   ClickRipple {
//     id: ripple
//     anchors.fill: parent
//   }
//   MouseArea {
//     onClicked: (mouse) => ripple.triggerRipple(mouse.x, mouse.y)
//   }
Item {
    id: root

    property color rippleColor: Colors.highlight
    // Peak opacity of the ripple burst; reduce for subtler surfaces.
    property real rippleOpacity: 0.28
    // Declared for API parity with HoverRevealHighlight; rounded clip is handled
    // by the parent container — the circular ripple itself does not need it.
    property real radius: 0

    clip: true

    property real _rx: width  / 2
    property real _ry: height / 2

    // 2× diagonal guarantees full coverage from any click point within the item.
    readonly property real _maxSize: 2 * Math.sqrt(width * width + height * height)

    function triggerRipple(clickX, clickY) {
        _rx = clickX
        _ry = clickY
        _anim.restart()
    }

    Item {
        x: root._rx - root._maxSize / 2
        y: root._ry - root._maxSize / 2
        width: root._maxSize
        height: root._maxSize

        Rectangle {
            id: _circle
            anchors.fill: parent
            radius: width / 2
            color: root.rippleColor
            opacity: 0
            scale: 0
            transformOrigin: Item.Center
        }
    }

    ParallelAnimation {
        id: _anim

        // Expand from the click point outward.
        NumberAnimation {
            target: _circle; property: "scale"
            from: 0; to: 1
            duration: 420; easing.type: Easing.OutQuart
        }

        // Flash at peak opacity then fade cleanly.
        SequentialAnimation {
            NumberAnimation {
                target: _circle; property: "opacity"
                from: root.rippleOpacity; to: root.rippleOpacity
                duration: 50
            }
            NumberAnimation {
                target: _circle; property: "opacity"
                to: 0
                duration: 370; easing.type: Easing.OutQuad
            }
        }
    }
}
