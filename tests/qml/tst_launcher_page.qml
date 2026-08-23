import QtQuick
import QtTest
import "../../modules/lazerbar" as Lazer

// Exercise the launcher page against a deterministic fixture session that
// mirrors the LauncherService observable contract: initial search focus,
// sidebar data and mode switching without a surface restart, selection,
// keyboard navigation and execution, pointer activation, and the explicit
// loading / empty / error / retry states.
Item {
    id: testRoot
    width: 800
    height: 600

    Lazer.LauncherPage {
        id: page
        anchors.fill: parent
    }

    SignalSpy { id: modeSpy; target: page; signalName: "modeChangeRequested" }

    TestCase {
        name: "LauncherPage"
        when: windowShown

        // --- fixture helpers ---

        function svc() { return page.session }

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

        function resetSession() {
            var s = svc()
            s._refreshToken++
            s.visible = false
            s.query = ""
            s.results = []
            s.loading = false
            s.error = ""
            s.selectedIndex = -1
            s._adapters = ({})
        }

        function openWithResults(items) {
            var apps = makeManualAdapter()
            svc()._adapters = ({ apps: apps })
            svc().open()
            resolveRefresh(apps, 0, items)
            return apps
        }

        function init() {
            Lazer.MotionTokens.reducedMotionOverride = false
            modeSpy.clear()
            resetSession()
            // Park focus away from the page so focus-on-open assertions start clean.
            testRoot.forceActiveFocus()
        }

        function cleanup() {
            Lazer.MotionTokens.reducedMotionOverride = false
        }

        // --- header and sidebar data provided to the wave shell ---

        function test_providesTitleDescriptionAndThreeSidebarEntries() {
            compare(page.title, "Launcher")
            verify(page.description.length > 0)

            compare(page.sidebarEntries.length, 3)
            compare(page.sidebarEntries[0].id, "apps")
            compare(page.sidebarEntries[0].label, "Apps")
            compare(page.sidebarEntries[1].id, "clipboard")
            compare(page.sidebarEntries[1].label, "Clipboard")
            compare(page.sidebarEntries[2].id, "shortcuts")
            compare(page.sidebarEntries[2].label, "Shortcuts")

            compare(page.activeMode, "apps")
        }

        // --- initial search focus ---

        function test_initialSearchFocusOnOpen() {
            verify(!page.searchField.activeFocus)

            openWithResults([makeItem("a", "Alpha", 0, 0)])

            tryVerify(function() { return page.searchField.activeFocus }, 300)
        }

        function test_typedCharactersReachTheSessionQuery() {
            openWithResults([])
            verify(page.searchField.activeFocus)

            keyClick(Qt.Key_F)
            keyClick(Qt.Key_I)
            keyClick(Qt.Key_R)

            tryCompare(svc(), "query", "fir")
            compare(svc().mode, "apps")
        }

        // --- escape contract ---

        function test_escapeWithInputClearsQueryAndKeepsSessionOpen() {
            var apps = openWithResults([makeItem("a", "Alpha", 0, 0)])
            verify(page.searchField.activeFocus)

            keyClick(Qt.Key_F)
            tryCompare(svc(), "query", "f")

            keyClick(Qt.Key_Escape)

            // Input was cleared and the session stays open and focused.
            compare(svc().visible, true)
            tryCompare(svc(), "query", "")
            compare(svc().error, "")
            resolveRefresh(apps, apps.pendingRefreshes.length - 1, [makeItem("a", "Alpha", 0, 0)])
            tryVerify(function() { return page.searchField.activeFocus }, 300)
            compare(page.loadingState.visible, false)

            keyClick(Qt.Key_B)
            tryCompare(svc(), "query", "b")
        }

        function test_escapeWithoutInputLeavesCloseOwnershipToTheHost() {
            openWithResults([makeItem("a", "Alpha", 0, 0)])
            compare(svc().query, "")
            verify(page.searchField.activeFocus)

            keyClick(Qt.Key_Escape)

            // With no input there is nothing to clear; the page must not
            // close or tear down its own session — the wave shell owns that.
            compare(svc().visible, true)
            compare(svc().results.length, 1)
            compare(page.title, "Launcher")
            tryVerify(function() { return page.searchField.activeFocus }, 300)

            // The page remains fully interactive afterwards.
            keyClick(Qt.Key_A)
            tryCompare(svc(), "query", "a")
        }

        // --- mode switching without surface restart ---

        function test_modeSwitchRewritesPrefixAndKeepsSearchFocus() {
            var apps = openWithResults([makeItem("a", "Alpha", 0, 0)])
            verify(page.searchField.activeFocus)

            page.handleModeSelected("clipboard")

            compare(svc().visible, true)
            compare(svc().query, ">clip ")
            compare(svc().mode, "clipboard")
            compare(svc().results.length, 0)
            verify(apps.pendingRefreshes.length > 0)
            compare(modeSpy.count, 1)
            compare(modeSpy.signalArguments[0][0], "clipboard")
            tryVerify(function() { return page.searchField.activeFocus }, 300)

            keyClick(Qt.Key_X)
            tryCompare(svc(), "query", ">clip x")
            compare(svc().mode, "clipboard")

            page.handleModeSelected("shortcuts")

            compare(svc().query, ">key x")
            compare(svc().mode, "shortcuts")
            compare(modeSpy.count, 2)

            page.handleModeSelected("apps")

            compare(svc().query, "x")
            compare(svc().mode, "apps")
            compare(modeSpy.count, 3)
            tryVerify(function() { return page.searchField.activeFocus }, 300)
        }

        // --- result presentation and selection ---

        function test_resultsRenderRowsAndFollowSelection() {
            openWithResults([
                makeItem("a", "Alpha", 0, 0),
                makeItem("b", "Beta", 0, 0),
                makeItem("c", "Gamma", 0, 0)
            ])

            compare(page.resultCount, 3)

            var firstRow = page.resultAt(0)
            verify(firstRow)
            compare(firstRow.selected, true)
            compare(firstRow.displayName, "Alpha")

            var secondRow = page.resultAt(1)
            compare(secondRow.selected, false)

            svc().selectNext()
            tryCompare(page.resultAt(1), "selected", true)
            tryCompare(page.resultAt(0), "selected", false)
        }

        // --- keyboard navigation and execution ---

        function test_upDownNavigationMovesSelection() {
            openWithResults([
                makeItem("a", "Alpha", 0, 0),
                makeItem("b", "Beta", 0, 0),
                makeItem("c", "Gamma", 0, 0)
            ])

            compare(svc().selectedIndex, 0)

            keyClick(Qt.Key_Down)
            compare(svc().selectedIndex, 1)

            keyClick(Qt.Key_Down)
            compare(svc().selectedIndex, 2)

            keyClick(Qt.Key_Down)
            compare(svc().selectedIndex, 2)

            keyClick(Qt.Key_Up)
            compare(svc().selectedIndex, 1)

            keyClick(Qt.Key_Up)
            keyClick(Qt.Key_Up)
            compare(svc().selectedIndex, 0)
        }

        function test_enterExecutesSelectedResult() {
            var apps = openWithResults([
                makeItem("firefox", "Firefox", 5, 10),
                makeItem("beta", "Beta", 0, 0)
            ])

            keyClick(Qt.Key_Down)
            compare(svc().selectedIndex, 1)

            keyClick(Qt.Key_Return)

            compare(apps.executions.length, 1)
            compare(apps.executions[0].id, "beta")

            resolveExecute(apps, 0, { ok: true })
            compare(svc().visible, false)
        }

        // --- pointer activation ---

        function test_pointerActivationExecutesClickedRow() {
            var apps = openWithResults([
                makeItem("a", "Alpha", 0, 0),
                makeItem("b", "Beta", 0, 0)
            ])
            compare(page.resultCount, 2)

            var row = page.resultAt(1)
            tryVerify(function() { return row.enabled && row.opacity === 1 }, 800)
            mouseClick(row, row.width / 2, row.height / 2)

            compare(apps.executions.length, 1)
            compare(apps.executions[0].id, "b")
        }

        // --- empty state ---

        function test_emptyStateShowsWithoutDroppingSearchFocus() {
            openWithResults([])

            compare(svc().loading, false)
            compare(svc().error, "")
            compare(page.emptyState.visible, true)
            compare(page.loadingState.visible, false)
            compare(page.errorState.visible, false)
            tryVerify(function() { return page.searchField.activeFocus }, 300)
        }

        // --- loading state ---

        function test_loadingStateShowsWhileRefreshing() {
            var apps = makeManualAdapter()
            svc()._adapters = ({ apps: apps })
            svc().open()

            compare(svc().loading, true)
            compare(page.loadingState.visible, true)
            compare(page.emptyState.visible, false)
            compare(page.errorState.visible, false)

            resolveRefresh(apps, 0, [makeItem("a", "Alpha", 0, 0)])

            compare(page.loadingState.visible, false)
            compare(page.emptyState.visible, false)
        }

        // --- error and retry state ---

        function test_errorStateOffersRetryThatReissuesRefresh() {
            var apps = makeManualAdapter()
            svc()._adapters = ({ apps: apps })
            svc().open()
            resolveRefresh(apps, 0, { error: "cache unavailable" })

            compare(svc().error, "cache unavailable")
            compare(page.errorState.visible, true)
            compare(page.emptyState.visible, false)
            compare(page.loadingState.visible, false)
            verify(page.retryButton.visible && page.retryButton.enabled)
            tryVerify(function() { return page.searchField.activeFocus }, 300)

            mouseClick(page.retryButton, page.retryButton.width / 2, page.retryButton.height / 2)

            compare(svc().loading, true)
            compare(page.loadingState.visible, true)
            compare(page.errorState.visible, false)
            tryCompare(apps.queries, "length", 2)
        }
    }
}
