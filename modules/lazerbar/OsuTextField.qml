import QtQuick
import "textdiff.js" as TextDiff

// Drop-in TextInput carrying osu!lazer's text editing feedback:
//  - a smooth gliding, pulsing caret (see OsuTextCaret);
//  - deleted characters detach at their exact old position and fall down
//    one text height while fading out, mirroring BasicTextBox's
//    FallingDownContainer.Hide(): FadeOut(200) + MoveToY(200, Easing.InQuad).
// All native behaviour (selection, clipboard, IME commit) is untouched; the
// ghost glyphs are spawned on the scene root so they can fall past every
// enclosing surface.
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
    readonly property alias caretItem: caret

    // Empty delegate swallows the native cursor; the real bar is our own
    // child bound to cursorRectangle so every move rides a Behavior.
    cursorDelegate: Item { }

    OsuTextCaret {
        id: caret
        target: root
        z: 2
    }

    TextMetrics {
        id: metrics
        font: root.font
    }

    // Snapshot of the previous string so onTextChanged can diff out exactly
    // which characters were removed and where they used to sit.
    property string trackedText: ""

    Component.onCompleted: {
        trackedText = text
        adoptRootGhostLayer()
    }

    onParentChanged: adoptRootGhostLayer()

    // The field clips its own text, so ghosts parented here could never fall
    // past the surface. Hand the layer to the scene root with a dominant z:
    // no intermediate clip and no later sibling subtree can cut the fall.
    function adoptRootGhostLayer() {
        var top = parent
        while (top && top.parent)
            top = top.parent
        if (!top || top === root)
            return
        ghostLayer.parent = top
        ghostLayer.z = 1000000
    }

    // Reparented layers do not die with their original owner.
    Component.onDestruction: ghostLayer.destroy()

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
        // Map fresh at spawn time: ancestor panels slide and scale between
        // edits, so any cached layer geometry would drift away from the field.
        var origin = root.mapToItem(ghostLayer, x, anchorRect.y)
        var unitEnd = root.mapToItem(ghostLayer, x + 1, anchorRect.y)
        var ancestorScale = Math.abs(unitEnd.x - origin.x) || 1
        return ghostComponent.createObject(ghostLayer, {
            text: ch,
            color: root.color,
            font: root.font,
            x: origin.x,
            y: origin.y,
            width: Math.max(2, anchorRect.height),
            height: anchorRect.height,
            transformOrigin: Item.TopLeft,
            scale: ancestorScale,
            verticalAlignment: Text.AlignVCenter,
            fallDistance: Math.max(anchorRect.height, metrics.height) * ghostFallDistanceScale * ancestorScale,
            fallDelayMs: delayMs
        })
    }

    // Ghost host on the scene root; clip stays off so falling glyphs may
    // exit any enclosing surface like osu's removals. Ghost coordinates are
    // mapped fresh at spawn time (see createGhost).
    Item {
        id: ghostLayer
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
