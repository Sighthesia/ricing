import QtQuick
import "../../services/launcher"
import "../../services/LauncherLogic.js" as LauncherLogic
import "../../services/launcher/LauncherCategories.js" as LauncherCategories

// Keyboard-first launcher content page for the wave surface: auto-focused
// search rail, mode sidebar data with prefix rewriting, service-driven result
// list, and explicit loading / empty / error / retry states. All session
// state flows through the injected session; the page never owns launcher data.
//
// The control center is the FOURTH rail entry's view of this same content area,
// not a sibling Wave route: one page, one content area, one selection semantic.
// See `controlCenterActive` below for why that is a page-local flag rather than
// a session mode.
Item {
    id: root
    objectName: "launcherPage"
    property double _born: Date.now()

    // --- Injected service seams for the control-center view ---
    //
    // The control center is the one thing on this page that reports system state,
    // so its services are injected rather than imported, exactly like the session
    // below: production binds Services.* singletons at the surface owner edge and
    // a test passes fakes. Every one defaults to null, which is a defined state -
    // the overview renders its explicit unavailable/optional states for a missing
    // service instead of throwing. This file still imports no service.
    property var networkService: null
    property var bluetoothService: null
    property var volumeService: null
    property var mediaService: null
    property var batteryService: null
    property var notificationService: null
    property var weatherService: null

    // Session contract: any object exposing the observable LauncherService
    // state (visible, query, mode, results, loading, error, selectedIndex)
    // plus refresh/selectNext/selectPrevious/executeSelected/execute, where
    // query edits re-request data while open. Production binds
    // Services.LauncherService; tests inject deterministic sessions. The
    // embedded default keeps the page self-contained without Quickshell.
    property var session: embeddedSession
    // Thumbnail decodes are deliberately held until the wave has finished
    // entering. The first cliphist decode spawns a process and competes with
    // the opening frame; the queue remains viewport-prioritized once this gate
    // opens. Standalone page tests keep the gate open by default.
    property bool thumbnailsActive: true
    // The real page is retained before the first open. Reserve its fixed row
    // window during that idle prewarm too, so the first clipboard batch fills
    // existing delegates instead of constructing the whole 96-row tree in the
    // opening frame.
    property bool prewarmSlots: false

    // Fallback keyboard owner: click-away can strand the surface with no
    // focused item, and then Escape would reach no handler at all. While
    // open, the guard reclaims scope focus whenever nothing inside the page
    // holds it; deeper focus owners (search editor, rows) always outrank.
    function reclaimKeyboardFallback() {
        var w = Window.window
        if (!w)
            return
        var fi = w.activeFocusItem
        if (fi) {
            var p = fi
            while (p) {
                if (p === root)
                    return
                p = p.parent
            }
        }
        root.forceActiveFocus()
    }

    Timer {
        // A prewarmed page stays mounted behind the closed wave and must never
        // steal keyboard ownership.
        running: !!root.session && root.session.visible === true && root.enabled
        interval: 250
        repeat: true
        onTriggered: root.reclaimKeyboardFallback()
    }

    // Data surfaced to the wave shell's three-block chrome.
    readonly property string title: "Launcher"
    // The masthead's subtitle line, which only the rail layout has room to
    // mean anything in. Under "blocks" it is empty: band 2 already names the
    // mode twice, and a mode's description sitting under the launcher's own
    // name describes neither, so the wiki-shaped masthead carries the site name
    // alone. Empty is a defined state — the header drops the slot rather than
    // reserving it.
    readonly property string description: root.chromeLayout === "rail"
            ? root.modeDescription(activeMode) : ""
    // Identity glyph for the masthead.
    readonly property string titleIcon: "icons/launcher.svg"
    // The navigation entries, in the order the chrome shows them. They used to
    // be a vertical rail's list and are now the page bar's tab row; both
    // layouts read this one list, which is why it is named for what it holds
    // rather than for where it is drawn.
    //
    // Two kinds of entry share it. The three primaries are FILTERS of this
    // page: they rewrite the query and change what the list shows. The footer
    // entry is not a filter - it leaves this page and switches the surface to
    // the control-center route, which is why it is marked `section: "footer"`
    // and answered by a different handler below. Declaring them together is
    // deliberate: they share one accent indicator, and the hairline is what
    // tells them apart.
    readonly property var sectionEntries: [
        { id: "apps", label: "Apps", icon: "icons/apps.svg" },
        { id: "clipboard", label: "Clipboard", icon: "icons/clipboard.svg" },
        { id: "shortcuts", label: "Shortcuts", icon: "icons/keyboard.svg" },
        { id: "control-center", label: "Control Center", icon: "icons/control-center.svg", section: "footer" }
    ]
    readonly property string activeMode: root.session && root.session.mode != null ? String(root.session.mode) : ""
    // Chrome-facing selection: the view on screen, not just the query mode.
    // While the control center owns the content area the rail/page-bar
    // selection follows it, so the shared accent strip can land on its entry.
    readonly property string activeSectionId: root.controlCenterActive
            ? root.controlCenterEntryId : root.activeMode
    readonly property string controlCenterEntryId: "control-center"

    // The control center is a retained view inside this page, not a launcher
    // mode or a second wave route. Keeping the flag local preserves the query
    // and caret while the content area changes owner.
    property bool controlCenterActive: false
    property bool controlCenterBuilt: false
    readonly property Item controlCenterItem: controlCenterLoader.item

    function openControlCenter() {
        if (root.controlCenterActive)
            return false
        root.controlCenterActive = true
        controlCenterFocusTimer.restart()
        return true
    }

    function closeControlCenter() {
        if (!root.controlCenterActive)
            return false
        root.controlCenterActive = false
        root.dismissControlCenterDetail()
        controlCenterFocusTimer.restart()
        resultsView.syncSelectionFrame()
        return true
    }

    Timer {
        id: controlCenterFocusTimer
        interval: 0
        repeat: false
        onTriggered: root.controlCenterActive
                ? root.handOverControlCenterFocus() : root.focusSearch()
    }

    function dismissControlCenterDetail() {
        var view = root.controlCenterItem
        if (view && view.detailActive === true
                && typeof view.closeSubPage === "function")
            view.closeSubPage()
        return true
    }

    function handOverControlCenterFocus() {
        if (!root.controlCenterActive)
            return false
        var view = root.controlCenterItem
        if (view && typeof view.focusDefault === "function") {
            view.focusDefault()
            return true
        }
        root.forceActiveFocus()
        return true
    }

    // Normalized free-text portion of the query; rows fold themselves against
    // it exactly like settings rows do under a search filter.
    readonly property string activeSearchText: {
        if (!root.session || root.session.query == null)
            return ""
        return LauncherLogic.parseQuery(String(root.session.query)).text
    }

    // Category chip lens: the active id ("" is the unfiltered "All" chip)
    // and the chip model for the current mode, rebuilt from the pooled data
    // and the live text filter. The model is built even for an empty pool so
    // the rail's presence depends on the mode alone - a rail that appears
    // with the first batch of data would shift the whole list mid-entrance.
    readonly property string activeCategory: root.session && root.session.category != null
                                                ? String(root.session.category) : ""
    // The counts come from the session, which publishes them when the data is
    // whole rather than on every arriving batch - a binding here would count
    // the whole pool per batch and the numbers would tick up as the tail
    // streamed in.
    readonly property var categoryChips: LauncherCategories.chipsFor(
        root.activeMode,
        root.session ? root.session.categorySummary : null)

    function setCategory(id) {
        if (!root.session)
            return
        root.session.category = id == null ? "" : String(id)
    }

    // Emitted when a sidebar-driven mode change is applied to the session.
    signal modeChangeRequested(string mode)
    // Bubbled from the activated result row so the owning surface can replay
    // the card's parabolic exit in a layer above the closing panel.
    signal exitFlingRequested(var spec)

    readonly property alias searchField: searchSurface
    // Chip rail handle for probes and tests (chipAt resolves one chip).
    readonly property alias categoryBarItem: categoryBar
    // Spinner row marking the tail that has not streamed in yet.
    readonly property alias listFooterItem: listFooter
    // Result access for tests and shell wiring.
    readonly property alias resultsView: resultsView
    readonly property int resultCount: resultsView.resultCount
    function resultAt(index) { return resultsView.resultAt(index) }
    readonly property alias loadingState: loadingSurface
    readonly property alias emptyState: emptyStateHost
    readonly property alias errorState: errorStateHost
    readonly property alias retryButton: retryButton
    // Current preview-pane item for probes/tests and shell wiring.
    readonly property alias previewSelectedResult: previewPane.selectedResult
    readonly property alias previewTextItem: paneText
    readonly property alias previewImageItem: paneImage

    // True while the session is still streaming batches. The list shows what
    // has arrived and the footer shows what has not, so this replaces the
    // old "indexing applications" notice.
    readonly property bool streamingResults: root.session && root.session.visible
                                   && root.session.loadingMore === true

    implicitWidth: 400
    implicitHeight: 300

    // Which chrome layout the wave host is wearing: "blocks" (the osu wiki
    // three-band stack) or "rail" (masthead + collapsible vertical navigation).
    //
    // The query surface answers it rather than staying put, because a comparison
    // that changed only the navigation would not be a comparison — under the
    // rail layout the full-bleed `settingsRail` strip this page had before the
    // stack came back exactly as it was, inset card and all.
    property string chromeLayout: "blocks"
    readonly property bool insetQuery: root.chromeLayout !== "rail"
    readonly property bool chromeVisible: !root.controlCenterActive

    // Row currently carrying the shared focus frame; pure var property so
    // imperative updates are safe under the qs engine.
    property var selectionAnchor: null

    // The shared rect's own band, in the space the rows are positioned in - the results
    // column - for the per-row tint masks. Read straight off `selectionFrame` rather than
    // recomputed from the anchor row, so this file holds ONE rectangle and the tint cannot
    // be placed from a second opinion about where it is; and because `selectionFrame.y`
    // carries the glide's `Behavior`, these two follow it frame for frame without a clock
    // of their own.
    //
    // Nothing subtracts `contentY` and nothing needs to: the rows and the frame share the
    // column's space, which is inside the viewport's content item, so a scrolling list
    // carries the band with it for free and a row's own `y` is the same number the band
    // is measured against.
    readonly property real selectionTintTop: selectionFrame.y
    readonly property real selectionTintHeight: selectionFrame.height

    LauncherSession { id: embeddedSession }

    Component.onCompleted: root.adoptSessionFocus()

    onSessionChanged: root.adoptSessionFocus()

    Connections {
        target: root.session
        function onVisibleChanged() {
            if (root.session.visible) {
                // Launched rows hide instantly for their fling exit; the
                // count-model Repeater reuses those delegates on reopen, so
                // a stale closing flag would strand the row invisible even
                // though its result still matches. Clear it before focusing.
                for (var i = 0; i < resultsRepeater.count; i++) {
                    var row = resultsRepeater.itemAt(i)
                    if (row) {
                        row.restoreFromClosing()
                        if (row.result && row.revealHeld === true
                                && typeof row.releaseInstantly === "function")
                            row.releaseInstantly()
                    }
                }
                root.focusSearch()
                // The full entrance wave is for a genuinely first paint; when
                // reopening onto already-materialized rows it would fold the
                // list away and re-reveal it row by row, reading as stale rows
                // jumping to a new order. Those commits fall through to the
                // light cascade (or no touch at all for identical ids).
                root._firstFillPending = resultsView.resultCount <= 0
            } else {
                root.cancelEntranceWave()
                entranceSettle.stop()
                entranceWatchdog.stop()
                root._firstFillPending = false
                // Pointer preview dies with the surface so a reopen starts
                // from the focused row instead of a stale hover.
                root._hoveredResult = null
                // Drop any query-driven window stretch: the next open starts
                // from the base slice and stretches only if its own query
                // needs deep matches, instead of rebuilding hundreds of
                // materialized rows on every pool swap.
                root._resultWindowExtra = 0
                windowStretchTimer.stop()
                // A thumbnail that would not load gets one more attempt on the
                // next open: the decoded-path cache is permanent, so nothing
                // else can ever hand that row a fresh one.
                root.rearmFailedThumbs()
                root.rearmFailedIcons()
                // The control center view dies with the surface that showed it.
                // The page is retained across closes, so without this a reopen
                // would land on the control center - which is not what any open
                // asked for, since the query survives but the VIEW is not
                // session state. `controlCenterBuilt` deliberately stays: the view
                // stays constructed, it just is not on screen.
                root.dismissControlCenterDetail()
                root.controlCenterActive = false
            }
        }
        function onSelectedIndexChanged() {
            resultsView.positionToSelection()
            resultsView.syncSelectionFrame()
            // The selected row is the preview pane's subject, so a move has to
            // re-rank the decode queue even when nothing is outstanding yet.
            thumbQueue.wake()
        }
        function onResultsChanged() {
            Qt.callLater(root._scheduleRowsCommit)
        }
        function onDisplayPoolChanged() {
            Qt.callLater(resultsView.normalizeViewport)
            root._syncWindowToMatches()
            // Delegates exist synchronously after the model assignment, so
            // hold-and-schedule here without an async gap a fresh row could
            // slip through unreleased.
            root._scheduleRowsCommit()
        }
        function onClipboardMetadataMerged() {
            root._clipMetaRev++
        }
        function onErrorChanged() {
            if (!root.session || !root.session.error)
                return
            // A failed launch leaves its row hidden for a fling exit that
            // never plays; restore the card so the surface stays usable.
            for (var i = 0; i < resultsRepeater.count; i++) {
                var row = resultsRepeater.itemAt(i)
                if (row && row.closing && typeof row.restoreFromClosing === "function")
                    row.restoreFromClosing()
            }
            resultsView.syncSelectionFrame()
        }
    }

    onThumbnailsActiveChanged: thumbQueue.wake()

    // Fallback key handling for focus held by the page itself or by rows;
    // the search field handles its own keys first and stops propagation.
    Keys.onPressed: event => {
        // Input isolation. The control-center view has its own controls and its
        // own key handling, and the launcher's editor is INVISIBLE while the view
        // is up - so an arrow key landing here must not move a selection the user
        // cannot see, and Return must not execute a row behind the view. Escape
        // is the one exception: it is the press that leaves the view.
        if (root.controlCenterActive && event.key !== Qt.Key_Escape)
            return
        switch (event.key) {
        case Qt.Key_Up:
            event.accepted = root.navigateSelection(-1)
            break
        case Qt.Key_Down:
            event.accepted = root.navigateSelection(1)
            break
        case Qt.Key_Return:
        case Qt.Key_Enter:
            root.executeSelected()
            event.accepted = true
            break
        case Qt.Key_Escape:
            // Single evaluation point: unaccepted keys bubble here from every
            // inner item, so Escape is decided once per press.
            event.accepted = root.handleEscape()
            break
        }
    }

    function modeDescription(mode) {
        if (mode === "clipboard")
            return "Search clipboard history"
        if (mode === "shortcuts")
            return "Search keybinds"
        return "Search applications"
    }

    // The chrome's contract entry point: the surface asks this, never the mode
    // handler directly, because one entry list now carries two kinds of entry.
    // A footer id is an action on the surface and is answered here; everything
    // else is a filter on this page and falls through unchanged. Named for the
    // section the chrome selects, not for the rail it used to be drawn in —
    // both layouts route through here, so the name has to cover both.
    function handleSectionSelected(id) {
        if (id === "control-center") {
            root.openControlCenter()
            return
        }
        // A filter chosen while the control center is up replaces the view, in
        // this order: leave the view first, so the mode handler's own focus
        // hand-back lands on a visible editor.
        root.closeControlCenter()
        root.handleModeSelected(id)
    }

    // Rewrite the current search text under the requested mode's prefix so
    // switching modes reuses the same data-source seam without reopening.
    function handleModeSelected(modeId) {
        if (!root.session || !root.isKnownMode(modeId))
            return
        var currentQuery = root.session.query == null ? "" : String(root.session.query)
        var prefix = modeId === "clipboard" ? ">clip "
                   : modeId === "shortcuts" ? ">key "
                   : ""
        root.session.query = prefix + LauncherLogic.parseQuery(currentQuery).text
        root.focusSearch()
        root.modeChangeRequested(modeId)
    }

    // Only the primaries are query modes. The control center names a VIEW of this
    // page rather than a data source, so admitting it here would let a mode
    // prefix be built for an id that names no pool - and a "mode change" would be
    // reported for a view switch.
    function isKnownMode(modeId) {
        for (var i = 0; i < root.sectionEntries.length; i++) {
            if (root.sectionEntries[i].id !== modeId)
                continue
            if (String(root.sectionEntries[i].section || "") === "footer")
                return false
            return true
        }
        return false
    }

    function requestRetry() {
        if (root.session && typeof root.session.refresh === "function")
            root.session.refresh(true)
    }

    // Route execution through the selected row so it replays the
    // notification-style fling exit before the launch fires; fall back to
    // the session path when no row backs the current selection.
    function executeSelected() {
        var service = root.session
        if (!service)
            return
        // Same isolation as navigateSelection, and for the same reason: the
        // editor and the preview pane each bind Return to this directly. Executing
        // a row behind the control center would launch an application the user
        // cannot see they picked.
        if (root.controlCenterActive)
            return
        var current = service.results && service.selectedIndex >= 0
                ? service.results[service.selectedIndex] : null
        if (current) {
            for (var i = 0; i < resultsRepeater.count; i++) {
                var row = resultsRepeater.itemAt(i)
                if (row && row.result && String(row.result.id) === String(current.id)
                        && typeof row.activate === "function") {
                    // A row still hidden by the entrance wave must release
                    // first or the activation guard would swallow the key.
                    if ((row.concealed || row.folded)
                            && typeof row.releaseInstantly === "function")
                        row.releaseInstantly()
                    row.activate()
                    return
                }
            }
        }
        if (typeof service.executeSelected === "function")
            service.executeSelected()
    }

    function navigateSelection(direction) {
        if (!root.session)
            return false
        // Input isolation, enforced here rather than only at the key handler. The
        // search editor, the preview pane and the page itself each register their
        // own arrow bindings and each calls this function, so a guard in
        // `Keys.onPressed` alone would leave the editor's own binding able to move
        // a selection the user cannot see - which is reachable in the one turn
        // between the view going up and the focus hand-back landing, measured
        // rather than assumed.
        if (root.controlCenterActive)
            return false
        // Keyboard navigation reclaims the preview: a resting mouse would
        // otherwise keep the hovered row previewed while the highlight moves.
        root._hoveredResult = null
        if (direction < 0 && typeof root.session.selectPrevious === "function") {
            root.session.selectPrevious()
            // Arrow navigation changes the selected row but must not move the
            // keyboard owner away from the search editor. This also repairs
            // focus when the event came from a result row or page fallback.
            root.focusSearch()
            return true
        }
        if (direction > 0 && typeof root.session.selectNext === "function") {
            root.session.selectNext()
            // Keep subsequent typing in the search field after navigation.
            root.focusSearch()
            return true
        }
        return false
    }

    // One press, four possible meanings, in the order they are decided here:
    //
    //   1. the control center's own detail sub-page, if one is mounted - it is
    //      INSIDE this view and pops itself, so the view does not close over it;
    //   2. the control center view itself, which hands back to the launcher view
    //      the user came from, with their query and caret untouched;
    //   3. typed text, which clears back to the active mode's bare prefix
    //      (never falling back to apps);
    //   4. nothing left, reported as "close" to the owning wave shell by leaving
    //      the key unaccepted.
    //
    // The order is the whole contract, and it is decided in ONE function because
    // every step is a different owner: the sub-page answers inside the control
    // center, the view is this page's own flag, and the query is the session's.
    // Splitting these across handlers is how a press ends up consumed by a page
    // that has already spent it. The page never tears down its own session.
    function handleEscape() {
        if (root.controlCenterActive) {
            var view = root.controlCenterItem
            // A mounted detail page consumes the press. Asking it FIRST is what
            // makes step 2 reachable at all: the overview declines, and declining
            // is the signal that the view itself is what leaves.
            if (view && typeof view.handleBack === "function" && view.handleBack() !== false)
                return true
            return root.closeControlCenter()
        }
        if (!root.session)
            return false
        var esc = LauncherLogic.escapeAction(root.session.query)
        if (esc.action === "clear") {
            root.session.query = esc.query
            return true
        }
        return false
    }

    // The page's half of the wave host's back contract, read by the host when a
    // press reaches it rather than this page's own key handler. Both halves or
    // neither: advertising a back step with no handler would take every press
    // and do nothing with it, and this page - not the host - is the authority.
    // While the control center is up the answer is always `true`, because
    // `handleEscape()` then has a step it can always take.
    readonly property bool canGoBack: root.controlCenterActive
    function handleBack() { return root.handleEscape() }

    function focusSearch() {
        // Same contract as the reclaim timer above: a prewarmed page must never
        // steal keyboard ownership. Without this guard the retained page
        // focuses its invisible editor when the session turns visible, which Qt
        // answers by clearing the window's active focus — the visible
        // launcher then opens with no focused search box, and Escape reaches
        // nothing at all.
        if (!root.enabled)
            return
        // The editor is hidden while the control center view is up, and Qt answers
        // a focus request on an invisible item with a refusal. Focusing it anyway
        // would leave the view with no keyboard owner at all, which is how a
        // sidebar selection ends up with a dead Escape.
        if (root.controlCenterActive)
            return
        searchSurface.focusEditor()
    }

    // Grab search focus when mounting onto an already-open session and when
    // the session swaps in production bindings.
    function adoptSessionFocus() {
        if (root.session && root.session.visible)
            Qt.callLater(root.focusSearch)
    }

    // Explicit result-area states; the search rail is never replaced so the
    // editing session and keyboard focus survive every transition. All states
    // require a visible session so closed/closing sessions never render them.
    readonly property bool sessionLoading: root.session && root.session.visible
                                           && root.session.loading && !root.session.error
    readonly property bool sessionError: root.session && root.session.visible
                                         && !root.session.loading && !!root.session.error
    // A stream that has only delivered its first batch has not answered yet:
    // reporting "No results" then would flash a wrong answer at a list that
    // is still arriving.
    readonly property bool sessionEmpty: root.session && root.session.visible
                                         && !root.session.loading
                                         && !root.streamingResults
                                         && !root.session.error
                                         && (!root.session.results || root.session.results.length === 0)
    readonly property bool stateVisible: sessionLoading || sessionError || sessionEmpty

    // Entrance wave, mirroring LazerSettingsSections.playEntranceWave:
    // hold every row instantly, release top-to-bottom on 18ms slots from a
    // 120ms base, and hold scrolling until the reveal transitions land.
    // Two gates, deliberately different:
    //  - rowsAnimatingIn is a row still travelling in. Scrolling fights that,
    //    so it is what blocks the wheel, and it clears the moment the last
    //    row lands. Gating the wheel on the settle timer instead left the
    //    list refusing input for hundreds of milliseconds after the rows had
    //    already settled.
    //  - entranceBusy also covers the settle timer, which exists to hold a
    //    deferred scroll until the wave has reshaped the layout.
    readonly property bool rowsAnimatingIn: _anyRowHeld()
    readonly property bool entranceBusy: rowsAnimatingIn || entranceSettle.running
    readonly property int entranceBaseDelay: 120
    readonly property int entranceSlotInterval: 18

    // The settle window measures the tail AFTER the last row lands, exactly
    // like LazerSettingsSections.onEntranceWaveActiveChanged. Starting it
    // together with the wave (as this page used to) made it outlast the rows
    // by the whole stagger, so the viewport stayed non-interactive long after
    // the list had stopped moving.
    onRowsAnimatingInChanged: {
        if (root.rowsAnimatingIn)
            entranceSettle.stop()
        else
            entranceSettle.restart()
    }

    property int _deferredScrollIndex: -1
    property bool _firstFillPending: false

    Timer {
        id: entranceSettle
        interval: MotionTokens.slow + MotionTokens.slow / 2 + 100
        repeat: false
        onTriggered: {
            resultsView.syncSelectionFrame()
            if (root._deferredScrollIndex >= 0) {
                var deferred = root._deferredScrollIndex
                root._deferredScrollIndex = -1
                resultsView.scrollTo(deferred)
            }
        }
    }

    // Backstop for the entrance gate. A held row keeps the wheel off
    // (entranceBusy disables the viewport), so a wave that never completes -
    // a delegate whose reveal timer was superseded, a commit that raced the
    // Repeater - must not cost the list its scrolling for the rest of the
    // session. Well past the longest wave the page can play.
    Timer {
        id: entranceWatchdog
        interval: 2000
        repeat: false
        onTriggered: {
            entranceSettle.stop()
            root.cancelEntranceWave()
            root._deferredScrollIndex = -1
        }
    }

    function _anyRowHeld() {
        var children = resultsColumn.children
        for (var i = 0; i < children.length; i++) {
            if (children[i].revealHeld === true || children[i].snapTransitions === true)
                return true
        }
        return false
    }

    onEntranceBusyChanged: {
        if (!root.entranceBusy && root._deferredScrollIndex >= 0) {
            var deferred = root._deferredScrollIndex
            root._deferredScrollIndex = -1
            resultsView.scrollTo(deferred)
        }
    }

    // Play the open-session wave over the current rows.
    function playEntranceWave() {
        var children = resultsColumn.children
        if (MotionTokens.reducedMotion) {
            for (var r = 0; r < children.length; r++)
                if (children[r].releaseInstantly !== undefined)
                    children[r].releaseInstantly()
            return
        }
        var baseDelay = root.entranceBaseDelay
        var slotInterval = root.entranceSlotInterval
        var slot = 0
        for (var i = 0; i < children.length; i++) {
            if (children[i].holdInstantly === undefined)
                continue
            children[i].holdInstantly()
            children[i].playReveal(baseDelay + slot * slotInterval)
            slot++
        }
        if (slot > 0)
            entranceWatchdog.restart()
    }

    // Cancel an unfinished wave, restoring every row instantly.
    function cancelEntranceWave() {
        var children = resultsColumn.children
        for (var i = 0; i < children.length; i++) {
            if (children[i].releaseInstantly === undefined)
                continue
            if (children[i].revealHeld === true || children[i].snapTransitions === true)
                children[i].releaseInstantly()
        }
    }

    // Refills cascade like the settings search-exit delay: each held row
    // unfolds with a small position-based stagger instead of a full wave.
    // Only rows already held by the commit choreography (fresh tail, full
    // swaps) replay the stagger; untouched survivors keep gliding.
    function playRefillCascade(hasNewcomers) {
        var children = resultsColumn.children
        if (MotionTokens.reducedMotion) {
            for (var r = 0; r < children.length; r++)
                if (children[r].releaseInstantly !== undefined)
                    children[r].releaseInstantly()
            return
        }
        var revealed = 0
        for (var i = 0; i < children.length; i++) {
            if (children[i].playReveal === undefined)
                continue
            if (children[i].revealHeld !== true)
                continue
            children[i].playReveal(children[i].entryExitDelay)
            revealed++
        }
        // Only a cascade that actually has something to reveal keeps the
        // entrance gate closed; a batch that filled nothing new would otherwise
        // arm the backstop on rows that never move.
        if (revealed > 0 && hasNewcomers !== false)
            entranceWatchdog.restart()
    }

    // Coalesce the commit choreography across the display-pool and results
    // writes landing in one refresh so hold/wave/cascade plays exactly once.
    property bool _rowsCommitScheduled: false
    // The commit is deferred on a child Timer, not with Qt.callLater. The wave
    // host swaps route pages by swapping its Loader's sourceComponent, which
    // destroys the outgoing page SYNCHRONOUSLY; a queued closure or a queued
    // method reference is then still delivered against a dead QML context and
    // throws ("Property '_holdAndScheduleReleases' is not a function"). A Timer
    // is a child of this page, so it dies with it and the pending frame is
    // dropped - the correct outcome for a page that no longer exists.
    //
    // Only this one deferral is a Timer. The page's other Qt.callLater sites
    // stay callLaters: a Timer competes with the thumbnail pacer for the timer
    // queue, and routing row commits through one shifted the pacer's phase
    // enough to make it catch up two ticks inside one interval.
    Timer {
        id: rowsCommitTimer
        interval: 0
        repeat: false
        onTriggered: root._commitRows()
    }

    function _scheduleRowsCommit() {
        if (root._rowsCommitScheduled)
            return
        root._rowsCommitScheduled = true
        rowsCommitTimer.restart()
    }

    // The deferred half of _scheduleRowsCommit.
    function _commitRows() {
        root._rowsCommitScheduled = false
        root._holdAndScheduleReleases()
        resultsView.syncSelectionFrame()
        resultsView.normalizeViewport()
    }

    // Route each commit to exactly one animation path. Window growth
    // rebuilds every delegate, so the commit tells survivors from
    // newcomers by id: only ids beyond the previous window count as new.
    // Same-id commits (query folding, metadata-only refreshes,
    // identical background polls) leave every row untouched so the
    // fold/glide keeps playing instead of snapping. Pure appends stagger
    // only visible newcomers: survivors release untouched at their settled
    // fold state and folded rows stay folded, so a deferred window stretch
    // never replays the entrance. Order or content swaps (mode switches,
    // pulls) hold the whole list through one full stagger. Very large
    // first fills, and first fills that already carry typed search text,
    // release instantly instead of waving.
    readonly property int largeListWaveThreshold: 24
    property var _lastRowIds: []
    function _releaseAllRowsInstantly() {
        var children = resultsColumn.children
        for (var i = 0; i < children.length; i++) {
            if (children[i].releaseInstantly !== undefined)
                children[i].releaseInstantly()
        }
    }
    function _releaseHeldRowsInstantly() {
        var children = resultsColumn.children
        for (var i = 0; i < children.length; i++) {
            var row = children[i]
            if (row && row.releaseInstantly !== undefined
                    && (row.revealHeld === true || row.snapTransitions === true))
                row.releaseInstantly()
        }
    }
    function _holdAllRowsInstantly() {
        var children = resultsColumn.children
        for (var i = 0; i < children.length; i++) {
            if (children[i].holdInstantly !== undefined)
                children[i].holdInstantly()
        }
    }
    function _windowRowIds() {
        var pool = root.windowedResults
        var ids = []
        for (var i = 0; i < pool.length; i++)
            ids.push(String(pool[i] ? pool[i].id : ""))
        return ids
    }
    function _isPrefixAppend(ids, prev) {
        if (ids.length <= prev.length)
            return false
        for (var i = 0; i < prev.length; i++) {
            if (ids[i] !== prev[i])
                return false
        }
        return true
    }
    function _sameIdSet(ids, prev) {
        if (ids.length !== prev.length)
            return false
        var seen = ({})
        for (var i = 0; i < prev.length; i++)
            seen[prev[i]] = true
        for (var j = 0; j < ids.length; j++)
            if (!seen[ids[j]])
                return false
        return true
    }
    function _holdAndScheduleReleases() {
        var ids = root._windowRowIds()
        // A hidden list has no entrance to play and nobody to show it to. The
        // page now outlives the surface it lives in, so a background poll can
        // land while the launcher is closed: record what arrived and put the
        // rows straight down, and let the next open find them settled.
        if (!root.session || !root.session.visible) {
            root._lastRowIds = ids
            root._firstFillPending = false
            root._releaseAllRowsInstantly()
            return
        }
        var children = resultsColumn.children
        var freshRows = []
        for (var h = 0; h < children.length; h++) {
            var row = children[h]
            if (row.freshFromBuild === true && row.holdInstantly !== undefined) {
                row.freshFromBuild = false
                freshRows.push(row)
            }
        }
        var prev = root._lastRowIds
        var sameIds = ids.length === prev.length
        if (sameIds) {
            for (var c = 0; c < ids.length; c++) {
                if (ids[c] !== prev[c]) {
                    sameIds = false
                    break
                }
            }
        }
        // A commit that runs before the Repeater has materialized this
        // window's rows must not write the id bookkeeping. Doing so makes the
        // NEXT commit read as "unchanged" and skip the choreography, leaving
        // every delegate it is about to build standing at its initial held
        // geometry - and a held row is what keeps the wheel off, so the list
        // would stop scrolling for the rest of the session.
        if (resultsView.resultCount <= 0)
            return
        // An unchanged id list is a rebuilt window, not new data: the fresh
        // delegates go back where they belong and the survivors are left
        // exactly as they are. No wave, no re-hold - re-releasing a settled
        // list would snap its transitions and kill the fold/glide.
        if (sameIds) {
            if (freshRows.length > 0 || root._anyRowHeld())
                root._releaseHeldRowsInstantly()
            return
        }
        root._lastRowIds = ids
        if (root._firstFillPending) {
            root._firstFillPending = false
            if (resultsView.resultCount > root.largeListWaveThreshold
                    || root.activeSearchText.length > 0)
                root._releaseAllRowsInstantly()
            else
                root.playEntranceWave()
        } else if (root._isPrefixAppend(ids, prev)) {
            // A batch that extends the window is a prefix append: every id the
            // previous window had is still there, in place, and only the ones
            // beyond it are new. Newcomer slots are found by id rather than by
            // "freshly built", because the window is materialized once now and
            // a slot that gains content is not a new delegate. Survivors are
            // left exactly as they are - re-holding a settled list would replay
            // the entrance - and rows the user cannot see have nothing to
            // reveal.
            var prevSet = ({})
            for (var s = 0; s < prev.length; s++)
                prevSet[prev[s]] = true
            var newcomers = 0
            for (var g = 0; g < ids.length; g++) {
                if (prevSet[ids[g]] === true)
                    continue
                var grown = resultsRepeater.itemAt(g)
                if (!grown || grown.result == null || typeof grown.holdInstantly !== "function")
                    continue
                newcomers++
                if (grown.hidden === true || grown.y > resultsView.height)
                    grown.releaseInstantly()
                else
                    grown.holdInstantly()
            }
            root.playRefillCascade(newcomers > 0)
        } else if (root._sameIdSet(ids, prev)) {
            // A new clipboard copy can reorder the window without changing
            // which rows it contains. Releasing all 96 rows here made every
            // idle reopen pay the full refill cascade even though every row
            // was already settled and only its result binding changed.
            root._releaseHeldRowsInstantly()
        } else {
            // Hold only genuinely new ids. Existing rows keep their settled
            // geometry when a pool refresh removes or replaces a small tail.
            var previousIds = ({})
            for (var p = 0; p < prev.length; p++)
                previousIds[prev[p]] = true
            var newcomers = 0
            for (var n = 0; n < ids.length; n++) {
                var survivor = resultsRepeater.itemAt(n)
                if (previousIds[ids[n]]) {
                    if (survivor && survivor.releaseInstantly !== undefined
                            && (survivor.revealHeld === true || survivor.snapTransitions === true))
                        survivor.releaseInstantly()
                    continue
                }
                var newcomer = survivor
                if (!newcomer || typeof newcomer.holdInstantly !== "function")
                    continue
                newcomers++
                newcomer.holdInstantly()
            }
            root.playRefillCascade(newcomers > 0)
        }
    }

    // Query column: the search field and the category lens as ONE inset card
    // sitting on the content plane.
    //
    // It used to be a full-bleed `settingsRail` strip, which is now impossible:
    // the rail tone is DARKER than the content band it would cut across, so a
    // full-bleed query surface became a fourth band with a tone that belongs to
    // none of the three. Insetting it is also the wiki's own answer — the
    // content column carries its blocks as cards, and the blocks read as
    // objects on a plane rather than as more plane.
    Item {
        id: queryColumn
        objectName: "launcherQueryColumn"
        // The launcher's own query surface. It yields the content area to the
        // control-center view, which paints its own header in the same space.
        visible: root.chromeVisible
        enabled: root.chromeVisible
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: root.insetQuery ? 14 : 0
        anchors.leftMargin: root.insetQuery ? 14 : 0
        anchors.rightMargin: root.insetQuery ? 14 : 0

        // Card padding and the gap between the field and the lens. One source
        // for both, so the field, the chips and the result rows below cannot
        // drift apart by a stray literal. Under the rail layout both collapse to
        // zero and the field carries its own 12px text margin, which is exactly
        // the full-bleed strip this page had before the stack.
        readonly property int cardPadding: root.insetQuery ? 10 : 0
        readonly property int queryGap: root.insetQuery ? 8 : 6
        // The lens collapses to zero height for a mode with no categories, and
        // the column's height folds that away with it — so everything below
        // still starts under the field rather than under a gap.
        height: cardPadding * 2 + searchSurface.height
              + (categoryBar.visible ? queryGap + categoryBar.height : 0)

        Rectangle {
            anchors.fill: parent
            radius: root.insetQuery ? LazerTheme.settingsControlRadius : 0
            color: root.insetQuery
                    ? LazerTheme.settingsSearchSurface
                    : LazerTheme.settingsRail
        }

        // Search field inside the card, carrying the osu caret text field.
        FocusScope {
            id: searchSurface
            anchors.top: parent.top
            anchors.topMargin: queryColumn.cardPadding
            anchors.left: parent.left
            anchors.leftMargin: queryColumn.cardPadding
            anchors.right: parent.right
            anchors.rightMargin: queryColumn.cardPadding
            height: root.insetQuery ? 40 : 44

            // Last query value pushed from this page into the session; external
            // session changes always differ from it and are adopted below.
            property string _lastPushedQuery: ""
            property bool _syncingEditor: false
            readonly property string queryText: root.session && root.session.query != null ? String(root.session.query) : ""
            readonly property alias editorItem: editor

            function focusEditor() {
                editor.forceActiveFocus()
            }

            // Adopt external session query values into the editor exactly once per
            // change so user typing remains the only other writer.
            function adoptSessionQuery() {
                if (queryText === _lastPushedQuery)
                    return
                _lastPushedQuery = queryText
                _syncingEditor = true
                editor.suppressDeleteFx = true
                editor.text = queryText
                editor.suppressDeleteFx = false
                _syncingEditor = false
            }

            onQueryTextChanged: adoptSessionQuery()
            Component.onCompleted: adoptSessionQuery()

            OsuTextField {
                id: editor
                anchors.left: parent.left
                // Rail chrome: text starts flush with the sidebar edge like
                // the chips below; blocks keeps the 12px text margin.
                anchors.leftMargin: root.insetQuery ? 12 : 0
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                clip: true
                color: LazerTheme.textPrimary
                selectionColor: LazerTheme.osuPink
                font.pixelSize: 14
                onTextChanged: {
                    if (searchSurface._syncingEditor)
                        return
                    searchSurface._lastPushedQuery = text
                    if (root.session)
                        root.session.query = text
                }
                Keys.onUpPressed: event => { event.accepted = root.navigateSelection(-1) }
                Keys.onDownPressed: event => { event.accepted = root.navigateSelection(1) }
                Keys.onReturnPressed: event => { root.executeSelected(); event.accepted = true }
                Keys.onEnterPressed: event => { root.executeSelected(); event.accepted = true }
            }

            Text {
                anchors.left: editor.left
                anchors.verticalCenter: editor.verticalCenter
                visible: !editor.text && !editor.activeFocus
                text: "Search..."
                color: LazerTheme.textMuted
                font.pixelSize: 14
            }
        }

        // Category lens under the field, inside the same card: the lens is part
        // of the query surface, so it shares the field's block rather than
        // becoming a panel of its own. Modes whose taxonomy yields a single
        // chip (shortcut binds, until their categories are known) take no space,
        // and the column's height folds the gap away with them.
        LauncherCategoryBar {
            id: categoryBar
            objectName: "launcherCategoryBar"
            anchors.top: searchSurface.bottom
            anchors.topMargin: visible ? queryColumn.queryGap : 0
            anchors.left: parent.left
            anchors.leftMargin: queryColumn.cardPadding
            anchors.right: parent.right
            anchors.rightMargin: queryColumn.cardPadding
            height: visible ? implicitHeight : 0
            visible: root.categoryChips.length > 1
            chips: root.categoryChips
            // Rail chrome: the content column already starts at the sidebar's
            // right edge, so the first chip sits flush with it instead of
            // leaving a blank strip. Blocks keeps the inset to match the field.
            railPadding: root.insetQuery ? 12 : 0
            selected: root.activeCategory
            onChipSelected: id => {
                root.setCategory(id)
                // Typing after picking a category must keep going to the search
                // field, so activation always hands the keyboard back.
                root.focusSearch()
            }
        }
    }

    // Divider contract for the host: the query strip spans the full
    // content width and merges with the rail tone, so the rail/content
    // hairline only separates the sidebar from the results below it.
    readonly property real dividerTopInset: root.chromeVisible ? queryColumn.height : 0

    // Result viewport: settings-panel structure (Flickable + folding rows)
    // so entrance wave, query reordering, and the scroll contract behave
    // exactly like LazerSettingsSections.
    // Result windowing: instantiating every pooled row (clipboard can carry
    // 750+) floods the entrance wave and scroll path. Materialize a base
    // slice and grow it as the user scrolls or navigates deeper; queries
    // additionally stretch the window over every current match (capped) so
    // rarely-used apps ranked deep in the pool surface immediately instead
    // of waiting for a scroll that folded rows can never trigger.
    readonly property int resultWindowBase: 96
    readonly property int resultWindowStep: 80
    readonly property int resultWindowCap: 384
    property int _resultWindowExtra: 0
    readonly property int _resultWindowLimit: resultWindowBase + _resultWindowExtra
    readonly property var windowedResults: {
        var pool = root.session ? root.session.displayPool : null
        if (!pool || pool.length <= _resultWindowLimit)
            return pool || []
        return pool.slice(0, _resultWindowLimit)
    }
    // The row window is materialized once, at its current limit, and the
    // arriving batches fill those slots instead of resizing it. Sizing it to
    // the results that happen to exist rebuilt every delegate on each commit -
    // measured at 15ms and 20ms for the two growths a 96-row window goes
    // through on a clipboard open, both of them right after the open and both
    // visible as the list twitching as it fills. A slot with no result yet is
    // collapsed and inert (see LauncherResultRow.slotEmpty).
    readonly property int rowSlotCount: windowedResults.length > 0 || root.prewarmSlots
            ? _resultWindowLimit : 0
    // Stretch the materialized window past the base slice only when a query
    // actually matches rows beyond it. This runs in two phases: the query
    // first folds the current window in place (persisted delegates glide,
    // never snap), and only after the fold settles does the window grow to
    // materialize deep matches. Growing rebuilds every delegate, so doing
    // it in the same turn as the query would kill the fold mid-flight and
    // read as an instant snap (or a replayed entrance). The timer doubles
    // as a keystroke debounce: rapid typing restarts it and only the
    // settled query pays for the rebuild.
    // NB: this must run on query edits, not just pool replacements — the
    // pool already holds the match while the base window does not, and then
    // the list renders blank (results non-empty, so the empty state hides
    // too) until a scroll that folded rows can never trigger.
    readonly property int windowStretchDelay: 300
    Timer {
        id: windowStretchTimer
        interval: root.windowStretchDelay
        repeat: false
        onTriggered: root._applyWindowStretch()
    }
    function _syncWindowToMatches() {
        if (!root.activeSearchText || !root.session || !root.session.visible) {
            windowStretchTimer.stop()
            return
        }
        var pool = root.session.displayPool
        if (!pool || !pool.length) {
            windowStretchTimer.stop()
            return
        }
        var needed = Math.min(root.resultWindowCap,
                              LauncherLogic.lastMatchIndex(pool, root.activeSearchText,
                                                          root.activeCategory) + 1)
        if (needed <= root._resultWindowLimit) {
            windowStretchTimer.stop()
            return
        }
        windowStretchTimer.restart()
    }
    // Grow the window once the fold has settled. Re-validates everything:
    // the query, pool, or visibility may all have moved on while waiting.
    function _applyWindowStretch() {
        if (!root.activeSearchText || !root.session || !root.session.visible)
            return
        var pool = root.session.displayPool
        if (!pool || !pool.length)
            return
        var needed = Math.min(root.resultWindowCap,
                              LauncherLogic.lastMatchIndex(pool, root.activeSearchText,
                                                          root.activeCategory) + 1)
        if (needed <= root._resultWindowLimit)
            return
        root._resultWindowExtra = needed - root.resultWindowBase
        Qt.callLater(root._scheduleRowsCommit)
    }
    onActiveSearchTextChanged: {
        resultsView.normalizeViewport()
        root._syncWindowToMatches()
        thumbQueue.wake()
    }
    // A chip switch folds rows exactly like a search edit, so the viewport
    // needs the same clamp and deep-match stretch.
    onActiveCategoryChanged: {
        resultsView.normalizeViewport()
        root._syncWindowToMatches()
        thumbQueue.wake()
    }
    // Window growth materializes rows below the fold and the query/category
    // re-ranks fold the ones in it, so both re-derive the decode queue's
    // served order on the next tick.
    onWindowedResultsChanged: thumbQueue.wake()

    // Clipboard thumbnail cache: one decode per entry id, owned here so
    // rows and the preview pane share the exact same proven path.
    readonly property var _thumbPaths: ({})
    property int _thumbRev: 0
    property int _iconRetryRev: 0
    // Entry ids whose thumbnail a row reported as unloadable. The decoded path
    // cache is keyed by id and never invalidated, so without this a single
    // failed load was final: the same path came back on every later commit, so
    // the row's thumbFailed latch - which clears only when thumbPath CHANGES -
    // had nothing to re-arm it and the row's icon slot stayed empty for the
    // rest of the session. Cleared on close by rearmFailedThumbs, which is
    // what bounds this to one fresh attempt per open rather than per failure.
    property var _thumbFailedIds: ({})
    // Bumped whenever the session merges clipboard metadata into the live
    // pool in place. Rows and the preview footer read it so merged display
    // fields repaint without replacing the pooled arrays (which would
    // rebuild every delegate and replay the refill cascade).
    property int _clipMetaRev: 0
    // Handle for probes and tests: the decode queue's counters are the only
    // way to prove a burst never happened.
    readonly property alias thumbScheduler: thumbQueue
    // Prefetch slack around the visible band, in rows. Rows just outside it
    // are still served - a flick reveals them before their decode could
    // possibly land - but never ahead of a row the user can actually see.
    readonly property int thumbPrefetchRows: 2

    function clipThumbPath(item) {
        if (!item || !item.isImage)
            return ""
        var id = String(item.id == null ? "" : item.id)
        if (!/^[0-9]+$/.test(id))
            return ""
        return root._thumbPaths[id] || ""
    }
    // A materialized row asked for a thumbnail. This records interest only:
    // whether the row is near enough to the viewport to be worth a process
    // spawn is re-decided every tick from live geometry (see
    // _thumbCandidates), so materializing 96 rows no longer asks for 96
    // decodes, and scrolling back to a row re-queues it with no extra wiring.
    function requestClipThumb(item) {
        if (!item || !item.isImage)
            return
        thumbQueue.enqueue()
    }
    function _thumbDecoded(id, path) {
        var key = String(id == null ? "" : id)
        if (!path)
            return
        root._thumbPaths[key] = path
        root._thumbRev++
    }
    // A materialized row could not load the thumbnail it was handed. Record it
    // and do nothing else: re-decoding immediately would spin, because the
    // cached path is already there and the file behind it has not changed.
    function noteThumbLoadFailed(id) {
        var key = String(id == null ? "" : id)
        if (!key)
            return false
        root._thumbFailedIds[key] = true
        return true
    }
    // Give every entry that failed to load one more chance, once per open:
    // drop its cached path so the row's thumbPath goes empty (which re-arms its
    // thumbFailed latch) and the queue serves the entry again on the next open.
    // Dropping the path is what makes the retry real - a re-decode writes the
    // same string back, and an unchanged path never reloads an Image.
    //
    // Called on close, so the cost is bounded by opens and not by failures: a
    // file that is genuinely gone settles on its second attempt instead of
    // spawning a decode every tick, and one that was merely unreadable for a
    // moment comes back the next time the launcher is opened.
    function rearmFailedThumbs() {
        var dropped = 0
        for (var id in root._thumbFailedIds) {
            if (root._thumbPaths[id] !== undefined) {
                delete root._thumbPaths[id]
                dropped++
            }
        }
        root._thumbFailedIds = ({})
        if (dropped > 0)
            root._thumbRev++
        return dropped
    }

    // App icons have the same one-way Image.Error failure mode as thumbnails,
    // but their source is carried by the pooled result. Re-arm failed rows once
    // per open so a transient provider/file failure cannot strand a fixed set
    // of apps forever, while a genuinely missing icon does not spin per tick.
    function rearmFailedIcons() {
        root._iconRetryRev++
        return root._iconRetryRev
    }
    function _issueThumbDecode(id, mime, done) {
        var service = root.session
        if (!service || typeof service.decodeThumbnail !== "function") {
            done("")
            return
        }
        service.decodeThumbnail(String(id), String(mime == null ? "" : mime), done)
    }
    function _selectedResultId() {
        var service = root.session
        if (!service || !service.results || service.selectedIndex < 0)
            return ""
        var current = service.results[service.selectedIndex]
        return current && current.id != null ? String(current.id) : ""
    }
    // The row the preview pane is rendering: the pointer target when there is
    // one, otherwise the keyboard selection. It is inside the band by
    // definition, and it is drawn at a size where a missing thumbnail is the
    // most visible thing on the whole surface, so it outranks every other
    // candidate rather than waiting its turn in document order.
    function _previewedResultId() {
        var hovered = root._hoveredResult
        if (hovered && hovered.id != null)
            return String(hovered.id)
        return root._selectedResultId()
    }

    // Ordered decode candidates for the current viewport: the previewed row
    // first, then rows overlapping the visible band, then the prefetch slack
    // outward. Rows already holding a decoded path are omitted, so a decoded
    // row is never asked for twice.
    //
    // Deliberately driven off the Repeater rather than off each delegate's
    // lifecycle: a delegate exists for every materialized row regardless of
    // where it sits, which is exactly what made the old per-row request ask
    // the service for 96 decodes on a cold open.
    function _thumbCandidates() {
        var out = []
        var children = resultsColumn.children
        if (!children || children.length <= 0)
            return out
        var probe = resultsRepeater.count > 0 ? resultsRepeater.itemAt(0) : null
        var pitch = probe ? probe.rowHeight + probe.listGap : 72
        var padding = root.thumbPrefetchRows * pitch
        var bandTop = resultsView.contentY - padding
        var bandBottom = resultsView.contentY + resultsView.height + padding
        var previewId = root._previewedResultId()
        for (var i = 0; i < children.length; i++) {
            var row = children[i]
            if (!row || !row.result || !row.result.isImage)
                continue
            var id = String(row.result.id == null ? "" : row.result.id)
            if (!/^[0-9]+$/.test(id) || root._thumbPaths[id])
                continue
            var previewed = id === previewId
            var height = row.height
            // A row folded to zero height (search lens, category lens, or the
            // entrance wave) occupies no pixels. Ranking on its position then
            // would stack the whole window at y=0 and put every row in band.
            if (!previewed && !(height > 0))
                continue
            var distance = 0
            if (!previewed) {
                if (row.y > bandBottom)
                    distance = row.y - bandBottom
                else if (row.y + height < bandTop)
                    distance = bandTop - (row.y + height)
                if (distance > 0)
                    continue
            }
            out.push({
                id: id,
                mime: row.result.mime == null ? "" : String(row.result.mime),
                distance: previewed ? -1 : distance,
                order: i
            })
        }
        // Nearest to the band first, document order inside the band so the
        // list decodes top to bottom, and the previewed row ahead of both.
        out.sort(function (a, b) {
            if (a.distance !== b.distance)
                return a.distance - b.distance
            return a.order - b.order
        })
        return out
    }

    // The decode queue: viewport priority, one in flight, paced one per tick.
    // A closed launcher stays inert even though its real page remains mounted
    // for the next open.
    LauncherThumbScheduler {
        id: thumbQueue
        active: root.thumbnailsActive && !!root.session
                && root.session.visible === true && root.enabled
        candidates: root._thumbCandidates
        decode: root._issueThumbDecode
        decoded: root._thumbDecoded
    }

    // The one scheduling point every thumbnail decode goes through: no row owns
    // a timer, and no decode can be issued from a delegate's lifecycle.
    Timer {
        id: thumbPacer
        interval: thumbQueue.interval
        repeat: true
        running: thumbQueue.running
        onTriggered: thumbQueue.pump()
    }

    // Full decoded text per entry id: `cliphist list` previews are a single
    // truncated line, so the preview pane pulls the real content through the
    // service decode seam and swaps it in when it lands. Until then the
    // single-line preview shows; a decode superseded by a newer request is
    // retried the next time the entry is previewed.
    readonly property var _previewTexts: ({})
    readonly property var _requestedTextIds: ({})
    property int _previewTextRev: 0
    function clipFullText(item) {
        if (!item || item.isImage)
            return ""
        var id = String(item.id == null ? "" : item.id)
        if (!/^[0-9]+$/.test(id))
            return item.previewText == null ? "" : String(item.previewText)
        if (!(id in root._previewTexts)) {
            if (!(id in root._requestedTextIds)) {
                root._requestedTextIds[id] = true
                if (root.session && typeof root.session.requestTextPreview === "function")
                    root.session.requestTextPreview(id)
            }
            return item.previewText == null ? "" : String(item.previewText)
        }
        return root._previewTexts[id]
    }

    // Decoded content arrives via the session relay; image decodes report
    // file:// URLs and are owned by the thumbnail path instead.
    Connections {
        target: root.session
        ignoreUnknownSignals: true
        function onTextPreviewDecoded(id, content) {
            var text = String(content == null ? "" : content)
            if (text.indexOf("file://") === 0)
                return
            root._previewTexts[String(id)] = text
            root._previewTextRev++
        }
    }

    // Hover tracking for the preview pane; leaving a row hands preview
    // back to the keyboard selection, destruction never leaves a stale ref.
    property var _hoveredResult: null
    function trackHover(item, entered) {
        if (entered)
            _hoveredResult = item
        else if (_hoveredResult === item)
            _hoveredResult = null
    }
    function clearHover(item) {
        if (_hoveredResult === item)
            _hoveredResult = null
    }

    // Clipboard preview pane: the selected entry rendered large — decoded
    // image or full multi-line text — beside a narrowed results list.
    // Pointing at any row previews it ahead of the keyboard selection. The
    // pane takes half the page width; content centers in the viewport and
    // wheel-scrolls when it outgrows it, while drag always stays with the
    // text so long excerpts remain mouse-selectable.
    Rectangle {
        id: previewPane
        readonly property var selectedResult: {
            var s = root.session
            if (!s || s.mode !== "clipboard" || !s.results)
                return null
            if (root._hoveredResult)
                return root._hoveredResult
            return s.selectedIndex >= 0 ? (s.results[s.selectedIndex] || null) : null
        }
        readonly property bool shown: !!selectedResult
        // The decoded path lands asynchronously; mirror it onto the image
        // imperatively because a declarative source binding does not track
        // this property reliably under the qs engine.
        onPaneThumbSourceChanged: {
            // Guard identical writes: with cache:false a redundant assign
            // restarts the async load and can starve Image.Ready.
            if (paneImage.source !== paneThumbSource)
                paneImage.source = paneThumbSource
        }
        Component.onCompleted: paneImage.source = paneThumbSource
        readonly property string paneThumbSource: {
            var r = selectedResult
            if (!r || !r.isImage)
                return ""
            // Load-bearing read: the engine eliminates bare expressions,
            // so the revision must be used or this binding never re-runs
            // when the async decode lands.
            var rev = root._thumbRev
            return rev >= 0 ? root.clipThumbPath(r) : ""
        }
        // Anchored to the query card's bottom edge, which already folds the
        // lens away when a mode has no categories — so everything below
        // starts under the search field either way.
        anchors.top: queryColumn.bottom
        anchors.topMargin: root.insetQuery ? 14 : 12
        anchors.right: parent.right
        anchors.rightMargin: root.insetQuery ? 14 : 8
        anchors.bottom: parent.bottom
        width: parent.width / 2
        // Gated on the launcher chrome as well as on a selection: the pane is a
        // preview OF the launcher's list, so it cannot stay on screen when the
        // control center owns the content area. `shown` keeps its own meaning -
        // "there is a result to preview" - so the anchors that read it below are
        // unaffected by the view switch.
        visible: root.chromeVisible && shown
        color: LazerTheme.settingsCard
        radius: 6
        clip: true

        // Wheel-driven viewport: interactive stays off so a mouse drag is
        // always a text selection, never a scroll grab.
        Flickable {
            id: paneScroll
            anchors.fill: parent
            clip: true
            interactive: false
            contentWidth: width
            // Footer height rides along as bottom clearance so the last
            // line can scroll clear above the pinned metadata strip.
            contentHeight: paneColumn.height + 10 + metaCaption.height
            boundsBehavior: Flickable.StopAtBounds
            onContentHeightChanged: contentY = Math.max(0, Math.min(contentY, Math.max(0, contentHeight - height)))
            onVisibleChanged: if (visible) contentY = 0

            // target must stay null: a Flickable target refuses to be
            // driven while interactive is false, so the wheel is consumed
            // here and contentY is driven manually instead.
            WheelHandler {
                target: null
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: wheel => {
                    var delta = wheel.pixelDelta.y
                    if (delta === 0)
                        delta = wheel.angleDelta.y / 120 * 40
                    if (delta === 0)
                        return
                    var maximumY = Math.max(0, paneScroll.contentHeight - paneScroll.height)
                    paneScroll.contentY = Math.max(0, Math.min(maximumY, paneScroll.contentY - delta))
                }
            }

            Column {
                id: paneColumn
                x: (paneScroll.width - width) / 2
                y: 10
                width: paneScroll.width - 20
                spacing: 8

                // Full text preview for text entries. Read-only TextEdit is
                // the only mouse-selectable text primitive (plain Text
                // carries no selection support in Qt Quick), so a partial
                // copy never requires re-copying the whole clipboard entry.
                // Arrow/Return keys route back to the launcher list; Escape
                // bubbles to the page handler untouched.
                TextEdit {
                    id: paneText
                    // Strict checks: a plain `&&` chain yields undefined for
                    // entries without isImage, erroring and disabling the
                    // binding on the first non-image selection.
                    visible: !!previewPane.selectedResult
                             && previewPane.selectedResult.isImage !== true
                    width: parent.width
                    text: {
                        var r = previewPane.selectedResult
                        if (!r || r.isImage === true)
                            return ""
                        // Load-bearing revision read: the qs engine drops
                        // bare expressions, so the async decode landing must
                        // be referenced or this binding never re-runs.
                        var rev = root._previewTextRev
                        return rev >= 0 ? root.clipFullText(r) : ""
                    }
                    textFormat: TextEdit.PlainText
                    wrapMode: TextEdit.WrapAnywhere
                    readOnly: true
                    selectByMouse: true
                    persistentSelection: true
                    selectionColor: LazerTheme.osuPink
                    selectedTextColor: LazerTheme.textPrimary
                    color: LazerTheme.textPrimary
                    font.pixelSize: 12
                    Keys.onUpPressed: event => { event.accepted = root.navigateSelection(-1) }
                    Keys.onDownPressed: event => { event.accepted = root.navigateSelection(1) }
                    Keys.onReturnPressed: event => { root.executeSelected(); event.accepted = true }
                    Keys.onEnterPressed: event => { root.executeSelected(); event.accepted = true }
                }

                // Large decoded image for image entries: the frame fills the
                // viewport above the footer strip and PreserveAspectFit
                // scales the image up or down to use all of it.
                Rectangle {
                    id: paneImageFrame
                    visible: !!previewPane.selectedResult
                             && previewPane.selectedResult.isImage === true
                    width: parent.width
                    height: Math.max(120, paneScroll.height - 20 - metaCaption.height)
                    radius: 4
                    color: LazerTheme.settingsCardHover

                    Image {
                        id: paneImage
                        anchors.centerIn: parent
                        width: parent.width - 8
                        height: parent.height - 8
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: false
                        mipmap: true
                        // Assigned imperatively from paneThumbSource below: the
                        // qs engine does not re-run this binding on property
                        // change notifications here.
                        source: ""
                    }
                }
            }
        }

        // Metadata footer pinned to the pane bottom with an opaque rail
        // background: scrolled content slides underneath it. A direct child
        // of the pane — never the Flickable — so the anchor baseline is the
        // pane viewport rather than the content space, and it cannot drift
        // past the bottom with long text. Declared after the Flickable so
        // it paints on top; the full text already renders above, so this
        // never repeats the content itself.
        Rectangle {
            id: metaCaption
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: metaText.implicitHeight + 12
            visible: previewPane.shown && metaText.text.length > 0
            color: LazerTheme.settingsRail
            radius: 6

            Text {
                id: metaText
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    var selected = previewPane.selectedResult
                    // Load-bearing read: in-place metadata merges mutate the
                    // kept row object, so the revision must be referenced or
                    // this binding never re-runs when merged text lands.
                    var metaRev = root._clipMetaRev
                    return selected && metaRev >= 0
                            ? (selected.description || "") : ""
                }
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: LazerTheme.textMuted
                font.pixelSize: 11
            }
        }
    }

    // The list starts under the query surface; the tail that has not arrived yet
    // is drawn inside the viewport as a footer row, so nothing above the list
    // has to move while a refresh streams in.
    Flickable {
        id: resultsView
        anchors.top: queryColumn.bottom
        anchors.left: parent.left
        anchors.right: previewPane.visible ? previewPane.left : parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: root.insetQuery ? 14 : 12
        anchors.leftMargin: root.insetQuery ? 14 : 8
        anchors.rightMargin: previewPane.visible
                ? (root.insetQuery ? 14 : 12)
                : (root.insetQuery ? 14 : 8)
        clip: true
        // The list yields the content area to the control center. It is hidden,
        // not collapsed: its geometry and its delegates stay exactly as they
        // were, so returning to a launcher view shows the same rows in the same
        // places with the same selection.
        visible: root.chromeVisible && !root.sessionLoading && !root.sessionError
        contentWidth: width
        contentHeight: resultsColumn.height + listFooter.height
        // The decode queue ranks rows against this viewport, so every shape
        // change to the visible band re-derives the served order.
        onContentHeightChanged: {
            syncSelectionFrame()
            thumbQueue.wake()
        }
        onHeightChanged: thumbQueue.wake()
        boundsBehavior: Flickable.StopAtBounds
        onContentYChanged: {
            // Stretch only for a list that actually runs past the prefetch
            // band. With less content than that band, "near the end" is
            // trivially true, so every contentY change - the open's own
            // normalization, the selection glide - would stretch the window on
            // every open even though the user is nowhere near the end.
            if (contentHeight > height + 900
                    && contentY > contentHeight - height - 900)
                extendResultWindow()
            thumbQueue.wake()
        }
        flickDeceleration: 2000
        // A concealed row keeps its slot while it fades in, so the list is
        // already full height on the frame it opens and scrolling never
        // fights the wave. Gating the wheel on the reveal left the list
        // refusing input for the length of the stagger - the wheel did
        // nothing until the last row had landed.
        interactive: true

        // Live results, not slots: window sizing, selection positioning and
        // every row lookup work in result indices.
        readonly property int resultCount: root.windowedResults.length
        readonly property int slotCount: root.rowSlotCount

        // Glide the shared frame onto the selected row; hide it while the
        // selection is empty or the target row is still folded.
        function syncSelectionFrame() {
            var service = root.session
            var current = service && service.results && service.selectedIndex >= 0
                    ? service.results[service.selectedIndex] : null
            var row = null
            if (current) {
                for (var i = 0; i < resultsView.resultCount; i++) {
                    var candidate = resultsRepeater.itemAt(i)
                    // A row mid-fling-exit is invisible; it must never
                    // anchor the shared frame over blank space.
                    if (candidate && !candidate.closing && candidate.result
                            && String(candidate.result.id) === String(current.id)) {
                        row = candidate
                        break
                    }
                }
            }
            // Hide while the target row is folded; reveal once it stands up.
            root.selectionAnchor = (row && row.height > 4) ? row : null
        }

        function resultAt(index) {
            return resultsRepeater.itemAt(index)
        }

        // Folding collapses most rows on a query change; a reused page can
        // keep a stale contentY far past the new end, parking the viewport
        // on blank space where matches exist but are invisible. Clamp it
        // whenever the content shape changes.
        function normalizeViewport() {
            var maximumY = Math.max(0, resultsView.contentHeight - resultsView.height)
            if (resultsView.contentY < -1)
                resultsView.contentY = 0
            else if (resultsView.contentY > maximumY + 1)
                resultsView.contentY = maximumY
        }

        // Grow the materialized window when the viewport approaches its
        // end so long histories browse without a hard cap.
        function extendResultWindow() {
            var pool = root.session ? root.session.displayPool : null
            if (!pool || pool.length <= root._resultWindowLimit)
                return
            root._resultWindowExtra += root.resultWindowStep
            // New delegates arrive in their held geometry, so the window has
            // to run the commit that releases them - otherwise rows nobody
            // ever released keep the viewport non-interactive.
            root._scheduleRowsCommit()
        }

        function positionToSelection() {
            var service = root.session
            if (!service || service.selectedIndex < 0 || !service.results)
                return
            // Keyboard navigation can outrun the window; extend until the
            // target row exists before positioning.
            while (service.selectedIndex >= resultsView.resultCount) {
                var before = resultsView.resultCount
                extendResultWindow()
                if (resultsView.resultCount === before)
                    return
            }
            var current = service.results[service.selectedIndex]
            if (!current)
                return
            for (var i = 0; i < resultsView.resultCount; i++) {
                var row = resultsRepeater.itemAt(i)
                if (row && row.result && row.result.id === current.id) {
                    scrollTo(i)
                    return
                }
            }
        }

        // Center the target row with the shared eased programmatic scroll;
        // defer while the entrance wave is still reshaping the layout.
        function scrollTo(index) {
            var row = resultAt(index)
            if (!row || row.height <= 0) {
                root._deferredScrollIndex = index
                return
            }
            var maximumY = Math.max(0, resultsView.contentHeight - resultsView.height)
            var target = row.y - Math.max(0, (resultsView.height - row.height) / 2)
            target = Math.max(0, Math.min(maximumY, target))
            _cancelScrollEdge()
            scrollBounce.stop()
            scrollAnim.to = target
            scrollAnim.duration = MotionTokens.reducedMotion ? 0 : 300
            scrollAnim.restart()
        }

        function _settleScrollEdge() {            var maximumY = Math.max(0, resultsView.contentHeight - resultsView.height)
            edgeDriving = false
            scrollEdgeSettleTimer.stop()
            scrollDriveAnim.stop()
            scrollSettleAnim.to = Math.max(0, Math.min(maximumY, resultsView.contentY))
            scrollSettleAnim.restart()
        }

        function _cancelScrollEdge() {
            edgeDriving = false
            scrollEdgeSettleTimer.stop()
            scrollSettleAnim.stop()
            scrollDriveAnim.stop()
        }

        property bool edgeDriving: false
        readonly property real edgeTakeoverDistance: 80
        // Hard overscroll rails for the edge-takeover and bounce bands,
        // mirroring LazerSettingsSections.overscrollDistance.
        readonly property real overscrollDistance: 88

        // Rubber-band resistance, ported from
        // LazerSettingsSections._resistedTarget: the further past the bound,
        // the smaller each additional step becomes, like a spring approaching
        // full tension. (Callers must use the resultsView receiver: this
        // helper lives on the viewport, not the page.)
        function _resistedScrollTarget(current, delta, bound) {
            var past = Math.max(0, Math.abs(current - bound))
            var tension = Math.min(1, past / resultsView.overscrollDistance)
            return current - delta * (1 - tension)
        }

        Timer {
            id: scrollEdgeSettleTimer
            interval: 140
            repeat: false
            onTriggered: resultsView._settleScrollEdge()
        }

        NumberAnimation {
            id: scrollSettleAnim
            target: resultsView
            property: "contentY"
            duration: MotionTokens.reducedMotion ? 0 : 260
            easing.type: Easing.InOutCubic
        }

        NumberAnimation {
            id: scrollDriveAnim
            target: resultsView
            property: "contentY"
            duration: MotionTokens.reducedMotion ? 0 : 80
            easing.type: Easing.OutQuint
        }

        SequentialAnimation {
            id: scrollBounce
            NumberAnimation {
                id: scrollBounceOut
                target: resultsView
                property: "contentY"
                duration: MotionTokens.reducedMotion ? 0 : 160
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                id: scrollBounceBack
                target: resultsView
                property: "contentY"
                duration: MotionTokens.reducedMotion ? 0 : 260
                easing.type: Easing.InOutCubic
            }
        }

        NumberAnimation {
            id: scrollAnim
            target: resultsView
            property: "contentY"
            duration: 300
            easing.type: Easing.OutQuint
        }

        WheelHandler {
            orientation: Qt.Vertical
            target: null
            blocking: false
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: wheel => {
                var scrollingDown = wheel.angleDelta.y < 0 || wheel.pixelDelta.y < 0
                var delta = wheel.pixelDelta.y
                if (delta === 0)
                    delta = wheel.angleDelta.y / 120 * 40
                if (delta === 0)
                    return
                var maximumY = Math.max(0, resultsView.contentHeight - resultsView.height)
                var nearBottom = scrollingDown && maximumY - resultsView.contentY <= resultsView.edgeTakeoverDistance
                var nearTop = !scrollingDown && resultsView.contentY <= resultsView.edgeTakeoverDistance
                if (resultsView.edgeDriving && !nearBottom && !nearTop)
                    resultsView._settleScrollEdge()
                if (!MotionTokens.reducedMotion && (nearBottom || nearTop)) {
                    resultsView.cancelFlick()
                    resultsView.edgeDriving = true
                    scrollEdgeSettleTimer.restart()
                    scrollSettleAnim.stop()
                    var proposed = resultsView.contentY - delta
                    if (proposed < 0)
                        proposed = resultsView._resistedScrollTarget(resultsView.contentY, delta, 0)
                    else if (proposed > maximumY)
                        proposed = resultsView._resistedScrollTarget(resultsView.contentY, delta, maximumY)
                    proposed = Math.max(-resultsView.overscrollDistance,
                                        Math.min(maximumY + resultsView.overscrollDistance, proposed))
                    scrollDriveAnim.from = resultsView.contentY
                    scrollDriveAnim.to = proposed
                    scrollDriveAnim.restart()
                    return
                }
                if ((!scrollingDown && resultsView.contentY <= 0.5)
                        || (scrollingDown && resultsView.contentY >= maximumY - 0.5)) {
                    resultsView.cancelFlick()
                    scrollBounceOut.from = resultsView.contentY
                    scrollBounceOut.to = Math.max(-resultsView.overscrollDistance,
                                                        Math.min(maximumY + resultsView.overscrollDistance,
                                                                 resultsView.contentY - delta))
                    scrollBounceBack.to = Math.max(0, Math.min(maximumY, scrollBounceOut.to))
                    scrollBounce.restart()
                }
            }
        }


        Column {
            id: resultsColumn
            width: parent.width
            spacing: 0

            // Count model (not the result array): same-length pool swaps
            // only swap row content instead of rebuilding every delegate.
            // Each row reads its item by index; prefix-stable pools resolve
            // to the identical object and no binding re-fires. Length
            // changes still rebuild, and the commit choreography tells
            // survivors from newcomers by id (see _holdAndScheduleReleases).
            Repeater {
                id: resultsRepeater
                model: root.rowSlotCount

                delegate: LauncherResultRow {
                    required property int index
                    width: resultsColumn.width
                    result: root.windowedResults[index]
                    Component.onCompleted: root.requestClipThumb(result)
                    onResultChanged: root.requestClipThumb(result)
                    thumbPath: root._thumbRev >= 0 ? root.clipThumbPath(result) : ""
                    metaStamp: root._clipMetaRev
                    iconRetryRevision: root._iconRetryRev
                    searchQuery: root.activeSearchText
                    categoryFilter: root.activeCategory
                    // The shared rect's band, so this row lights the slice of itself the
                    // rect is over rather than deciding for itself whether it is selected.
                    selectionTintTop: root.selectionTintTop
                    selectionTintHeight: root.selectionTintHeight
                    selected: {
                        if (!root.session || !root.session.results || root.session.selectedIndex < 0)
                            return false
                        var sel = root.session.results[root.session.selectedIndex]
                        return !!sel && !!result && String(sel.id) === String(result.id)
                    }
                    onActivated: {
                        if (root.session)
                            root.session.execute(result)
                    }
                    onHoveredChanged: root.trackHover(result, hovered)
                    // The page owns the decoded-path cache, so a row that could
                    // not load its thumbnail reports here and gets re-armed on
                    // the next open rather than staying blank for good.
                    onThumbLoadFailed: id => root.noteThumbLoadFailed(id)
                    Component.onDestruction: root.clearHover(result)
                    onExitFlingRequested: spec => root.exitFlingRequested(spec)
                }
            }
        }

        // Tail of the list: the not-yet-arrived region, marked by the shared
        // loading ring. Sits directly under the rows so a batch landing
        // extends the list downward instead of moving anything above it.
        LauncherListFooter {
            id: listFooter
            objectName: "launcherListFooter"
            y: resultsColumn.height
            width: resultsView.width - 8
            loadingMore: root.streamingResults
        }

        // One shared focus frame for the whole list: glides between rows
        // like the settings sidebar's shared indicator instead of every row
        // showing/hiding its own.
        Rectangle {
            id: selectionFrame
            objectName: "selectionFrame"
            z: 5
            radius: 6
            // Border-only glide: the landing highlight is the shared rect's band clipped
            // to each row, so this rectangle never covers text or icons either - it is
            // the same rectangle the tint is measured from, which is why the two cannot
            // disagree about where the selection is.
            color: "transparent"
            border.width: root.selectionAnchor ? 1.5 : 0
            border.color: LazerTheme.settingsAccent
            enabled: false

            // Size snaps from constants and visibility fades; only y glides.
            // Tracking the anchor row's animated height made every search
            // re-rank visibly squash the frame through fold mid-heights.
            opacity: root.selectionAnchor && root.selectionAnchor.fullyShown ? 1 : 0
            Behavior on opacity {
                enabled: !MotionTokens.reducedMotion
                NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint }
            }

            x: root.selectionAnchor ? root.selectionAnchor.x : 0
            y: root.selectionAnchor ? root.selectionAnchor.y : 0
            width: root.selectionAnchor ? root.selectionAnchor.width : 0
            height: root.selectionAnchor ? root.selectionAnchor.rowHeight : 0

            Behavior on y {
                enabled: !MotionTokens.reducedMotion
                NumberAnimation { duration: MotionTokens.settingsSidebarCollapse; easing.type: Easing.OutQuint }
            }
        }

}

    // Loading surface keeps its own body color so stale rows never linger.
    Rectangle {
        id: loadingSurface
        objectName: "launcherLoadingSurface"
        anchors.fill: resultsView
        // Part of the launcher chrome: a spinner over the control center would
        // report a search that is not running. `sessionLoading` itself is
        // unchanged, so a background refresh landing while the view is up does
        // not clear this latch on the way back.
        visible: root.chromeVisible && root.sessionLoading
        radius: 0
        color: "transparent"

        // osu!lazer's loading ring, sized up from the popup's 16px because this
        // is the one place afloat waits on something the user is watching for.
        Column {
            anchors.centerIn: parent
            spacing: 10

            LazerLoadingRing {
                objectName: "launcherLoadingRing"
                width: 28
                height: 28
                active: root.sessionLoading
                running: root.sessionLoading
            }

            Text {
                objectName: "launcherLoadingText"
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Searching…"
                color: LazerTheme.textMuted
                font.pixelSize: 14
            }
        }
    }

    // Empty state stays interactive so the next keystroke can repopulate.
    Item {
        id: emptyStateHost
        anchors.fill: resultsView
        visible: root.chromeVisible && root.sessionEmpty

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            // An empty lens and an empty query are different failures: name
            // the half of the filter that came up dry.
            text: root.activeCategory.length > 0 ? "No results in this category" : "No results"
            color: LazerTheme.textMuted
            font.pixelSize: 14
        }
    }

    // Error state offers retry without closing or dropping search focus.
    Item {
        id: errorStateHost
        anchors.fill: resultsView
        visible: root.chromeVisible && root.sessionError

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.session && root.session.error ? String(root.session.error) : ""
                color: LazerTheme.textMuted
                font.pixelSize: 14
            }

            // Sharp retry strip following the reset-button hover contract,
            // keyboard-reachable and executable with Return or Space.
            Rectangle {
                id: retryButton
                anchors.horizontalCenter: parent.horizontalCenter
                width: 96
                height: 32
                radius: 0
                activeFocusOnTab: true
                color: retryHover.hovered || retryPress.pressed
                       ? LazerTheme.settingsResetSurfaceHover : LazerTheme.settingsResetSurface
                scale: retryPress.pressed ? MotionTokens.pressScale : 1
                Behavior on scale {
                    enabled: !MotionTokens.reducedMotion
                    NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint }
                }

                Text {
                    anchors.centerIn: parent
                    text: "Retry"
                    color: LazerTheme.textPrimary
                    font.pixelSize: 13
                }

                HoverHandler { id: retryHover }
                TapHandler { id: retryPress; onTapped: root.requestRetry() }
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                        root.requestRetry()
                        event.accepted = true
                    }
                }
            }
        }
    }

    // --- The control center: this page's fourth view ---
    //
    // ONE Loader, filling the whole content area. It is inside this page rather
    // than inside the wave host, which is what makes the control center a VIEW
    // rather than a sibling route: the host keeps its single retained Loader on
    // its single surface, and this swaps what the content area shows underneath
    // one unchanged header and one unchanged rail.
    //
    // No cross-fade here. The host's own sibling-route swap animates because two
    // whole pages replace each other; a view swap replaces the content area with
    // one view that already knows its own entrance, and `MotionTokens.waveRoute`
    // is spent on the control center's OWN sub-page hand-off instead. Inventing a
    // second reveal for this would make a faster, quieter switch than the rail's
    // own indicator already gives - the accent strip moving to the fourth row IS
    // the transition, exactly as it is for the three mode filters.
    //
    // `active` latches on the first build (see `controlCenterBuilt`) so a control
    // center is constructed once per page and then survives every switch back to
    // a launcher view - the same retention contract the host's route page has.
    Loader {
        id: controlCenterLoader
        objectName: "launcherControlCenter"
        anchors.fill: parent
        // The request OR the latch: the first open asks for it, and the latch
        // keeps it afterwards. `active: controlCenterBuilt` alone would deadlock -
        // a Loader that is never active can never load, so the latch that its own
        // onLoaded sets would never be reached.
        active: root.controlCenterActive || root.controlCenterBuilt
        visible: root.controlCenterActive
        // Input belongs to whatever is on top. Without this a card under the
        // control center's first frame would still answer a click meant for the
        // launcher list behind it - and, while the view is up, the launcher list's
        // own invisible rows would claim keys meant for the controls.
        enabled: root.controlCenterActive
        sourceComponent: controlCenterComponent
        onLoaded: {
            root.controlCenterBuilt = true
            // The focus hand-off asked for by `openControlCenter` may have run
            // before this item existed - the Loader is asynchronous, and on the
            // FIRST open it always is. Asking again here is what makes the first
            // open hand the keyboard over exactly like every later one; without it
            // the view would come up with no keyboard owner at all.
            if (root.controlCenterActive)
                root.handOverControlCenterFocus()
        }
    }

    Component {
        id: controlCenterComponent
        ControlCenter {
            // The injected services are forwarded UNCHANGED, so the view and its
            // same-surface sub-pages can never describe two different instances of
            // one service. A null service is a defined state: the overview renders
            // its explicit unavailable/optional state rather than throwing.
            networkService: root.networkService
            bluetoothService: root.bluetoothService
            volumeService: root.volumeService
            mediaService: root.mediaService
            batteryService: root.batteryService
            notificationService: root.notificationService
            weatherService: root.weatherService
        }
    }

    // Test and shell seams: the mounted view, and the switch's own observable
    // edge so a test can assert what the rail actually did rather than inferring
    // it from a re-render.
    readonly property bool controlCenterVisible: controlCenterLoader.visible
        && controlCenterLoader.item !== null
}
