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
    property string _lastNormalizedQuery: ""
    property var _lastProvider: null
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
        root._lastNormalizedQuery = ""
        root._lastProvider = null
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
        root._lastNormalizedQuery = ""
        root._lastProvider = null
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

    function _providerDebugName(provider): string {
        if (provider === appProvider)
            return "applications"
        if (provider === clipProvider)
            return "clipboard"
        return "unknown"
    }

    function _debugKeySample(keys, limit): string {
        let sample = []
        let capped = Math.min(Number(limit) || 0, keys ? keys.length : 0)

        for (let index = 0; index < capped; index++)
            sample.push(String(keys[index] || ""))

        return "[" + sample.join(", ") + "]"
    }

    function _debugCurrentModelKeys(limit): string {
        let keys = []
        let capped = Math.min(Math.max(0, Number(limit) || 0), _results.count)

        for (let index = 0; index < capped; index++) {
            let existing = _results.get(index)
            keys.push(existing ? String(existing.key || "") : "")
        }

        return root._debugKeySample(keys, capped)
    }

    function _debugDisplayItemKeys(displayItems, limit): string {
        let keys = []
        let capped = Math.min(Number(limit) || 0, displayItems.length)

        for (let index = 0; index < capped; index++)
            keys.push(String(displayItems[index].key || ""))

        return root._debugKeySample(keys, capped)
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
        let refiningQuery = sameProvider
            && q.length > root._lastNormalizedQuery.length
            && q.startsWith(root._lastNormalizedQuery)

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

        if (refiningQuery) {
            let stabilized = root._stabilizeRefinedResults(displayItems, items)
            displayItems = stabilized.displayItems
            items = stabilized.items

            console.log(
                "[LauncherSearch]",
                "stabilizedRefine",
                "provider=", root._providerDebugName(provider),
                "query=", JSON.stringify(q),
                "nextTop=", root._debugDisplayItemKeys(displayItems, 6)
            )
        }

        if (root._displayItemsMatch(displayItems)) {
            console.log("[LauncherSearch]", "branch=no-op")
            root._resultData = items
            _selectedIndex = root._resultData.length > 0 ? 0 : -1
            root._rememberSearchState(provider, q)
            return
        }

        if (_results.count === 0) {
            console.log("[LauncherSearch]", "branch=initial-entry")
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

        let shrinkOnly = displayItems.length < _results.count && insertedCount === 0
        let removedCount = 0

        for (let existingKey in previousKeys) {
            if (!nextKeys[existingKey])
                removedCount += 1
        }

        let expandOnly = displayItems.length > _results.count
            && removedCount === 0
            && root._currentItemsAreStableSubsequence(displayItems)

        let currentInstantiatedKeys = _resultsList && _resultsList.instantiatedDelegateKeys
            ? _resultsList.instantiatedDelegateKeys()
            : []
        let shrinkVisibleStable = root._nextTopKeysStayWithinVisibleWindow(displayItems, currentInstantiatedKeys)
        let allowStableShrink = shrinkOnly && (shrinkVisibleStable || refiningQuery)

        console.log(
            "[LauncherSearch]",
            "refresh",
            "provider=", root._providerDebugName(provider),
            "rawQuery=", JSON.stringify(_searchHeader.text),
            "normalizedQuery=", JSON.stringify(q),
            "lastQuery=", JSON.stringify(root._lastNormalizedQuery),
            "sameProvider=", sameProvider,
            "refiningQuery=", refiningQuery,
            "previousCount=", _results.count,
            "nextCount=", displayItems.length,
            "insertedCount=", insertedCount,
            "removedCount=", removedCount,
            "shrinkOnly=", shrinkOnly,
            "expandOnly=", expandOnly,
            "shrinkVisibleStable=", shrinkVisibleStable,
            "allowStableShrink=", allowStableShrink,
            "currentTop=", root._debugCurrentModelKeys(6),
            "nextTop=", root._debugDisplayItemKeys(displayItems, 6),
            "instantiated=", root._debugKeySample(currentInstantiatedKeys, 6)
        )

        if (allowStableShrink) {
            console.log("[LauncherSearch]", "branch=shrink-stable")
            if (_resultsList && _resultsList.beginFilterTransition)
                _resultsList.beginFilterTransition()
            if (_resultsList && _resultsList.runSwapExit)
                _resultsList.runSwapExit(nextKeys)
            if (_resultsList && _resultsList.resetFilterViewport)
                _resultsList.resetFilterViewport()

            root._syncResults(displayItems, items)

            if (_resultsList && _resultsList.syncVisibleDelegateState)
                _resultsList.syncVisibleDelegateState()

            if (_resultsList && _resultsList.scheduleFilterTransitionRelease)
                _resultsList.scheduleFilterTransitionRelease(Theme.anim.moveDuration + 20)
            else if (_resultsList && _resultsList.endFilterTransition)
                Qt.callLater(function() { _resultsList.endFilterTransition() })

            root._rememberSearchState(provider, q)
            return
        }

        if (expandOnly) {
            console.log("[LauncherSearch]", "branch=expand-stable")
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

            root._rememberSearchState(provider, q)
            return
        }

        if (_resultsList && _resultsList.beginFilterTransition)
            _resultsList.beginFilterTransition()
        if (_resultsList && _resultsList.runSwapExit)
            _resultsList.runSwapExit()
        if (_resultsList && _resultsList.prepareManagedEntry)
            _resultsList.prepareManagedEntry()

        console.log("[LauncherSearch]", "branch=full-replace")

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

        root._rememberSearchState(provider, q)
    }

    function _rememberSearchState(provider, normalizedQuery): void {
        root._lastProvider = provider
        root._lastNormalizedQuery = String(normalizedQuery || "")
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

    function _nextTopKeysStayWithinVisibleWindow(displayItems, currentVisibleKeys): bool {
        if (!currentVisibleKeys || currentVisibleKeys.length === 0)
            return false

        let topCount = Math.min(displayItems.length, currentVisibleKeys.length)
        let currentVisibleIndex = 0

        for (let displayIndex = 0; displayIndex < topCount; displayIndex++) {
            let targetKey = String(displayItems[displayIndex].key || "")
            let matched = false

            while (currentVisibleIndex < currentVisibleKeys.length) {
                if (String(currentVisibleKeys[currentVisibleIndex]) === targetKey) {
                    matched = true
                    currentVisibleIndex += 1
                    break
                }

                currentVisibleIndex += 1
            }

            if (!matched)
                return false
        }

        return true
    }

    function _stabilizeRefinedResults(displayItems, items): var {
        let keyedItems = ({})
        let keyedDisplayItems = ({})
        let stabilizedItems = []
        let stabilizedDisplayItems = []

        for (let index = 0; index < displayItems.length; index++) {
            let displayItem = displayItems[index]
            let key = String(displayItem.key || "")
            keyedDisplayItems[key] = displayItem
            keyedItems[key] = items[index]
        }

        for (let resultIndex = 0; resultIndex < _results.count; resultIndex++) {
            let existing = _results.get(resultIndex)
            let existingKey = existing ? String(existing.key || "") : ""
            if (!keyedDisplayItems[existingKey])
                continue

            stabilizedDisplayItems.push(keyedDisplayItems[existingKey])
            stabilizedItems.push(keyedItems[existingKey])
            delete keyedDisplayItems[existingKey]
            delete keyedItems[existingKey]
        }

        for (let nextIndex = 0; nextIndex < displayItems.length; nextIndex++) {
            let nextDisplayItem = displayItems[nextIndex]
            let nextKey = String(nextDisplayItem.key || "")
            if (!keyedDisplayItems[nextKey])
                continue

            stabilizedDisplayItems.push(nextDisplayItem)
            stabilizedItems.push(keyedItems[nextKey])
        }

        return {
            displayItems: stabilizedDisplayItems,
            items: stabilizedItems
        }
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
