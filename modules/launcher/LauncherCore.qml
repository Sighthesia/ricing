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
    property var _lastProvider: null
    property string _lastQuery: ""
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
        root._lastProvider = null
        if (_resultsList && _resultsList.resetTransientState)
            _resultsList.resetTransientState()
        _results.clear()
        root._lastQuery = ""
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
        root._lastProvider = null
        if (_resultsList && _resultsList.resetTransientState)
            _resultsList.resetTransientState()
        _searchHeader.text = ""
        _results.clear()
        root._resultData = []
        root._lastQuery = ""
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

    function _traceTopKeysFromDisplayItems(displayItems, limit): string {
        let keys = []
        let total = Math.min(displayItems ? displayItems.length : 0, Math.max(0, Number(limit) || 0))

        for (let index = 0; index < total; index++)
            keys.push(String((displayItems[index] && displayItems[index].key) || ""))

        return "[" + keys.join(", ") + "]"
    }

    function _traceTopKeys(keys, limit): string {
        let values = []
        let total = Math.min(keys ? keys.length : 0, Math.max(0, Number(limit) || 0))

        for (let index = 0; index < total; index++)
            values.push(String(keys[index] || ""))

        return "[" + values.join(", ") + "]"
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

        let sameProvider = provider === root._lastProvider

        let items = provider.getResults(q)
        let displayItems = []
        let previousKeys = ({})
        let nextKeys = ({})
        let retainedKeys = ({})
        let currentVisibleKeys = _resultsList && _resultsList.strictVisibleDelegateKeys
            ? _resultsList.strictVisibleDelegateKeys()
            : []

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
            retainedKeys[displayItem.key] = previousKeys[displayItem.key] === true

            if (!previousKeys[displayItem.key])
                insertedCount += 1
            if (!previousKeys[displayItem.key])
                insertedMaxIndex = i
        }

        let removedCount = 0
        let retainedCount = 0
        for (let existingKey in previousKeys) {
            if (!nextKeys[existingKey])
                removedCount += 1
            else
                retainedCount += 1
        }

        if (root._displayItemsMatch(displayItems)) {
            root._resultData = items
            _selectedIndex = root._resultData.length > 0 ? 0 : -1
            root._rememberSearchState(provider, q)
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
            root._rememberSearchState(provider, q)
            if (_resultsList && _resultsList.scheduleManagedEntryRelease)
                _resultsList.scheduleManagedEntryRelease(0)
            else
                Qt.callLater(function() { _resultsList.releaseManagedEntry() })
            return
        }

        let filterAnimationsEnabled = _resultsList && _resultsList.itemAnimationsEnabled
        let currentInstantiatedKeys = _resultsList && _resultsList.instantiatedDelegateKeys
            ? _resultsList.instantiatedDelegateKeys()
            : []
        let sameProviderRefinement = sameProvider
            && root._isQueryRefinement(root._lastQuery, q)
        let retainedVisibleCount = 0

        for (let visibleIndex = 0; visibleIndex < currentVisibleKeys.length; visibleIndex++) {
            if (retainedKeys[String(currentVisibleKeys[visibleIndex] || "")])
                retainedVisibleCount += 1
        }
        let sameProviderIncremental = filterAnimationsEnabled
            && sameProviderRefinement
            && _results.count > 0
            && retainedVisibleCount > 0
            && (insertedCount > 0 || removedCount > 0 || retainedCount > 0)
        let syncVisibleStateDuringFilter = true

        console.log(
            "[LauncherSearchTrace]",
            "refreshDecision",
            "query=", JSON.stringify(q),
            "sameProvider=", sameProvider,
            "sameProviderRefinement=", sameProviderRefinement,
            "path=", sameProviderIncremental ? "incremental" : "fullReplace",
            "currentCount=", _results.count,
            "nextCount=", displayItems.length,
            "inserted=", insertedCount,
            "removed=", removedCount,
            "retained=", retainedCount,
            "retainedVisible=", retainedVisibleCount,
            "instantiatedTopKeys=", root._traceTopKeys(currentInstantiatedKeys, 8),
            "nextTopKeys=", root._traceTopKeysFromDisplayItems(displayItems, 8)
        )

        if (sameProviderIncremental) {
            let expandFadeEnabled = removedCount > 0

            if (insertedCount > 0 && _resultsList && _resultsList.beginExpandTransition)
                _resultsList.beginExpandTransition(insertedCount, insertedMaxIndex + 1, syncVisibleStateDuringFilter, expandFadeEnabled)
            else if (_resultsList && _resultsList.beginFilterTransition)
                _resultsList.beginFilterTransition(syncVisibleStateDuringFilter)

            if (removedCount > 0 && _resultsList && _resultsList.runSwapExit)
                _resultsList.runSwapExit(nextKeys)
            if (_resultsList && _resultsList.resetFilterViewport)
                _resultsList.resetFilterViewport()

            root._syncResults(displayItems, items)

            if (_resultsList && _resultsList.resetFilterViewport)
                _resultsList.resetFilterViewport()

            if (_resultsList && _resultsList.queueRetainedVisibleEntries)
                _resultsList.queueRetainedVisibleEntries(retainedKeys)

            let incrementalReleaseDelay = Theme.anim.moveDuration + 20
            if (_resultsList) {
                let expandDuration = insertedCount > 0 && _resultsList.expandTransitionDuration
                    ? _resultsList.expandTransitionDuration()
                    : 0
                let swapExitDuration = removedCount > 0 && _resultsList.activeSwapExitDuration
                    ? _resultsList.activeSwapExitDuration()
                    : 0
                incrementalReleaseDelay = Math.max(Theme.anim.moveDuration, expandDuration, swapExitDuration) + 20
            }

            if (_resultsList && _resultsList.scheduleFilterTransitionRelease)
                _resultsList.scheduleFilterTransitionRelease(incrementalReleaseDelay)
            else if (_resultsList && _resultsList.endFilterTransition)
                Qt.callLater(function() { _resultsList.endFilterTransition() })

            root._rememberSearchState(provider, q)
            return
        }

        if (_resultsList && _resultsList.beginFilterTransition)
            _resultsList.beginFilterTransition()
        if (_resultsList && _resultsList.runSwapExit)
            _resultsList.runSwapExit()
        if (_resultsList && _resultsList.prepareManagedEntry)
            _resultsList.prepareManagedEntry()

        console.log(
            "[LauncherSearchTrace]",
            "fullReplace",
            "query=", JSON.stringify(q),
            "sameProvider=", sameProvider,
            "sameProviderRefinement=", sameProviderRefinement,
            "currentCount=", _results.count,
            "nextCount=", displayItems.length,
            "inserted=", insertedCount,
            "removed=", removedCount,
            "retained=", retainedCount,
            "instantiatedTopKeys=", root._traceTopKeys(currentInstantiatedKeys, 8),
            "nextTopKeys=", root._traceTopKeysFromDisplayItems(displayItems, 8)
        )

        _results.clear()
        root._resultData = items
        for (let batchIndex = 0; batchIndex < displayItems.length; batchIndex++)
            _results.append(displayItems[batchIndex])

        _selectedIndex = root._resultData.length > 0 ? 0 : -1

        if (_resultsList && _resultsList.scheduleManagedEntryRelease)
            _resultsList.scheduleManagedEntryRelease(
                (_resultsList.activeSwapExitDuration
                    ? _resultsList.activeSwapExitDuration()
                    : 0) + 20
            )
        else if (_resultsList && _resultsList.releaseManagedEntry)
            Qt.callLater(function() { _resultsList.releaseManagedEntry() })

        root._rememberSearchState(provider, q)
    }

    function _rememberSearchState(provider, query): void {
        root._lastProvider = provider
        root._lastQuery = String(query || "")
    }

    function _isQueryRefinement(previousQuery, nextQuery): bool {
        let previous = String(previousQuery || "")
        let next = String(nextQuery || "")

        if (previous.length === 0 || next.length === 0 || previous === next)
            return false

        return next.startsWith(previous) || previous.startsWith(next)
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

    function _syncResults(displayItems, items): void {
        let nextKeys = ({})
        let removedOps = []
        let movedOps = []
        let insertedOps = []
        let setOps = []

        for (let index = 0; index < displayItems.length; index++)
            nextKeys[displayItems[index].key] = true

        for (let removeIndex = _results.count - 1; removeIndex >= 0; removeIndex--) {
            let existing = _results.get(removeIndex)
            let existingKey = existing ? String(existing.key || "") : ""
            if (!nextKeys[existingKey]) {
                removedOps.push(removeIndex + ":" + existingKey)
                _results.remove(removeIndex, 1)
            }
        }

        for (let targetIndex = 0; targetIndex < displayItems.length; targetIndex++) {
            let displayItem = displayItems[targetIndex]
            let currentIndex = root._indexOfDisplayItem(displayItem.key, targetIndex)

            if (currentIndex === -1) {
                insertedOps.push(targetIndex + ":" + String(displayItem.key || ""))
                _results.insert(targetIndex, displayItem)
                continue
            }

            if (currentIndex !== targetIndex) {
                movedOps.push(String(displayItem.key || "") + "@" + currentIndex + "->" + targetIndex)
                _results.move(currentIndex, targetIndex, 1)
            }

            setOps.push(targetIndex + ":" + String(displayItem.key || ""))
            _results.set(targetIndex, displayItem)
        }

        while (_results.count > displayItems.length) {
            let trailing = _results.get(_results.count - 1)
            removedOps.push((_results.count - 1) + ":" + String((trailing && trailing.key) || ""))
            _results.remove(_results.count - 1, 1)
        }

        console.log(
            "[LauncherSearchTrace]",
            "syncResults",
            "remove=", "[" + removedOps.slice(0, 8).join(", ") + "]",
            "move=", "[" + movedOps.slice(0, 8).join(", ") + "]",
            "insert=", "[" + insertedOps.slice(0, 8).join(", ") + "]",
            "set=", "[" + setOps.slice(0, 8).join(", ") + "]",
            "finalCount=", displayItems.length
        )

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
            if (root.panelActive)
                _refreshResults()
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
