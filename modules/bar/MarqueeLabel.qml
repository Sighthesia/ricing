import QtQuick
import "../lazerbar"

// Single-line label that grows with its natural width up to a cap, then
// marquee-scrolls instead of eliding. Natural width comes from TextMetrics,
// never from the label's own implicitWidth, so a clipping/elide state can
// never feed back into the measurement (the cause of collapsed-width bugs).
// Under reduced motion it degrades to a statically elided line.
Item {
    id: root

    property string text: ""
    // Width cap where growth stops and marquee scrolling takes over.
    property int maxWidth: 300
    property color textColor
    property int pixelSize: 12
    property bool bold: false
    readonly property bool overflowing: metrics.advanceWidth > root.maxWidth
    // Exposed for entrance/ghost choreography that needs the raw label or
    // the clipping slot (e.g. per-character fade-ins sharing this origin).
    property alias label: label
    property alias slot: clipSlot
    // Unclipped overlay above the label, for effects that must escape the
    // clip window (e.g. exit ghosts falling past the surface).
    property alias overlay: overlayLayer

    implicitWidth: Math.min(metrics.advanceWidth, root.maxWidth)
    implicitHeight: metrics.height

    // Clipping window; the full-width label slides inside it while scrolling.
    Item {
        id: clipSlot

        anchors.fill: parent
        clip: true

        Text {
            id: label

            text: root.text
            color: root.textColor
            font.pixelSize: root.pixelSize
            font.bold: root.bold
            // Reduced motion keeps a static ellipsis; otherwise the label
            // always renders at full natural width and scrolls instead.
            width: MotionTokens.reducedMotion ? Math.min(metrics.advanceWidth, root.maxWidth) : metrics.advanceWidth
            elide: MotionTokens.reducedMotion ? Text.ElideRight : Text.ElideNone
        }
    }

    Item {
        id: overlayLayer

        anchors.fill: parent
        clip: false
    }

    // Independent measuring context — unaffected by the label's live layout.
    TextMetrics {
        id: metrics

        font: label.font
        text: root.text
    }

    // Marquee is sync-driven: every input change (text, reveal opacity, slot
    // width) resets x to 0 and restarts against current geometry, so a shorter
    // title can never leave the label parked outside the clip window and a
    // mid-morph slot width can never leave stale from/to offsets.
    function syncScroll() {
        var shouldRun = root.overflowing && !MotionTokens.reducedMotion
            && label.opacity >= 0.99 && clipSlot.width > 0
        scroll.stop()
        label.x = 0
        if (shouldRun)
            scroll.restart()
    }

    Component.onCompleted: syncScroll()
    onTextChanged: syncScroll()

    Connections {
        target: label
        function onOpacityChanged() { root.syncScroll() }
    }

    // Slot width changes per frame during the host pill's width morph; only
    // resync once it settles so the scroll is not perpetually restarted.
    Timer {
        id: slotWidthSettle

        interval: 240
        onTriggered: root.syncScroll()
    }

    Connections {
        target: clipSlot
        function onWidthChanged() {
            if (root.overflowing && !MotionTokens.reducedMotion)
                slotWidthSettle.restart()
        }
    }

    SequentialAnimation {
        id: scroll

        loops: Animation.Infinite

        PauseAnimation { duration: 1400 }
        NumberAnimation {
            target: label
            property: "x"
            from: 0
            to: -(metrics.advanceWidth - clipSlot.width)
            duration: Math.max(2000, (metrics.advanceWidth - clipSlot.width) * 18)
            easing.type: Easing.Linear
        }
        PauseAnimation { duration: 1400 }
        NumberAnimation {
            target: label
            property: "x"
            from: -(metrics.advanceWidth - clipSlot.width)
            to: 0
            duration: Math.max(2000, (metrics.advanceWidth - clipSlot.width) * 18)
            easing.type: Easing.Linear
        }
    }

    // --- Text transition: scan-line sweep ---
    // A virtual scan line sweeps left to right across the label. Where it
    // just passed, new characters fade in semi-transparent; where it has
    // not yet reached, old characters fall away in sequence; at the line
    // itself there is a brief blank gap. Once the sweep completes the
    // revealed line settles to full opacity. Inert unless a host calls
    // transitionFrom().
    // Wavefront tightness rule: each per-char animation lasts about one
    // sweep step, so only a single char falls on the leading side and a
    // single char fades on the trailing side at any instant. The animated
    // zone's width is therefore speed × duration ≈ one character.
    readonly property int ghostFallTime: 40
    readonly property real ghostFallDistanceScale: 1.0
    // Per-character sweep step — the scan line's travel speed.
    readonly property int scanStepMs: 40
    // Blank window the line leaves before the next char starts fading in.
    readonly property int scanGapMs: 24
    readonly property int scanRevealMs: 40
    // Swept characters rest semi-transparent until the whole sweep ends.
    readonly property real scanRestOpacity: 0.65
    readonly property int transitionMaxChars: 48
    property var _enterRow: null

    // Play the scan-line transition for a just-applied text change.
    // Both texts are passed explicitly: a live `text:` binding may not have
    // re-evaluated yet when the host's change handler runs, so root.text
    // cannot be trusted as either value here.
    function transitionFrom(oldText, newText) {
        if (MotionTokens.reducedMotion || oldText === "" || oldText === newText)
            return
        spawnGhosts(oldText)
        label.opacity = 0
        label.x = 0
        if (root._enterRow) {
            root._enterRow.destroy()
            root._enterRow = null
        }
        root._enterRow = scanRowComponent.createObject(clipSlot, { chars: newText })
        // Safety net: no matter what happens inside the row, the real
        // label always comes back.
        enterGuard.restart()
    }

    // Old characters fall away in sequence, one per sweep step; ghosts ride
    // the unclipped overlay so they can fall past the surface.
    function spawnGhosts(oldText) {
        if (oldText === "")
            return
        var count = Math.min(oldText.length, root.transitionMaxChars)
        for (var i = 0; i < count; i++) {
            ghostMetrics.font = label.font
            ghostMetrics.text = oldText.slice(0, i)
            lyricGhostComponent.createObject(overlayLayer, {
                text: oldText[i],
                color: textColor,
                font: label.font,
                x: ghostMetrics.advanceWidth,
                y: 0,
                opacity: 1,
                delay: i * root.scanStepMs,
                // Travel one-and-a-half line heights, like the field's delete ghosts.
                fallDistance: Math.max(1, label.height) * root.ghostFallDistanceScale
            })
        }
    }

    // Fallback restores the label if the enter row's own timers ever fail.
    Timer {
        id: enterGuard

        interval: 2400
        onTriggered: {
            if (root._enterRow) {
                root._enterRow.destroy()
                root._enterRow = null
            }
            label.opacity = 1
            label.x = 0
        }
    }

    TextMetrics {
        id: ghostMetrics
    }

    Component {
        id: lyricGhostComponent

        Text {
            id: ghost

            property real fallDistance: 10
            property int delay: 0

            font.pixelSize: root.pixelSize
            elide: Text.ElideNone

            Behavior on y { NumberAnimation { duration: root.ghostFallTime; easing.type: Easing.InQuad } }
            Behavior on opacity { NumberAnimation { duration: root.ghostFallTime; easing.type: Easing.InQuad } }

            Timer {
                id: fallTimer

                interval: ghost.delay > 0 ? ghost.delay + 1 : 1
                onTriggered: {
                    ghost.y += ghost.fallDistance
                    ghost.opacity = 0
                }
            }
            Timer {
                id: retireTimer

                running: true
                interval: (ghost.delay > 0 ? ghost.delay : 0) + root.ghostFallTime + 2
                onTriggered: ghost.destroy()
            }
            Component.onCompleted: {
                fallTimer.restart()
                retireTimer.restart()
            }
        }
    }

    Component {
        id: scanRowComponent

        Row {
            id: enterRow

            property string chars: ""

            spacing: 0

            // When the sweep finishes: total travel + gap + one reveal.
            readonly property int sweepTotal:
                Math.min(chars.length, root.transitionMaxChars) * root.scanStepMs

            Repeater {
                model: Math.min(enterRow.chars.length, root.transitionMaxChars)

                Text {
                    id: charItem

                    required property int index

                    text: enterRow.chars[index]
                    color: root.textColor
                    font.pixelSize: root.pixelSize
                    font.bold: root.bold
                    opacity: 0

                    Behavior on opacity { NumberAnimation { duration: root.scanRevealMs; easing.type: Easing.OutQuad } }

                    // The line passes this char: fade in to the resting
                    // semi-transparent level (the drop gap keeps the line
                    // itself blank).
                    Timer {
                        running: true
                        interval: charItem.index * root.scanStepMs + root.scanGapMs + 1
                        onTriggered: charItem.opacity = root.scanRestOpacity
                    }

                    // Sweep done: the revealed line settles to full ink.
                    Timer {
                        running: true
                        interval: enterRow.sweepTotal + root.scanGapMs + root.scanRevealMs + 1
                        onTriggered: charItem.opacity = 1
                    }
                }
            }

            Timer {
                id: retireTimer

                running: true
                interval: enterRow.sweepTotal + root.scanGapMs + root.scanRevealMs + MotionTokens.fast
                onTriggered: {
                    label.opacity = 1
                    label.x = 0
                    if (root._enterRow === enterRow)
                        root._enterRow = null
                    enterRow.destroy()
                }
            }
        }
    }
}
