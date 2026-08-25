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

    // --- Text transition: scan-line trigger ---
    // A virtual scan line sweeps left to right across the label in a fixed
    // time (a percentage-of-length pace, so the traverse speed reads the
    // same on any text). The line is only a trigger: each character it
    // passes enters its full animation at standard durations — old chars
    // fall with the shared ghost contract (200ms), new chars fade in
    // (140ms). The wavefront width simply emerges from speed × duration.
    // At the line itself there is a brief blank gap. Inert unless a host
    // calls transitionFrom().
    readonly property int ghostFallTime: 200
    readonly property real ghostFallDistanceScale: 1.5
    // Time for the scan line to cross one whole label.
    readonly property int scanSweepMs: 480
    // Blank window the line leaves before the char behind it fades in.
    // Pinned to the fall duration (+ margin) so a position's new char only
    // starts appearing after its old char has fully dropped away — no
    // same-spot overlap between the falling ghost and the reveal.
    readonly property int scanGapMs: ghostFallTime + 20
    readonly property int scanRevealMs: 140
    readonly property int transitionMaxChars: 48
    property var _enterRow: null
    property bool _sweepActive: false

    // Delay until the scan line reaches pixel offset x on a line `width`
    // wide — percentage-of-length mapping, constant px/s velocity.
    function _scanDelayAt(xOffset, lineWidth) {
        var span = Math.max(1, lineWidth)
        return Math.round(root.scanSweepMs * Math.min(1, Math.max(0, xOffset / span)))
    }

    // Tear down any in-flight sweep row and restore the real label.
    function _stopSweepRow() {
        if (root._enterRow) {
            root._enterRow.destroy()
            root._enterRow = null
        }
        label.opacity = 1
        label.x = 0
    }

    // Kill ghosts still mid-fall so an interrupted sweep can never rain
    // old characters over the next transition.
    function _clearGhosts() {
        var kids = overlayLayer.children
        for (var i = kids.length - 1; i >= 0; i--)
            kids[i].destroy()
    }

    // Play the scan-line transition for a just-applied text change.
    // Both texts are passed explicitly: a live `text:` binding may not have
    // re-evaluated yet when the host's change handler runs, so root.text
    // cannot be trusted as either value here.
    //
    // Any in-flight choreography collapses into this sweep — row, ghosts,
    // and any pending fade are torn down first, so wavefronts never stack
    // and every change (including rapid focus switches that pass through
    // transient titles) plays the scan.
    function transitionFrom(oldText, newText) {
        if (MotionTokens.reducedMotion || oldText === "" || oldText === newText)
            return
        root._sweepActive = false
        _stopSweepRow()
        _clearGhosts()
        root._sweepActive = true
        spawnGhosts(oldText)
        label.opacity = 0
        label.x = 0
        root._enterRow = scanRowComponent.createObject(clipSlot, {
            chars: newText,
            delays: _charDelays(newText)
        })
        // Safety net: no matter what happens inside the row, the real
        // label always comes back.
        enterGuard.restart()
    }

    // Old characters fall away as the line reaches them; ghosts ride the
    // unclipped overlay so they can fall past the surface.
    function spawnGhosts(oldText) {
        if (oldText === "")
            return
        var count = Math.min(oldText.length, root.transitionMaxChars)
        ghostMetrics.font = label.font
        ghostMetrics.text = oldText
        // Span over the text's own full width — never the live slot width,
        // which still carries the previous text's geometry during the
        // change handler and would clamp all later chars to one delay.
        var span = Math.max(1, ghostMetrics.advanceWidth)
        for (var i = 0; i < count; i++) {
            ghostMetrics.text = oldText.slice(0, i)
            lyricGhostComponent.createObject(overlayLayer, {
                text: oldText[i],
                color: textColor,
                font: label.font,
                x: ghostMetrics.advanceWidth,
                y: 0,
                opacity: 1,
                delay: root._scanDelayAt(ghostMetrics.advanceWidth, span),
                // Travel one-and-a-half line heights, like the field's delete ghosts.
                fallDistance: Math.max(1, label.height) * root.ghostFallDistanceScale
            })
        }
    }

    // Per-char scan arrival delays for the incoming text, in ms.
    function _charDelays(text) {
        var count = Math.min(text.length, root.transitionMaxChars)
        var delays = []
        ghostMetrics.font = label.font
        ghostMetrics.text = text
        var span = Math.max(1, ghostMetrics.advanceWidth)
        for (var i = 0; i < count; i++) {
            ghostMetrics.text = text.slice(0, i)
            delays.push(root._scanDelayAt(ghostMetrics.advanceWidth, span))
        }
        return delays
    }

    // Fallback restores the label if the enter row's own timers ever fail.
    Timer {
        id: enterGuard

        interval: 2400
        onTriggered: {
            root._sweepActive = false
            root._stopSweepRow()
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
            // Scan arrival delay per char, ms — computed from the text's
            // own pixel positions so the line moves at constant speed.
            property var delays: []

            Repeater {
                model: Math.min(enterRow.chars.length, root.transitionMaxChars)

                Text {
                    id: charItem

                    required property int index
                    // Delay for this char; falls back to an even pace when
                    // the host supplies no measured array.
                    readonly property int delay:
                        enterRow.delays && enterRow.delays.length > index
                        ? enterRow.delays[index] : index * 16

                    text: enterRow.chars[index]
                    color: root.textColor
                    font.pixelSize: root.pixelSize
                    font.bold: root.bold
                    opacity: 0

                    Behavior on opacity { NumberAnimation { duration: root.scanRevealMs; easing.type: Easing.OutQuad } }

                    // The line passes this char: fade straight in to full
                    // ink (the drop gap keeps the line itself blank).
                    Timer {
                        running: true
                        interval: charItem.delay + root.scanGapMs + 1
                        onTriggered: charItem.opacity = 1
                    }
                }
            }

            Timer {
                id: retireTimer

                running: true
                interval: root.scanSweepMs + root.scanGapMs + root.scanRevealMs + MotionTokens.fast
                onTriggered: {
                    root._sweepActive = false
                    if (root._enterRow === enterRow)
                        root._enterRow = null
                    label.opacity = 1
                    label.x = 0
                    enterRow.destroy()
                }
            }
        }
    }
}
