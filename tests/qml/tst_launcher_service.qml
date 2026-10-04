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

    // Clipboard-service stub: records decode requests and can emit the
    // previewDecoded completion the session relays to its consumers.
    Component {
        id: clipboardStubComponent
        QtObject {
            property var requests: []
            signal previewDecoded(string id, string contentOrPath)
            signal metadataUpdated(string id)
            function requestPreview(id, isImage) {
                requests.push({ id: id, isImage: isImage })
            }
        }
    }

    property var _clipboardStub: null

    TestCase {
        name: "LauncherService"

        // --- fixture helpers ---

        function makeItem(id, name, weight, usedAt) {
            return { id: id, displayName: name, favoriteWeight: weight, lastUsedAt: usedAt }
        }

        function makeCategorized(id, name, category, usedAt) {
            return {
                id: id,
                displayName: name,
                category: category,
                favoriteWeight: 0,
                lastUsedAt: usedAt == null ? 0 : usedAt
            }
        }

        function openWithCategories(items) {
            var apps = makeManualAdapter()
            svc()._adapters = { apps: apps }
            svc().open()
            wait(0)
            apps.pendingRefreshes[0](items)
            return apps
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
            adapter.pendingRefreshes[index](outcome, true)
        }

        // Delivers one batch of a streaming refresh; complete defaults to the
        // final batch, matching the adapter contract.
        function resolveBatch(adapter, index, outcome, complete) {
            adapter.pendingRefreshes[index](outcome, complete === undefined ? true : complete)
        }

        function resolveExecute(adapter, index, outcome) {
            adapter.pendingExecutions[index](outcome)
        }

        function svc() {
            return sessionLoader.item
        }

        function openAndWait() {
            svc().open()
            wait(0)
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
            svc().category = ""
            svc()._metadataRefreshPending = false
            svc().loadingMore = false
            svc()._streamActive = false
            svc()._inputActive = false
            svc()._heldBatches = []
            if (_clipboardStub) {
                _clipboardStub.destroy()
                _clipboardStub = null
            }
            svc().clipboardService = null
        }

        // --- clipboard preview decode relay ---

        function test_textPreviewRelayForwardsRequestsAndDecodes() {
            _clipboardStub = clipboardStubComponent.createObject(null)
            svc().clipboardService = _clipboardStub

            svc().requestTextPreview("42")
            compare(_clipboardStub.requests.length, 1)
            compare(_clipboardStub.requests[0].id, "42")
            compare(_clipboardStub.requests[0].isImage, false)

            var got = []
            svc().textPreviewDecoded.connect(function(id, content) { got.push([id, content]) })

            // Both text and image completions ride the same relay; the
            // consumer (preview pane) filters file:// URLs itself.
            _clipboardStub.previewDecoded("42", "full\ntext body")
            _clipboardStub.previewDecoded("9", "file:///tmp/x.img?rev=2")

            compare(got.length, 2)
            compare(got[0][0], "42")
            compare(got[0][1], "full\ntext body")
            compare(got[1][0], "9")
        }

        function test_requestTextPreviewWithoutServiceIsInert() {
            svc().requestTextPreview("7")
            compare(svc().visible, false)
            compare(svc().results.length, 0)
        }

        // --- open / close defaults ---

        function test_openDefaultsToAppsAndBeginsLoading() {
            var apps = makeManualAdapter()
            svc()._adapters = { apps: apps }

            svc().open()

            compare(svc().visible, true)
            compare(apps.queries.length, 0)
            wait(0)

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

        function test_primeAppsBuildsClosedPoolWithoutOpeningSession() {
            var apps = makeManualAdapter()
            svc()._adapters = { apps: apps }

            svc().primeApps()

            compare(svc().visible, false)
            compare(svc().loading, false)
            compare(apps.queries.length, 1)

            resolveRefresh(apps, 0, [makeItem("a", "Alpha", 0, 0)])

            compare(svc().visible, false)
            compare(svc()._pooledMode, "apps")
            compare(svc().displayPool.length, 1)
            compare(svc().results.length, 1)
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

            openAndWait()
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

            openAndWait()
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

            openAndWait()
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

            openAndWait()
            resolveRefresh(apps, 0, [makeItem("firefox", "Firefox", 0, 0)])

            svc().executeSelected()
            compare(apps.executions.length, 1)
            compare(apps.executions[0].id, "firefox")

            resolveExecute(apps, 0, { ok: true })

            compare(svc().visible, false)
            compare(svc().query, "")
            // Results freeze at the pool-derived set instead of emptying:
            // keeping the row delegates alive means the next open never
            // rebuilds the list on its first frame.
            compare(svc().results.length, 1)
            compare(svc().results[0].id, "firefox")
            compare(svc().loading, false)
        }

        function test_failedExecutionPreservesVisibilityAndReportsError() {
            var apps = makeManualAdapter()
            svc()._adapters = { apps: apps }

            openAndWait()
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

            openAndWait()
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

            openAndWait()
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

            openAndWait()
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

            openAndWait()
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

            openAndWait()
            resolveRefresh(apps, 0, [makeItem("a", "Alpha", 0, 0), makeItem("b", "Beta", 0, 0)])
            var stablePool = svc().displayPool

            // Close and reopen: the apps pool survives the close, so the
            // open must serve results locally without re-pulling the source
            // and without rebuilding the pooled array.
            svc().close()
            openAndWait()
            compare(apps.queries.length, 1, "reopen re-pulled the source")
            verify(svc().displayPool === stablePool)
            compare(svc().results.length, 2)
            compare(svc().selectedIndex, 0)

            // Keystrokes after the pooled reopen stay local as well.
            svc().query = "al"
            compare(apps.queries.length, 1)
            compare(svc().results.length, 1)
            compare(svc().results[0].id, "a")
        }

        // --- background pool revalidation ---

        function test_revalidatePoolSwapsClosedSessionPool() {
            var apps = makeManualAdapter()
            svc()._adapters = ({ apps: apps })

            openAndWait()
            resolveRefresh(apps, 0, [makeItem("a", "Alpha", 0, 0)])
            var firstPool = svc().displayPool
            svc().close()

            // A change announcer fires while closed: the pool updates in
            // the background without touching visibility or results. The
            // incoming set must already be in sorted order (Alpha ranks
            // before New app on the name tiebreak).
            svc().revalidatePool()
            compare(apps.queries.length, 2)
            resolveRefresh(apps, 1, [makeItem("a", "Alpha", 0, 0), makeItem("n", "New app", 0, 0)])

            compare(svc().visible, false)
            // Results freeze at the pre-close set while closed; background
            // pool swaps must not disturb them. The frozen rows keep their
            // delegates alive so the next open never rebuilds the list.
            compare(svc().results.length, 1)
            compare(svc().results[0].id, "a")
            verify(svc().displayPool !== firstPool)
            compare(svc().displayPool.length, 2)
            compare(svc().displayPool[1].id, "n")

            // The next open serves the fresh pool without re-pulling.
            openAndWait()
            compare(apps.queries.length, 2, "reopen after revalidation re-pulled the source")
            compare(svc().results.length, 2)
            compare(svc().results[1].id, "n")
        }

        function test_revalidatePoolKeepsIdenticalPoolIdentity() {
            var apps = makeManualAdapter()
            svc()._adapters = ({ apps: apps })

            openAndWait()
            resolveRefresh(apps, 0, [makeItem("a", "Alpha", 0, 0)])
            var stablePool = svc().displayPool
            svc().close()

            svc().revalidatePool()
            resolveRefresh(apps, 1, [makeItem("a", "Alpha", 0, 0)])

            verify(svc().displayPool === stablePool)
        }

        function test_revalidatePoolKeepsPoolOnSourceError() {
            var apps = makeManualAdapter()
            svc()._adapters = ({ apps: apps })

            openAndWait()
            resolveRefresh(apps, 0, [makeItem("a", "Alpha", 0, 0)])
            var stablePool = svc().displayPool
            svc().close()

            // A closed session has no error surface; a transient source
            // failure must keep the stale pool instead of emptying it.
            svc().revalidatePool()
            resolveRefresh(apps, 1, { error: "source failed" })

            verify(svc().displayPool === stablePool)
            compare(svc().error, "")
        }

        function test_revalidatePoolNoopWithoutAppsPool() {
            // No pooled apps data (never opened, or closed from another
            // mode): there is nothing to revalidate and no adapter hit.
            var apps = makeManualAdapter()
            svc()._adapters = ({ apps: apps })
            svc()._pooledMode = ""

            svc().revalidatePool()
            compare(apps.queries.length, 0)

            // Also inert when the pool is empty (first-open not pulled yet).
            svc()._pooledMode = "apps"
            svc().revalidatePool()
            compare(apps.queries.length, 0)
        }

        function test_revalidatePoolWhileVisibleForcePulls() {
            var apps = makeManualAdapter()
            svc()._adapters = ({ apps: apps })

            openAndWait()
            resolveRefresh(apps, 0, [makeItem("a", "Alpha", 0, 0)])

            svc().revalidatePool()
            compare(apps.queries.length, 2)
            compare(svc().loading, true)
            resolveRefresh(apps, 1, [makeItem("a", "Alpha", 0, 0)])
            compare(svc().loading, false)
            compare(svc().results.length, 1)
        }

        // --- keyboard contract ---

        function test_handleKeyFollowsKeyboardContract() {
            var apps = makeManualAdapter()
            svc()._adapters = { apps: apps }

            openAndWait()
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
            openAndWait()
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

            openAndWait()
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

            openAndWait()
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

            openAndWait()
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

            openAndWait()
            resolveRefresh(apps, 0, [makeItem("a", "Alpha", 0, 0)])
            var queriesBefore = apps.queries.length

            svc().refresh(true)
            compare(apps.queries.length, queriesBefore + 1)

            resolveRefresh(apps, queriesBefore, [makeItem("a", "Alpha", 0, 0), makeItem("n", "New app", 0, 1)])
            compare(svc().results.length, 2)
            compare(svc().results[0].id, "n")
        }

        function test_clipboardCloseRepullsAppsOnceThenStaysLocal() {
            // The apps and clipboard pools survive a close; other modes must
            // re-fetch. After the mode-switch reopen re-pulls once, the
            // restored marker must keep every later keystroke local.
            var apps = makeManualAdapter()
            var clips = makeManualAdapter()
            svc()._adapters = ({ apps: apps, clipboard: clips })

            openAndWait()
            resolveRefresh(apps, 0, [makeItem("a", "Alpha", 0, 0)])
            compare(svc()._pooledMode, "apps")

            svc().query = ">clip "
            resolveRefresh(clips, 0, [makeItem("c1", "Clip", 0, 0)])
            compare(svc()._pooledMode, "clipboard")

            svc().close()
            openAndWait()
            compare(apps.queries.length, 2, "apps reopen must re-pull after a clipboard session")
            resolveRefresh(apps, 1, [makeItem("a", "Alpha", 0, 0), makeItem("b", "Beta", 0, 0)])
            compare(svc().results.length, 2)

            svc().query = "al"
            compare(apps.queries.length, 2, "keystroke re-pulled the source")
            compare(svc().results.length, 1)
            verify(svc().results.length >= 1)
        }

        function test_clipboardReopenRepullsSynchronouslyWithoutLoadingFlash() {
            // Reopening clipboard re-pulls through the adapter instead of
            // painting the possibly-stale pool: one extra source query, but
            // still no loading flash, and the same array identity when the
            // backend data did not change, so the surface skips its wave.
            var clips = makeManualAdapter()
            svc()._adapters = { clipboard: clips }

            svc().openClipboard()
            wait(0)
            resolveRefresh(clips, 0, [makeItem("c1", "Clip one", 0, 10), makeItem("c2", "Clip two", 0, 5)])
            compare(svc()._pooledMode, "clipboard")
            compare(svc().loading, false)
            compare(svc().selectedIndex, 0)
            var firstPool = svc().displayPool

            svc().close()
            compare(svc().visible, false)
            compare(svc()._pooledMode, "clipboard")
            // close() freezes a pool-derived slice; the reopen must keep
            // that frozen array instead of swapping in a fresh one.
            var frozenResults = svc().results
            compare(frozenResults.length, 2)

            var queriesBefore = clips.queries.length
            svc().openClipboard()
            wait(0)

            compare(clips.queries.length, queriesBefore + 1, "reopen skipped the fresh pull")
            compare(svc().loading, false)
            resolveRefresh(clips, queriesBefore, [makeItem("c1", "Clip one", 0, 10), makeItem("c2", "Clip two", 0, 5)])
            compare(svc().error, "")
            compare(svc().results.length, 2)
            compare(svc().results[0].id, "c1")
            verify(svc().results === frozenResults, "reopen replaced the results array")
            verify(svc().displayPool === firstPool, "reopen replaced the pooled array")
            compare(svc().selectedIndex, 0)
        }

        function test_clipboardBackgroundPollCommitsWithoutLoadingFlash() {
            // The 5s history poll force-pulls while open; with stale rows on
            // screen it must commit in the background instead of blanking
            // the list behind "Searching...".
            var clips = makeManualAdapter()
            svc()._adapters = { clipboard: clips }

            svc().openClipboard()
            wait(0)
            resolveRefresh(clips, 0, [makeItem("c1", "Clip one", 0, 10)])
            compare(svc().loading, false)

            svc().refresh(true)
            compare(clips.queries.length, 2)
            compare(svc().loading, false, "background poll raised loading over stale rows")
            compare(svc().interactive, true)
            compare(svc().results.length, 1)

            resolveRefresh(clips, 1, [makeItem("c1", "Clip one", 0, 10), makeItem("c2", "Clip two", 0, 5)])
            compare(svc().loading, false)
            compare(svc().error, "")
            compare(svc().results.length, 2)
        }

        function test_closeDuringClipboardLoadKeepsTruthfulPoolMarker() {
            // Switching to clipboard then closing before the pull resolves:
            // the pool still holds apps rows, so the marker must stay "apps"
            // instead of claiming "clipboard" (which would later serve apps
            // rows under ">clip ").
            var apps = makeManualAdapter()
            var clips = makeManualAdapter()
            svc()._adapters = ({ apps: apps, clipboard: clips })

            openAndWait()
            resolveRefresh(apps, 0, [makeItem("a", "Alpha", 0, 0)])
            compare(svc()._pooledMode, "apps")

            svc().query = ">clip "
            compare(clips.queries.length, 1)
            compare(svc().loading, true)
            svc().close()
            compare(svc()._pooledMode, "apps")

            // The stale pull must not resurrect closed-session state.
            resolveRefresh(clips, 0, [makeItem("c1", "Clip", 0, 0)])
            compare(svc().visible, false)

            // Reopening clipboard re-pulls real clipboard rows instead of
            // serving the apps pool under the clipboard prefix.
            svc().openClipboard()
            wait(0)
            compare(clips.queries.length, 2)
            compare(svc().loading, true)
            resolveRefresh(clips, 1, [makeItem("c1", "Clip", 0, 0)])
            compare(svc().mode, "clipboard")
            compare(svc().results.length, 1)
            compare(svc().results[0].id, "c1")
        }

        function test_redundantCloseKeepsRetainedClipboardMarker() {
            var clips = makeManualAdapter()
            svc()._adapters = { clipboard: clips }

            svc().openClipboard()
            wait(0)
            resolveRefresh(clips, 0, [makeItem("c1", "Clip", 0, 0)])
            compare(svc()._pooledMode, "clipboard")

            svc().close()
            compare(svc()._pooledMode, "clipboard")
            // A redundant close (e.g. a host onClosed landing after the
            // session already closed) reads an empty query and must not
            // downgrade the retained marker to "apps".
            svc().close()
            compare(svc()._pooledMode, "clipboard")

            var queriesBefore = clips.queries.length
            svc().openClipboard()
            wait(0)
            // The retained marker routes the reopen through one synchronous
            // fresh pull (no loading flash over the frozen rows).
            compare(clips.queries.length, queriesBefore + 1, "reopen re-pulled after marker downgrade")
            compare(svc().loading, false)
            resolveRefresh(clips, queriesBefore, [makeItem("c1", "Clip", 0, 0)])
            compare(svc().results[0].id, "c1")
        }

        function test_identicalRefreshKeepsResultsIdentity() {
            // Background polls (clipboard every 5s) re-resolve with the same
            // ids; the results array must keep its identity so the surface
            // does not replay the refill cascade - that read as list jitter.
            var apps = makeManualAdapter()
            svc()._adapters = { apps: apps }

            openAndWait()
            resolveRefresh(apps, 0, [makeItem("a", "Alpha", 0, 0), makeItem("b", "Beta", 0, 1)])
            var first = svc().results

            // Background-poll equivalent: the session stays open and the
            // pooled fast path re-filters the unchanged data.
            svc().refresh()
            verify(svc().results === first,
                   "identical refresh replaced the results array")

            // A genuinely changed pull swaps the array.
            svc().refresh(true)
            resolveRefresh(apps, 1, [makeItem("a", "Alpha", 0, 0)])
            verify(svc().results !== first, "changed refresh must swap arrays")
        }

        function test_clipboardMetadataMergeUpdatesRowsWithoutReplacingPool() {
            _clipboardStub = clipboardStubComponent.createObject(null)
            svc().clipboardService = _clipboardStub
            var clips = makeManualAdapter()
            svc()._adapters = { clipboard: clips }

            svc().openClipboard()
            wait(0)
            resolveRefresh(clips, 0, [{ id: "img", displayName: "[Image]" }])
            compare(svc().results[0].displayName, "[Image]")
            var first = svc().results
            var merged = []
            svc().clipboardMetadataMerged.connect(function() { merged.push(1) })

            // Metadata landing must merge into the kept row objects instead
            // of swapping the pool: same array identity, fresh text. The merge
            // waits for the metadata stream to go quiet before it reads.
            _clipboardStub.metadataUpdated("img")
            wait(svc()._metadataQuietMs + 60)
            resolveRefresh(clips, 1, [{ id: "img", displayName: "[Image] 712x522" }])
            verify(svc().results === first)
            compare(svc().results[0].displayName, "[Image] 712x522")
            compare(merged.length, 1)
        }

        function test_metadataBurstMergesOnceAfterTheStreamGoesQuiet() {
            // Metadata now lands in batches, and each batch ends with its own
            // signal. Merging per signal re-mapped the whole history once per
            // batch; a burst must cost exactly one round, and only once the
            // signals have stopped.
            _clipboardStub = clipboardStubComponent.createObject(null)
            svc().clipboardService = _clipboardStub
            var clips = makeManualAdapter()
            svc()._adapters = { clipboard: clips }

            svc().openClipboard()
            wait(0)
            resolveRefresh(clips, 0, [{ id: "img", displayName: "[Image]" }])

            for (var burst = 0; burst < 8; burst++) {
                _clipboardStub.metadataUpdated("img")
                wait(10)
            }
            // Still inside the quiet window: nothing may have been read yet.
            compare(clips.queries.length, 1)

            wait(svc()._metadataQuietMs + 60)
            // One round for the whole burst - the adapter was asked once.
            compare(clips.queries.length, 2)
            resolveRefresh(clips, 1, [{ id: "img", displayName: "[Image] 712x522" }])
            wait(0)
            compare(clips.queries.length, 2)
        }

        // --- IPC entry helpers keep their prefix behavior ---

        function test_openClipboardOpensWithClipboardPrefix() {
            var clips = makeManualAdapter()
            svc()._adapters = { clipboard: clips }

            svc().openClipboard()
            wait(0)

            compare(svc().visible, true)
            compare(svc().query, ">clip ")
            compare(svc().mode, "clipboard")
            compare(clips.queries.length, 1)
            compare(clips.queries[0].query, "")

            svc().close()
            svc().openShortcuts()
            wait(0)
            compare(svc().mode, "shortcuts")
            compare(svc().query, ">key ")
        }

        // --- streaming batches ---

        function test_firstBatchPaintsAndTheRestStreamBehindIt() {
            var apps = makeManualAdapter()
            svc()._adapters = { apps: apps }
            svc().open()
            wait(0)
            compare(svc().loading, true)

            // Nothing is on screen yet, so the full loading state owns the
            // surface until the first batch lands.
            resolveBatch(apps, 0, [makeItem("a", "Alpha", 0, 0)], false)
            compare(svc().loading, false)
            compare(svc().loadingMore, true)
            compare(svc().results.length, 1)
            // Navigation works while the tail is still streaming.
            compare(svc().interactive, true)

            var pool = svc().displayPool
            resolveBatch(apps, 0, [makeItem("b", "Beta", 0, 0)], false)
            resolveBatch(apps, 0, [makeItem("c", "Gamma", 0, 0)], true)

            compare(svc().loadingMore, false)
            compare(svc().results.length, 3)
            // Appending must not replace the pooled array wholesale, or every
            // live delegate would be rebuilt on each batch.
            verify(svc().displayPool !== pool)
            verify(svc().displayPool.length === 3)
            compare(svc().results[2].id, "c")
        }

        function test_appendedBatchKeepsTheSelectedRow() {
            var apps = makeManualAdapter()
            svc()._adapters = { apps: apps }
            svc().open()
            wait(0)
            resolveBatch(apps, 0, [makeItem("a", "Alpha", 0, 0),
                                   makeItem("b", "Beta", 0, 0)], false)
            svc().selectNext()
            compare(svc().selectedIndex, 1)

            // The user is on Beta when the next batch lands; the row must not
            // move out from under the highlight.
            resolveBatch(apps, 0, [makeItem("c", "Gamma", 0, 0)], true)
            compare(svc().selectedIndex, 1)
            compare(svc().results[1].id, "b")
        }

        function test_staleBatchFromASupersededRefreshIsDropped() {
            var apps = makeManualAdapter()
            var other = makeManualAdapter()
            svc()._adapters = { apps: apps }
            svc().open()
            wait(0)

            // A force pull supersedes the first refresh; the old stream's late
            // batch must not land on top of the new state.
            svc().refresh(true)
            wait(0)
            svc()._adapters = { apps: other }
            svc().refresh(true)
            wait(0)
            resolveBatch(other, 0, [makeItem("new", "New", 0, 0)], true)
            compare(svc().results.length, 1)
            compare(svc().results[0].id, "new")

            resolveBatch(apps, 0, [makeItem("stale", "Stale", 0, 0)], true)
            compare(svc().results.length, 1)
            compare(svc().results[0].id, "new")
            compare(svc().loadingMore, false)
        }

        function test_errorAfterTheFirstBatchEndsTheStream() {
            var apps = makeManualAdapter()
            svc()._adapters = { apps: apps }
            svc().open()
            wait(0)
            resolveBatch(apps, 0, [makeItem("a", "Alpha", 0, 0)], false)
            compare(svc().loadingMore, true)

            resolveBatch(apps, 0, { error: "boom" }, true)
            compare(svc().loadingMore, false)
            compare(svc().loading, false)
            compare(svc().error, "boom")
            // The rows that did arrive stay: the failure is about the tail.
            compare(svc().results.length, 1)
        }

        function test_closeClearsAnInFlightStream() {
            var apps = makeManualAdapter()
            svc()._adapters = { apps: apps }
            svc().open()
            wait(0)
            resolveBatch(apps, 0, [makeItem("a", "Alpha", 0, 0)], false)
            compare(svc().loadingMore, true)

            svc().close()
            compare(svc().loadingMore, false)
            // A batch that lands after the close must not resurrect the state.
            resolveBatch(apps, 0, [makeItem("b", "Beta", 0, 0)], true)
            compare(svc().results.length, 1)
        }

        function test_primeAppsWaitsForTheWholeStream() {
            // The idle pool builder has nothing to paint, so it must collect
            // every batch before swapping the pool in one go.
            var apps = makeManualAdapter()
            svc()._adapters = { apps: apps }
            svc().primeApps()
            resolveBatch(apps, 0, [makeItem("a", "Alpha", 0, 0)], false)
            compare(svc().displayPool.length, 0)
            resolveBatch(apps, 0, [makeItem("b", "Beta", 0, 0)], true)
            compare(svc().displayPool.length, 2)
            compare(svc().results.length, 2)
        }

        function test_primeAppsKeepsThePoolOnSourceError() {
            // A failed source must not be mistaken for "the app list is
            // empty": the kept pool survives an errored prime.
            var apps = makeManualAdapter()
            svc()._adapters = { apps: apps }
            svc().displayPool = [makeItem("a", "Alpha", 0, 0)]
            svc()._pooledMode = "apps"
            svc().primeApps()
            resolveRefresh(apps, 0, { error: "boom" })
            compare(svc().displayPool.length, 1)
        }

        // --- input priority ---

        function test_tailBatchWaitsForTheInputToSettle() {
            var apps = makeManualAdapter()
            svc()._adapters = { apps: apps }
            svc().open()
            wait(0)
            resolveBatch(apps, 0, [makeItem("a", "Alpha", 0, 0)], false)
            compare(svc().loadingMore, true)

            // The user starts arrowing through the list, and the tail lands
            // mid-input: it must not spend the frame the input needs.
            svc().selectNext()
            resolveBatch(apps, 0, [makeItem("b", "Beta", 0, 0)], false)
            compare(svc().results.length, 1)
            compare(svc().displayPool.length, 1)
            compare(svc().loadingMore, true)

            svc().drainHeldBatches()
            compare(svc().displayPool.length, 2)
            compare(svc().loadingMore, true)
        }

        function test_firstBatchLandsEvenMidInput() {
            // A mode switch asks for new content while the user is typing. That
            // first batch replaces the pool, so holding it would show an empty
            // list until the input window closed.
            var apps = makeManualAdapter()
            var clips = makeManualAdapter()
            svc()._adapters = { apps: apps, clipboard: clips }
            svc().open()
            wait(0)
            resolveBatch(apps, 0, [makeItem("a", "Alpha", 0, 0)], true)
            compare(svc().results.length, 1)

            svc().noteInput()
            svc().query = ">clip "
            wait(0)
            resolveBatch(clips, 0, [makeItem("c", "Copied", 0, 0)], true)
            compare(svc().results.length, 1)
            compare(svc().results[0].id, "c")
            compare(svc().displayPool.length, 1)
        }

        function test_aFreshRefreshDropsHeldBatches() {
            var apps = makeManualAdapter()
            svc()._adapters = { apps: apps }
            svc().open()
            wait(0)
            resolveBatch(apps, 0, [makeItem("a", "Alpha", 0, 0)], false)
            svc().selectNext()
            resolveBatch(apps, 0, [makeItem("stale", "Stale", 0, 0)], false)

            // A superseding refresh must not be handed the held batch later:
            // the pool stays on the rows the live refresh last committed, and
            // the held one never appears.
            svc().refresh(true)
            wait(0)
            svc().drainHeldBatches()
            compare(svc().displayPool.length, 1)
            compare(svc().displayPool[0].id, "a")
            compare(svc().loadingMore, false)
        }

        // --- category lens ---

        function test_categoryLensNarrowsResultsWithoutPullingAgain() {
            var apps = openWithCategories([makeCategorized("a", "Steam", "games", 3),
                                           makeCategorized("b", "Firefox", "network", 2)])
            compare(svc().results.length, 2)
            var pool = svc().displayPool

            svc().category = "games"

            // The lens rides the pooled fast path: same pool, same array
            // object, no adapter round trip.
            compare(apps.queries.length, 1)
            verify(svc().displayPool === pool)
            compare(svc().results.length, 1)
            compare(svc().results[0].id, "a")
            // A lens switch with no query starts the narrowed list at the top.
            compare(svc().selectedIndex, 0)
        }

        function test_categoryLensCombinesWithTheTextFilter() {
            openWithCategories([makeCategorized("a", "Steam", "games"),
                                makeCategorized("b", "Steam Deck", "network"),
                                makeCategorized("c", "Firefox", "network")])

            svc().query = "steam"
            compare(svc().results.length, 2)
            svc().category = "network"
            compare(svc().results.length, 1)
            compare(svc().results[0].id, "b")
        }

        function test_categoryLensReachesRowsWithoutACategory() {
            // An uncategorized row (a test fixture, a mode with no taxonomy)
            // must stay reachable unfiltered and drop out of every chip.
            openWithCategories([makeItem("a", "Alpha", 0, 0),
                                makeCategorized("b", "Beta", "games")])
            compare(svc().results.length, 2)
            svc().category = "games"
            compare(svc().results.length, 1)
            compare(svc().results[0].id, "b")
        }

        function test_modeSwitchRevertsTheLensWithoutAnExtraPull() {
            var apps = openWithCategories([makeCategorized("a", "Steam", "games")])
            svc().category = "games"
            compare(svc().category, "games")

            svc().query = ">clip "

            // Category ids are per-mode, so the lens rewinds to "All" - and
            // the mode's own refresh must not be duplicated by the reset.
            compare(svc().category, "")
            compare(apps.queries.length, 1)
        }

        function test_closeRevertsTheLensSoReopenStartsUnfiltered() {
            openWithCategories([makeCategorized("a", "Steam", "games")])
            svc().category = "games"
            svc().close()
            compare(svc().category, "")
        }
    }
}
