pragma Singleton

import Quickshell
import Quickshell.Services.SystemTray
import QtQuick
import qs.services

// Shared system tray state: upstream item tracking, pin partitioning, and
// first-appearance flash-session accumulation for the bar widget.
Singleton {
    id: root

    property var _testItemsOverride: undefined
    property var _previousNonPinnedKeys: []
    property var _flashSessionKeys: []
    property var _pinnedItemsCache: []
    property var _nonPinnedItemsCache: []
    property var _flashItemsCache: []

    readonly property var pinnedItems: _pinnedItemsCache
    readonly property var nonPinnedItems: _nonPinnedItemsCache
    readonly property var flashItems: _flashItemsCache
    readonly property bool hasNonPinnedItems: nonPinnedItems.length > 0
    readonly property bool hasFlashItems: flashItems.length > 0
    readonly property var _upstreamItems:
        root._testItemsOverride !== undefined ? root._testItemsOverride : SystemTray.items.values
    readonly property var _pinnedKeySet: {
        const configured = SettingsService.data.systemTray.pinnedItems || []
        let next = ({})
        for (let index = 0; index < configured.length; index++) {
            const key = configured[index]
            if (!key)
                continue
            next[key] = true
        }
        return next
    }
    function clearFlashItems() {
        if (root._flashSessionKeys.length === 0)
            return

        root._flashSessionKeys = []
        root._flashItemsCache = []
    }

    function itemKey(item) {
        if (!item)
            return ""

        if (item.id !== undefined && item.id !== null && item.id !== "")
            return String(item.id)

        return ""
    }

    function _fallbackKey(item, index) {
        if (!item)
            return "fallback:" + index

        const title = item.tooltipTitle || item.title || ""
        const description = item.tooltipDescription || ""
        const icon = item.icon || ""
        return ["fallback", index, title, description, icon].join(":")
    }

    function _effectiveKey(item, index) {
        const stableKey = root.itemKey(item)
        if (stableKey !== "")
            return stableKey

        return root._fallbackKey(item, index)
    }

    function _flashEnabled() {
        const settings = SettingsService.data.systemTray
        return !!(settings && settings.enabled && settings.flashEnabled)
    }

    function _arraysMatch(first, second) {
        if (first.length !== second.length)
            return false

        for (let index = 0; index < first.length; index++) {
            if (first[index] !== second[index])
                return false
        }

        return true
    }

    function _rebuildState() {
        const sourceItems = root._upstreamItems || []
        let pinned = []
        let nonPinned = []
        let currentByKey = ({})
        let currentKeys = []

        for (let index = 0; index < sourceItems.length; index++) {
            const item = sourceItems[index]
            if (!item)
                continue

            const stableKey = root.itemKey(item)
            if (stableKey !== "" && root._pinnedKeySet[stableKey] === true) {
                pinned.push(item)
                continue
            }

            nonPinned.push(item)
        }

        for (let index = 0; index < nonPinned.length; index++) {
            const item = nonPinned[index]
            const key = root._effectiveKey(item, index)
            currentByKey[key] = item
            currentKeys.push(key)
        }

        if (!root._flashEnabled()) {
            root._previousNonPinnedKeys = currentKeys
            root._flashSessionKeys = []
            root._pinnedItemsCache = pinned
            root._nonPinnedItemsCache = nonPinned
            root._flashItemsCache = []
            return
        }

        let previousMap = ({})
        for (let prevIndex = 0; prevIndex < root._previousNonPinnedKeys.length; prevIndex++)
            previousMap[root._previousNonPinnedKeys[prevIndex]] = true

        let newArrivalKeys = []
        for (let currentIndex = 0; currentIndex < currentKeys.length; currentIndex++) {
            const key = currentKeys[currentIndex]
            if (previousMap[key] === true)
                continue
            newArrivalKeys.push(key)
        }

        let nextFlashKeys = []
        if (root._flashSessionKeys.length > 0) {
            for (let flashIndex = 0; flashIndex < root._flashSessionKeys.length; flashIndex++) {
                const key = root._flashSessionKeys[flashIndex]
                if (currentByKey[key] !== undefined)
                    nextFlashKeys.push(key)
            }
        }

        for (let arrivalIndex = 0; arrivalIndex < newArrivalKeys.length; arrivalIndex++) {
            const arrivalKey = newArrivalKeys[arrivalIndex]
            if (nextFlashKeys.indexOf(arrivalKey) !== -1)
                continue
            nextFlashKeys.push(arrivalKey)
        }

        root._previousNonPinnedKeys = currentKeys
        if (!root._arraysMatch(nextFlashKeys, root._flashSessionKeys))
            root._flashSessionKeys = nextFlashKeys

        let flashItems = []
        for (let resolvedIndex = 0; resolvedIndex < root._flashSessionKeys.length; resolvedIndex++) {
            const flashKey = root._flashSessionKeys[resolvedIndex]
            const flashItem = currentByKey[flashKey]
            if (flashItem !== undefined)
                flashItems.push(flashItem)
        }

        root._pinnedItemsCache = pinned
        root._nonPinnedItemsCache = nonPinned
        if (!root._arraysMatch(flashItems, root._flashItemsCache))
            root._flashItemsCache = flashItems
    }

    Instantiator {
        id: trayItemTracker

        model: root._upstreamItems || []

        delegate: QtObject {
            required property var modelData

            property Connections watcher: Connections {
                target: modelData
                ignoreUnknownSignals: true

                function onIdChanged() { root._rebuildState() }
                function onIconChanged() { root._rebuildState() }
                function onTooltipTitleChanged() { root._rebuildState() }
                function onTooltipDescriptionChanged() { root._rebuildState() }
                function onOnlyMenuChanged() { root._rebuildState() }
                function onHasMenuChanged() { root._rebuildState() }
                function onStatusChanged() { root._rebuildState() }
            }
        }

        onObjectAdded: Qt.callLater(root._rebuildState)
        onObjectRemoved: Qt.callLater(root._rebuildState)
        onModelChanged: Qt.callLater(root._rebuildState)
    }

    Connections {
        target: SystemTray.items
        ignoreUnknownSignals: true

        function onObjectInsertedPost() { root._rebuildState() }
        function onObjectRemovedPost() { root._rebuildState() }
    }

    Connections {
        target: SettingsService

        function onSettingsLoaded() { root._rebuildState() }
        function onSettingsReloaded() { root._rebuildState() }
    }

    on_TestItemsOverrideChanged: Qt.callLater(root._rebuildState)

    Component.onCompleted: Qt.callLater(root._rebuildState)
}
