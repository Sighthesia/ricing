import QtQuick

// osu!lazer-style keyboard caret rendered as an overlay child of the target
// TextInput. The native cursor is suppressed by an empty cursorDelegate on
// the host; this bar binds to the target's cursorRectangle so every position
// change rides a Behavior (native delegate placement bypasses Behaviors
// entirely, which is why the caret used to jump).
// Glides over 60ms with Easing.Out and pulses 0.7 -> 0.4 like BasicCaret;
// fades away when the field loses keyboard focus (OsuCaret.Hide()).
Rectangle {
    id: caretRoot

    // Owning TextInput; drives geometry and focus state.
    property TextInput target: null

    readonly property bool focused: target ? target.activeFocus : false

    // osu! BasicTextBox contracts: caret_move_time = 60ms, blink pulse
    // oscillating 0.7 -> 0.4, Hide() fade ~= 200ms.
    readonly property int moveTime: 60
    readonly property real blinkHigh: 0.7
    readonly property real blinkLow: 0.4
    readonly property int blinkHalfPeriod: 250

    // Test-facing read-only view of the visible bar's current opacity.
    readonly property real visualOpacity: opacity

    width: 3
    radius: 1
    color: "#FFFFFF"
    opacity: 0

    height: target && target.cursorRectangle.height > 0
            ? target.cursorRectangle.height
            : (target ? target.font.pixelSize * 1.5 : 12)

    x: target ? target.cursorRectangle.x : 0
    y: target ? target.cursorRectangle.y : 0

    Behavior on x {
        enabled: !MotionTokens.reducedMotion
        NumberAnimation { duration: caretRoot.moveTime; easing.type: Easing.OutQuint }
    }

    Behavior on opacity {
        enabled: !MotionTokens.reducedMotion
        NumberAnimation { duration: caretRoot.blinkHalfPeriod; easing.type: Easing.InOutSine }
    }

    // Pulse driver: flip the target opacity every half period and let the
    // Behavior ease between the stops like osu's beat-synced pulse.
    Timer {
        id: blinkTimer
        interval: caretRoot.blinkHalfPeriod
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var mid = (caretRoot.blinkHigh + caretRoot.blinkLow) / 2
            caretRoot.opacity = caretRoot.opacity < mid ? caretRoot.blinkHigh : caretRoot.blinkLow
        }
    }

    onFocusedChanged: syncFocusState()
    Component.onCompleted: syncFocusState()

    function syncFocusState() {
        blinkTimer.stop()
        if (!caretRoot.focused) {
            caretRoot.opacity = 0
            return
        }
        if (MotionTokens.reducedMotion) {
            caretRoot.opacity = 1
            return
        }
        blinkTimer.start()
    }
}
