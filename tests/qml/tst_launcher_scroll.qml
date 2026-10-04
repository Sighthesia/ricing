import QtQuick
import QtTest
import "../../modules/lazerbar" as Lazer

// The launcher list must always accept the wheel.
//
// This file exists because the failure it pins down could not be reproduced
// from a synchronous fixture: the launcher streams its results one batch per
// frame, and a commit that lands before the Repeater has materialized the
// window's rows used to write the id bookkeeping anyway. Every later commit
// then read as "unchanged", skipped the release, and left each delegate at
// its initial held geometry - and a held row is exactly what disables the
// viewport, so the list silently stopped scrolling for the rest of the
// session. Driving the batches from a timer reproduces that ordering.
Item {
    id: testRoot
    width: 800
    height: 600

    property var activeAdapter: null
    property alias batchTimer: pumpTimer

    // One queued batch per event-loop turn, the shape of the production frame
    // stepper in LauncherService.
    Timer {
        id: pumpTimer
        interval: 8
        repeat: false
        onTriggered: if (testRoot.activeAdapter) testRoot.activeAdapter.pump()
    }

    Lazer.LauncherPage {
        id: page
        anchors.fill: parent
    }

    // Chunked stand-in for the production apps adapter: batches in arrival
    // order, delivered one per tick.
    Component {
        id: chunkedAdapterComponent
        QtObject {
            id: adapter
            property var rows: []
            property int chunkSize: 48
            property int cursor: 0
            property var pendingDone: null
            property var pendingQuery: ""
            property var tick: null

            function refresh(query, mode, done) {
                adapter.pendingDone = done
                adapter.pendingQuery = query || ""
                adapter.cursor = 0
                adapter.pump()
            }

            function pump() {
                var needle = adapter.pendingQuery.toLowerCase()
                var batch = []
                var scanned = 0
                while (adapter.cursor < adapter.rows.length && scanned < adapter.chunkSize) {
                    var raw = adapter.rows[adapter.cursor]
                    adapter.cursor++
                    scanned++
                    if (needle && raw.displayName.toLowerCase().indexOf(needle) < 0)
                        continue
                    batch.push(raw)
                }
                var complete = adapter.cursor >= adapter.rows.length
                if (batch.length > 0 || complete)
                    adapter.pendingDone(batch, complete)
                if (!complete && typeof adapter.tick === "function")
                    adapter.tick()
            }

            function execute(item, done) { done({ ok: true }) }
        }
    }

    function makeRows(count, prefix) {
        var stem = prefix || "app"
        var out = []
        for (var i = 0; i < count; i++) {
            out.push({
                id: stem + i,
                displayName: "App " + i,
                description: "",
                category: i % 3 === 0 ? "games" : (i % 3 === 1 ? "network" : "office"),
                searchText: ("App " + i + " games network office").toLowerCase(),
                favoriteWeight: count - i,
                lastUsedAt: 1700000000000 + i
            })
        }
        return out
    }

    TestCase {
        name: "LauncherScroll"
        when: windowShown

        function init() {
            Lazer.MotionTokens.reducedMotionOverride = false
            page.session.close()
            wait(60)
            testRoot.activeAdapter = null
        }

        // Park the viewport mid-list and report whether one wheel notch
        // travels. The first and last 80px are the edge-takeover bands, where
        // a notch is spent on the rubber band rather than on travel.
        function wheelTravel() {
            var view = page.resultsView
            view.contentY = Math.max(0, (view.contentHeight - view.height) / 2)
            wait(30)
            var before = view.contentY
            // Not enough content to travel: the caller reports it rather than
            // measuring a rubber-band bounce.
            if (before <= 100)
                return -1
            mouseWheel(view, view.width / 2, view.height / 2, 0, -120, 0, 0)
            tryVerify(function() { return view.contentY !== before }, 1000)
            return view.contentY > before ? 1 : 0
        }

        function test_streamedOpensScrollEveryTime() {
            var adapter = chunkedAdapterComponent.createObject(null)
            adapter.rows = makeRows(251)
            adapter.tick = function() { testRoot.batchTimer.restart() }
            testRoot.activeAdapter = adapter
            page.session._adapters = ({ apps: adapter })

            for (var round = 1; round <= 3; round++) {
                page.session.open()
                tryVerify(function() {
                    return page.session.loadingMore === false && page.session.loading === false
                }, 5000)
                // Every row has landed: nothing may still be travelling in.
                tryVerify(function() { return !page.rowsAnimatingIn }, 3000)
                // The selection-driven scroll animates for 300ms after the last
                // batch; measure only once it has landed.
                wait(600)
                verify(page.resultsView.interactive,
                       "viewport must be interactive on open " + round)
                compare(wheelTravel(), 1, "wheel must scroll on open " + round)
                page.session.close()
                wait(120)
            }
            adapter.destroy()
            testRoot.activeAdapter = null
        }

        function test_aConcealedRowKeepsItsSlotSoTheListStaysScrollable() {
            // The live failure: the entrance wave folds every row to zero
            // height, and both wheel paths refuse input while it plays. The list
            // is therefore flat - nothing to scroll - and unresponsive until
            // the last row has landed, which on a 96-row window is the better
            // part of a second, and it is why the wheel did nothing on some
            // opens and worked on the ones that skipped the wave.
            //
            // Driven through a single row rather than by timing: holdInstantly()
            // is exactly what the wave does to a row, so this asserts the
            // contract without racing the stagger.
            var adapter = chunkedAdapterComponent.createObject(null)
            adapter.rows = makeRows(251)
            adapter.tick = function() { testRoot.batchTimer.restart() }
            testRoot.activeAdapter = adapter
            page.session._adapters = ({ apps: adapter })

            page.session.open()
            tryVerify(function() {
                return page.session.loadingMore === false && !page.rowsAnimatingIn
            }, 5000)
            wait(600)
            tryVerify(function() { return page.resultCount > 0 }, 2000)

            var view = page.resultsView
            var heightBefore = view.contentHeight
            var row = page.resultAt(0)
            verify(row !== null, "the first row must be materialized")
            var rowSlot = row.rowHeight + row.listGap
            compare(row.height, rowSlot, "a settled row occupies its slot")

            // Claim the row the way the wave does.
            row.holdInstantly()
            tryCompare(row, "revealHeld", true)
            tryVerify(function() { return page.rowsAnimatingIn }, 1000,
                      "a concealed row is what the page reads as animating")
            compare(row.height, rowSlot,
                    "a concealed row keeps its slot - folding it flattens the list")
            compare(row.opacity, 0, "a concealed row is still not drawn")
            verify(view.interactive,
                   "the viewport must take input while a row is concealed")
            compare(view.contentHeight, heightBefore,
                    "concealing a row must not shrink the scrollable content")
            compare(wheelTravel(), 1,
                    "a notch must travel while a row is still concealed")

            row.releaseInstantly()
            wait(60)
            tryVerify(function() { return !page.rowsAnimatingIn }, 2000)
            page.session.close()
            adapter.destroy()
            testRoot.activeAdapter = null
        }

        function test_scrollingDeepKeepsTheListScrollable() {
            // Every pass near the end materializes more rows. Those rows are
            // built held, so growth has to run the commit that releases them -
            // otherwise scrolling deep is what stops the wheel working.
            var adapter = chunkedAdapterComponent.createObject(null)
            adapter.rows = makeRows(251)
            adapter.tick = function() { testRoot.batchTimer.restart() }
            testRoot.activeAdapter = adapter
            page.session._adapters = ({ apps: adapter })

            page.session.open()
            tryVerify(function() { return page.session.loadingMore === false }, 5000)
            tryVerify(function() { return !page.rowsAnimatingIn }, 3000)
            tryVerify(function() { return page.resultCount === 96 }, 2000)

            var view = page.resultsView
            for (var pass = 0; pass < 4; pass++) {
                view.contentY = Math.max(0, view.contentHeight - view.height)
                wait(120)
            }
            verify(page.resultCount > 96, "the window should have grown past its base slice")
            tryVerify(function() { return !page.rowsAnimatingIn }, 3000)
            verify(page.resultsView.interactive, "growth must not strand the viewport")
            compare(wheelTravel(), 1, "wheel must still work after deep scrolling")

            page.session.close()
            adapter.destroy()
            testRoot.activeAdapter = null
        }
    }
}