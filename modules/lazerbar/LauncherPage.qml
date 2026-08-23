import QtQuick
import "../../services/launcher"
import "../../services/LauncherLogic.js" as LauncherLogic

// Keyboard-first launcher content page for the wave surface: auto-focused
// search rail, mode sidebar data with prefix rewriting, service-driven result
// list, and explicit loading / empty / error / retry states. All session
// state flows through the injected session; the page never owns launcher data.
Item {
    id: root

    // Session contract: any object exposing the observable LauncherService
    // state (visible, query, mode, results, loading, error, selectedIndex)
    // plus refresh/selectNext/selectPrevious/executeSelected/execute, where
    // query edits re-request data while open. Production binds
    // Services.LauncherService; tests inject deterministic sessions. The
    // embedded default keeps the page self-contained without Quickshell.
    property var session: embeddedSession

    // Data surfaced to the wave shell header and sidebar.
    readonly property string title: "Launcher"
    readonly property string description: root.modeDescription(activeMode)
    readonly property var sidebarEntries: [
        { id: "apps", label: "Apps", icon: "icons/apps.svg" },
        { id: "clipboard", label: "Clipboard", icon: "icons/clipboard.svg" },
        { id: "shortcuts", label: "Shortcuts", icon: "icons/keyboard.svg" }
    ]
    readonly property string activeMode: root.session && root.session.mode != null ? String(root.session.mode) : ""

    // Normalized free-text portion of the query; rows fold themselves against
    // it exactly like settings rows do under a search filter.
    readonly property string activeSearchText: {
        if (!root.session || root.session.query == null)
            return ""
        return LauncherLogic.parseQuery(String(root.session.query)).text
    }

    // Emitted when a sidebar-driven mode change is applied to the session.
    signal modeChangeRequested(string mode)

    readonly property alias searchField: searchSurface
    // Result access for tests and shell wiring.
    readonly property alias resultsView: resultsView
    readonly property int resultCount: resultsView.resultCount
    function resultAt(index) { return resultsView.resultAt(index) }
    readonly property alias loadingState: loadingSurface
    readonly property alias emptyState: emptyStateHost
    readonly property alias errorState: errorStateHost
    readonly property alias retryButton: retryButton

    implicitWidth: 400
    implicitHeight: 300

    LauncherSession { id: embeddedSession }

    Component.onCompleted: root.adoptSessionFocus()

    onSessionChanged: root.adoptSessionFocus()

    Connections {
        target: root.session
        function onVisibleChanged() {
            if (root.session.visible) {
                root.focusSearch()
                root._firstFillPending = true
            } else {
                root.cancelEntranceWave()
                entranceSettle.stop()
                root._firstFillPending = false
            }
        }
        function onSelectedIndexChanged() {
            resultsView.positionToSelection()
        }
        function onDisplayPoolChanged() {
            Qt.callLater(root._scheduleReleases)
        }
    }

    // Fallback key handling for focus held by the page itself or by rows;
    // the search field handles its own keys first and stops propagation.
    Keys.onPressed: event => {
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

    function isKnownMode(modeId) {
        for (var i = 0; i < root.sidebarEntries.length; i++)
            if (root.sidebarEntries[i].id === modeId)
                return true
        return false
    }

    function requestRetry() {
        if (root.session && typeof root.session.refresh === "function")
            root.session.refresh()
    }

    function executeSelected() {
        if (root.session && typeof root.session.executeSelected === "function")
            root.session.executeSelected()
    }

    function navigateSelection(direction) {
        if (!root.session)
            return false
        if (direction < 0 && typeof root.session.selectPrevious === "function") {
            root.session.selectPrevious()
            return true
        }
        if (direction > 0 && typeof root.session.selectNext === "function") {
            root.session.selectNext()
            return true
        }
        return false
    }

    // Decides Escape through the shared pure keyboard contract: with input,
    // clear the query and consume the key; otherwise report "close" to the
    // owning wave shell by leaving the key unaccepted. The page never tears
    // down its own session.
    function handleEscape() {
        if (!root.session)
            return false
        var query = root.session.query == null ? "" : String(root.session.query)
        var action = LauncherLogic.keyboardAction(
            "escape",
            query.length > 0,
            root.session.selectedIndex >= 0,
            !root.session.loading && !root.session.error
        )
        if (action === "clear")
            root.session.query = ""
        return action === "clear"
    }

    function focusSearch() {
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
    readonly property bool sessionEmpty: root.session && root.session.visible
                                         && !root.session.loading
                                         && !root.session.error
                                         && (!root.session.results || root.session.results.length === 0)
    readonly property bool stateVisible: sessionLoading || sessionError || sessionEmpty

    // Entrance wave, mirroring LazerSettingsSections.playEntranceWave:
    // hold every row instantly, release top-to-bottom on 18ms slots from a
    // 120ms base, and hold scrolling until the reveal transitions land.
    readonly property bool entranceBusy: _anyRowHeld() || entranceSettle.running
    readonly property int entranceBaseDelay: 120
    readonly property int entranceSlotInterval: 18

    property int _deferredScrollIndex: -1
    property bool _firstFillPending: false

    Timer {
        id: entranceSettle
        interval: MotionTokens.slow + MotionTokens.slow / 2 + 100
        repeat: false
        onTriggered: {
            if (root._deferredScrollIndex >= 0) {
                var deferred = root._deferredScrollIndex
                root._deferredScrollIndex = -1
                resultsView.scrollTo(deferred)
            }
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
            entranceSettle.restart()
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

    // Refills cascade like the settings search-exit delay: each new row set
    // unfolds with a small position-based stagger instead of a full wave.
    function playRefillCascade() {
        var children = resultsColumn.children
        if (MotionTokens.reducedMotion) {
            for (var r = 0; r < children.length; r++)
                if (children[r].releaseInstantly !== undefined)
                    children[r].releaseInstantly()
            return
        }
        for (var i = 0; i < children.length; i++) {
            if (children[i].holdInstantly === undefined)
                continue
            children[i].holdInstantly()
            children[i].playReveal(children[i].entryExitDelay)
        }
        entranceSettle.restart()
    }

    // Route each fresh result set through the wave (first fill after open)
    // or the lighter cascade (subsequent query refills).
    function _scheduleReleases() {
        if (resultsView.resultCount <= 0)
            return
        if (root._firstFillPending) {
            root._firstFillPending = false
            root.playEntranceWave()
        } else {
            root.playRefillCascade()
        }
    }

    // Full-width sharp search rail carrying the osu caret text field.
    FocusScope {
        id: searchSurface
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 44

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

        Rectangle {
            anchors.fill: parent
            radius: 0
            color: LazerTheme.settingsRail
        }

        OsuTextField {
            id: editor
            anchors.left: parent.left
            anchors.leftMargin: 12
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

    // Result viewport: settings-panel structure (Flickable + folding rows)
    // so entrance wave, query reordering, and the scroll contract behave
    // exactly like LazerSettingsSections.
    Flickable {
        id: resultsView
        anchors.top: searchSurface.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: 12
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        clip: true
        visible: !root.stateVisible
        contentWidth: width
        contentHeight: resultsColumn.height
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 2000
        interactive: !root.entranceBusy

        readonly property int resultCount: resultsRepeater.count

        function resultAt(index) {
            return resultsRepeater.itemAt(index)
        }

        function positionToSelection() {
            var service = root.session
            if (!service || service.selectedIndex < 0 || !service.results)
                return
            var current = service.results[service.selectedIndex]
            if (!current)
                return
            for (var i = 0; i < resultsRepeater.count; i++) {
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

        function _cancelScrollEdge() {
            edgeDriving = false
            scrollEdgeSettleTimer.stop()
            scrollSettleAnim.stop()
            scrollDriveAnim.stop()
        }

        property bool edgeDriving: false
        readonly property real edgeTakeoverDistance: 80

        Timer {
            id: scrollEdgeSettleTimer
            interval: 140
            repeat: false
            onTriggered: root._settleScrollEdge()
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
                if (root.entranceBusy)
                    return
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
                    root._settleScrollEdge()
                if (!MotionTokens.reducedMotion && (nearBottom || nearTop)) {
                    resultsView.cancelFlick()
                    resultsView.edgeDriving = true
                    scrollEdgeSettleTimer.restart()
                    scrollSettleAnim.stop()
                    var proposed = resultsView.contentY - delta
                    if (proposed < 0)
                        proposed = root._resistedScrollTarget(resultsView.contentY, delta, 0)
                    else if (proposed > maximumY)
                        proposed = root._resistedScrollTarget(resultsView.contentY, delta, maximumY)
                    proposed = Math.max(-88, Math.min(maximumY + 88, proposed))
                    scrollDriveAnim.from = resultsView.contentY
                    scrollDriveAnim.to = proposed
                    scrollDriveAnim.restart()
                    return
                }
                if ((!scrollingDown && resultsView.contentY <= 0.5)
                        || (scrollingDown && resultsView.contentY >= maximumY - 0.5)) {
                    resultsView.cancelFlick()
                    scrollBounceOut.from = resultsView.contentY
                    scrollBounceOut.to = Math.max(-88, Math.min(maximumY + 88, resultsView.contentY - delta))
                    scrollBounceBack.to = Math.max(0, Math.min(maximumY, scrollBounceOut.to))
                    scrollBounce.restart()
                }
            }
        }

        Column {
            id: resultsColumn
            width: parent.width
            spacing: 0

            Repeater {
                id: resultsRepeater
                model: root.session && root.session.results ? root.session.results : []

                delegate: LauncherResultRow {
                    required property var modelData
                    required property int index
                    width: resultsColumn.width
                    result: modelData
                    revealHeld: true
                    selected: root.session && index === root.session.selectedIndex
                    onActivated: {
                        if (root.session)
                            root.session.execute(modelData)
                    }
                }
            }
        }
    }

    // Loading surface keeps its own body color so stale rows never linger.
    Rectangle {
        id: loadingSurface
        anchors.fill: resultsView
        visible: root.sessionLoading
        radius: 0
        color: "transparent"

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            text: "Searching..."
            color: LazerTheme.textMuted
            font.pixelSize: 14
        }
    }

    // Empty state stays interactive so the next keystroke can repopulate.
    Item {
        id: emptyStateHost
        anchors.fill: resultsView
        visible: root.sessionEmpty

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            text: "No results"
            color: LazerTheme.textMuted
            font.pixelSize: 14
        }
    }

    // Error state offers retry without closing or dropping search focus.
    Item {
        id: errorStateHost
        anchors.fill: resultsView
        visible: root.sessionError

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
}
