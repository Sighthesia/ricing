import QtQuick
import "modules/lazerbar"
import "services/launcher"

// [DEBUG-lr2] Feedback loop: an app vanishes from the pool after being
// launched, then the user reopens and searches for it. The page must show
// the explicit empty state with no floating selection frame - never a
// frame hovering over blank space with dead selection.
Item {
    id: root
    width: 400
    height: 600

    property int failures: 0

    // Adapter whose single app disappears once executed (post-launch
    // desktop-entry rewrite, as Electron-family apps do).
    property bool _appGone: false
    property bool _dieOnExecute: false
    readonly property var vanishingAdapter: ({
        refresh: function(queryText, modeName, done) {
            var items = []
            if (!_appGone) {
                items.push({
                    id: "app.vanishing",
                    displayName: "Vanishing App",
                    description: "demo",
                    searchText: "vanishing app demo",
                    icon: "",
                    favoriteWeight: 0,
                    lastUsedAt: 0
                })
                // Filler apps so ordering/windowing paths are exercised.
                for (var f = 0; f < 8; f++)
                    items.push({
                        id: "app.filler" + f,
                        displayName: "Filler " + f,
                        description: "filler",
                        searchText: "filler " + f,
                        icon: "",
                        favoriteWeight: 0,
                        lastUsedAt: 100 - f
                    })
                // Second clipboard entry so hover-vs-selection can differ.
                if (modeName === "clipboard") {
                    items.push({
                        id: "clip.other",
                        preview: "other",
                        displayName: "Other clip",
                        description: "text/plain · copied 01-01 00:00:00",
                        previewText: "other clip body text",
                        searchText: "other clip",
                        icon: "",
                        favoriteWeight: 0,
                        lastUsedAt: 0
                    })
                    items.push({
                        id: "424242",
                        preview: "image",
                        displayName: "[Image]",
                        description: "image/png · copied 01-01 00:00:00",
                        searchText: "image",
                        icon: "",
                        isImage: true,
                        mime: "image/png",
                        favoriteWeight: 0,
                        lastUsedAt: 0
                    })
                }
            }
            done(items)
        },
        execute: function(item, done) {
            if (root._dieOnExecute) {
                // Simulate a broken desktop entry: entry.execute() throws
                // inside the production adapter before done() can run.
                _appGone = false
                throw new Error("Exec line missing")
            }
            _appGone = true
            done({ ok: true })
        }
    })

    // Mirror of LauncherSurface's prewarm page: a second, disabled page
    // sharing the same session.
    property bool _prewarm: false
    Loader {
        id: prewarm
        active: root._prewarm
        visible: false
        enabled: false
        x: -10000; y: -10000
        width: 480; height: 640
        sourceComponent: LauncherPage { session: session }
    }

    LauncherSession {
        id: session
        _adapters: ({ apps: root.vanishingAdapter, clipboard: root.vanishingAdapter })
        clipboardService: ({
            decodeThumbnail: function(id, mime, cb) {
                // Async like the real decoder; a synchronous callback would
                // write _thumbRev during binding evaluation.
                Qt.callLater(function() { cb("/tmp/opencode/probe_thumb.png") })
            }
        })
    }

    LauncherPage {
        id: page
        anchors.fill: parent
        session: session
    }

    function fail(msg) { failures++; console.log("[DEBUG-lr2] FAIL:", msg) }
    function pass(name) { console.log("[DEBUG-lr2] PASS:", name) }

    property int _revProbe: 0
    Timer { id: nudgeTimer; interval: 120; onTriggered: {
        for (var i = 0; i < session.results.length; i++)
            if (String(session.results[i].id) === "424242")
                session.selectedIndex = i
        step.next = root.scenario5_done
        step.interval = 150
        step.restart()
    } }
    Timer { id: step; interval: 30; property var next; onTriggered: next() }

    Component.onCompleted: {
        // Locate the shared frame by objectName through the visual tree.
        frameRef = null
        var stack = [page]
        while (stack.length) {
            var cur = stack.pop()
            if (cur.objectName === "selectionFrame") { frameRef = cur; break }
            var kids = cur.data
            if (kids)
                for (var k = 0; k < kids.length; k++)
                    if (kids[k] && kids[k].objectName !== undefined)
                        stack.push(kids[k])
        }
        if (!frameRef) { fail("selectionFrame not found"); finish() ; return }
        step.next = scenario1
        step.restart()
    }
    property var frameRef: null

    function finish() {
        console.log(failures === 0 ? "[DEBUG-lr2] ALL GREEN" : "[DEBUG-lr2] RED x" + failures)
        Qt.quit()
    }

    // Scenario 1: launch the app, reopen, search its exact name.
    function scenario1() {
        session.query = ""
        session.open()
        step.next = scenario1_loaded
        step.restart()
    }
    function scenario1_loaded() {
        var vIdx = -1
        for (var i = 0; i < (session.results || []).length; i++)
            if (String(session.results[i].id) === "app.vanishing")
                vIdx = i
        if (vIdx < 0) {
            fail("vanishing entry missing on open")
            return scenario2()
        }
        session.selectedIndex = vIdx
        // Simulate the activation path without the fling ghost layer.
        session.execute(session.results[0])
        step.next = scenario1_reopened
        step.restart()
    }
    function scenario1_reopened() {
        if (session.visible) { fail("session should have closed after launch"); session.close() }
        session.open()
        step.next = scenario1_searching
        step.restart()
    }
    function scenario1_searching() {
        session.query = "vanishing"
        step.next = scenario1_assert
        step.restart()
    }
    function scenario1_assert() {
        var emptyShown = page.emptyState.visible
        var resultsLen = session.results ? session.results.length : -1
        var frameOpacity = frameRef.opacity
        if (resultsLen !== 0)
            fail("stale results survived vanish: len=" + resultsLen)
        else
            pass("scenario1 results emptied")
        if (!emptyShown)
            fail("empty state not visible despite 0 results")
        else
            pass("scenario1 emptyState visible")
        if (frameOpacity > 0.01)
            fail("selection frame floating over blank space (opacity=" + frameOpacity + ")")
        else
            pass("scenario1 frame hidden")
        scenario2()
    }

    // Scenario 2: same vanish, but the search happens while a stale
    // selectedIndex from the pre-launch session survived into the new one.
    function scenario2() {
        _appGone = false
        session.open()
        step.next = scenario2_select
        step.restart()
    }
    function scenario2_select() {
        session.selectedIndex = Math.max(0, session.results.length - 1)
        session.execute(session.results[session.selectedIndex])
        step.next = scenario2_searchWhileStale
        step.restart()
    }
    function scenario2_searchWhileStale() {
        session.open()
        step.next = scenario2_assert
        step.restart()
    }
    function scenario2_assert() {
        session.query = "nothing-matches-this"
        step.next = scenario2_final
        step.restart()
    }
    function scenario2_final() {
        var frameOpacity = frameRef.opacity
        var selOk = session.selectedIndex < 0 || session.selectedIndex < session.results.length
        if (!selOk)
            fail("selectedIndex out of bounds: " + session.selectedIndex)
        else
            pass("scenario2 selection clamped")
        if (frameOpacity > 0.01 && session.results.length === 0)
            fail("frame visible with zero results (opacity=" + frameOpacity + ")")
        else
            pass("scenario2 frame consistent")
        scenario3()
    }

    // Scenario 3: the launch dies mid-execute (done never called). The
    // activated row hides for the fling but must not strand the surface:
    // error must surface and no frame may float over the hidden card.
    function scenario3() {
        if (session.visible)
            session.close()
        _dieOnExecute = true
        _appGone = false
        session.open()
        step.next = scenario3_activate
        step.restart()
    }
    function scenario3_activate() {
        if (session.loading) { step.restart(); return }
        var vIdx = -1
        for (var j = 0; j < (session.results || []).length; j++)
            if (String(session.results[j].id) === "app.vanishing")
                vIdx = j
        if (vIdx < 0) {
            fail("scenario3 expected vanishing result")
            return finish()
        }
        session.selectedIndex = vIdx
        page.executeSelected()   // routes through row.activate() like Enter
        step.interval = 350      // let the frame fade-out Behavior finish
        step.next = scenario3_assert
        step.restart()
    }
    function scenario3_assert() {
        var errorShown = page.errorState.visible
        var frameOpacity = frameRef.opacity
        var row0 = page.resultAt(0)
        // Restore criterion: own-state flags cleared (list-wide visibility
        // is legitimately suppressed by the error overlay).
        var cardRestored = !!row0 && !row0.closing && !row0.revealHeld
                && row0.height > 4 && row0.opacity > 0.9
        if (!errorShown)
            fail("dead launch left no error state (stuck silently)")
        else
            pass("scenario3 error surfaced")
        if (!cardRestored)
            fail("activated card stayed invisible after failed launch")
        else
            pass("scenario3 card restored")
        // Invariant: the shared frame never anchors a row that hid itself
        // for an exit fling - that is the blank-space float.
        var anchoringHiddenRow = !!page.selectionAnchor
                && (page.selectionAnchor.closing === true
                    || page.selectionAnchor.height <= 4)
        if (anchoringHiddenRow)
            fail("frame anchored to self-hidden row")
        else
            pass("scenario3 frame consistent")
        scenario4()
    }

    // Scenario 4: pointing at a row previews it in the right pane ahead of
    // the keyboard selection; leaving the row hands preview back.
    function scenario4() {
        if (session.visible)
            session.close()
        session.query = ">clip "
        session.open()
        step.next = scenario4_hover
        step.restart()
    }
    function scenario4_hover() {
        if (session.loading) { step.restart(); return }
        if (!session.results || session.results.length < 1) {
            fail("scenario4 expected results, got " + (session.results ? session.results.length : "null"))
            return finish()
        }
        var selected = page.previewSelectedResult
        if (!selected)
            fail("preview pane empty despite selection")
        else
            pass("scenario4 pane follows selection")

        // Hover a row that is NOT the keyboard-selected one.
        var hoveredItem = session.results[session.results.length - 1]
        session.selectedIndex = 0
        page.trackHover(hoveredItem, true)
        if (page.previewSelectedResult !== hoveredItem)
            fail("hovered row did not take over the preview")
        else
            pass("scenario4 hover drives preview")

        page.trackHover(hoveredItem, false)
        if (page.previewSelectedResult === hoveredItem)
            fail("leaving hover did not hand back to selection")
        else
            pass("scenario4 hover release falls back to selection")
        scenario5()
    }

    // Scenario 5: image entries must show the decoded preview large in the
    // pane, and text previews must be mouse-selectable.
    function scenario5() {
        if (session.visible)
            session.close()
        session.query = ">clip other"
        session.open()
        step.next = scenario5_assert
        step.restart()
    }
    function scenario5_assert() {
        if (session.loading) { step.restart(); return }
        // Text entry first: full preview must render for selection.
        var txt = page.previewTextItem
        if (!txt || !txt.visible || String(txt.text).length === 0)
            fail("text preview not shown for text entry")
        else
            pass("scenario5 text preview present")

        // Then narrow to the image entry via the pooled fast path.
        session.query = ">clip image"
        step.next = scenario5_image
        step.interval = 250
        step.restart()
    }

    function scenario5_image() {
        var img = page.previewImageItem
        if (!img || !img.visible) {
            fail("preview image not visible")
            return finish()
        }
        if (img.status !== Image.Ready) {
            // Nudge a dependency of paneThumbSource; a live binding then
            // picks up the cached decode path.
            session.selectedIndex = -1
            nudgeTimer.restart()
            return
        }
        scenario5_done()
    }
    function scenario5_done() {
        var img = page.previewImageItem
        if (img.status === Image.Ready && img.width > 0 && img.height > 0)
            pass("scenario5 preview image visible and loaded")
        else
            fail("preview image dead after nudge (src=" + String(img.source) + " st=" + img.status + " prog=" + img.progress + ")")

        // Keyboard fallback: with the editor unfocused and no other focus
        // owner, the page itself must hold scope focus so Escape still has
        // a landing point.
        var ed = page.searchField.editorItem
        ed.focus = false
        page.reclaimKeyboardFallback()
        // Pass when any focus owner lives inside the page (Escape bubbles
        // through it) or the page itself took over.
        var w = page.Window ? page.Window.window : null
        var fi = w ? w.activeFocusItem : null
        var inside = false
        while (fi) {
            if (fi === page || fi === frameRef) { inside = true; break }
            fi = fi.parent
        }
        if (inside || page.activeFocus)
            pass("scenario5 keyboard fallback owner exists")
        else
            fail("no focus owner: Escape would be dead")
        scenario6()
    }

    // Scenario 6: searching an app shows its unfolded row - across the
    // refill cascade, a forced upstream re-pull, and a clipboard round
    // trip. Data presence alone is not enough; the card must stand.
    function findRow(id) {
        for (var i = 0; i < resultsViewCount(); i++) {
            var row = page.resultAt(i)
            if (row && row.result && String(row.result.id) === id)
                return row
        }
        return null
    }
    function resultsViewCount() {
        var n = 0
        while (page.resultAt(n) !== null && page.resultAt(n) !== undefined)
            n++
        return n
    }
    function assertRowStanding(id, label) {
        var row = findRow(id)
        if (!row) { fail(label + ": no delegate for " + id); return }
        if (row.searchHidden) fail(label + ": row folded by search")
        else if (row.revealHeld) fail(label + ": row stuck held by wave")
        else if (row.height <= 4 || row.opacity < 0.9) fail(label + ": row not standing (h=" + row.height + " op=" + row.opacity + ")")
        else pass(label + ": row standing")
    }
    function scenario6() {
        root._prewarm = true   // arm the prewarm copy like production
        if (session.visible)
            session.close()
        session.open()
        step.next = scenario6_type
        step.restart()
    }
    function scenario6_type() {
        if (session.loading) { step.restart(); return }
        // Simulate a reused page parked past the end of the shrunken list.
        page.resultsView.contentY = 9999
        session.selectedIndex = -1
        session.query = "filler 3"
        step.interval = 900      // let the refill cascade settle
        step.next = scenario6_afterType
        step.restart()
    }
    function scenario6_afterType() {
        var cy = page.resultsView.contentY
        var maxY = Math.max(0, page.resultsView.contentHeight - page.resultsView.height)
        if (cy > maxY + 1)
            fail("s6 viewport parked past end (contentY=" + cy + " max=" + maxY + ")")
        else
            pass("s6 viewport clamped")
        assertRowStanding("app.filler3", "s6 typed")
        // Upstream churn while open: forced pull with identical data.
        session.refresh(true)
        step.next = scenario6_afterPull
        step.restart()
    }
    function scenario6_afterPull() {
        assertRowStanding("app.filler3", "s6 after repull")
        // Clipboard round trip and back.
        session.query = ">clip "
        step.next = scenario6_backToApps
        step.interval = 400
        step.restart()
    }
    function scenario6_backToApps() {
        session.query = ""
        step.next = scenario6_retype
        step.interval = 400
        step.restart()
    }
    function scenario6_retype() {
        session.query = "filler 3"
        step.interval = 900
        step.next = scenario6_finalAssert
        step.restart()
    }
    function scenario6_finalAssert() {
        assertRowStanding("app.filler3", "s6 roundtrip")
        finish()
    }
}
