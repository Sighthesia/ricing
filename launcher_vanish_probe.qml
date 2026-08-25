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
                // Second clipboard entry so hover-vs-selection can differ.
                if (modeName === "clipboard")
                    items.push({
                        id: "clip.other",
                        displayName: "Other clip",
                        description: "text/plain · copied 01-01 00:00:00",
                        searchText: "other clip",
                        icon: "",
                        favoriteWeight: 0,
                        lastUsedAt: 0
                    })
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

    LauncherSession {
        id: session
        _adapters: ({ apps: root.vanishingAdapter, clipboard: root.vanishingAdapter })
    }

    LauncherPage {
        id: page
        anchors.fill: parent
        session: session
    }

    function fail(msg) { failures++; console.log("[DEBUG-lr2] FAIL:", msg) }
    function pass(name) { console.log("[DEBUG-lr2] PASS:", name) }

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
        if (!session.results || session.results.length !== 1) {
            fail("expected 1 result on open, got " + (session.results ? session.results.length : "null"))
            return scenario2()
        }
        session.selectedIndex = 0
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
        if (!session.results || session.results.length !== 1) {
            fail("scenario3 expected 1 result, got " + (session.results ? session.results.length : "null"))
            return finish()
        }
        session.selectedIndex = 0
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
        finish()
    }
}
