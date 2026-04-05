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

    // Parallel stores: ListModel holds display-only scalars; _resultData holds
    // the full result objects including onActivate functions (ListModel cannot
    // store JS functions — they are stripped on append).
    ListModel { id: _results }

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
        _results.clear()
        _searchHeader.text = LauncherService.prefillText
        _refreshResults()

        Qt.callLater(function() {
            if (LauncherService.isOpen)
                _searchHeader.focusInput()
        })

        for (let i = 0; i < _providers.length; i++) {
            _providers[i].onOpened()
        }
    }

    // Called by LauncherPanel when closing
    function closePanel(): void {
        _pendingDisplayItems = []
        _pendingResultData = []
        _suspendRefresh = true
        _searchHeader.text = ""
        _results.clear()
        root._resultData = []
        _suspendRefresh = false
    }

    function setQueryText(text): void {
        _searchHeader.text = text
        _refreshResults()

        Qt.callLater(function() {
            if (LauncherService.isOpen)
                _searchHeader.focusInput()
        })

    }

    function focusSearch(): void {
        Qt.callLater(function() {
            if (LauncherService.isOpen)
                _searchHeader.focusInput()
        })
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
        if (text.startsWith(">clip"))
            return clipProvider
        return appProvider
    }

    function _refreshResults(): void {
        if (_suspendRefresh || !root.panelActive)
            return

        let provider = _activeProvider()
        if (!provider)
            return

        let q = _searchHeader.text
        if (q.startsWith(">clip ")) q = q.substring(6)
        else if (q === ">clip") q = ""

        let items = provider.getResults(q)
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
            _resultsList.prepareManagedEntry()
            _results.clear()
            root._resultData = items
            for (let j = 0; j < displayItems.length; j++) {
                _results.append(displayItems[j])
            }
            _selectedIndex = items.length > 0 ? 0 : -1
            Qt.callLater(function() {
                _resultsList.releaseManagedEntry()
            })
            return
        }

        _pendingDisplayItems = displayItems
        _pendingResultData = items
        _runVisibleExit()
        root._applyPendingResults()
    }

    function _runVisibleExit(): void {
        _resultsList.runSwapExit()
    }

    function _applyPendingResults(): void {
        _resultsList.prepareManagedEntry()
        _results.clear()
        root._resultData = _pendingResultData
        for (let i = 0; i < _pendingDisplayItems.length; i++) {
            _results.append(_pendingDisplayItems[i])
        }
        _pendingDisplayItems = []
        _pendingResultData = []
        _selectedIndex = root._resultData.length > 0 ? 0 : -1

        Qt.callLater(function() {
            _resultsList.releaseManagedEntry()
        })
    }

    function _activateCurrent(): void {
        if (root._selectedIndex < 0 || root._selectedIndex >= root._resultData.length)
            return

        let item = root._resultData[root._selectedIndex]
        LauncherService.close()
        if (item && item.onActivate) item.onActivate()
    }

    // Re-query results whenever the desktop entry database finishes loading.
    // DesktopEntries is lazily initialized: the first access in getResults() triggers
    // async XDG scanning. Without this listener the panel stays blank on first open.
    Connections {
        target: DesktopEntries
        function onApplicationsChanged(): void {
            if (root.panelActive) _refreshResults()
        }
    }

    Connections {
        target: ClipboardService
        function onRevisionChanged(): void {
            if (root.panelActive && _activeProvider() === clipProvider)
                _refreshResults()
        }
    }
}
