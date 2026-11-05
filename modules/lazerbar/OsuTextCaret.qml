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
//  - the pulse rides the inner container, not the caret itself: the outer
//    caret carries the 200ms FadeColour(White) and its own 200ms show/hide
//    fade, so appearing and colour are two independent legs;
//  - Hide() = FadeOut(200).
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
    // Bar color. osu fades the caret to white (FadeColour(Color4.White));
    // hosts on light surfaces override this so the bar keeps its contrast —
    // the Afloat default stays white to keep the osu contract in one place.
    property color caretColor: "#FFFFFF"
    readonly property int moveTime: 60
    readonly property int pulseDecay: 300
    readonly property int hideFadeTime: 200
    // osu fades the bar's colour in over the same 200ms it takes to hide, so
    // arriving at a new colour and arriving on screen share one rhythm.
    readonly property int colourFadeTime: 200
    readonly property real blinkHigh: 0.7
    readonly property real blinkLow: 0.4

    // Test-facing read-only view of the visible bar's current opacity.
    readonly property real visualOpacity: opacity * barPulse.opacity

    width: 3
    radius: 1
    // This rectangle is a carrier, not the bar: it owns geometry and the
    // show/hide fade, and paints nothing. Leaving it filled put a second, fully
    // opaque bar under the pulsing one - two stacked fills compose to
    // 1-(1-1)(1-p) = 1, so the caret sat solid at full strength and the pulse
    // was invisible while still running.
    color: "transparent"
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

    // The visible bar. It is a child rather than the caret itself because osu
    // keeps two clocks apart: the outer caret owns show/hide and FadeColour,
    // the inner CaretBeatSyncedContainer owns the pulse. Folding them onto one
    // rectangle means the beat animation overwrites the show fade, so the bar
    // can never cross-fade - it snaps to 0.7 on the focus frame.
    Rectangle {
        id: barPulse
        anchors.fill: parent
        radius: caretRoot.radius
        color: caretRoot.caretColor
        opacity: 1

        // osu! FadeColour(White, 200, Easing.Out) on every DisplayAt, carried by
        // the layer that actually paints. A host that re-tints the caret (the
        // lock screen follows the scheme) therefore fades rather than snapping.
        Behavior on color {
            enabled: !MotionTokens.reducedMotion
            ColorAnimation { duration: caretRoot.colourFadeTime; easing.type: Easing.OutQuad }
        }
    }

    // osu! pulse: the snap is a zero-duration step, the decay is one beat.
    SequentialAnimation {
        id: osuBlink
        loops: Animation.Infinite
        NumberAnimation { target: barPulse; property: "opacity"; to: caretRoot.blinkHigh; duration: 0 }
        NumberAnimation {
            target: barPulse
            property: "opacity"
            to: caretRoot.blinkLow
            duration: caretRoot.pulseDecay
            easing.type: Easing.InOutSine
        }
    }

    // osu shows the caret with a 200ms fade from the colour it is arriving at,
    // so focus arrival is one leg and the pulse starts after it.
    NumberAnimation {
        id: showFade
        target: caretRoot
        property: "opacity"
        to: 1
        duration: caretRoot.colourFadeTime
        easing.type: Easing.OutQuad
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
        hideFade.stop()
        showFade.stop()

        if (!caretRoot.focused) {
            // Leaving restarts the pulse from a known phase so a returning
            // caret does not resume mid-decay.
            barPulse.opacity = 1
            if (MotionTokens.reducedMotion)
                caretRoot.opacity = 0
            else
                hideFade.start()
            return
        }

        barPulse.opacity = 1
        if (MotionTokens.reducedMotion) {
            caretRoot.opacity = 1
            return
        }

        // Two legs, as in osu: the bar fades in over 200ms while the pulse
        // already owns the inner container's alpha.
        showFade.start()
        osuBlink.start()
    }
}
