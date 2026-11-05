import QtQuick
import "../lazerbar" as Lazer

// One osu!lazer password cell: a vertical capsule that grows from the centre
// when a character lands and falls away while fading when it is deleted.
//
// Reference: osu.Game/Graphics/UserInterface/OsuPasswordTextBox.cs
// (PasswordMaskChar: 0.4em x 0.8em capsule, 500ms OutQuint reveal) and
// osu-framework BasicTextBox.cs (FallingDownContainer: 200ms fade + fall).
Item {
    id: dot

    property int index: 0
    property bool filled: false
    property real cellWidth: 9
    property real cellHeight: 18
    property color dotColor: "white"

    readonly property bool reducedMotion: Lazer.MotionTokens.reducedMotion
    // cellWidth is half an em, so 0.8 of it is the 0.4em capsule width.
    readonly property real capsuleWidth: cellWidth * 0.8
    readonly property real capsuleHeight: cellHeight * 0.8
    // Guards the initial binding update: a cell may be born filled.
    property bool animationsArmed: false

    width: cellWidth
    height: cellHeight

    // The capsule stays centre-anchored so it grows symmetrically; the falling
    // layer carries the delete offset so the growth itself stays centred.
    Item {
        id: fallingLayer
        anchors.fill: parent

        Rectangle {
            id: capsule
            anchors.centerIn: parent
            width: dot.capsuleWidth
            radius: width / 2
            color: dot.dotColor
            height: 0
            opacity: 0
        }
    }

    // Reveal: height and opacity share the 500ms OutQuint curve.
    ParallelAnimation {
        id: growAnimation
        NumberAnimation {
            target: capsule
            property: "height"
            from: 0
            to: dot.capsuleHeight
            duration: 500
            easing.type: Easing.OutQuint
        }
        NumberAnimation {
            target: capsule
            property: "opacity"
            from: 0
            to: 1
            duration: 500
            easing.type: Easing.OutQuint
        }
    }

    // Delete: linear fade while dropping one cell height with InQuad.
    ParallelAnimation {
        id: fallAnimation
        NumberAnimation {
            target: fallingLayer
            property: "y"
            from: 0
            to: dot.cellHeight
            duration: 200
            easing.type: Easing.InQuad
        }
        NumberAnimation {
            target: capsule
            property: "opacity"
            to: 0
            duration: 200
            easing.type: Easing.Linear
        }
        onFinished: dot.resetEmpty()
    }

    function growNow() {
        // A backspace followed by typing must regrow from scratch, so kill any
        // half-finished fall first.
        growAnimation.stop()
        fallAnimation.stop()
        fallingLayer.y = 0
        if (reducedMotion) {
            capsule.height = capsuleHeight
            capsule.opacity = 1
            return
        }
        growAnimation.start()
    }

    function fallNow() {
        growAnimation.stop()
        fallAnimation.stop()
        if (reducedMotion) {
            resetEmpty()
            return
        }
        fallAnimation.start()
    }

    function resetEmpty() {
        fallingLayer.y = 0
        capsule.height = 0
        capsule.opacity = 0
    }

    onFilledChanged: {
        if (!animationsArmed)
            return
        if (filled)
            growNow()
        else
            fallNow()
    }

    // A reduced-motion change mid-flight snaps to the matching end state.
    onReducedMotionChanged: {
        if (!animationsArmed)
            return
        if (filled)
            growNow()
        else
            resetEmpty()
    }

    Component.onCompleted: {
        animationsArmed = true
        if (filled)
            growNow()
    }
}
