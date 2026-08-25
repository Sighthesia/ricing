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
        // Remember the scroll offset before zeroing it: a transition fired
        // for this same text change still needs the outgoing viewport.
        if (label.x < 0) {
            root._preservedScrollX = label.x
            root._scrollActive = true
        } else {
            root._scrollActive = false
        }
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
    // same-spot overlap between the falling ghost and the reveal. The
    // margin absorbs timer/frame jitter; 20ms was tight enough to rub.
    readonly property int scanGapMs: ghostFallTime + 60
    readonly property int scanRevealMs: 140
    readonly property int transitionMaxChars: 48
    property var _enterRow: null
    property bool _sweepActive: false
    // State of the in-flight sweep, for collapsing it mid-flight.
    property string _sweepRowChars: ""
    property var _sweepDelays: []
    property var _sweepOffsets: []
    property real _sweepStart: 0
    // Scroll state of the outgoing label, captured by syncScroll before it
    // zeroes x — the transition needs to know where the viewport was.
    property real _preservedScrollX: 0
    property bool _scrollActive: false

    // Delay until the scan line reaches pixel offset x on a line `width`
    // wide — percentage-of-length mapping, constant px/s velocity.
    function _scanDelayAt(xOffset, lineWidth) {
        var span = Math.max(1, lineWidth)
        return Math.round(root.scanSweepMs * Math.min(1, Math.max(0, xOffset / span)))
    }

    // Fall delay for a ghost at pixel offset x, unclamped so the line
    // keeps sweeping past the incoming title's edge; past 2x span the
    // pace compresses into a bounded tail instead of a hard cap, so
    // surplus chars still fall in sequence rather than as one batch.
    function _fallDelayAt(xOffset, span) {
        var s = Math.max(1, span)
        var capX = 2 * s
        if (xOffset <= capX)
            return Math.round(root.scanSweepMs * Math.max(0, xOffset / s))
        var maxX = Math.max(capX + 1, root.maxWidth)
        return Math.round(root.scanSweepMs * 2
            + 400 * (xOffset - capX) / (maxX - capX))
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

    // A sweep interrupted mid-reveal: the already-revealed chars fall on
    // the NEW sweep's wavefront — delay paced by position over the shared
    // span, exactly one gap ahead of the incoming char at the same spot —
    // so the interrupt reads as one continuous scan, never two stacked
    // transitions. Chars never revealed simply vanish.
    function _collapseRevealedChars(elapsed, span) {
        var chars = root._sweepRowChars
        var delays = root._sweepDelays
        var offsets = root._sweepOffsets
        var count = Math.min(chars.length, root.transitionMaxChars)
        ghostMetrics.font = label.font
        for (var i = 0; i < count && i < delays.length && i < offsets.length - 1; i++) {
            var startedAt = delays[i] + root.scanGapMs
            if (startedAt > elapsed)
                break
            var revealAge = elapsed - startedAt
            var opacity = revealAge >= root.scanRevealMs
                ? 1 : Math.max(0.08, revealAge / root.scanRevealMs)
            lyricGhostComponent.createObject(overlayLayer, {
                text: chars[i],
                color: textColor,
                font: label.font,
                x: offsets[i],
                y: 0,
                opacity: opacity,
                delay: root._fallDelayAt(offsets[i], span),
                fallDistance: Math.max(1, label.height) * root.ghostFallDistanceScale
            })
        }
    }

    // Standing ghosts of the interrupted sweep dissolve IN PLACE: they are
    // debris of an older title, usually sharing glyphs and positions with
    // the incoming one — re-anchoring them into a fall produced two
    // identical glyphs dropping at the same spot. Fading them under the
    // new sweep keeps exactly one falling instance per glyph.
    function _collapseStandingGhosts() {
        var kids = overlayLayer.children
        // Snapshot the count: creates below append after it.
        var n = kids.length
        for (var i = 0; i < n; i++) {
            var gh = kids[i]
            if (gh.y > 0 || gh.opacity < 0.99)
                continue
            var text = gh.text
            var x = gh.x
            // Their fall timers were fixed at creation — rebuild with
            // fade-only parameters so the debris dissolves immediately.
            gh.destroy()
            lyricGhostComponent.createObject(overlayLayer, {
                text: text,
                color: textColor,
                font: label.font,
                x: x,
                y: 0,
                opacity: 1,
                delay: 0,
                fallDistance: 0
            })
        }
    }

    // Play the scan-line transition for a just-applied text change.
    // Both texts are passed explicitly: a live `text:` binding may not have
    // re-evaluated yet when the host's change handler runs, so root.text
    // cannot be trusted as either value here.
    //
    // A change arriving while a sweep is still running collapses it: only
    // the already-revealed chars fall (from their current opacity), chars
    // never shown vanish, and the new sweep starts cleanly — wavefronts
    // never stack and nothing flashes complete before falling.
    function transitionFrom(oldText, newText) {
        if (MotionTokens.reducedMotion || oldText === "" || oldText === newText)
            return
        var wasActive = root._sweepActive
        var elapsed = wasActive ? Date.now() - root._sweepStart : 0
        root._sweepActive = false
        // Pace both wavefronts over the incoming title's VISIBLE width:
        // the scan always crosses what can be seen in one sweep duration,
        // so a fully-visible line cascades across the full range instead
        // of compressing into a wall (pacing over the raw text width would
        // squeeze the visible part into a fraction of the sweep). Same
        // span for both fronts keeps the per-position gap exact. The span
        // is needed up front: the collapse rides this same wavefront.
        ghostMetrics.font = label.font
        ghostMetrics.text = oldText
        var oldWidth = ghostMetrics.advanceWidth
        ghostMetrics.text = newText
        var newWidth = ghostMetrics.advanceWidth
        var span = Math.max(1, Math.min(newWidth, root.maxWidth))
        if (wasActive) {
            // Debris first (snapshot excludes the collapse ghosts that the
            // second call appends), then the positional reveal-char fall.
            _collapseStandingGhosts()
            _collapseRevealedChars(elapsed, span)
        } else {
            _clearGhosts()
        }
        _stopSweepRow()
        root._sweepActive = true
        // The outgoing viewport: the scroll offset is read live off label.x
        // (the handler may run before the text binding updates, while the
        // label is still scrolled); if syncScroll already zeroed it, fall
        // back to the offset preserved at that moment. The visible width is
        // the old text clipped to the label's cap.
        var scrollX = label.x !== 0
            ? Math.min(0, label.x)
            : (root._scrollActive ? Math.min(0, root._preservedScrollX) : 0)
        root._scrollActive = false
        var viewRight = Math.min(oldWidth, root.maxWidth)
        if (!wasActive)
            spawnGhosts(oldText, span, scrollX, viewRight)
        label.opacity = 0
        label.x = 0
        var offsets = _charOffsets(newText)
        var delays = _charDelays(offsets, span)
        root._enterRow = scanRowComponent.createObject(clipSlot, {
            chars: newText,
            delays: delays,
            offsets: offsets
        })
        root._sweepRowChars = newText
        root._sweepDelays = delays
        root._sweepOffsets = offsets
        root._sweepStart = Date.now()
        // Safety net: no matter what happens inside the row, the real
        // label always comes back.
        enterGuard.restart()
    }

    // Old characters fall away as the line reaches them; ghosts ride the
    // unclipped overlay so they can fall past the surface. `span` is the
    // shared sweep width so the fall front matches the reveal front's
    // pixel velocity. A scrolling label shows a window into the text:
    // ghosts fall at their on-screen positions and chars outside the
    // viewport (scrolled past or not yet reached) never materialize.
    function spawnGhosts(oldText, span, scrollX, viewRight) {
        if (oldText === "")
            return
        var count = Math.min(oldText.length, root.transitionMaxChars)
        ghostMetrics.font = label.font
        // Chars past 2x span would batch at the hard cap; spread the
        // excess across a bounded tail so the cascade stays sequential.
        var capX = 2 * span
        var tailSpan = Math.max(1, viewRight - capX)
        for (var i = 0; i < count; i++) {
            ghostMetrics.text = oldText.slice(0, i)
            var x = ghostMetrics.advanceWidth + scrollX
            ghostMetrics.text = oldText.slice(0, i + 1)
            var charEnd = ghostMetrics.advanceWidth + scrollX
            if (viewRight > 0 && (charEnd <= 0 || x >= viewRight))
                continue
            ghostMetrics.text = oldText.slice(0, i)
            var delay = x <= capX
                ? root.scanSweepMs * x / span
                : root.scanSweepMs * 2 + 400 * (x - capX) / tailSpan
            lyricGhostComponent.createObject(overlayLayer, {
                text: oldText[i],
                color: textColor,
                font: label.font,
                x: x,
                y: 0,
                opacity: 1,
                delay: Math.round(delay),
                // Travel one-and-a-half line heights, like the field's delete ghosts.
                fallDistance: Math.max(1, label.height) * root.ghostFallDistanceScale
            })
        }
    }

    // Per-char scan arrival delays (ms), paced on the shared sweep span so
    // the reveal front matches the fall front. Takes precomputed offsets.
    function _charDelays(offsets, span) {
        var delays = []
        for (var i = 0; i < offsets.length - 1; i++)
            delays.push(root._scanDelayAt(offsets[i], span))
        return delays
    }

    // Per-char pixel offsets (prefix advance widths, total at the end) so
    // the scan row places every character exactly where the real label
    // renders it: a natural Row accumulates fractional advances differently,
    // and the handback to the single-Text label shifted ~1px, reading as a
    // twitch right when a long title settled into its marquee.
    function _charOffsets(text) {
        var count = Math.min(text.length, root.transitionMaxChars)
        var xs = []
        ghostMetrics.font = label.font
        for (var i = 0; i <= count; i++) {
            ghostMetrics.text = text.slice(0, i)
            xs.push(ghostMetrics.advanceWidth)
        }
        return xs
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

        // Characters sit at the label's own measured prefix offsets instead
        // of flowing in a Row, so the handback to the real single-Text
        // label lands pixel-for-pixel with no horizontal twitch.
        Item {
            id: enterRow

            property string chars: ""
            // Scan arrival delay per char, ms — computed from the text's
            // own pixel positions so the line moves at constant speed.
            property var delays: []
            // Prefix advance widths shared with the real label's metrics.
            property var offsets: []
            readonly property int count: Math.min(chars.length, root.transitionMaxChars)

            width: offsets && offsets.length > count ? offsets[count] : 0
            height: root.label.height

            Repeater {
                model: enterRow.count

                Text {
                    id: charItem

                    required property int index
                    // Delay for this char; falls back to an even pace when
                    // the host supplies no measured array.
                    readonly property int delay:
                        enterRow.delays && enterRow.delays.length > index
                        ? enterRow.delays[index] : index * 16
                    readonly property real xOffset:
                        enterRow.offsets && enterRow.offsets.length > index
                        ? enterRow.offsets[index] : 0

                    x: xOffset
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
