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
        if (_resultsList && _resultsList.resetTransientState)
            _resultsList.resetTransientState()
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
        _suspendRefresh = true
        if (_resultsList && _resultsList.resetTransientState)
            _resultsList.resetTransientState()
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
        let previousKeys = ({})
        let nextKeys = ({})

        for (let existingIndex = 0; existingIndex < _results.count; existingIndex++) {
            let existingItem = _results.get(existingIndex)
            let existingKey = existingItem ? String(existingItem.key || "") : ""
            previousKeys[existingKey] = true
        }

        let insertedCount = 0
        let insertedMaxIndex = -1
        for (let i = 0; i < items.length; i++) {
            let displayItem = {
                key:         root._resultKeyForItem(items[i], i),
                name:        items[i].name        || "",
                description: items[i].description || "",
                icon:        items[i].icon        || ""
            }

            displayItems.push(displayItem)
            nextKeys[displayItem.key] = true

            if (!previousKeys[displayItem.key])
                insertedCount += 1
            if (!previousKeys[displayItem.key])
                insertedMaxIndex = i
        }

        if (root._displayItemsMatch(displayItems)) {
            root._resultData = items
            _selectedIndex = root._resultData.length > 0 ? 0 : -1
            return
        }

        if (_results.count === 0) {
            _resultsList.prepareManagedEntry()
            _results.clear()
            root._resultData = items
            for (let j = 0; j < displayItems.length; j++) {
                _results.append(displayItems[j])
            }
            _selectedIndex = items.length > 0 ? 0 : -1
            if (_resultsList && _resultsList.scheduleManagedEntryRelease)
                _resultsList.scheduleManagedEntryRelease(0)
            else
                Qt.callLater(function() { _resultsList.releaseManagedEntry() })
            return
        }

        let shrinkOnly = displayItems.length < _results.count && insertedCount === 0
        let removedCount = 0

        for (let existingKey in previousKeys) {
            if (!nextKeys[existingKey])
                removedCount += 1
        }

        let expandOnly = displayItems.length > _results.count
            && removedCount === 0
            && root._currentItemsAreStableSubsequence(displayItems)

        if (shrinkOnly) {
            if (_resultsList && _resultsList.beginFilterTransition)
                _resultsList.beginFilterTransition()
            if (_resultsList && _resultsList.runSwapExit)
                _resultsList.runSwapExit(nextKeys)
            if (_resultsList && _resultsList.resetFilterViewport)
                _resultsList.resetFilterViewport()

            root._syncResults(displayItems, items)

            if (_resultsList && _resultsList.scheduleFilterTransitionRelease)
                _resultsList.scheduleFilterTransitionRelease(Theme.anim.moveDuration + 20)
            else if (_resultsList && _resultsList.endFilterTransition)
                Qt.callLater(function() { _resultsList.endFilterTransition() })

            return
        }

        if (expandOnly) {
            if (_resultsList && _resultsList.beginExpandTransition)
                _resultsList.beginExpandTransition(insertedCount, insertedMaxIndex + 1)
            else if (_resultsList && _resultsList.beginFilterTransition)
                _resultsList.beginFilterTransition()
            if (_resultsList && _resultsList.resetFilterViewport)
                _resultsList.resetFilterViewport()

            root._syncResults(displayItems, items)

            if (_resultsList && _resultsList.scheduleFilterTransitionRelease)
                _resultsList.scheduleFilterTransitionRelease(
                    _resultsList.expandTransitionDuration
                        ? _resultsList.expandTransitionDuration()
                        : Theme.anim.moveDuration + Theme.anim.highlightDuration
                )
            else if (_resultsList && _resultsList.endFilterTransition)
                Qt.callLater(function() { _resultsList.endFilterTransition() })

            return
        }

        if (_resultsList && _resultsList.beginFilterTransition)
            _resultsList.beginFilterTransition()
        if (_resultsList && _resultsList.runSwapExit)
            _resultsList.runSwapExit()
        if (_resultsList && _resultsList.prepareManagedEntry)
            _resultsList.prepareManagedEntry()

        _results.clear()
        root._resultData = items
        for (let batchIndex = 0; batchIndex < displayItems.length; batchIndex++)
            _results.append(displayItems[batchIndex])

        _selectedIndex = root._resultData.length > 0 ? 0 : -1

        if (_resultsList && _resultsList.scheduleManagedEntryRelease)
            _resultsList.scheduleManagedEntryRelease(
                _resultsList.activeSwapExitDuration
                    ? _resultsList.activeSwapExitDuration()
                    : 0
            )
        else if (_resultsList && _resultsList.releaseManagedEntry)
            Qt.callLater(function() { _resultsList.releaseManagedEntry() })
    }

    function _resultKeyForItem(item, index): string {
        if (item && item.key !== undefined && item.key !== null && item.key !== "")
            return String(item.key)

        return String((item && item.name) || "")
            + "|" + String((item && item.description) || "")
            + "|" + String((item && item.icon) || "")
            + "|" + String(index)
    }

    function _displayItemsMatch(displayItems): bool {
        if (_results.count !== displayItems.length)
            return false

        for (let index = 0; index < displayItems.length; index++) {
            let existing = _results.get(index)
            let incoming = displayItems[index]

            if (!existing)
                return false

            if (String(existing.key || "") !== String(incoming.key || ""))
                return false
            if (String(existing.name || "") !== String(incoming.name || ""))
                return false
            if (String(existing.description || "") !== String(incoming.description || ""))
                return false
            if (String(existing.icon || "") !== String(incoming.icon || ""))
                return false
        }

        return true
    }

    function _indexOfDisplayItem(key, startIndex): int {
        for (let index = Math.max(0, startIndex); index < _results.count; index++) {
            let existing = _results.get(index)
            if (existing && String(existing.key || "") === key)
                return index
        }

        return -1
    }

    function _currentItemsAreStableSubsequence(displayItems): bool {
        let displayIndex = 0

        for (let resultIndex = 0; resultIndex < _results.count; resultIndex++) {
            let existing = _results.get(resultIndex)
            if (!existing)
                return false

            let existingKey = String(existing.key || "")
            let matched = false

            while (displayIndex < displayItems.length) {
                let incoming = displayItems[displayIndex]
                displayIndex += 1

                if (String(incoming.key || "") !== existingKey)
                    continue

                if (String(existing.name || "") !== String(incoming.name || ""))
                    return false
                if (String(existing.description || "") !== String(incoming.description || ""))
                    return false
                if (String(existing.icon || "") !== String(incoming.icon || ""))
                    return false

                matched = true
                break
            }

            if (!matched)
                return false
        }

        return true
    }

    function _syncResults(displayItems, items): void {
        let nextKeys = ({})

        for (let index = 0; index < displayItems.length; index++)
            nextKeys[displayItems[index].key] = true

        for (let removeIndex = _results.count - 1; removeIndex >= 0; removeIndex--) {
            let existing = _results.get(removeIndex)
            let existingKey = existing ? String(existing.key || "") : ""
            if (!nextKeys[existingKey])
                _results.remove(removeIndex, 1)
        }

        for (let targetIndex = 0; targetIndex < displayItems.length; targetIndex++) {
            let displayItem = displayItems[targetIndex]
            let currentIndex = root._indexOfDisplayItem(displayItem.key, targetIndex)

            if (currentIndex === -1) {
                _results.insert(targetIndex, displayItem)
                continue
            }

            if (currentIndex !== targetIndex)
                _results.move(currentIndex, targetIndex, 1)

            _results.set(targetIndex, displayItem)
        }

        while (_results.count > displayItems.length)
            _results.remove(_results.count - 1, 1)

        root._resultData = items
        _selectedIndex = root._resultData.length > 0 ? 0 : -1
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
