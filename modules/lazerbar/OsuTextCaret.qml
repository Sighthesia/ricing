import QtQuick

// osu!lazer-style keyboard caret. Geometry comes either from a TextInput's
// cursorRectangle or from the explicit cursor* properties, so editors that
// draw their own text (the lock screen's password cells) can share the same
// caret contract.
//
// Reference: osu.Game/Graphics/UserInterface/OsuTextBox.cs, nested OsuCaret.
//  - 3px wide, 0.9 of the line box tall, 1px radius;
//  - glide 60ms Easing.Out;
//  - beat-synced pulse: snap to 0.7, then InOutSine decay to 0.4 over one beat
//    (MinimumBeatLength = 300ms, so 300ms here);
//  - Hide() = FadeOut(200).
// `osuPulse: false` restores the previous 250ms symmetric breathe, so the
// change can be reverted from one place without touching any call site.
Rectangle {
    id: caretRoot

    // Owning TextInput; drives geometry and focus unless overridden below.
    property TextInput target: null

    // Explicit geometry for editors without a TextInput (lock password row).
    property bool focused: target ? target.activeFocus : false
    property real cursorX: target ? target.cursorRectangle.x : 0
    property real cursorY: target && target.cursorRectangle.height > 0
            ? target.cursorRectangle.y + (target.cursorRectangle.height - height) / 2
            : (target ? target.cursorRectangle.y : 0)
    property real cursorHeight: target
            ? (target.cursorRectangle.height > 0
               ? target.cursorRectangle.height * 0.9
               : target.font.pixelSize * 0.9)
            : 0

    // osu! OsuCaret values (see the header).
    property bool osuPulse: true
    readonly property int moveTime: 60
    readonly property int pulseDecay: 300
    readonly property int hideFadeTime: 200
    readonly property real blinkHigh: 0.7
    readonly property real blinkLow: 0.4
    // Previous Afloat implementation, kept for the revert path.
    readonly property int legacyHalfPeriod: 250

    // Test-facing read-only view of the visible bar's current opacity.
    readonly property real visualOpacity: opacity

    width: 3
    radius: 1
    color: "#FFFFFF"
    opacity: 0

    height: cursorHeight

    x: target ? target.cursorRectangle.x : cursorX
    y: target && target.cursorRectangle.height > 0
       ? target.cursorRectangle.y + (target.cursorRectangle.height - height) / 2
       : cursorY

    Behavior on x {
        enabled: !MotionTokens.reducedMotion
        NumberAnimation { duration: caretRoot.moveTime; easing.type: Easing.OutQuad }
    }

    // osu! pulse: the snap is a zero-duration step, the decay is one beat.
    SequentialAnimation {
        id: osuBlink
        loops: Animation.Infinite
        NumberAnimation { target: caretRoot; property: "opacity"; to: caretRoot.blinkHigh; duration: 0 }
        NumberAnimation {
            target: caretRoot
            property: "opacity"
            to: caretRoot.blinkLow
            duration: caretRoot.pulseDecay
            easing.type: Easing.InOutSine
        }
    }

    // Revert path: the old triangle wave, eased in both directions.
    Timer {
        id: legacyBlinkTimer
        interval: caretRoot.legacyHalfPeriod
        repeat: true
        onTriggered: {
            var mid = (caretRoot.blinkHigh + caretRoot.blinkLow) / 2
            legacyBlink.to = caretRoot.opacity < mid ? caretRoot.blinkHigh : caretRoot.blinkLow
            legacyBlink.restart()
        }
    }
    NumberAnimation {
        id: legacyBlink
        target: caretRoot
        property: "opacity"
        duration: caretRoot.legacyHalfPeriod
        easing.type: Easing.InOutSine
    }

    // osu! OsuCaret.Hide().
    NumberAnimation {
        id: hideFade
        target: caretRoot
        property: "opacity"
        to: 0
        duration: caretRoot.hideFadeTime
    }

    onFocusedChanged: syncFocusState()
    Component.onCompleted: syncFocusState()

    function syncFocusState() {
        osuBlink.stop()
        legacyBlinkTimer.stop()
        legacyBlink.stop()
        hideFade.stop()

        if (!caretRoot.focused) {
            if (MotionTokens.reducedMotion)
                caretRoot.opacity = 0
            else
                hideFade.start()
            return
        }

        if (MotionTokens.reducedMotion) {
            caretRoot.opacity = 1
            return
        }

        if (caretRoot.osuPulse) {
            caretRoot.opacity = caretRoot.blinkHigh
            osuBlink.start()
        } else {
            // Keep the old fade-in on focus instead of leaving the bar
            // invisible until the first half period elapses.
            legacyBlink.to = caretRoot.blinkHigh
            legacyBlink.restart()
            legacyBlinkTimer.start()
        }
    }
}
