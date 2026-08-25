import QtQuick
import QtTest

// Exercise the standalone launcher session state machine with deterministic
// fixture adapters injected via the _adapters seam: open defaults, prefix
// mode transitions, refresh sequencing, selection clamping, execution
// outcomes, and the keyboard contract.
//
// The Quickshell-free LauncherSession component is loaded by file path so
// the suite runs under plain qmltestrunner; the services directory module
// itself pulls Quickshell-only singletons that cannot load without the
// embedded plugin.
Item {
    Loader {
        id: sessionLoader
        source: "../../services/launcher/LauncherSession.qml"
    }

    TestCase {
        name: "LauncherService"

        // --- fixture helpers ---

        function makeItem(id, name, weight, usedAt) {
            return { id: id, displayName: name, favoriteWeight: weight, lastUsedAt: usedAt }
        }

        // Records every adapter call and keeps the completion callbacks so a
        // test resolves them in any order; nothing shells out or runs timers.
        function makeManualAdapter() {
            var adapter = {
                queries: [],
                executions: [],
                pendingRefreshes: [],
                pendingExecutions: []
            }
            adapter.refresh = function(query, mode, done) {
                adapter.queries.push({ query: query, mode: mode })
                adapter.pendingRefreshes.push(done)
            }
            adapter.execute = function(item, done) {
                adapter.executions.push(item)
                adapter.pendingExecutions.push(done)
            }
            return adapter
        }

        function resolveRefresh(adapter, index, outcome) {
            adapter.pendingRefreshes[index](outcome)
        }

        function resolveExecute(adapter, index, outcome) {
            adapter.pendingExecutions[index](outcome)
        }

        function svc() {
            return sessionLoader.item
        }

        function init() {
            verify(sessionLoader.status === Loader.Ready,
                   "LauncherSession failed to load: " + sessionLoader.source)
            svc()._refreshToken++
            svc().visible = false
            svc().query = ""
            svc().results = []
            svc().loading = false
            svc().error = ""
            svc().selectedIndex = -1
            svc()._adapters = ({})
            svc()._pooledMode = ""
            svc().displayPool = []
        }

        // --- open / close defaults ---

        function test_openDefaultsToAppsAndBeginsLoading() {
            var apps = makeManualAdapter()
            svc()._adapters = { apps: apps }

            svc().open()

            compare(svc().visible, true)
            compare(svc().mode, "apps")
            compare(svc().loading, true)
            compare(apps.queries.length, 1)
            compare(apps.queries[0].query, "")
            compare(apps.queries[0].mode, "apps")

            // Favorite weight outranks recency per the LauncherLogic contract.
            resolveRefresh(apps, 0, [makeItem("b", "Beta", 0, 99), makeItem("a", "Alpha", 5, 0)])

            compare(svc().loading, false)
            compare(svc().error, "")
            compare(svc().results.length, 2)
            compare(svc().results[0].id, "a")
            compare(svc().results[1].id, "b")
            compare(svc().selectedIndex, 0)
        }

        function test_toggleFlipsVisibility() {
            svc().toggle()
            compare(svc().visible, true)

            svc().toggle()
            compare(svc().visible, false)
        }

        // --- query-prefix mode transitions ---

        function test_queryPrefixesTransitionModesWhileStayingOpen() {
            var apps = makeManualAdapter()
            var clips = makeManualAdapter()
            var keys = makeManualAdapter()
            svc()._adapters = ({ apps: apps, clipboard: clips, shortcuts: keys })

            svc().open()
            svc().query = ">clip secret"

            compare(svc().mode, "clipboard")
            compare(svc().visible, true)
            // The pool pull requests the full set; text filtering is local.
            compare(clips.queries.length, 1)
            compare(clips.queries[0].query, "")
            compare(clips.queries[0].mode, "clipboard")

            resolveRefresh(clips, 0, [makeItem("c1", "Secret token", 0, 5)])
            compare(svc().selectedIndex, 0)

            svc().query = ">key spawn terminal"

            compare(svc().mode, "shortcuts")
            compare(keys.queries.length, 1)
            compare(keys.queries[0].query, "")

            resolveRefresh(keys, 0, [])
            compare(svc().selectedIndex, -1)

            svc().query = "firefox"
            compare(svc().mode, "apps")
            compare(svc().visible, true)
            // Switching back to apps re-pulls its pool with empty text.
            compare(apps.queries.length, 2)
            compare(apps.queries[1].query, "")
        }

        // --- selection clamping ---

        function test_selectionClampsToResultBounds() {
            var apps = makeManualAdapter()
            svc()._adapters = { apps: apps }

            svc().open()
            resolveRefresh(apps, 0, [
                makeItem("a", "Alpha", 0, 0),
                makeItem("b", "Beta", 0, 0),
                makeItem("c", "Gamma", 0, 0)
            ])

            compare(svc().selectedIndex, 0)

            svc().selectNext()
            svc().selectNext()
            compare(svc().selectedIndex, 2)

            svc().selectNext()
            compare(svc().selectedIndex, 2)

            svc().selectPrevious()
            svc().selectPrevious()
            compare(svc().selectedIndex, 0)

            svc().selectPrevious()
            compare(svc().selectedIndex, 0)
        }

        function test_clearingQueryResetsSelectionToFirstItem() {
            var apps = makeManualAdapter()
            svc()._adapters = ({ apps: apps })

            svc().open()
            resolveRefresh(apps, 0, [
                makeItem("alpha", "Alpha", 0, 0),
                makeItem("beta", "Beta", 0, 0),
                makeItem("gamma", "Gamma", 0, 2)
            ])

            svc().selectNext()
            svc().selectNext()

            // Narrow to gamma (anchor preserved), then clear the search:
            // the selection must land back on the first row.
            svc().query = "gam"
            compare(svc().results.length, 1)
            compare(svc().selectedIndex, 0)

            svc().query = ""
            compare(apps.queries.length, 1)
            compare(svc().results.length, 3)
            compare(svc().selectedIndex, 0)
        }

        // --- execution outcomes ---

        function test_successfulExecutionClosesSurface() {
            var apps = makeManualAdapter()
            svc()._adapters = { apps: apps }

            svc().open()
            resolveRefresh(apps, 0, [makeItem("firefox", "Firefox", 0, 0)])

            svc().executeSelected()
            compare(apps.executions.length, 1)
            compare(apps.executions[0].id, "firefox")

            resolveExecute(apps, 0, { ok: true })

            compare(svc().visible, false)
            compare(svc().query, "")
            compare(svc().results.length, 0)
            compare(svc().loading, false)
        }

        function test_failedExecutionPreservesVisibilityAndReportsError() {
            var apps = makeManualAdapter()
            svc()._adapters = { apps: apps }

            svc().open()
            resolveRefresh(apps, 0, [makeItem("firefox", "Firefox", 0, 0)])

            svc().executeSelected()
            resolveExecute(apps, 0, { ok: false, error: "desktop entry missing" })

            compare(svc().visible, true)
            compare(svc().error, "desktop entry missing")
            compare(svc().loading, false)
            compare(svc().results.length, 1)
        }

        // --- explicit error state ---

        function test_refreshFailureSetsExplicitErrorState() {
            var apps = makeManualAdapter()
            svc()._adapters = { apps: apps }

            svc().open()
            resolveRefresh(apps, 0, { error: "cache unavailable" })

            compare(svc().visible, true)
            compare(svc().loading, false)
            compare(svc().error, "cache unavailable")
        }

        // --- refresh sequencing ---

        function test_staleRefreshResultsAreDiscardedInFavorOfNewerQuery() {
            var apps = makeManualAdapter()
            var clips = makeManualAdapter()
            svc()._adapters = ({ apps: apps, clipboard: clips })

            svc().open()
            compare(apps.pendingRefreshes.length, 1)

            svc().query = ">clip x"
            resolveRefresh(clips, 0, [makeItem("c1", "xray clip", 0, 5)])
            compare(svc().results.length, 1)

            // A newer apps pull invalidates the still-pending older apps pull.
            svc().query = "fresh"
            compare(apps.pendingRefreshes.length, 2)
            compare(svc().loading, true)

            resolveRefresh(apps, 0, [makeItem("stale", "Stale", 9, 9)])

            compare(svc().results.length, 1)
            compare(svc().loading, true)
            compare(svc().error, "")

            resolveRefresh(apps, 1, [makeItem("fresh", "Fresh", 0, 0)])

            compare(svc().results.length, 1)
            compare(svc().results[0].id, "fresh")
            compare(svc().loading, false)
            compare(svc().selectedIndex, 0)
        }

        function test_closeInvalidatesInFlightRefresh() {
            var apps = makeManualAdapter()
            svc()._adapters = { apps: apps }

            svc().open()
            svc().close()

            resolveRefresh(apps, 0, [makeItem("late", "Late", 9, 9)])

            compare(svc().visible, false)
            compare(svc().loading, false)
            compare(svc().results.length, 0)
        }

        // --- pooled typing stability ---

        function test_refilterKeepsSurvivingSelection() {
            var apps = makeManualAdapter()
            svc()._adapters = ({ apps: apps })

            svc().open()
            resolveRefresh(apps, 0, [
                makeItem("alpha", "Alpha", 0, 0),
                makeItem("beta", "Beta", 0, 0),
                makeItem("gamma", "Gamma", 0, 0)
            ])
            compare(svc().selectedIndex, 0)

            // Pick the third row, then narrow the query; the same item must
            // stay selected instead of the highlight jumping back to top.
            svc().selectNext()
            svc().selectNext()
            compare(svc().selectedIndex, 2)

            svc().query = "gam"
            compare(svc().results.length, 1)
            compare(svc().results[svc().selectedIndex].id, "gamma")

            // Broadening again must land back on the first row instead of
            // staying anchored on the previously matched item.
            svc().query = "a"
            compare(svc().results.length, 3)
            compare(svc().selectedIndex, 0)
        }

        function test_identicalPoolPullKeepsDisplayPoolIdentity() {
            var apps = makeManualAdapter()
            svc()._adapters = ({ apps: apps })

            svc().open()
            resolveRefresh(apps, 0, [makeItem("a", "Alpha", 0, 0), makeItem("b", "Beta", 0, 0)])
            var stablePool = svc().displayPool

            // Close and reopen: the invalidated mode re-pulls, and identical
            // ordered contents must reuse the existing array so delegates
            // never rebuild.
            svc().close()
            svc()._adapters = ({ apps: apps })
            svc().open()
            compare(apps.pendingRefreshes.length, 2)
            resolveRefresh(apps, 1, [makeItem("a", "Alpha", 0, 0), makeItem("b", "Beta", 0, 0)])

            verify(svc().displayPool === stablePool)
            compare(svc().results.length, 2)
            compare(svc().selectedIndex, 0)
        }

        // --- keyboard contract ---

        function test_handleKeyFollowsKeyboardContract() {
            var apps = makeManualAdapter()
            svc()._adapters = { apps: apps }

            svc().open()
            resolveRefresh(apps, 0, [makeItem("a", "Alpha", 0, 0), makeItem("b", "Beta", 0, 0)])

            compare(svc().handleKey("down"), "down")
            compare(svc().selectedIndex, 1)

            compare(svc().handleKey("up"), "up")
            compare(svc().selectedIndex, 0)

            compare(svc().handleKey("end"), "none")

            svc().handleKey("escape")
            compare(svc().visible, false)
        }

        function test_escapeInRoutedModeKeepsPrefixAndClosesOnEmpty() {
            svc().open()
            svc().query = ">clip foo"

            compare(svc().handleKey("escape"), "clear")
            compare(svc().visible, true)
            compare(svc().query, ">clip ")
            compare(svc().mode, "clipboard")

            compare(svc().handleKey("escape"), "close")
            compare(svc().visible, false)
        }

        function test_escapeClearsInputBeforeClosingSession() {
            var apps = makeManualAdapter()
            svc()._adapters = { apps: apps }

            svc().open()
            svc().query = "fir"

            compare(svc().handleKey("escape"), "clear")
            compare(svc().visible, true)
            compare(svc().query, "")

            compare(svc().handleKey("escape"), "close")
            compare(svc().visible, false)
        }

        function test_enterBlockedWhileLoadingThenExecutesWhenReady() {
            var apps = makeManualAdapter()
            svc()._adapters = { apps: apps }

            svc().open()
            compare(svc().handleKey("enter"), "none")

            resolveRefresh(apps, 0, [makeItem("a", "Alpha", 0, 0)])
            compare(svc().handleKey("enter"), "execute")
            compare(apps.executions.length, 1)
        }

        function test_throwingAdapterStillCompletesExecution() {
            // An adapter that throws synchronously inside execute() must not
            // swallow the completion: the activated row is already hidden
            // for its exit fling, so a lost outcome strands the surface.
            var apps = makeManualAdapter()
            svc()._adapters = { apps: apps }

            svc().open()
            resolveRefresh(apps, 0, [makeItem("a", "Alpha", 0, 0)])
            apps.execute = function(item, done) {
                throw new Error("broken entry")
            }
            svc().executeSelected()

            compare(svc().error.length > 0, true)
            verify(String(svc().error).indexOf("broken entry") >= 0)
        }

        function test_forceRefreshRepullsPooledMode() {
            // Upstream-change announcers (entry rescans, clipboard polls)
            // must bypass the pooled fast path or their new data never
            // reaches an open list.
            var apps = makeManualAdapter()
            svc()._adapters = { apps: apps }

            svc().open()
            resolveRefresh(apps, 0, [makeItem("a", "Alpha", 0, 0)])
            var queriesBefore = apps.queries.length

            svc().refresh(true)
            compare(apps.queries.length, queriesBefore + 1)

            resolveRefresh(apps, queriesBefore, [makeItem("a", "Alpha", 0, 0), makeItem("n", "New app", 0, 1)])
            compare(svc().results.length, 2)
            compare(svc().results[0].id, "n")
        }

        function test_identicalRefreshKeepsResultsIdentity() {
            // Background polls (clipboard every 5s) re-resolve with the same
            // ids; the results array must keep its identity so the surface
            // does not replay the refill cascade - that read as list jitter.
            var apps = makeManualAdapter()
            svc()._adapters = { apps: apps }

            svc().open()
            resolveRefresh(apps, 0, [makeItem("a", "Alpha", 0, 0), makeItem("b", "Beta", 0, 1)])
            var first = svc().results

            // Background-poll equivalent: the session stays open and the
            // pooled fast path re-filters the unchanged data.
            svc().refresh()
            verify(svc().results === first,
                   "identical refresh replaced the results array")

            // A genuinely changed pull swaps the array.
            svc().close()
            svc().open()
            resolveRefresh(apps, 1, [makeItem("a", "Alpha", 0, 0)])
            verify(svc().results !== first, "changed refresh must swap arrays")
        }

        // --- IPC entry helpers keep their prefix behavior ---

        function test_openClipboardOpensWithClipboardPrefix() {
            var clips = makeManualAdapter()
            svc()._adapters = { clipboard: clips }

            svc().openClipboard()

            compare(svc().visible, true)
            compare(svc().query, ">clip ")
            compare(svc().mode, "clipboard")
            compare(clips.queries.length, 1)
            compare(clips.queries[0].query, "")

            svc().close()
            svc().openShortcuts()
            compare(svc().mode, "shortcuts")
            compare(svc().query, ">key ")
        }
    }
}
