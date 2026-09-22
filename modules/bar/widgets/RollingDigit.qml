import QtQuick
import "../../lazerbar"

// Rolling digit strip ported from the pre-lazer bar (main branch
// RollingDigit.qml): a 0-9 strip inside a clipped window that slides when
// the target digit changes, giving the clock its flip/roll transition.
// Lazer adaptation: plain Text + LazerTheme-agnostic colors via properties,
// all timings from MotionTokens with a reducedMotion gate.
Item {
    id: root

    property int targetDigit: 0
    property color digitColor: "white"
    property color mutedDigitColor: "white"
    property int digitPixelSize: 15
    property string digitFontFamily: "monospace"
    property bool digitBold: true
    property real overscanFactor: 1.35
    property int transitionDuration: MotionTokens.medium
    property int transitionEasing: MotionTokens.clickFlashEasing

    readonly property int digitHeight: Math.max(1, Math.round(root.digitPixelSize * root.overscanFactor))
    readonly property int digitWidth: Math.max(1, Math.ceil(_digitMetrics.advanceWidth))

    width: digitWidth
    height: digitHeight
    clip: true

    // Measure the widest digit so the strip never reflows mid-roll.
    TextMetrics {
        id: _digitMetrics
        text: "8"
        font.family: root.digitFontFamily
        font.pixelSize: root.digitPixelSize
        font.bold: root.digitBold
    }

    property real _displayDigit: root.targetDigit
    onTargetDigitChanged: _displayDigit = root.targetDigit

    Behavior on _displayDigit {
        enabled: !MotionTokens.reducedMotion
        NumberAnimation {
            duration: root.transitionDuration
            easing.type: root.transitionEasing
        }
    }

    // Ten stacked digits; the window shows the slice at _displayDigit.
    Repeater {
        model: 10
        Text {
            width: root.width
            height: root.digitHeight
            y: index * root.digitHeight - root._displayDigit * root.digitHeight
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: index.toString()
            color: index === root.targetDigit ? root.digitColor : root.mutedDigitColor
            font.family: root.digitFontFamily
            font.pixelSize: root.digitPixelSize
            font.bold: root.digitBold
        }
    }
}
