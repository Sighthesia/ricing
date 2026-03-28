import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "." as LauncherParts
import "providers" as LauncherProviders

// Central search + results component embedded inside LauncherPanel.
// Owns all providers and routes queries to the active one.
Item {
    id: root

    readonly property var _searchHeader: _searchHeaderItem
    readonly property var _resultsList: _resultsListItem
    readonly property string _modeLabel: (_searchHeader && _searchHeader.text.startsWith(">clip"))
        ? "剪切板"
        : "应用"

    property int _selectedIndex: -1
    property var _providers: [appProvider, clipProvider]
    property var _resultData: []
    property var _pendingDisplayItems: []
    property var _pendingResultData: []
    property bool _suspendRefresh: false
    property bool panelActive: LauncherService.isOpen

    function _log(message) {
        console.info("[DymicShell:LauncherCore]", message,
            "panelActive=", root.panelActive,
            "serviceOpen=", LauncherService.isOpen,
            "query=", _searchHeader ? _searchHeader.text : "",
            "results=", root._resultData.length)
    }

    function _providerLabel(provider): string {
        if (provider === clipProvider)
            return "clipboard"
        if (provider === appProvider)
            return "applications"
        return "unknown"
    }

    // Parallel stores: ListModel holds display-only scalars; _resultData holds
    // the full result objects including onActivate functions (ListModel cannot
    // store JS functions — they are stripped on append).
    ListModel { id: _results }

    Timer {
        id: _swapTimer
        // Wait for old items to finish short exit before model swap.
        // FIXME: +20ms safety margin is empirical; expose as token if reused.
        interval: SettingsService.data.animation.staggerExitDuration + 20
        repeat: false
        onTriggered: root._applyPendingResults()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        LauncherParts.LauncherSearchHeader {
            id: _searchHeaderItem
            modeLabel: root._modeLabel

            onQueryChanged: Qt.callLater(root._refreshResults)
            onMoveSelectionUp: {
                if (root._selectedIndex > 0) root._selectedIndex--;
                _resultsList.positionSelection(root._selectedIndex);
            }
            onMoveSelectionDown: {
                if (root._selectedIndex < _results.count - 1) root._selectedIndex++;
                _resultsList.positionSelection(root._selectedIndex);
            }
            onActivateRequested: root._activateCurrent()
            onCloseRequested: LauncherService.close()
        }

        // Divider
        Rectangle {
            id: s_divider
            Layout.fillWidth: true
            height: 1
            color: Colors.border

            function runEnter() {
            }

            function runExit() {
            }
        }

        LauncherParts.LauncherResultsList {
            id: _resultsListItem
            model: _results
            selectedIndex: root._selectedIndex

            onSelectRequested: (index) => {
                root._selectedIndex = index;
            }
            onActivateRequested: (index) => {
                root._selectedIndex = index;
                root._activateCurrent();
            }
        }
    }

    // Provider instances (children of LauncherCore)
    LauncherProviders.ApplicationsProvider { id: appProvider }
    LauncherProviders.ClipboardProvider { id: clipProvider }

    // Called by LauncherPanel after panel becomes active
    function openPanel(): void {
        root._log("open panel")
        _results.clear()
        _searchHeader.text = LauncherService.prefillText
        _searchHeader.focusInput()
        _refreshResults()

        for (let i = 0; i < _providers.length; i++) {
            _providers[i].onOpened()
        }
    }

    // Called by LauncherPanel when closing
    function closePanel(): void {
        root._log("close panel")
        _swapTimer.stop()
        _pendingDisplayItems = []
        _pendingResultData = []
        _suspendRefresh = true
        _searchHeader.text = ""
        _results.clear()
        root._resultData = []
        _suspendRefresh = false
    }

    function setQueryText(text): void {
        root._log("set query text to '" + text + "'")
        _searchHeader.text = text
        _searchHeader.focusInput()
        _refreshResults()
    }

    function focusSearch(): void {
        _searchHeader.focusInput()
    }

    function runStructuralEnter(): void {
        if (_searchHeader && _searchHeader.runEnter)
            _searchHeader.runEnter()
        if (s_divider && s_divider.runEnter)
            s_divider.runEnter()
        if (_resultsList && _resultsList.runEnter)
            _resultsList.runEnter()
    }

    function runStructuralExit(): void {
        if (_searchHeader && _searchHeader.runExit)
            _searchHeader.runExit()
        if (s_divider && s_divider.runExit)
            s_divider.runExit()
        if (_resultsList && _resultsList.runExit)
            _resultsList.runExit()
    }

    function _activeProvider(): var {
        let text = _searchHeader.text
        if (text.startsWith(">clip")) {
            root._log("provider resolved to clipboard")
            return clipProvider
        }

        root._log("provider resolved to applications")
        return appProvider
    }

    function _refreshResults(): void {
        if (_suspendRefresh || !root.panelActive) {
            root._log("refresh skipped")
            return
        }

        let provider = _activeProvider()
        if (!provider) {
            root._log("refresh skipped: missing provider")
            return
        }

        let q = _searchHeader.text
        if (q.startsWith(">clip ")) q = q.substring(6)
        else if (q === ">clip") q = ""

        let items = provider.getResults(q)
        root._log("provider=" + root._providerLabel(provider) + " query='" + q + "' items=" + items.length)
        let displayItems = []
        for (let i = 0; i < items.length; i++) {
            displayItems.push({
                name:        items[i].name        || "",
                description: items[i].description || "",
                icon:        items[i].icon        || ""
            })
        }

        if (_results.count === 0) {
            _swapTimer.stop()
            _pendingDisplayItems = []
            _pendingResultData = []
            _results.clear()
            root._resultData = items
            for (let j = 0; j < displayItems.length; j++) {
                _results.append(displayItems[j])
            }
            _selectedIndex = items.length > 0 ? 0 : -1
            root._log("applied immediate results")
            return
        }

        _pendingDisplayItems = displayItems
        _pendingResultData = items
        if (!_swapTimer.running) {
            _runVisibleExit()
            _swapTimer.restart()
        }
    }

    function _runVisibleExit(): void {
        for (let i = 0; i < _results.count; i++) {
            let delegate = _resultsList.delegateAtIndex(i)
            if (delegate && delegate.runExit) delegate.runExit()
        }
    }

    function _applyPendingResults(): void {
        _results.clear()
        root._resultData = _pendingResultData
        for (let i = 0; i < _pendingDisplayItems.length; i++) {
            _results.append(_pendingDisplayItems[i])
        }
        _pendingDisplayItems = []
        _pendingResultData = []
        _selectedIndex = root._resultData.length > 0 ? 0 : -1
        root._log("applied pending results")
    }

    function _activateCurrent(): void {
        if (root._selectedIndex < 0 || root._selectedIndex >= root._resultData.length) {
            root._log("activate skipped")
            return
        }

        let item = root._resultData[root._selectedIndex]
        root._log("activating index=" + root._selectedIndex + " name='" + (item && item.name ? item.name : "") + "'")
        LauncherService.close()
        if (item && item.onActivate) item.onActivate()
    }

    // Re-query results whenever the desktop entry database finishes loading.
    // DesktopEntries is lazily initialized: the first access in getResults() triggers
    // async XDG scanning. Without this listener the panel stays blank on first open.
    Connections {
        target: DesktopEntries
        function onApplicationsChanged(): void {
            root._log("desktop entries changed")
            if (root.panelActive) _refreshResults()
        }
    }

    Connections {
        target: ClipboardService
        function onRevisionChanged(): void {
            root._log("clipboard revision changed")
            if (root.panelActive && _activeProvider() === clipProvider)
                _refreshResults()
        }
    }
}
