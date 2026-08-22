import QtQuick
import "textdiff.js" as TextDiff

// Drop-in TextInput carrying osu!lazer's text editing feedback:
//  - a smooth gliding, pulsing caret (see OsuTextCaret);
//  - deleted characters detach at their exact old position and fall down
//    one text height while fading out, mirroring BasicTextBox's
//    FallingDownContainer.Hide(): FadeOut(200) + MoveToY(200, Easing.InQuad).
// All native behaviour (selection, clipboard, IME commit) is untouched; the
// ghost glyphs are plain child items stacked above the live text.
TextInput {
    id: root

    // osu! FallingDownContainer.Hide() timing contract.
    readonly property int ghostFallTime: 200
    // Fall travel as a multiple of the line box so the drop clearly reads
    // beyond osu's own-height baseline.
    readonly property real ghostFallDistanceScale: 1.5
    // Cascade pacing when several characters are removed in one edit;
    // capped so a bulk delete never outlives the fall animation itself.
    readonly property int ghostStaggerStepMs: 24
    readonly property int ghostStaggerMaxTotalMs: 120

    // Set while the host replaces text programmatically so resets and
    // external syncs never spawn falling ghosts.
    property bool suppressDeleteFx: false

    // Read-only views for tests: live ghost population and its container.
    readonly property int ghostCount: ghostLayer.children.length
    readonly property alias ghostLayerItem: ghostLayer

    cursorDelegate: OsuTextCaret { editor: root }

    TextMetrics {
        id: metrics
        font: root.font
    }

    // Snapshot of the previous string so onTextChanged can diff out exactly
    // which characters were removed and where they used to sit.
    property string trackedText: ""
    Component.onCompleted: trackedText = text

    onTextChanged: {
        if (!suppressDeleteFx)
            spawnDeleteGhosts(trackedText, text)
        trackedText = text
    }

    // Replays every removed character as an independent falling ghost,
    // cascading from the rightmost glyph toward the cursor ("one by one").
    function spawnDeleteGhosts(oldText, newText) {
        if (MotionTokens.reducedMotion)
            return
        var range = TextDiff.removeRange(oldText, newText)
        if (!range)
            return
        var anchor = positionToRectangle(range.start)
        var offsets = TextDiff.cumulativeOffsets(range.removed, function(ch) {
            metrics.text = ch
            return metrics.advanceWidth
        })
        var count = range.removed.length
        for (var i = count - 1; i >= 0; i--) {
            createGhost(range.removed[i], anchor.x + offsets[i], anchor,
                        TextDiff.staggerDelayMs(i, count, ghostStaggerStepMs, ghostStaggerMaxTotalMs))
        }
    }

    function createGhost(ch, x, anchorRect, delayMs) {
        return ghostComponent.createObject(ghostLayer, {
            text: ch,
            color: root.color,
            font: root.font,
            x: x,
            y: anchorRect.y,
            width: Math.max(2, anchorRect.height),
            height: anchorRect.height,
            verticalAlignment: Text.AlignVCenter,
            fallDistance: Math.max(anchorRect.height, metrics.height) * ghostFallDistanceScale,
            fallDelayMs: delayMs
        })
    }

    // Ghosts live inside the field so the host clip bounds them like osu's
    // masked TextBox surface.
    Item {
        id: ghostLayer
        anchors.fill: parent
    }

    Component {
        id: ghostComponent

        Text {
            id: ghost

            property real fallDistance: 10
            property int fallDelayMs: 0

            Behavior on y { NumberAnimation { duration: root.ghostFallTime; easing.type: Easing.InQuad } }
            Behavior on opacity { NumberAnimation { duration: root.ghostFallTime; easing.type: Easing.InQuad } }

            Timer { id: fallTimer; interval: Math.max(1, ghost.fallDelayMs); onTriggered: { ghost.y += ghost.fallDistance; ghost.opacity = 0 } }
            Timer { id: retireTimer; interval: Math.max(1, ghost.fallDelayMs) + root.ghostFallTime; onTriggered: ghost.destroy() }
            Component.onCompleted: { fallTimer.restart(); retireTimer.restart() }
        }
    }
}
