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
            // Match the scan row's independent glyph layout at handback.
            font.kerning: false
            // Track the live scroll offset every frame: a transition can
            // fire before or after syncScroll zeroes x, and this always
            // holds the true current viewport position.
            onXChanged: if (x < 0) {
                root._preservedScrollX = x
                root._scrollActive = true
            }
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

    // One-way marquee leg time: linear with overflow up to a cap. The cap
    // keeps very long titles from crawling left for tens of seconds —
    // past ~8s the traversal reads as drift instead of motion.
    readonly property int maxScrollLegMs: 8000
    function marqueeLegDuration() {
        var overflow = Math.max(0, metrics.advanceWidth - clipSlot.width)
        return Math.max(2000, Math.min(root.maxScrollLegMs, overflow * 18))
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
            // One-way leg time grows with overflow but stays capped: an
            // unclamped linear pace sends very long titles crawling left
            // for half a minute, which reads as the title drifting out of
            // view and never coming back.
            duration: marqueeLegDuration()
            easing.type: Easing.Linear
        }
        PauseAnimation { duration: 1400 }
        NumberAnimation {
            target: label
            property: "x"
            from: -(metrics.advanceWidth - clipSlot.width)
            to: 0
            duration: marqueeLegDuration()
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

    // Fall delay for a ghost at pixel offset x — ONE monotonic wavefront:
    // within the incoming title's width the line moves at sweep pace;
    // past its right edge the pace compresses into a bounded tail, so
    // surplus chars keep falling in sequence instead of forming a second,
    // faster front.
    function _fallDelayAt(xOffset, span) {
        var s = Math.max(1, span)
        if (xOffset <= s)
            return Math.round(root.scanSweepMs * Math.max(0, xOffset / s))
        var maxX = Math.max(s + 1, root.maxWidth)
        return Math.round(root.scanSweepMs
            + 240 * (xOffset - s) / (maxX - s))
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
        for (var i = kids.length - 1; i >= 0; i--) {
            kids[i].visible = false
            kids[i].opacity = 0
            kids[i].destroy()
        }
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
            ghostMetrics.text = chars.slice(0, i)
            var charX = offsets[i]
            var charStart = ghostMetrics.advanceWidth
            ghostMetrics.text = chars.slice(0, i + 1)
            var charWidth = Math.max(1, ghostMetrics.advanceWidth - charStart)
            if (_ghostOverlaps(charX, charWidth))
                continue
            // All revealed chars fall immediately in a light left-to-right
            // stagger. Positional pacing here would just make middle chars
            // stand frozen waiting for the wavefront — and an immediate
            // fall can never overlap the reveal, which arrives at any
            // position no earlier than 220ms from now.
            lyricGhostComponent.createObject(overlayLayer, {
                text: chars[i],
                color: textColor,
                font: label.font,
                x: charX,
                y: 0,
                opacity: opacity,
                delay: i * 8,
                fallDistance: Math.max(1, label.height) * root.ghostFallDistanceScale
            })
        }
    }

    // A rapid title switch can carry standing ghosts from the prior sweep
    // into the same positions occupied by revealed characters. Keep one
    // falling glyph per horizontal span so two generations cannot read as
    // overlapping text or a doubled fall.
    function _ghostOverlaps(x, width, ignoredGhost) {
        var kids = overlayLayer.children
        var right = x + Math.max(1, width)
        for (var i = 0; i < kids.length; i++) {
            var ghost = kids[i]
            if (ghost === ignoredGhost)
                continue
            if (ghost.opacity <= 0)
                continue
            var overlap = Math.min(right, ghost.x + ghost.width)
                - Math.max(x, ghost.x)
            if (Math.abs(x - ghost.x) < 0.5 && overlap > 1)
                return true
        }
        return false
    }

    // Standing ghosts of the interrupted sweep are debris from an older
    // title: they fall immediately in a tight stagger. Re-anchoring them
    // onto the new wavefront instead lets rapid switching defer them
    // indefinitely (each interrupt resets their delay), so they never
    // exit at all. Snapshot the count first — creates below append after.
    function _collapseStandingGhosts() {
        var kids = overlayLayer.children
        var n = kids.length
        var stagger = 0
        for (var i = 0; i < n; i++) {
            var gh = kids[i]
            if (gh.y > 0 || gh.opacity < 0.99)
                continue
            var text = gh.text
            var x = gh.x
            var width = gh.width
            gh.destroy()
            if (_ghostOverlaps(x, width, gh))
                continue
            lyricGhostComponent.createObject(overlayLayer, {
                text: text,
                color: textColor,
                font: label.font,
                x: x,
                y: 0,
                opacity: 1,
                delay: (stagger++) * 8,
                fallDistance: Math.max(1, label.height) * root.ghostFallDistanceScale
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
        // The fall front spans the outgoing viewport whenever it is wider
        // than the incoming title: one constant velocity across everything
        // visible — no slow crawl over the overlap region followed by a
        // fast rush through the orphaned tail.
        var viewRight = Math.min(oldWidth, root.maxWidth)
        var fallSpan = Math.max(1, Math.max(span, viewRight))
        // Capture the outgoing viewport before clearing an interrupted sweep.
        // The old title must still fall even when the previous incoming scan
        // had not revealed a character yet.
        var scrollX = label.x !== 0
            ? Math.min(0, label.x)
            : (root._scrollActive ? Math.min(0, root._preservedScrollX) : 0)
        // A text/width binding can briefly expose an offset measured against
        // the next title. Clamp it to the outgoing title's real viewport so
        // a long title can never have every ghost filtered as off-screen.
        var maxScrollX = Math.max(0, oldWidth - viewRight)
        scrollX = Math.max(-maxScrollX, Math.min(0, scrollX))
        if (wasActive) {
            // A fresh interrupt owns the outgoing layer. Previous ghosts
            // belong to an older title generation and must not be retained.
            _clearGhosts()
            spawnGhosts(oldText, fallSpan, scrollX, viewRight)
        } else {
            _clearGhosts()
            spawnGhosts(oldText, fallSpan, scrollX, viewRight)
        }
        _stopSweepRow()
        root._sweepActive = true
        // The outgoing viewport: the scroll offset is read live off label.x
        // (the handler may run before the text binding updates, while the
        // label is still scrolled); if syncScroll already zeroed it, fall
        // back to the offset preserved at that moment. The visible width is
        // the old text clipped to the label's cap.
        root._scrollActive = false
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
        ghostMetrics.font = label.font
        var created = 0
        for (var i = 0; i < oldText.length && created < root.transitionMaxChars; i++) {
            ghostMetrics.text = oldText.slice(0, i)
            var x = ghostMetrics.advanceWidth + scrollX
            ghostMetrics.text = oldText.slice(0, i + 1)
            var charEnd = ghostMetrics.advanceWidth + scrollX
            if (viewRight > 0 && (charEnd <= 0 || x >= viewRight))
                continue
            ghostMetrics.text = oldText.slice(0, i)
            lyricGhostComponent.createObject(overlayLayer, {
                text: oldText[i],
                color: textColor,
                font: label.font,
                x: x,
                y: 0,
                opacity: 1,
                delay: root._fallDelayAt(x, span),
                // Travel one-and-a-half line heights, like the field's delete ghosts.
                fallDistance: Math.max(1, label.height) * root.ghostFallDistanceScale
            })
            created++
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
                    font.kerning: false
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
