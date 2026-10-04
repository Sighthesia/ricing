import QtQuick
import QtTest
import "../../modules/lazerbar" as Lazer

// Clipboard thumbnail decoding must be viewport-priority and throttled.
//
// Every materialized row used to ask for its own decode from the delegate's
// lifecycle, so opening the launcher on a screenshot-heavy clipboard spawned
// one `cliphist decode` process per row in the materialized window - up to 96
// of them before the user had scrolled anywhere. The page now routes every
// request through one queue that (a) only serves rows near the visible band,
// (b) keeps exactly one decode in flight and paces the rest, (c) drops rows
// that leave the band before their turn, and (d) serves the row the preview
// pane is rendering - the pointer target, else the selection - first.
//
// These tests drive the page with the real LauncherSession and a stub
// ClipboardService, so what is measured is the page's own request count.
Item {
    id: testRoot
    width: 800
    height: 600

    Lazer.LauncherPage {
        id: page
        anchors.fill: parent
    }

    // Stand-in for Services.ClipboardService: records every decode request in
    // issue order and hands the completion back so the test decides when - and
    // whether - a decode ever settles.
    QtObject {
        id: backend
        property var requests: []
        // Off by default: a decode that never settles is what proves the queue
        // stays behind a single in-flight request instead of piling more on.
        property bool autoComplete: false
        // Wall time of each request, for the spacing assertion. Read through a
        // Date instance: Quickshell patches Date.now() to its engine clock.
        property var stamps: []
        // A real, loadable file so the decoded path is not just a string: the
        // row's Image actually resolves it, exactly as production does.
        readonly property string fixtureThumb: Qt.resolvedUrl("../../modules/lazerbar/icons/apps.svg")
        // Requests whose callback has not been called yet.
        readonly property int unresolved: _unresolved

        property int _unresolved: 0
        property var _callbacks: []

        function decodeThumbnail(id, mime, callback) {
            backend.requests.push({ id: String(id), mime: String(mime) })
            backend.stamps.push(new Date().getTime())
            backend._unresolved++
            if (backend.autoComplete) {
                Qt.callLater(function () {
                    backend._unresolved--
                    callback(backend.fixtureThumb)
                })
                return
            }
            backend._callbacks.push(callback)
        }

        // Settle every deliberately stuck decode. The real service always calls
        // back; a test that refuses to would otherwise wedge the queue for
        // every test that follows it.
        function flush() {
            var pending = backend._callbacks
            backend._callbacks = []
            for (var i = 0; i < pending.length; i++) {
                backend._unresolved--
                pending[i](backend.fixtureThumb)
            }
        }

        function requestedIds() {
            var out = []
            for (var i = 0; i < backend.requests.length; i++)
                out.push(backend.requests[i].id)
            return out
        }
    }

    // Clipboard data source stub: one complete batch of the fixture rows.
    QtObject {
        id: adapter
        property var rows: []

        function refresh(query, mode, done) {
            done(adapter.rows, true)
        }
        function execute(item, done) { done({ ok: true }) }
    }

    // --- fixtures ---

    // Image entries shaped like the clipboard adapter's output, newest first so
    // pool order matches the index the row lands at.
    function makeImageRows(count, firstId) {
        var out = []
        for (var i = 0; i < count; i++) {
            out.push({
                id: String(firstId + i),
                displayName: "[Image] 800x600",
                description: "image/png | PNG | 64.0 KiB",
                searchText: "[image] 800x600 image",
                icon: "",
                previewText: "[[ binary data 64 KiB png 800x600 ]]",
                mime: "image/png",
                isImage: true,
                category: "image",
                favoriteWeight: 0,
                lastUsedAt: 1700000000000 + (count - i)
            })
        }
        return out
    }

    function resetSession() {
        var s = page.session
        s._refreshToken++
        s.visible = false
        s.query = ""
        s.results = []
        s.loading = false
        s.error = ""
        s.selectedIndex = -1
        s._pooledMode = ""
        s.displayPool = []
        s._adapters = ({})
        s.category = ""
        s.loadingMore = false
    }

    // Fire the open. Each test uses its own id range, so the page's decoded path
    // cache can never make one test's rows invisible to another. Blocking waits
    // live in the TestCase below: `tryVerify`/`wait` are TestCase methods and
    // do not resolve from this scope.
    function openClipboard(count, firstId, autoComplete) {
        // A previous test may have parked a decode on purpose; let it settle so
        // its in-flight slot cannot follow this test.
        backend.flush()
        resetSession()
        backend.requests = []
        backend.stamps = []
        backend._unresolved = 0
        backend.autoComplete = autoComplete === true
        adapter.rows = makeImageRows(count, firstId)
        page.session.clipboardService = backend
        page.session._adapters = ({ clipboard: adapter })
        page.session.query = ">clip "
        page.session.open()
    }

    function rowPitch() {
        var row = page.resultAt(0)
        return row.rowHeight + row.listGap
    }

    // How many of the materialized rows the queue is even allowed to serve:
    // every row overlapping the visible band plus the prefetch slack. Measured
    // from the live viewport rather than assumed, and counted the way the page
    // counts: a row is in range while it overlaps the band at all, so a
    // partially visible row counts and one wholly past the slack does not.
    function bandRowCount() {
        var pitch = rowPitch()
        var view = page.resultsView
        var padding = page.thumbPrefetchRows * pitch
        var bandTop = view.contentY - padding
        var bandBottom = view.contentY + view.height + padding
        var count = 0
        for (var i = 0; i < page.resultCount; i++) {
            var top = i * pitch
            if (top > bandBottom)
                break
            if (top + pitch >= bandTop)
                count++
        }
        return count
    }

    // Rows that are actually on screen right now: the same overlap test with
    // no slack, which is the half of the contract the user can see.
    function visibleRowCount() {
        var pitch = rowPitch()
        var view = page.resultsView
        var count = 0
        for (var i = 0; i < page.resultCount; i++) {
            var top = i * pitch
            if (top > view.contentY + view.height)
                break
            if (top + pitch >= view.contentY)
                count++
        }
        return count
    }

    // The queue has drained: nothing outstanding AND something actually
    // served. `!busy && outstandingCount === 0` is also true before the first
    // tick ever fires, so a drain assertion that accepted that would measure
    // nothing and pass for the wrong reason.
    function drained(base) {
        var queue = page.thumbScheduler
        return queue.issuedCount - base > 0 && !queue.busy && queue.outstandingCount === 0
    }

    // The page (and its queue) is one long-lived object, so the counters are
    // lifetime totals. Every test reads them against the baseline it took
    // before opening, which is also what keeps a passing earlier test from
    // satisfying a later one by accident.
    function queueBase() {
        return page.thumbScheduler.issuedCount
    }

    TestCase {
        name: "LauncherThumbs"
        when: windowShown

        function init() {
            // Instant geometry everywhere: the queue ranks rows against real
            // heights, so an animating fold would make the served order a
            // moving target rather than a contract.
            Lazer.MotionTokens.reducedMotionOverride = true
            testRoot.forceActiveFocus()
        }

        function cleanup() {
            // The singleton outlives this file under the shared-process suite
            // runner, so the override must not leak into the next file.
            Lazer.MotionTokens.reducedMotionOverride = false
        }

        // Open the launcher onto `count` clipboard image rows and wait until
        // every delegate is materialized. `openRowsStuck` leaves every decode
        // outstanding, which is what a stalled queue looks like from outside.
        function openRows(count, firstId) {
            openClipboard(count, firstId, true)
            openSettledRows(count)
        }
        function openRowsStuck(count, firstId) {
            openClipboard(count, firstId, false)
            openSettledRows(count)
        }
        // Park at the top: where the viewport sits IS the contract under test,
        // and the list keeps its scroll offset across an open, so a previous
        // test that scrolled away would silently measure the wrong band.
        function openSettledRows(count) {
            tryVerify(function () { return page.resultCount === count }, 3000)
            page.resultsView.contentY = 0
        }

        // --- viewport priority ---

        function test_coldOpenDecodesOnlyTheVisibleBand() {
            // 40 image rows, all inside the base materialized window. The
            // viewport shows a fraction of them, so a queue that served
            // materialized rows would spawn 40 decode processes here.
            var base = queueBase()
            openRows(40, 1000)
            var view = page.resultsView
            var pitch = rowPitch()
            verify(view.height < 40 * pitch, "the viewport must be shorter than the list")

            tryVerify(function () { return drained(base) }, 8000)

            var asked = backend.requestedIds()
            verify(asked.length >= 1, "a visible image row must still get its thumbnail")
            verify(asked.length < 40,
                   "asked for " + asked.length + " decodes for a viewport of "
                   + view.height + "px")
            verify(asked.length <= bandRowCount(),
                   "asked for " + asked.length + " decodes, the band holds "
                   + bandRowCount())
            // The tail below the fold is what the old per-row request spent
            // its processes on.
            verify(asked.indexOf("1039") < 0, "a row far below the fold must not be decoded")
            // And the user-visible half of the contract: everything actually
            // on screen still decodes.
            var visible = visibleRowCount()
            verify(visible >= 6, "the fixture needs a viewport of several rows")
            for (var i = 0; i < visible; i++)
                verify(asked.indexOf(String(1000 + i)) >= 0,
                       "visible row " + i + " never decoded")
            // The decoded path really landed and the row repainted from it.
            verify(page.clipThumbPath(page.resultAt(0).result).length > 0)
            verify(page.resultAt(0).thumbPath.length > 0)
            verify(!page.resultAt(0).thumbFailed)
        }

        function test_oneDecodeInFlightWhenNothingSettles() {
            // Decodes never settle, so the queue has to stay parked behind a
            // single request: every other candidate waits its turn instead of
            // piling another process on top of it.
            var base = queueBase()
            openRowsStuck(40, 2000)
            var queue = page.thumbScheduler
            tryVerify(function () { return queue.issuedCount - base >= 1 }, 4000)

            compare(queue.busy, true, "a request must still be outstanding")
            compare(backend.requests.length, queue.issuedCount - base,
                    "every request must go through the paced queue")
            compare(backend.unresolved, 1, "exactly one decode may be in flight")
            compare(queue.inFlightId, backend.requestedIds()[0])
            verify(queue.outstandingCount > 0, "the rest of the band must be queued")

            // And it stays that way: no second request while the first lives.
            var issued = queue.issuedCount
            wait(600)
            compare(queue.issuedCount, issued)
            compare(backend.requests.length, 1)
            compare(backend.unresolved, 1)
        }

        function test_requestsAreSpacedOnePerTick() {
            // Now let them settle: consecutive requests must be at least one
            // pacer interval apart, so a burst of newly visible rows decodes
            // over a few frames instead of all of them in the frame that
            // revealed the rows.
            var base = queueBase()
            openRows(40, 2100)
            tryVerify(function () { return drained(base) }, 15000)

            compare(backend.requests.length, page.thumbScheduler.issuedCount - base)
            verify(backend.stamps.length > 2, "the band must have taken several requests")
            for (var i = 1; i < backend.stamps.length; i++) {
                var gap = backend.stamps[i] - backend.stamps[i - 1]
                verify(gap >= Lazer.MotionTokens.fast - 20,
                       "requests " + (i - 1) + " and " + i + " were " + gap + "ms apart")
            }
        }

        function test_scrollingAQueuedRowOutOfRangeDropsIt() {
            var base = queueBase()
            openRowsStuck(40, 3000)
            var queue = page.thumbScheduler
            var view = page.resultsView
            tryVerify(function () { return queue.issuedCount - base >= 1 }, 3000)

            // Everything in the band that is not already in flight is waiting.
            var queued = queue.pendingIds()
            verify(queued.length > 0, "the band must have queued candidates")

            // Park at the far end: the queued top rows leave the band.
            view.contentY = Math.max(0, view.contentHeight - view.height)
            tryVerify(function () {
                var still = queue.pendingIds()
                for (var i = 0; i < queued.length; i++)
                    if (still.indexOf(queued[i]) >= 0)
                        return false
                return true
            }, 2000)

            var after = queue.pendingIds()
            for (var i = 0; i < queued.length; i++)
                verify(after.indexOf(queued[i]) < 0,
                       "row " + queued[i] + " stayed queued after leaving the band")
            // Dropped means dropped: none of them was handed to the service.
            var asked = backend.requestedIds()
            compare(asked.length, 1, "only the in-flight row may ever have been issued")
            for (var q = 0; q < queued.length; q++)
                verify(asked.indexOf(queued[q]) < 0,
                       "row " + queued[q] + " was decoded while off screen")

            // The rows that just came into range are picked up instead, which
            // is the half of the contract that keeps scrolling honest.
            tryVerify(function () {
                return queue.pendingIds().indexOf("3039") >= 0
            }, 2000)
        }

        function test_selectedRowIsServedBeforeCloserRows() {
            var base = queueBase()
            openRows(40, 4000)
            var queue = page.thumbScheduler
            // Let the cold open drain first. The queue is now idle, so the
            // selection move below is the only thing that can start it: the
            // order it picks in is fully determined by the contract.
            tryVerify(function () {
                return drained(base) && queue.issuedCount - base > 1
            }, 8000)
            var afterDrain = queue.issuedCount - base

            // Select the very last row. Nothing scrolls it into view here, so
            // it is off the band as well as last in document order - it only
            // has a candidate slot because the selection carries it there.
            page.session.selectedIndex = 39
            tryVerify(function () {
                return queue.issuedCount - base > afterDrain
            }, 3000)
            compare(queue.issuedIds[base + afterDrain], "4039")
            // The rest of the band the move brought into range follows it.
            tryVerify(function () { return drained(base) }, 8000)
            verify(queue.issuedCount - base > afterDrain + 1)
        }

        // --- cache semantics survive the queue ---

        function test_decodedRowKeepsItsThumbnailAndIsNeverAskedTwice() {
            var base = queueBase()
            openRows(6, 5000)
            var queue = page.thumbScheduler
            tryVerify(function () {
                return drained(base) && queue.issuedCount - base === 6
            }, 8000)
            compare(backend.requests.length, 6)

            for (var i = 0; i < 6; i++) {
                var row = page.resultAt(i)
                verify(row.thumbPath.length > 0, "row " + i + " has no thumbnail")
                verify(!row.thumbFailed, "row " + i + " failed to load its thumbnail")
                verify(page.clipThumbPath(row.result).length > 0)
            }
            verify(page._thumbRev >= 6, "the revision must repaint decoded rows")

            // A scroll and a re-commit re-derive the served order. A decoded
            // row is no longer a candidate, so neither may spawn a process.
            page.resultsView.contentY = 0
            page._scheduleRowsCommit()
            wait(400)
            compare(queue.issuedCount - base, 6, "a decoded row must not be re-requested")
            compare(backend.requests.length, 6)
            verify(page.resultAt(3).thumbPath.length > 0)
        }

        // --- the queue follows the session ---

        function test_closedLauncherStopsTheDecodeQueue() {
            var base = queueBase()
            openRows(20, 6000)
            var queue = page.thumbScheduler
            tryVerify(function () { return queue.issuedCount - base >= 1 }, 3000)

            page.session.close()
            // Rows stay materialized across a close - the instant reopen
            // depends on it - so what stops them spending processes is the
            // session going hidden, not the rows going away.
            compare(queue.active, false)
            compare(queue.running, false, "a closed launcher must not keep a pacer ticking")
            var issued = queue.issuedCount - base
            wait(500)
            compare(queue.issuedCount - base, issued)
            compare(backend.requests.length, issued)
        }
    }
}