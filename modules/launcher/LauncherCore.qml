import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.modules.bar
import "providers"

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

    StaggerOrchestrator {
        id: _stagger
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

        LauncherSearchHeader {
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
            onCloseRequested: LauncherService.isOpen = false
        }

        // Divider
        StaggerItem {
            id: s_divider
            Layout.fillWidth: true
            height: 1
            exitDelay: 0

            Rectangle {
                anchors.fill: parent
                color: Colors.border
            }
        }

        LauncherResultsList {
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
    ApplicationsProvider { id: appProvider }
    ClipboardProvider    { id: clipProvider }

    // Called by LauncherPanel after panel becomes active
    function openPanel(): void {
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
        _swapTimer.stop()
        _pendingDisplayItems = []
        _pendingResultData = []
        _suspendRefresh = true
        _searchHeader.text = ""
        _results.clear()
        root._resultData = []
        _suspendRefresh = false
    }

    function runStructuralEnter(): void {
        _stagger.clear()
        _stagger.registerItem(_searchHeader, 0, 1)
        _stagger.registerItem(s_divider, 1, 1)
        _stagger.registerItem(_resultsList, 2, 1)
        _stagger.runEnter()
    }

    function runStructuralExit(): void {
        _stagger.clear()
        _stagger.registerItem(_searchHeader, 0, 1)
        _stagger.registerItem(s_divider, 1, 1)
        _stagger.registerItem(_resultsList, 2, 1)
        _stagger.runExit()
    }

    function _activeProvider(): var {
        let text = _searchHeader.text
        if (text.startsWith(">clip")) return clipProvider
        return appProvider
    }

    function _refreshResults(): void {
        if (_suspendRefresh || !LauncherService.isOpen) return

        let provider = _activeProvider()
        if (!provider) return

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
            _results.clear()
            root._resultData = items
            for (let j = 0; j < displayItems.length; j++) {
                _results.append(displayItems[j])
            }
            _selectedIndex = items.length > 0 ? 0 : -1
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
    }

    function _activateCurrent(): void {
        if (root._selectedIndex < 0 || root._selectedIndex >= root._resultData.length) return

        let item = root._resultData[root._selectedIndex]
        LauncherService.isOpen = false
        if (item && item.onActivate) item.onActivate()
    }

    // Re-query results whenever the desktop entry database finishes loading.
    // DesktopEntries is lazily initialized: the first access in getResults() triggers
    // async XDG scanning. Without this listener the panel stays blank on first open.
    Connections {
        target: DesktopEntries
        function onApplicationsChanged(): void {
            if (LauncherService.isOpen) _refreshResults()
        }
    }

    Connections {
        target: ClipboardService
        function onRevisionChanged(): void {
            if (LauncherService.isOpen && _activeProvider() === clipProvider)
                _refreshResults()
        }
    }
}
