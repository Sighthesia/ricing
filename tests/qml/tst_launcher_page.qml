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

    // Standalone result-row probe for thumbnail failure behavior.
    Component {
        id: rowProbe
        Lazer.LauncherResultRow {}
    }

    TestCase {
        name: "LauncherPage"
        when: windowShown

        // --- fixture helpers ---

        function svc() { return page.session }

        function makeItem(id, name, weight, usedAt) {
            return { id: id, displayName: name, favoriteWeight: weight, lastUsedAt: usedAt }
        }

        // A network service good enough for the control center's card to be `ready`.
        // Declared with ONLY the properties the overview reads, so a binding that
        // reaches for anything else resolves to undefined here exactly as it does
        // in production.
        QtObject {
            id: readyNetwork
            property bool wifiConnected: true
            property bool wifiEnabled: true
            property var networks: ({
                "Home": { ssid: "Home", security: "WPA2", signal: 78,
                    connected: true, existing: true }
            })
            property bool ethernetConnected: false
            property string activeEthernetConnection: ""
            property bool scanningActive: false
            property bool connecting: false
            property string connectingTo: ""
            property string lastError: ""

            function setWifiEnabled(value) { wifiEnabled = value }
            function refreshForOpen() {}
            function requestScan(rescan, clearError) {}
            function connect(ssid, password, isHidden, securityKey) {}
            function disconnect(ssid) {}
            function needsPasswordFor(ssid) { return false }
            function isCredentialFailure(message) { return false }
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

        function resolveRefresh(adapter, index, outcome, complete) {
            adapter.pendingRefreshes[index](outcome,
                    complete === undefined ? true : complete)
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
            s._pooledMode = ""
            s.displayPool = []
            s._adapters = ({})
            // A lens left behind by a previous test would silently filter
            // this one's results.
            s.category = ""
            s.loadingMore = false
        }

        function openWithResults(items) {
            var apps = makeManualAdapter()
            svc()._adapters = ({ apps: apps })
            svc().open()
            wait(0)
            resolveRefresh(apps, 0, items, true)
            return apps
        }

        function init() {
            Lazer.MotionTokens.reducedMotionOverride = false
            modeSpy.clear()
            // Both halves of the view flag are page state, not fixture state, and a
            // retained view from the previous test would make the cold-path
            // assertion below read as a build the test did not ask for.
            page.controlCenterActive = false
            page.controlCenterBuilt = false
            page.networkService = null
            resetSession()
            // Park focus away from the page so focus-on-open assertions start clean.
            testRoot.forceActiveFocus()
        }

        function cleanup() {
            Lazer.MotionTokens.reducedMotionOverride = false
        }

        // --- header and sidebar data provided to the wave shell ---

        function test_providesTitleDescriptionAndFourPeerEntriesInOrder() {
            compare(page.title, "Launcher")
            verify(page.description.length > 0)

            // Four peers in ONE list. The control center is asserted here rather
            // than in a separate test because the whole point of the fold-in is
            // that it is not a different kind of entry: a rail that showed a
            // `section` marker on the fourth would lay out identically and still
            // be re-partitioned on the next change.
            compare(page.sidebarEntries.length, 4)
            compare(page.sidebarEntries[0].id, "apps")
            compare(page.sidebarEntries[0].label, "Apps")
            compare(page.sidebarEntries[1].id, "clipboard")
            compare(page.sidebarEntries[1].label, "Clipboard")
            compare(page.sidebarEntries[2].id, "shortcuts")
            compare(page.sidebarEntries[2].label, "Shortcuts")
            compare(page.sidebarEntries[3].id, "control-center")
            compare(page.sidebarEntries[3].label, "Control Center")
            compare(page.sidebarEntries[3].section, undefined,
                "no entry may carry a section marker")
            compare(page.controlCenterEntryId, "control-center")

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

        // --- the control-center view inside this page ---

        // The fourth rail entry is a VIEW, and the load-bearing consequence is
        // that it is not answerable as a query mode. If it were, handleModeSelected
        // would build a prefix for a data source that does not exist, rewrite the
        // user's query with it and report a mode change - which is precisely the
        // state this switch has to leave untouched.
        function test_theControlCenterViewIsNotAQueryMode() {
            openWithResults([makeItem("a", "Alpha", 0, 0)])

            verify(!page.isKnownMode(page.controlCenterEntryId),
                   "the control center names a view, not a data source")
            compare(page.isKnownMode("apps"), true)
            compare(page.isKnownMode("clipboard"), true)
            compare(page.isKnownMode("shortcuts"), true)
            compare(page.isKnownMode("not-an-entry"), false)
        }

        // Opening the view must not touch the session at all. Every one of these
        // is a piece of state the user would have to retype: the query text, the
        // mode, the category lens and the result window. Asserted individually
        // because a regression here is invisible - the list still looks right, it
        // is just filtered by something the user never asked for.
        function test_openingTheViewChangesNothingTheUserTyped() {
            openWithResults([makeItem("a", "Alpha", 0, 0), makeItem("b", "Beta", 0, 0)])
            svc().category = ""
            keyClick(Qt.Key_B)
            tryCompare(svc(), "query", "b")
            var windowBefore = page._resultWindowExtra

            page.handleSidebarSelected(page.controlCenterEntryId)

            verify(page.controlCenterActive, "the view must be up")
            compare(svc().query, "b", "the typed query must survive the switch")
            compare(svc().mode, "apps", "the mode must not be rewritten")
            compare(svc().category, "", "the category lens must survive the switch")
            compare(modeSpy.count, 0, "a view switch is not a mode change")
            compare(page._resultWindowExtra, windowBefore,
                "the materialized result window must not be torn down")
            compare(page.resultCount, 2, "the rows must still be materialized")
        }

        // The view is a cold path and then a retained one, in that order. A
        // control center is four cards, a calendar and a summary; building it on
        // every open is what the old route swap avoided by retaining its Loader.
        function test_theViewIsBuiltOnFirstUseAndThenRetained() {
            openWithResults([makeItem("a", "Alpha", 0, 0)])
            compare(page.controlCenterBuilt, false,
                "a control center nobody opened must not be constructed")
            verify(page.controlCenterItem === null)

            page.handleSidebarSelected(page.controlCenterEntryId)
            tryVerify(function() { return page.controlCenterItem !== null }, 2000)
            tryVerify(function() { return page.controlCenterVisible }, 500)
            var built = page.controlCenterItem
            tryVerify(function() { return built.controlCardCount === 4 }, 2000)

            page.handleEscape()
            verify(!page.controlCenterActive)
            verify(page.controlCenterBuilt, "the view stays built across a switch back")

            page.handleSidebarSelected(page.controlCenterEntryId)
            tryVerify(function() { return page.controlCenterItem === built }, 1000,
                "returning must restore the same instance, not rebuild it")
        }

        // The rail's own selection semantics: the accent strip follows the view.
        // Asserted through the published id because that is what the host binds
        // the rail's `selected` to - a flag that flipped but was never published
        // would leave the strip on "apps" over a wall of toggles.
        function test_theRailHighlightsTheViewWhileItIsUp() {
            openWithResults([makeItem("a", "Alpha", 0, 0)])
            compare(page.activeSidebarId, "apps")

            page.handleSidebarSelected(page.controlCenterEntryId)
            tryCompare(page, "activeSidebarId", page.controlCenterEntryId, 500)

            page.handleEscape()
            tryCompare(page, "activeSidebarId", "apps", 500)
        }

        // The header follows the view too, for the same reason: announcing
        // "Search applications" over the control center is a claim about an input
        // that is not there.
        function test_theHeaderFollowsTheView() {
            openWithResults([makeItem("a", "Alpha", 0, 0)])
            compare(page.title, "Launcher")
            verify(page.description.indexOf("Search") === 0)

            page.handleSidebarSelected(page.controlCenterEntryId)
            tryCompare(page, "title", "Control Center", 500)
            verify(page.description.indexOf("Search") !== 0,
                "the control center has nothing to search, so the header must not say so")

            page.handleEscape()
            tryCompare(page, "title", "Launcher", 500)
        }

        // The launcher's chrome leaves the content area for the view and comes
        // back EXACTLY as it was. Hidden, never collapsed: a height animation or
        // a collapsed rail would move the list under the viewport, and the user's
        // selection would then point at a different row on the way back.
        function test_theChromeIsHiddenForTheViewAndRestoredIntact() {
            openWithResults([
                makeItem("a", "Alpha", 0, 0),
                makeItem("b", "Beta", 0, 0),
                makeItem("c", "Gamma", 0, 0)
            ])
            compare(page.resultCount, 3)
            var editorBefore = page.searchField.editorItem
            var rowsBefore = []
            for (var r = 0; r < page.resultCount; r++)
                rowsBefore.push(page.resultsView.resultAt(r))
            var listYBefore = page.resultsView.y
            var listHeightBefore = page.resultsView.height

            page.handleSidebarSelected(page.controlCenterEntryId)
            tryVerify(function() { return page.controlCenterVisible }, 500)

            verify(!page.chromeVisible, "the launcher chrome must leave for the view")
            verify(!page.searchField.visible, "the search rail must be hidden")
            verify(!page.resultsView.visible, "the result list must be hidden")

            page.handleEscape()
            tryVerify(function() { return page.chromeVisible }, 500)
            verify(page.searchField.visible)
            verify(page.resultsView.visible)
            compare(page.searchField.editorItem, editorBefore,
                "the editor must be the same instance, with its text and caret")
            compare(page.resultsView.y, listYBefore, "the list must not shift")
            compare(page.resultsView.height, listHeightBefore)
            for (var i = 0; i < rowsBefore.length; i++)
                compare(page.resultsView.resultAt(i), rowsBefore[i],
                    "row " + i + " must be the same delegate after the round trip")
        }

        // A typed query survives the round trip by VALUE, which is what the user
        // notices: they come back to the text they left, not to an empty box.
        function test_theTypedQueryIsStillThereOnReturn() {
            openWithResults([makeItem("a", "Alpha", 0, 0), makeItem("b", "Beta", 0, 0)])
            keyClick(Qt.Key_B)
            tryCompare(svc(), "query", "b")
            tryCompare(page.searchField.editorItem, "text", "b", 500)

            page.handleSidebarSelected(page.controlCenterEntryId)
            tryVerify(function() { return page.controlCenterVisible }, 500)
            // The editor is hidden, so the text lives in the editor AND the
            // session. Both are asserted: a switch that only preserved the
            // session would show an empty box when the view closed.
            compare(page.searchField.editorItem.text, "b",
                "the hidden editor keeps its text")

            page.handleEscape()
            tryVerify(function() { return page.chromeVisible }, 500)
            compare(svc().query, "b")
            compare(page.searchField.editorItem.text, "b")
        }

        // Focus must land somewhere real on both edges of the switch. Opening: the
        // view's own landing, because the editor is invisible and Qt refuses
        // focus on an invisible item - focusing it anyway would leave the whole
        // surface with no keyboard owner. Returning: the editor, one turn later,
        // after it is visible again.
        function test_focusLandsOnEachSideOfTheSwitch() {
            openWithResults([makeItem("a", "Alpha", 0, 0)])
            tryVerify(function() { return page.searchField.activeFocus }, 300)

            page.handleSidebarSelected(page.controlCenterEntryId)
            tryVerify(function() { return page.controlCenterItem !== null }, 2000)
            tryVerify(function() { return page.controlCenterItem.activeFocus === true }, 1000,
                "the view must own the keyboard while it is up")
            verify(!page.searchField.activeFocus,
                "the hidden editor must not hold focus")

            page.handleEscape()
            tryVerify(function() { return page.searchField.activeFocus }, 1000,
                "the editor must reclaim the keyboard when the view closes")
        }

        // Choosing a mode filter from the rail while the view is up must leave the
        // view as well. If it did not, the query would be rewritten behind a
        // hidden editor and the user would come back to a filtered list with no
        // visible sign of why.
        function test_choosingAModeFilterReplacesTheView() {
            openWithResults([makeItem("a", "Alpha", 0, 0)])
            page.handleSidebarSelected(page.controlCenterEntryId)
            tryVerify(function() { return page.controlCenterVisible }, 500)

            page.handleSidebarSelected("clipboard")

            verify(!page.controlCenterActive, "a mode filter must replace the view")
            compare(svc().query, ">clip ")
            compare(svc().mode, "clipboard")
            tryVerify(function() { return page.searchField.activeFocus }, 500,
                "the editor must be focused and visible again")
            compare(page.activeSidebarId, "clipboard")
        }

        // --- back precedence, and the page's half of the host's contract ---

        // Four steps, in order, and each one is a different owner. Asserted as a
        // sequence rather than four separate tests because the ORDER is the whole
        // contract: a detail page that could not be reached, or a query that
        // cleared before the view closed, would each be a plausible-looking
        // green suite.
        function test_backGoesDetailThenViewThenQuery() {
            // A ready network service, so the overview's network card is `ready`
            // and its detail request passes the module's gate. With no service the
            // card is `unavailable`, its action is `none`, and openNetworkDetails()
            // correctly does nothing - which would make every step below pass for
            // the wrong reason.
            page.networkService = readyNetwork
            openWithResults([makeItem("a", "Alpha", 0, 0)])
            keyClick(Qt.Key_B)
            tryCompare(svc(), "query", "b")

            page.handleSidebarSelected(page.controlCenterEntryId)
            tryVerify(function() { return page.controlCenterItem !== null }, 2000)
            var view = page.controlCenterItem
            compare(view.controlCardCount, 4)

            tryVerify(function() { return view.networkCardData.action === "detail" }, 1000,
                "the fixture must present a card that can request its detail page")

            // The view must offer back to the host: this page is the authority,
            // and `canGoBack: true` with no callable handler would take every
            // press and do nothing with it.
            verify(page.canGoBack, "the view must be offered back while it is up")
            verify(typeof page.handleBack === "function")

            // Step 1: a detail sub-page consumes the press, and the view stays up.
            view.openNetworkDetails()
            tryVerify(function() { return view.activeSubPage !== "" }, 1000)
            verify(page.handleBack(), "the detail page must consume the press")
            tryVerify(function() { return view.activeSubPage === "" }, 1000)
            verify(page.controlCenterActive,
                "popping a detail page must not close the view")
            compare(svc().query, "b", "and it must not touch the query")

            // Step 2: the view itself, and the query is still untouched.
            verify(page.handleBack(), "the view must consume the next press")
            verify(!page.controlCenterActive)
            compare(svc().query, "b", "leaving the view must not clear the query")

            // Step 3: typed text clears, back to the bare prefix for the mode.
            verify(page.handleBack(), "the typed query must consume the next press")
            compare(svc().query, "")

            // Step 4: nothing left, so the press is declined and the host closes.
            compare(page.canGoBack, false, "an idle launcher view offers no back")
            compare(page.handleBack(), false,
                "declining is what lets the host close the surface")
        }

        // One openControlCenter on an already-open view is a no-op, not a second
        // focus hand-off: re-running it would steal the focus the view's own
        // controls had.
        // A mode filter chosen from the rail replaces the view, and a view closed while
// holding a DETAIL sub-page must take that sub-page with it.
//
// The second half is the retention bug this guards, and it is only reachable by
// closing the view with something mounted - the Escape path pops the sub-page
// first, so a plain Escape walk would pass with the dismissal removed. Measured,
// not assumed: focus followed straight into the retained detail page on the next
// open, and the user would have had no way back to the overview.
function test_leavingTheViewTakesItsDetailSubPageWithIt() {
    page.networkService = readyNetwork
    openWithResults([makeItem("a", "Alpha", 0, 0)])
    page.handleSidebarSelected(page.controlCenterEntryId)
    tryVerify(function() { return page.controlCenterVisible }, 2000)
    var view = page.controlCenterItem

    view.openNetworkDetails()
    tryVerify(function() { return view.activeSubPage !== "" }, 1000)

    // Leave through the rail, the way a mode filter does.
    page.handleSidebarSelected("clipboard")

    verify(!page.controlCenterActive)
    verify(view.activeSubPage === "",
        "the retained view must be back on its overview, not holding a stale sub-page")
    // The view itself is still the retained instance - dismissing the sub-page is
    // not rebuilding anything.
    compare(page.controlCenterItem, view)
    compare(page.controlCenterBuilt, true)
}

function test_openingTheViewTwiceChangesNothing() {
            openWithResults([makeItem("a", "Alpha", 0, 0)])
            page.handleSidebarSelected(page.controlCenterEntryId)
            tryVerify(function() { return page.controlCenterItem !== null }, 2000)
            var built = page.controlCenterItem

            compare(page.openControlCenter(), false,
                "opening an open view must report that it changed nothing")
            compare(page.controlCenterItem, built)
        }

        function test_closingAViewThatIsNotUpChangesNothing() {
            openWithResults([makeItem("a", "Alpha", 0, 0)])
            keyClick(Qt.Key_B)
            tryCompare(svc(), "query", "b")

            compare(page.closeControlCenter(), false)
            compare(svc().query, "b")
            compare(modeSpy.count, 0)
        }

        // --- the rail's other three entries, unchanged ---

        // The other three ids keep working through the same entry point - one
        // dispatch, four peer ids.
        function test_theModeFiltersStillAnswerThroughTheRailEntryPoint() {
            openWithResults([makeItem("a", "Alpha", 0, 0)])

            page.handleSidebarSelected("clipboard")

            compare(svc().query, ">clip ")
            compare(svc().mode, "clipboard")
            compare(modeSpy.count, 1)
            compare(modeSpy.signalArguments[0][0], "clipboard")
            verify(!page.controlCenterActive, "a mode filter must not open the view")
        }

        // An unknown id stays inert rather than falling into a mode rewrite. The
        // closing call is in the path on purpose: an unknown id is not a request
        // to leave the view either.
        function test_anUnknownRailIdChangesNothing() {
            openWithResults([makeItem("a", "Alpha", 0, 0)])

            page.handleSidebarSelected("not-a-mode")

            compare(modeSpy.count, 0)
            compare(page.controlCenterActive, false)
            compare(svc().query, "")
        }

        // Input isolation, the other half of the view switch. The editor is
        // hidden while the view is up, so an arrow key that still moved the
        // launcher's selection would move something the user cannot see - and
        // would do it invisibly when they came back.
        function test_arrowsAndReturnCannotActOnTheListBehindTheView() {
            openWithResults([
                makeItem("a", "Alpha", 0, 0),
                makeItem("b", "Beta", 0, 0),
                makeItem("c", "Gamma", 0, 0)
            ])
            page.handleSidebarSelected(page.controlCenterEntryId)
            tryVerify(function() { return page.controlCenterVisible }, 500)
            var indexBefore = svc().selectedIndex

            keyClick(Qt.Key_Down)
            keyClick(Qt.Key_Down)
            compare(svc().selectedIndex, indexBefore,
                "an arrow key must not move a selection behind the view")

            keyClick(Qt.Key_Return)
            compare(svc().selectedIndex, indexBefore,
                "Return must not execute a row the user cannot see")
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

        function test_arrowNavigationReclaimsPreviewFromHover() {
            openWithResults([
                makeItem("a", "Alpha", 0, 0),
                makeItem("b", "Beta", 0, 0),
                makeItem("c", "Gamma", 0, 0)
            ])

            // A resting mouse keeps its row previewed ahead of the keyboard.
            var hovered = svc().results[2]
            page.trackHover(hovered, true)
            compare(page._hoveredResult, hovered)

            // Arrow navigation hands the preview back to the focused row.
            verify(page.navigateSelection(1))
            verify(page._hoveredResult === null)
            compare(svc().selectedIndex, 1)

            verify(page.navigateSelection(-1))
            verify(page._hoveredResult === null)
            compare(svc().selectedIndex, 0)
        }

        function test_hiddenSessionClearsHoverPreview() {
            openWithResults([
                makeItem("a", "Alpha", 0, 0),
                makeItem("b", "Beta", 0, 0)
            ])

            page.trackHover(svc().results[1], true)
            verify(page._hoveredResult !== null)

            svc().close()
            verify(page._hoveredResult === null)
        }

        function test_reopenWithKeptRowsSkipsEntranceWave() {
            openWithResults([
                makeItem("a", "Alpha", 0, 0),
                makeItem("b", "Beta", 0, 0),
                makeItem("c", "Gamma", 0, 0)
            ])
            wait(0)

            // Arm the flag to prove the open flip clears it (not leftover state).
            page._firstFillPending = true
            svc().close()
            svc().open()
            verify(page._firstFillPending === false)
        }

        function test_launchedRowCanBeSearchedAndExecutedAfterReopen() {
            var apps = openWithResults([
                makeItem("a", "Alpha", 0, 0),
                makeItem("b", "Beta", 0, 0)
            ])
            wait(0)
            page._releaseAllRowsInstantly()
            svc().query = "Alpha"
            wait(0)
            page.executeSelected()
            compare(apps.executions.length, 1)
            verify(page.resultAt(0).closing)
            resolveExecute(apps, 0, { ok: true })
            compare(svc().visible, false)
            wait(700)

            svc().open()
            wait(0)
            svc().query = "Alpha"
            wait(700)
            compare(svc().results.length, 1)
            compare(page.emptyState.visible, false)
            var row = page.resultAt(0)
            compare(row.result.id, "a")
            verify(row.visible, "Launched row must become visible on reopen")
            verify(row.enabled)
            verify(!row.closing)
            page.executeSelected()
            compare(apps.executions.length, 2)
            compare(apps.executions[1].id, "a")
            // Resolve the second execution so no in-flight launch leaks
            // into the next test's session state.
            resolveExecute(apps, 1, { ok: true })
            compare(svc().visible, false)
        }

        function test_firstOpenWithoutRowsKeepsEntranceWave() {
            // init() reset the session to empty results; let the repeater
            // settle before opening onto the empty list.
            wait(0)
            svc().open()
            wait(0)
            verify(page._firstFillPending === true)
        }

        function test_closeResetsResultWindowStretch() {
            var items = []
            for (var i = 0; i < 150; i++)
                items.push(makeItem("id" + i, "Item" + String(i).padStart(3, "0"), 0, i))
            openWithResults(items)

            // A query matching only the deepest row stretches the window
            // past the base slice so the match materializes. The stretch
            // is deferred past the fold, so wait for it instead of
            // asserting it synchronously.
            compare(page._resultWindowExtra, 0)
            svc().query = "item000"
            tryVerify(function() { return page._resultWindowExtra > 0 }, 2000)

            // Hiding drops the stretch: the next open starts from the base
            // slice instead of rebuilding hundreds of rows on every swap.
            svc().close()
            compare(page._resultWindowExtra, 0)

            svc().open()
            wait(0)
            compare(page._resultWindowExtra, 0)
            compare(svc().results.length, 150)
        }

        function test_enterExecutesSelectedResult() {
            var apps = openWithResults([
                makeItem("firefox", "Firefox", 5, 10),
                makeItem("beta", "Beta", 0, 0)
            ])

            keyClick(Qt.Key_Down)
            compare(svc().selectedIndex, 1)

            keyClick(Qt.Key_Return)

            // Execution fires after the card's fling exit completes.
            tryCompare(apps.executions, "length", 1, 1500)
            compare(apps.executions[0].id, "beta")

            resolveExecute(apps, 0, { ok: true })
            compare(svc().visible, false)
        }

        // --- category chip rail ---

        function openCategorized(items) {
            var apps = makeManualAdapter()
            svc()._adapters = ({ apps: apps })
            svc().open()
            wait(0)
            apps.pendingRefreshes[0](items)
            wait(30)
            return apps
        }

        function chipById(id) {
            var chips = page.categoryChips
            for (var i = 0; i < chips.length; i++)
                if (chips[i].id === id)
                    return chips[i]
            return null
        }

        function test_categoryChipsCarryLiveCountsForTheActiveMode() {
            openCategorized([makeCategorized("a", "Steam", "games", 3),
                             makeCategorized("b", "Firefox", "network", 2)])

            var chips = page.categoryChips
            compare(chips.length, 10)
            compare(chips[0].id, "")
            compare(chips[0].label, "All")
            compare(chips[0].count, 2)
            compare(chipById("games").count, 1)
            compare(chipById("network").count, 1)
            // An empty category keeps its slot so typing never reflows the bar.
            compare(chipById("office").count, 0)

            // Typing narrows the counts without dropping any chip.
            keyClick(Qt.Key_F)
            tryCompare(svc(), "query", "f")
            compare(chipById("network").count, 1)
            compare(chipById("games").count, 0)
            compare(page.categoryChips.length, 10)
        }

        function test_categoryChipActivationNarrowsRowsAndKeepsSearchFocused() {
            openCategorized([makeCategorized("a", "Steam", "games", 3),
                             makeCategorized("b", "Firefox", "network", 2)])

            var gamesIndex = -1
            for (var i = 0; i < page.categoryChips.length; i++)
                if (page.categoryChips[i].id === "games")
                    gamesIndex = i
            verify(gamesIndex > 0)

            var chip = page.categoryBarItem.chipAt(gamesIndex)
            verify(chip !== null)
            tryVerify(function() { return chip.width > 0 }, 800)
            mouseClick(chip, chip.width / 2, chip.height / 2)

            tryCompare(svc(), "category", "games")
            compare(svc().results.length, 1)
            compare(svc().results[0].id, "a")
            // Activating a chip hands the keyboard back so typing continues.
            tryVerify(function() { return page.searchField.activeFocus }, 300)

            // The row outside the lens folds through the shared contract
            // instead of vanishing from the model.
            var other = page.resultAt(1)
            tryCompare(other, "height", 0, 1000)
            compare(page.resultCount, 2)
        }

        function test_allChipClearsTheLens() {
            openCategorized([makeCategorized("a", "Steam", "games", 3),
                             makeCategorized("b", "Firefox", "network", 2)])
            page.setCategory("games")
            compare(svc().results.length, 1)

            var all = page.categoryBarItem.chipAt(0)
            verify(all !== null)
            tryVerify(function() { return all.width > 0 }, 800)
            mouseClick(all, all.width / 2, all.height / 2)

            tryCompare(svc(), "category", "")
            compare(svc().results.length, 2)
        }

        function test_emptyLensAndModeSwitchResetTheChipSelection() {
            openCategorized([makeCategorized("a", "Steam", "games", 3)])
            page.setCategory("games")
            compare(svc().category, "games")
            // A lens with no match is a different message from no query.
            page.setCategory("office")
            compare(svc().results.length, 0)
            verify(page.emptyState.visible)

            // Category ids are per-mode: switching routes rewinds to "All"
            // and the rail swaps to the new mode's taxonomy.
            page.handleModeSelected("clipboard")
            tryCompare(svc(), "category", "")
            compare(page.categoryChips.length, 7)
            compare(page.categoryChips[1].id, "text")
        }

        // --- the list must never stop accepting the wheel ---

function test_streamedFirstFillLeavesTheViewportScrollable() {
    // A refresh that streams its rows in batches is the production shape, and
        // its first batch is what ends the loading state. If that first commit
        // does not release the delegates it built, every row stays held and the
        // viewport stays non-interactive: the list then refuses the wheel for
        // the rest of the session.
        var items = []
        for (var i = 0; i < 140; i++)
            items.push(makeItem("item" + i, "Item " + i, 0, 140 - i))
        var apps = makeManualAdapter()
        svc()._adapters = ({ apps: apps })
        svc().open()
        wait(0)

        // 48-row batches, the size the apps adapter streams, resolved one turn
        // apart exactly like the production frame stepper.
        var batches = []
        for (var b = 0; b < items.length; b += 48)
            batches.push(items.slice(b, b + 48))
        apps.pendingRefreshes[0](batches[0], false)
        for (var n = 1; n < batches.length; n++) {
            wait(0)
            apps.pendingRefreshes[0](batches[n], n === batches.length - 1)
        }

        tryVerify(function() { return page.session.loadingMore === false }, 3000)
        verify(page.resultCount > 48)
        // Nothing is left travelling in once the stream ends...
        tryVerify(function() { return !page.rowsAnimatingIn }, 3000)
        // ...and the selection-driven scroll has landed before the wheel does:
        // it animates for 300ms and would otherwise be read as a dead wheel.
        wait(500)
        // ...and the wheel works on this very first open.
        verify(page.resultsView.interactive)
        var view = page.resultsView
        tryVerify(function() { return view.contentHeight > view.height }, 2000)
        // Wheel from mid-list: the first and last 80px are the edge-takeover
        // bands, where a notch is spent on the rubber band, not on travel.
        view.contentY = Math.max(0, (view.contentHeight - view.height) / 2)
        wait(30)
        var before = view.contentY
        verify(before > 100, "must be parked mid-list, was " + before)
        mouseWheel(view, view.width / 2, view.height / 2, 0, -120, 0, 0)
        tryVerify(function() { return view.contentY > before }, 1000)
    }

    function test_theRowWindowIsMaterializedOnceAndBatchesFillItsSlots() {
        // A Repeater rebuilds every delegate when its count changes, so sizing
        // the row window to the results that happen to exist rebuilt all of
        // them on every commit - measured at 15ms and 20ms for the two growths
        // a 96-row window goes through while a clipboard open fills in, both
        // of them right after the open and both visible as the list twitching.
        // The window is materialized once, and batches fill its slots.
        var first = []
        for (var i = 0; i < 24; i++)
            first.push(makeItem("item" + i, "Item " + i, 0, 200 - i))
        // Open with an unfinished stream, the way a real open arrives.
        var apps = makeManualAdapter()
        svc()._adapters = ({ apps: apps })
        svc().open()
        wait(0)
        resolveRefresh(apps, 0, first, false)
        tryVerify(function() { return page.resultCount === 24 }, 2000)
        var slots = page.resultsView.slotCount
        compare(slots, page.rowSlotCount,
                "the window is materialized at its limit, not at what has arrived")
        verify(slots > page.resultCount, "an unfinished window has slots waiting")

        var survivor = page.resultAt(0)
        tryVerify(function() {
            return survivor && survivor.enabled && survivor.revealHeld === false
        }, 3000)

        // A second batch brings more results. Same window, so the rows already
        // there must be the same delegate objects - not rebuilt ones.
        var more = []
        for (var m = 24; m < 60; m++)
            more.push(makeItem("item" + m, "Item " + m, 0, 200 - m))
        // Through the same callback, the way a stream delivers: one refresh,
        // many batches.
        apps.pendingRefreshes[0](more, false)
        tryVerify(function() { return page.resultCount === 60 }, 2000)
        compare(page.resultsView.slotCount, slots, "a batch must not resize the window")
        verify(page.resultAt(0) === survivor,
               "a batch must not rebuild the rows that were already there")
        // And the slots it filled become real, interactive rows.
        tryVerify(function() {
            var last = page.resultAt(59)
            return last !== null && last.enabled === true && last.height > 0
        }, 3000)
    }

    function test_prewarmSlotsReserveTheFixedWindowBeforeResultsArrive() {
        page.prewarmSlots = true
        compare(page.resultCount, 0)
        compare(page.rowSlotCount, page._resultWindowLimit)
        tryVerify(function() { return page.resultsView.slotCount === page.rowSlotCount }, 2000)
        page.prewarmSlots = false
        tryVerify(function() { return page.rowSlotCount === 0 }, 2000)
    }

    function test_windowGrowthReleasesItsNewRowsAndKeepsScrolling() {
        // Growing the materialized window builds fresh delegates. Nothing
        // releases them but the commit that growth schedules, and a held row is
        // what disables the viewport - so scrolling deep must not be what kills
        // scrolling.
        var items = []
        for (var i = 0; i < 200; i++)
            items.push(makeItem("item" + i, "Item " + i, 0, 200 - i))
        openWithResults(items)
        tryVerify(function() { return page.resultCount === 96 }, 2000)
        tryVerify(function() { return !page.rowsAnimatingIn }, 3000)

        var view = page.resultsView
        // Wait for the window to be laid out before parking: a list whose rows
        // are still unfolding has no end to park at, and "near the end" is
        // trivially true of a list with no height yet.
        tryVerify(function() { return view.contentHeight > view.height + 900 }, 3000)
        // Parking at the end is what triggers the growth in production.
        view.contentY = Math.max(0, view.contentHeight - view.height)
        tryVerify(function() { return page.resultCount > 96 }, 2000)
        tryVerify(function() { return !page.rowsAnimatingIn }, 3000)
        verify(page.resultsView.interactive)

        view.contentY = Math.max(0, (view.contentHeight - view.height) / 2)
        wait(30)
        var before = view.contentY
        verify(before > 100, "must be parked mid-list, was " + before)
        mouseWheel(view, view.width / 2, view.height / 2, 0, -120, 0, 0)
        tryVerify(function() { return view.contentY > before }, 1000)
    }

    function test_reopenKeepsScrollingAfterAnIdenticalCommit() {
        // Reopening onto a settled pool re-commits the same ids. That commit
        // must leave the rows alone - and must not leave them held either.
        var items = []
        for (var i = 0; i < 40; i++)
            items.push(makeItem("item" + i, "Item " + i, 0, 40 - i))
        openWithResults(items)
        tryVerify(function() { return !page.rowsAnimatingIn }, 3000)
        wait(500)
        svc().close()
        wait(60)
        svc().open()
        wait(500)
        tryVerify(function() { return !page.rowsAnimatingIn }, 3000)
        verify(page.resultsView.interactive)
        var view = page.resultsView
        view.contentY = Math.max(0, (view.contentHeight - view.height) / 2)
        wait(30)
        var before = view.contentY
        verify(before > 100, "must be parked mid-list, was " + before)
        mouseWheel(view, view.width / 2, view.height / 2, 0, -120, 0, 0)
        tryVerify(function() { return view.contentY > before }, 1000)
    }

    function test_aCommitThatOutrunsItsRowsDoesNotStrandThem() {
        // Regression. The commit bookkeeping must never advance past the rows it
        // can actually see. A commit that runs before the Repeater has built
        // the window used to write those ids anyway, so the next real commit
        // read as "unchanged", skipped the release, and left every freshly
        // built delegate held - which is what silently killed the wheel.
        var items = []
        for (var i = 0; i < 200; i++)
            items.push(makeItem("item" + i, "Item " + i, 0, 200 - i))
        openWithResults(items)
        tryVerify(function() { return page.resultCount === 96 }, 2000)
        tryVerify(function() { return !page.rowsAnimatingIn }, 3000)

        // Grow the window and commit in the same turn, before the Repeater can
        // build the new rows.
        page._resultWindowExtra = 120
        page._holdAndScheduleReleases()

        tryVerify(function() { return page.resultCount === 200 }, 2000)
        // The delegates the growth built must be released, not stranded.
        tryVerify(function() { return !page.rowsAnimatingIn }, 3000)
        verify(page.resultsView.interactive)
    }

    function test_shiftedIdsKeepSettledSurvivorsUnheld() {
        var initial = []
        for (var i = 0; i < 96; i++)
            initial.push(makeItem("clip" + i, "Clip " + i, 0, 1000 - i))
        openWithResults(initial)
        tryVerify(function() { return !page.rowsAnimatingIn }, 3000)

        var shifted = [makeItem("new", "New copy", 0, 2000)]
        for (var j = 0; j < 95; j++)
            shifted.push(makeItem("clip" + j, "Clip " + j, 0, 1000 - j))
        page.session.results = shifted
        page.session.displayPool = shifted
        page._scheduleRowsCommit()
        wait(100)

        var held = 0
        for (var k = 0; k < page.resultCount; k++) {
            var row = page.resultAt(k)
            if (row && row.revealHeld)
                held++
        }
        verify(held <= 1, "shifted survivors triggered a full-window hold: " + held)
        verify(page.resultsView.interactive)
    }

    // --- progressive loading ---

        function test_settledListShowsNoFooter() {
            openWithResults([makeItem("a", "Alpha", 0, 0)])
            verify(!page.listFooterItem.visible)
            compare(page.listFooterItem.height, 0)
        }

        function test_footerMarksTheNotYetArrivedTail() {
            openWithResults([makeItem("a", "Alpha", 0, 0)])

            // First batch landed: the rows own the surface and the spinner
            // moves to the tail, so nothing above the list shifts.
            svc().loadingMore = true
            tryVerify(function() { return page.listFooterItem.visible }, 300)
            compare(page.loadingState.visible, false)
            compare(page.resultsView.visible, true)
            // It sits directly under the rows it will be replaced by. The row height
            // animates in, so the check allows the one-pixel band an
            // in-flight layout pass can leave it at.
            var row = page.resultAt(0)
            var settled = row.rowHeight + row.listGap
            tryVerify(function() {
                var tail = page.listFooterItem.y
                return tail >= settled - 1 && tail <= settled + 1
            }, 1000)
            verify(page.listFooterItem.y > 0)

            svc().loadingMore = false
            tryVerify(function() { return !page.listFooterItem.visible }, 300)
            compare(page.listFooterItem.height, 0)
        }

        function test_streamingListNeverFlashesTheEmptyState() {
            openWithResults([])
            compare(svc().results.length, 0)
            // A stream that has not answered yet must not claim "no results".
            svc().loadingMore = true
            tryVerify(function() { return !page.emptyState.visible }, 300)

            svc().loadingMore = false
            tryVerify(function() { return page.emptyState.visible }, 300)
        }

        // --- pointer activation ---

        // The selection tint is the shared frame's band CLIPPED to each row, so moving the
        // selection is a mark travelling over the list rather than one row switching
        // state. The whole difference is visible only mid-glide: the card the frame is
        // leaving and the card it is arriving at are BOTH partly lit, in proportion to how
        // much of each the frame is currently over. A test that only looked at where the
        // selection ended would pass on the old whole-card fill, which is lit exactly and
        // never partly - so the claim here is the midpoint, not the destination.
        function test_theSelectionTintIsTheSharedFrameClippedToEachRow() {
            // A card is 64 tall and consecutive cards are 72 apart, so an 8px gap sits
            // between any two of them. Stated here because the arithmetic below divides by
            // them: the frame is 64 tall and cannot fit in that gap, so it always has both
            // cards partly lit at once rather than handing over through a dark one.
            var cardHeight = 64
            var cardGap = 8
            var straddledTotal = cardHeight - cardGap

            openWithResults([
                makeItem("a", "Alpha", 0, 0),
                makeItem("b", "Beta", 0, 0),
                makeItem("c", "Gamma", 0, 0)
            ])
            // Rows have to be standing before anything is measured: a held row is at zero
            // height, has no intersection, and would make every assertion below vacuous.
            var leaving = page.resultAt(0)
            var arriving = page.resultAt(1)
            tryVerify(function() {
                return leaving.bodyHeight > 60 && arriving.bodyHeight > 60
            }, 1500)
            compare(svc().selectedIndex, 0, "the first result starts selected")
            // The band is anchored only once the entrance wave has settled and the page
            // has re-resolved the anchor - `syncSelectionFrame` runs from the rows commit
            // and from the wave's settle timer - so wait for the band itself rather than
            // for a duration. Everything below is about the relationship between the band
            // and the cards, so waiting on the band cannot make any of it true by itself.
            tryVerify(function() {
                return page.selectionTintHeight === cardHeight
            }, 2500)

            // At rest the band covers the whole card, so a settled selection looks exactly
            // as it always did - the change is invisible until the frame is moving. Read
            // off the painted overlay rather than off the row's arithmetic, so every
            // assertion below is about what is on screen.
            compare(leaving.selectionTintItem.y, 0,
                "and the settled band starts at the card's own top edge")
            compare(leaving.selectionTintItem.height, cardHeight,
                "and fills it whole")
            verify(leaving.selectionTintItem.visible, "so its tint is painted")
            compare(String(leaving.selectionTintItem.color),
                String(Lazer.LazerTheme.settingsSelected),
                "in the shared selection token")
            compare(arriving.selectionTintItem.visible, false,
                "and no other card is lit at all")

            keyClick(Qt.Key_Down)
            tryCompare(svc(), "selectedIndex", 1)

            // Sampled off the real glide rather than a driven clock, because the claim is
            // about an instant nobody can schedule: the band between two cards, where both
            // are lit and neither is fully lit.
            var samples = 0
            var sawBothPartial = false
            var split = 0
            while (samples < 40) {
                samples += 1
                var from = leaving.selectionTintItem.height
                var to = arriving.selectionTintItem.height
                if (leaving.selectionTintItem.visible && arriving.selectionTintItem.visible
                        && from > 0.5 && from < cardHeight - 0.5
                        && to > 0.5 && to < cardHeight - 0.5) {
                    sawBothPartial = true
                    split = from + to
                    break
                }
                wait(8)
            }
            verify(sawBothPartial,
                "mid-glide both cards are PARTLY lit - the one being left and the one "
                    + "being arrived at, which a whole-card fill cannot do on any frame")
            // And the split is the frame's own height less the gap it cannot cover: the
            // two lit amounts together are exactly the rectangle, with the 8px between the
            // cards taking none of it.
            compare(split, straddledTotal,
                "and the two lit amounts add up to the frame less the gap between the "
                    + "cards, was " + split + " against " + straddledTotal)

            // Landed: full on the destination, nothing at all on the row it left.
            wait(Lazer.MotionTokens.settingsSidebarCollapse + 150)
            compare(arriving.selectionTintItem.y, 0,
                "on arrival the band is the whole destination card")
            compare(arriving.selectionTintItem.height, cardHeight)
            compare(leaving.selectionTintItem.height, 0,
                "and the card the frame left is not lit at all")
            compare(leaving.selectionTintItem.visible, false)
            // `selected` still says what it always said - it is the row's other
            // affordances that read it, not its fill.
            compare(arriving.selected, true, "and the destination row is the selected one")
            compare(leaving.selected, false, "while the one it left is not")
        }

        function test_theSelectionTintIsNowhereWhenNothingIsSelected() {
            openWithResults([
                makeItem("a", "Alpha", 0, 0),
                makeItem("b", "Beta", 0, 0)
            ])
            var row = page.resultAt(0)
            tryVerify(function() { return row.bodyHeight > 60 }, 1500)
            compare(svc().selectedIndex, 0)
            tryVerify(function() { return page.selectionTintHeight === 64 }, 2500)
            verify(row.selectionTintItem.visible, "so the first card is lit")

            svc().selectedIndex = -1
            tryVerify(function() { return !row.selectionTintItem.visible }, 800)

            // The honest failure mode here is a band parked at coordinate zero painting
            // the first card, so the first card specifically is asserted dark - and so is
            // every other, because a zero-height band intersects nothing anywhere.
            compare(row.selectionTintItem.height, 0,
                "and nothing is lit at all - not the first card at coordinate zero")
            compare(row.selectionTintItem.visible, false)
            var lit = 0
            for (var i = 0; i < page.resultCount; ++i) {
                if (page.resultAt(i).selectionTintItem.visible)
                    lit += 1
            }
            compare(lit, 0, "no card in the list is lit")
        }

        // A guard on the mask's own arithmetic rather than on the change: a card with no
        // height has no intersection, so it must come back with a height of exactly zero -
        // not a negative one from an unclamped difference, and not a leftover sliver from
        // the 8px gap that belongs to the row but not to the card. A whole-card fill was
        // immune to both by having no arithmetic, which is the trade the mask makes.
        function test_aFoldedRowHasNoIntersectionToLight() {
            openWithResults([
                makeItem("alpha", "Alpha", 0, 0),
                makeItem("beta", "Beta", 0, 0)
            ])
            var folded = page.resultAt(0)
            var standing = page.resultAt(1)
            tryVerify(function() {
                return folded.bodyHeight > 60 && standing.bodyHeight > 60
            }, 1500)
            tryVerify(function() { return page.selectionTintHeight === 64 }, 2500)
            verify(folded.selectionTintItem.visible, "the first card starts lit")

            // Fold the first card the way a non-match does. `searchQuery` is the page's own
            // input for exactly this - it pushes the active text into every row and a row
            // that stops matching folds to zero height - so setting it on the delegate is
            // the same fold the query change performs, without a session refresh in the
            // way to say which results came back.
            folded.searchQuery = "beta"
            tryVerify(function() { return folded.bodyHeight === 0 }, 1500)
            compare(folded.bodyHeight, 0, "the non-matching card is folded away")
            tryVerify(function() { return standing.bodyHeight > 60 }, 1500)

            // Put the selection on the card that survived, so there is a real band over the
            // list and the folded card beside it is dark for the right reason. Waiting on
            // the card rather than on the band's height, because the band's height was
            // already 64 before the fold and would have said nothing about re-resolving.
            svc().selectedIndex = 1
            tryVerify(function() { return standing.selectionTintItem.visible }, 1500)
            compare(page.selectionTintHeight, 64,
                "so the band really is a full-height rectangle over the list")
            compare(folded.selectionTintItem.height, 0,
                "and the folded card has no lit slice of it - it has no height to be "
                    + "over, which is the whole of why it goes dark")
            compare(folded.selectionTintItem.visible, false,
                "so nothing is painted on a card that is not there")
            // The 8px gap below a standing card belongs to no card, so the band's whole
            // height has to be on the card itself: a mask measured against the row's outer
            // height would leave a sliver of tint in that gap.
            compare(standing.selectionTintItem.height, standing.bodyHeight,
                "while the card that is there is lit exactly to its own edges and not "
                    + "into the gap")
        }

        function test_pointerActivationExecutesClickedRow() {
            var apps = openWithResults([
                makeItem("a", "Alpha", 0, 0),
                makeItem("b", "Beta", 0, 0)
            ])
            compare(page.resultCount, 2)

            var row = page.resultAt(1)
            tryVerify(function() { return row.enabled && row.opacity === 1 }, 800)
            mouseClick(row, row.width / 2, row.height / 2)

            tryCompare(apps.executions, "length", 1, 1500)
            compare(apps.executions[0].id, "b")
        }

        // Shared focus frame: exactly one instance rides the selected row.
        function findFrame() {
            var f = null
            function walk(it) {
                if (f || !it) return
                for (var i = 0; i < it.children.length; i++) {
                    var c = it.children[i]
                    if (c.objectName === "selectionFrame") { f = c; return }
                    walk(c)
                }
            }
            walk(page)
            return f
        }

        function test_sharedFocusFrameFollowsSelection() {
            openWithResults([
                makeItem("a", "Alpha", 0, 0),
                makeItem("b", "Beta", 0, 0)
            ])
            var frame = findFrame()
            verify(frame)
            tryCompare(frame, "opacity", 1)

            keyClick(Qt.Key_Down)
            tryCompare(svc(), "selectedIndex", 1)
            tryVerify(function() {
                return frame.opacity === 1 && Math.round(frame.height) === 64
            }, 600)

            function test_resultWindowCapsInitialRowsAndExtends() {
            var many = []
            for (var i = 0; i < 200; i++)
                many.push(makeItem("item" + i, "Item " + i, 0, 0))
            openWithResults(many)
            compare(page.resultCount, 96)

            page.resultsView.extendResultWindow()
            compare(page.resultCount, 176)
        }

        // Exactly one shared instance across the whole list.
            var count = 0
            function countAll(it) {
                if (!it) return
                for (var i = 0; i < it.children.length; i++) {
                    if (it.children[i].objectName === "selectionFrame") count++
                    countAll(it.children[i])
                }
            }
            countAll(page)
            compare(count, 1)
        }

        function test_deepMatchStretchesWindowInsteadOfBlankList() {
            var many = []
            for (var i = 0; i < 200; i++)
                many.push(makeItem("item" + i, "Item " + i, 0, 0))
            many.push(makeItem("deep-target", "Zzz Quux", 0, 0))
            openWithResults(many)
            compare(page.resultCount, 96)

            // The pool holds the only match at index 200, far past the base
            // window. Typing the query must stretch the materialized window
            // so the match renders; results are non-empty so the empty state
            // stays hidden — without the stretch the list sits blank with no
            // explanation until an impossible scroll.
            svc().query = "zzz"

            compare(svc().results.length, 1)
            // The stretch lands after the deferred fold window plus tail
            // delegate creation; budget generously on slow runners.
            tryCompare(page, "resultCount", 201, 3000)
            compare(page.emptyState.visible, false)
            compare(page.resultsView.visible, true)
            tryVerify(function() {
                var row = page.resultAt(200)
                return row && row.displayName === "Zzz Quux"
                        && row.enabled && row.opacity === 1
            }, 3000)
        }

        function test_scrollEdgeTakeoverSettlesWithoutMissingHelpers() {
            // The edge-takeover wheel path must resolve its viewport
            // helpers: a wrong receiver (or an unported helper) throws a
            // TypeError that both warns and strands edgeDriving, freezing
            // further wheel input. Kept under the base window so no window
            // growth can interfere with the scroll geometry.
            var items = []
            for (var i = 0; i < 40; i++)
                items.push(makeItem("item" + i, "Item " + i, 0, 0))
            openWithResults(items)
            var view = page.resultsView
            tryVerify(function() {
                return view.contentHeight > view.height && !page.entranceBusy
            }, 3000)

            var maximumY = Math.max(0, view.contentHeight - view.height)
            verify(maximumY > view.edgeTakeoverDistance)

            // Park at the bottom edge and push further down: the overshoot
            // is resisted and the view takes over edge driving.
            // NOTE: Qt6 mouseWheel takes deltas before buttons/modifiers:
            // (item, x, y, xDelta, yDelta, buttons, modifiers).
            view.contentY = maximumY
            mouseWheel(view, view.width / 2, view.height / 2, 0, -120, 0, 0)
            compare(view.edgeDriving, true)

            // A wheel back in the middle settles the edge drive synchronously.
            view.contentY = Math.min(100, maximumY / 2)
            mouseWheel(view, view.width / 2, view.height / 2, 0, 120, 0, 0)
            compare(view.edgeDriving, false)
        }

        function test_failedThumbnailHidesWithoutBreakingItsBinding() {
            // A thumbnail file that fails to load must hide the image slot
            // without clearing the bound path, so later paths (and reused
            // delegates) still flow through the same binding.
            ignoreWarning(/QML Image: Cannot open: .*tst_missing_thumb_xyz\.png/)
            var row = rowProbe.createObject(testRoot, {
                result: { id: "7", displayName: "Clip", description: "d", icon: "", isImage: true },
                thumbPath: Qt.resolvedUrl("tst_missing_thumb_xyz.png")
            })
            verify(row)

            tryVerify(function() { return row.thumbFailed === true }, 2000)
            verify(!row.thumbnailItem.visible)
            verify(row.thumbPath.length > 0)

            row.thumbPath = Qt.resolvedUrl("../../modules/lazerbar/icons/apps.svg")
            tryVerify(function() { return row.thumbnailItem.status === Image.Ready }, 2000)
            verify(row.thumbnailItem.visible)
            row.destroy()
        }

        function test_identicalCommitReleasesRowsWithoutReplayingWave() {            openWithResults([
                makeItem("a", "Alpha", 0, 0),
                makeItem("b", "Beta", 0, 0)
            ])
            // First commit claims the fresh rows and records their ids.
            tryVerify(function() { return page._lastRowIds.length === 2 }, 1000)
            tryVerify(function() {
                return page.resultAt(0).enabled && page.resultAt(1).enabled
            }, 3000)
            // Committing the identical set again (metadata-only refreshes,
            // identical background polls) must leave every row untouched:
            // releasing would snap Transitions and kill the fold/glide.
            page._holdAndScheduleReleases()
            verify(page.resultAt(0).enabled)
            verify(page.resultAt(1).enabled)
            compare(page._lastRowIds.length, 2)
        }

        function test_windowGrowthKeepsSurvivorsAndFoldsInsteadOfSnapping() {
            // First-search window stretch runs in two phases: the query
            // first folds the current window in place (no model change, so
            // the fold glides instead of snapping), and only after the fold
            // settles does the window grow to materialize deep matches.
            var items = []
            for (var i = 0; i < 150; i++)
                items.push(makeItem("id" + i, "Item" + String(i).padStart(3, "0"), 0, i))
            items.push(makeItem("deep-target", "Zzz Quux", 0, 0))
            openWithResults(items)
            tryVerify(function() { return page.resultCount === 96 }, 1000)
            // Wait for the first commit AND the entrance wave to settle:
            // delegates report enabled from birth, so only a settled row
            // proves the open choreography ran before the query lands.
            tryVerify(function() { return page._lastRowIds.length === 96 }, 1000)
            var sameRow = page.resultAt(0)
            tryVerify(function() {
                return sameRow.enabled && sameRow.snapTransitions === false
            }, 3000)

            svc().query = "zzz"

            // Phase one: no synchronous rebuild — the window still holds
            // the base slice while the fold plays on persisted delegates.
            compare(page.resultCount, 96)
            verify(sameRow.freshFromBuild === false)
            verify(sameRow.snapTransitions === false)
            verify(sameRow.revealHeld === false)
            tryVerify(function() { return sameRow.searchHidden }, 1000)
            // Phase two: the deferred stretch materializes the deep match.
            tryCompare(page, "resultCount", 151, 3000)
            tryVerify(function() {
                var row = page.resultAt(150)
                return row && row.displayName === "Zzz Quux"
                        && row.enabled && row.opacity === 1
            }, 3000)
        }

        function test_refillCascadeKeepsReleasedSurvivorsVisible() {
            openWithResults([
                makeItem("a", "Alpha", 0, 0),
                makeItem("b", "Beta", 0, 0)
            ])
            tryVerify(function() { return page._lastRowIds.length === 2 }, 1000)
            tryVerify(function() { return page.resultAt(0).enabled }, 3000)
            var survivor = page.resultAt(0)
            var fresh = page.resultAt(1)
            survivor.releaseInstantly()
            fresh.holdInstantly()
            page.playRefillCascade()
            verify(survivor.revealHeld === false)
            verify(survivor.enabled)
            verify(fresh.revealHeld === true)
        }

        // --- empty state ---

        function test_zeroResultsKeepsExitVisible_data() {
            return [
                { tag: "apps", prefix: "", reduced: false },
                { tag: "clipboard", prefix: ">clip ", reduced: false },
                { tag: "apps-reduced", prefix: "", reduced: true },
                { tag: "clipboard-reduced", prefix: ">clip ", reduced: true }
            ]
        }

        function test_zeroResultsKeepsExitVisible(data) {
            var adapter = makeManualAdapter()
            svc()._adapters = ({ apps: adapter, clipboard: adapter })
            svc().query = data.prefix
            svc().open()
            wait(0)
            resolveRefresh(adapter, 0, [makeItem("alpha", "Alpha", 0, 0)])
            tryVerify(function() { return page._lastRowIds.length === 1 }, 1000)
            var row = page.resultAt(0)
            tryVerify(function() {
                return !row.snapTransitions && !row.revealHeld
                        && row.height === row.rowHeight + row.listGap && row.opacity === 1
            }, 1000)
            Lazer.MotionTokens.reducedMotionOverride = data.reduced

            svc().query = data.prefix + "no-match"
            compare(svc().results.length, 0)
            compare(page.emptyState.visible, true)
            compare(row.enabled, false)
            if (!data.reduced) {
                verify(page.resultsView.visible, "Empty state must not hide exiting rows")
                verify(row.visible)
                tryVerify(function() {
                    return row.height > 0 && row.height < row.rowHeight + row.listGap
                            && row.opacity > 0 && row.opacity < 1
                }, 200)
                verify(row.visible)
            }
            tryCompare(row, "height", 0, 1000)
            tryCompare(row, "opacity", 0, 1000)
            compare(row.visible, false)

            svc().query = data.prefix + "alpha"
            compare(page.emptyState.visible, false)
            tryCompare(row, "opacity", 1, 1000)
            verify(row.visible && row.enabled)
            verify(page.searchField.activeFocus)

            svc().query = data.prefix + "no-match"
            svc().query = data.prefix + "alpha"
            tryCompare(row, "height", row.rowHeight + row.listGap, 1000)
            tryCompare(row, "opacity", 1, 1000)
            verify(row.visible && row.enabled)
        }

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
            wait(0)

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
            wait(0)
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
