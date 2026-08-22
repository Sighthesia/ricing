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
    // plus refresh/selectNext/selectPrevious/executeSelected/handleKey, where
    // query edits re-request data while open. Production binds
    // Services.LauncherService; tests inject deterministic sessions. The
    // embedded default keeps the page self-contained without Quickshell.
    property var session: embeddedSession

    // Data surfaced to the wave shell header and sidebar.
    readonly property string title: "Launcher"
    readonly property string description: root.modeDescription(activeMode)
    readonly property var sidebarEntries: [
        { id: "apps", label: "Apps" },
        { id: "clipboard", label: "Clipboard" },
        { id: "shortcuts", label: "Shortcuts" }
    ]
    readonly property string activeMode: root.session && root.session.mode != null ? String(root.session.mode) : ""

    // Emitted when a sidebar-driven mode change is applied to the session.
    signal modeChangeRequested(string mode)

    readonly property alias searchField: searchSurface
    readonly property alias resultsList: resultsListView
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
            if (root.session.visible)
                root.focusSearch()
        }
        function onSelectedIndexChanged() {
            resultsListView.positionToSelection()
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
        case Qt.Key_Escape: {
            var action = root.sessionEscapeAction()
            // A close falls through so the owning wave shell closes itself.
            event.accepted = action !== "close"
            break
        }
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

    // Returns the action taken for Escape ("clear" or "close").
    function sessionEscapeAction() {
        if (root.session && typeof root.session.handleKey === "function")
            return String(root.session.handleKey("escape"))
        return ""
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
    // editing session and keyboard focus survive every transition.
    readonly property bool sessionLoading: root.session && root.session.loading && !root.session.error
    readonly property bool sessionError: root.session && !root.session.loading && !!root.session.error
    readonly property bool sessionEmpty: root.session && !root.session.loading
                                          && !root.session.error
                                          && (!root.session.results || root.session.results.length === 0)
    readonly property bool stateVisible: sessionLoading || sessionError || sessionEmpty

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

        onQueryTextChanged: {
            if (queryText === _lastPushedQuery)
                return
            _lastPushedQuery = queryText
            _syncingEditor = true
            editor.suppressDeleteFx = true
            editor.text = queryText
            editor.suppressDeleteFx = false
            _syncingEditor = false
        }
        Component.onCompleted: onQueryTextChanged()

        function focusEditor() {
            editor.forceActiveFocus()
        }

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
            Keys.onEscapePressed: event => {
                var action = root.sessionEscapeAction()
                event.accepted = action !== "close"
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

    // Result viewport: fixed sharp rows bound to the service selection.
    ListView {
        id: resultsListView
        anchors.top: searchSurface.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: 12
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 2
        clip: true
        visible: !root.stateVisible
        model: root.session && root.session.results ? root.session.results : []

        function positionToSelection() {
            if (!root.session || root.session.selectedIndex < 0)
                return
            if (root.session.selectedIndex >= count)
                return
            positionViewAtIndex(root.session.selectedIndex, ListView.Contain)
        }

        delegate: LauncherResultRow {
            required property var modelData
            required property int index
            width: ListView.view.width
            result: modelData
            selected: root.session && index === root.session.selectedIndex
            onActivated: {
                if (root.session)
                    root.session.execute(modelData)
            }
        }
    }

    // Loading surface keeps its own body color so stale rows never linger.
    Rectangle {
        id: loadingSurface
        anchors.fill: resultsListView
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
        anchors.fill: resultsListView
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
        anchors.fill: resultsListView
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

            // Sharp retry strip following the reset-button hover contract.
            Rectangle {
                id: retryButton
                anchors.horizontalCenter: parent.horizontalCenter
                width: 96
                height: 32
                radius: 0
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
            }
        }
    }
}
