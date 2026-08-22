import QtQuick

// osu!lazer-style keyboard caret used as a TextInput.cursorDelegate.
// Glides between cursor positions over 60ms with Easing.Out and pulses
// opacity 0.7 -> 0.4 on a 500ms InOutSine loop instead of hard blinking,
// mirroring BasicTextBox.BasicCaret; fades out over 200ms when the field
// loses keyboard focus, mirroring OsuCaret.Hide().
Item {
    id: caretRoot

    // Owning TextInput; supplies focus state and line geometry. The host
    // TextInput assigns x/y/height to this delegate directly every layout pass.
    property Item editor: null

    readonly property bool focused: editor ? editor.activeFocus : false

    // osu! BasicTextBox contracts: caret_move_time = 60ms, blink pulse
    // FadeTo(0.7) -> FadeTo(0.4, 500ms, InOutSine), Hide() fade = 200ms.
    readonly property int moveTime: 60
    readonly property real blinkHigh: 0.7
    readonly property real blinkLow: 0.4
    readonly property int blinkPeriod: 500
    readonly property int fadeTime: 200

    // Test-facing read-only view of the visible bar's current opacity.
    readonly property real visualOpacity: caretVisual.opacity

    // Deferred so gaining focus snaps the caret into place before the first
    // assignment instead of gliding in from x=0.
    property bool glideReady: false

    width: 3
    // Visibility is driven entirely on caretVisual below; the delegate root
    // itself must stay opaque or the bar can never be seen.
    // The host TextInput normally sizes the delegate to the line height; the
    // fallback keeps the bar visible if that assignment never lands.
    height: editor && editor.cursorRectangle.height > 0
            ? editor.cursorRectangle.height
            : (editor ? editor.font.pixelSize * 1.5 : 12)

    onXChanged: {
        if (!glideReady)
            Qt.callLater(function() { caretRoot.glideReady = true })
    }

    // Smooth cursor travel: the whole point of the delegate. Typing keeps
    // retargeting the assignment and the behavior glides from wherever the
    // caret currently is, exactly like osu's DisplayAt MoveTo.
    Behavior on x {
        enabled: caretRoot.glideReady && !MotionTokens.reducedMotion
        NumberAnimation { duration: caretRoot.moveTime; easing.type: Easing.Out }
    }

    // One pulse cycle: snap bright, ease down, repeat forever while focused.
    SequentialAnimation {
        id: blinkAnim
        loops: Animation.Infinite
        NumberAnimation { target: caretVisual; property: "opacity"; to: caretRoot.blinkHigh; duration: 0 }
        NumberAnimation { target: caretVisual; property: "opacity"; to: caretRoot.blinkLow; duration: caretRoot.blinkPeriod; easing.type: Easing.InOutSine }
    }

    // Focus-loss exit path (OsuCaret.Hide(): FadeOut(200)).
    NumberAnimation {
        id: hideAnim
        target: caretVisual
        property: "opacity"
        to: 0
        duration: caretRoot.fadeTime
        easing.type: Easing.Out
    }

    onFocusedChanged: syncFocusState()
    Component.onCompleted: syncFocusState()

    function syncFocusState() {
        hideAnim.stop()
        blinkAnim.stop()
        if (!caretRoot.focused) {
            hideAnim.restart()
            return
        }
        if (MotionTokens.reducedMotion) {
            caretVisual.opacity = 1
            return
        }
        blinkAnim.restart()
    }

    // Caret bar kept at 90% line height like osu's InternalChild Height=0.9f.
    Rectangle {
        id: caretVisual
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: Math.max(1, parent.height * 0.9)
        radius: 1
        color: "#FFFFFF"
        opacity: 0
    }
}
