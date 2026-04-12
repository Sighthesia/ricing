import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../bar" as BarComponents

// Launcher results viewport with delegate rendering and row interactions.
Item {
    id: root

    property alias model: resultList.model
    property int selectedIndex: -1
    property bool scrollAnimationsEnabled: false
    property bool itemAnimationsEnabled: true
    property bool _filterTransitionActive: false
    property bool _syncVisibleStateDuringFilter: true
    property bool _managedEntryPending: false
    property bool _expandTransitionActive: false
    property bool _expandFadeEnabled: true
    property int _expandInsertCount: 0
    property int _expandDelaySlots: 0
    property int _filterTransitionRevision: 0
    property int _activeSwapExitDuration: 0
    property bool _softManagedEntryActive: false
    property bool _softReplaceActive: false
    property bool _dropInterruptedTransitions: false
    property int _activeSoftReplaceDuration: 0
    property var _softReplaceOverlayKeys: ({})
    property var _outgoingItems: []
    property var _incomingItems: []
    property var _pendingIncomingItems: []
    property var _preTransitionVisibleKeys: []
    readonly property int _maxViewportSlots: 6
    readonly property int _managedEnterStep: SettingsService.effectiveAnimation.staggerLevel2Step
    readonly property int _filterSlideOffsetX: 30
    readonly property int _filterSlideOffsetY: 14

    Timer {
        id: _outgoingClearTimer
        interval: root.visibleExitDuration() + 20
        repeat: false
        onTriggered: {
            root._outgoingItems = []
            root._activeSwapExitDuration = 0
        }
    }

    Timer {
        id: _managedEntryReleaseTimer
        interval: 0
        repeat: false
        onTriggered: root.releaseManagedEntry()
    }

    Timer {
        id: _incomingStartTimer
        interval: 0
        repeat: false
        onTriggered: {
            root._incomingItems = root._pendingIncomingItems
            if (root._incomingItems.length > 0) {
                _incomingClearTimer.interval = root._activeSoftReplaceDuration + 20
                _incomingClearTimer.restart()
            } else {
                root._softReplaceActive = false
                root._activeSoftReplaceDuration = 0
            }
        }
    }

    Timer {
        id: _incomingClearTimer
        interval: 0
        repeat: false
        onTriggered: root.completeSoftReplace()
    }

    Timer {
        id: _filterTransitionReleaseTimer
        interval: Theme.anim.moveDuration + 20
        repeat: false
        onTriggered: root.endFilterTransition()
    }

    signal selectRequested(int index)
    signal activateRequested(int index)

    Layout.fillWidth: true
    Layout.fillHeight: true

    function runEnter(): void {
        root.scrollAnimationsEnabled = root.itemAnimationsEnabled

        if (!root.itemAnimationsEnabled) {
            root.syncInstantiatedDelegateState()
            return
        }

        if (root._managedEntryPending)
            return

        let delegates = root._visibleDelegates()
        for (let index = 0; index < delegates.length; index++) {
            if (delegates[index].runViewportEnter)
                delegates[index].runViewportEnter()
        }
    }

    function runExit(): void {
        if (!root.itemAnimationsEnabled) {
            root.syncInstantiatedDelegateState()
            return
        }

        let delegates = root._visibleDelegates()
        for (let index = 0; index < delegates.length; index++) {
            delegates[index].exitDelay = root._compressedDelay(index, delegates.length)
            delegates[index].runExit()
        }
    }

    function runSwapExit(nextKeys): void {
        if (!root.itemAnimationsEnabled) {
            _outgoingClearTimer.stop()
            root._outgoingItems = []
            root._activeSwapExitDuration = 0
            return
        }

        let delegates = root._visibleDelegates()
        let snapshots = []

        for (let index = 0; index < delegates.length; index++) {
            let delegate = delegates[index]
            let delegateKey = String(delegate.key || "")

            if (nextKeys && nextKeys[delegateKey])
                continue

            snapshots.push({
                key: delegateKey,
                name: delegate.name,
                description: delegate.description,
                icon: delegate.icon,
                selected: root.selectedIndex === delegate.index,
                y: Math.round(delegate.y - resultList.contentY),
                exitDelay: root._compressedDelay(index, delegates.length)
            })
        }

        if (root._outgoingItems.length > 0 && !root._dropInterruptedTransitions) {
            let merged = []
            let seen = ({})

            function pushSnapshot(snapshot) {
                let snapshotId = String(snapshot.key || "") + "@" + Math.round(Number(snapshot.y || 0))
                if (seen[snapshotId])
                    return

                seen[snapshotId] = true
                merged.push(snapshot)
            }

            for (let existingIndex = 0; existingIndex < root._outgoingItems.length; existingIndex++)
                pushSnapshot(root._outgoingItems[existingIndex])

            for (let snapshotIndex = 0; snapshotIndex < snapshots.length; snapshotIndex++)
                pushSnapshot(snapshots[snapshotIndex])

            for (let mergedIndex = 0; mergedIndex < merged.length; mergedIndex++)
                merged[mergedIndex].exitDelay = root._compressedDelay(mergedIndex, merged.length)

            snapshots = merged
        }

        _outgoingClearTimer.stop()
        root._outgoingItems = snapshots
        root._activeSwapExitDuration = snapshots.length > 0
            ? SettingsService.effectiveAnimation.staggerExitDuration + root._windowForCount(snapshots.length)
            : 0

        if (snapshots.length > 0) {
            _outgoingClearTimer.interval = root._activeSwapExitDuration + 20
            _outgoingClearTimer.restart()
        }
    }

    function resetFilterViewport(): void {
        if (resultList.count > 0)
            resultList.positionViewAtIndex(0, ListView.Beginning)
        else
            resultList.contentY = 0

        if (resultList.forceLayout)
            resultList.forceLayout()
    }

    function normalizeInstantiatedDelegates(): void {
        for (let index = 0; index < resultList.count; index++) {
            let delegate = resultList.itemAtIndex(index)
            if (!delegate)
                continue

            if (delegate._filterAddOpacity !== undefined)
                delegate._filterAddOpacity = 1
            delegate.opacity = 1

            if (delegate.syncViewportState)
                delegate.syncViewportState()
        }

        if (resultList.forceLayout)
            resultList.forceLayout()
    }

    function isTransitionBusy(): bool {
        return root._filterTransitionActive
            || root._softReplaceActive
            || root._incomingItems.length > 0
            || root._pendingIncomingItems.length > 0
            || root._outgoingItems.length > 0
    }

    function beginFilterTransition(syncVisibleStateDuringFilter, dropInterruptedTransitions): void {
        if (!root.itemAnimationsEnabled) {
            root.resetTransientState()
            root.scrollAnimationsEnabled = false
            return
        }

        root.normalizeInstantiatedDelegates()

        root._preTransitionVisibleKeys = root.strictVisibleDelegateKeys()
        root._filterTransitionRevision += 1
        root._dropInterruptedTransitions = dropInterruptedTransitions === true
        if (root._dropInterruptedTransitions) {
            _outgoingClearTimer.stop()
            _incomingStartTimer.stop()
            _incomingClearTimer.stop()
            root._outgoingItems = []
            root._incomingItems = []
            root._pendingIncomingItems = []
            root._softReplaceOverlayKeys = ({})
            root._softReplaceActive = false
            root._activeSwapExitDuration = 0
            root._activeSoftReplaceDuration = 0
        } else {
            root._promoteInterruptedIncomingToOutgoing()
        }
        _managedEntryReleaseTimer.stop()
        _filterTransitionReleaseTimer.stop()
        root._managedEntryPending = false
        root._softManagedEntryActive = false
        root._expandTransitionActive = false
        root._expandInsertCount = 0
        root._filterTransitionActive = true
        root._syncVisibleStateDuringFilter = syncVisibleStateDuringFilter !== false
    }

    function beginExpandTransition(insertCount, delaySlots, syncVisibleStateDuringFilter, fadeEnabled, dropInterruptedTransitions): void {
        beginFilterTransition(syncVisibleStateDuringFilter, dropInterruptedTransitions)

        if (!root.itemAnimationsEnabled)
            return

        root._expandTransitionActive = true
        root._expandFadeEnabled = fadeEnabled !== false
        root._expandInsertCount = Math.max(0, Number(insertCount) || 0)
        root._expandDelaySlots = Math.max(root._expandInsertCount, Math.max(0, Number(delaySlots) || 0))
    }

    function endFilterTransition(): void {
        if (!root.itemAnimationsEnabled) {
            root.resetTransientState()
            root.syncInstantiatedDelegateState()
            return
        }

        _filterTransitionReleaseTimer.stop()
        root._filterTransitionActive = false
        root._syncVisibleStateDuringFilter = true
        root._expandTransitionActive = false
        root._expandFadeEnabled = true
        root._expandInsertCount = 0
        root._expandDelaySlots = 0
        root._preTransitionVisibleKeys = []

        Qt.callLater(function() {
            if (resultList.forceLayout)
                resultList.forceLayout()

            root.syncInstantiatedDelegateState()
        })
    }

    function scheduleFilterTransitionRelease(delayMs): void {
        if (!root.itemAnimationsEnabled) {
            root.endFilterTransition()
            return
        }

        _filterTransitionReleaseTimer.interval = Math.max(0, Number(delayMs) || 0)
        _filterTransitionReleaseTimer.restart()
    }

    function resetTransientState(): void {
        _outgoingClearTimer.stop()
        _managedEntryReleaseTimer.stop()
        _filterTransitionReleaseTimer.stop()
        _incomingStartTimer.stop()
        _incomingClearTimer.stop()
        root._outgoingItems = []
        root._incomingItems = []
        root._pendingIncomingItems = []
        root._softReplaceOverlayKeys = ({})
        root._filterTransitionActive = false
        root._syncVisibleStateDuringFilter = true
        root._managedEntryPending = false
        root._expandTransitionActive = false
        root._expandFadeEnabled = true
        root._expandInsertCount = 0
        root._expandDelaySlots = 0
        root._activeSwapExitDuration = 0
        root._softReplaceActive = false
        root._dropInterruptedTransitions = false
        root._activeSoftReplaceDuration = 0
        root._softManagedEntryActive = false
        root._preTransitionVisibleKeys = []
    }

    function visibleExitDuration(): int {
        return SettingsService.effectiveAnimation.staggerExitDuration
            + root._windowForCount(root._visibleDelegates().length)
    }

    function activeSwapExitDuration(): int {
        return Math.max(0, root._activeSwapExitDuration)
    }

    function activeSoftReplaceDuration(): int {
        return Math.max(0, root._activeSoftReplaceDuration)
    }

    function expandTransitionDuration(): int {
        return Theme.anim.moveDuration
            + root._windowForCount(root._expandDelaySlots)
            + Theme.anim.highlightDuration
    }

    function retainedEntryDuration(): int {
        return SettingsService.effectiveAnimation.staggerEnterDuration
            + root._windowForCount(root._estimatedVisibleSlotCount())
    }

    function beginSoftReplace(displayItems, delayMs, sourcePositions): void {
        let snapshots = []
        let total = displayItems ? displayItems.length : 0

        _incomingStartTimer.stop()
        _incomingClearTimer.stop()
        root._incomingItems = []
        root._pendingIncomingItems = []

        for (let index = 0; index < total; index++) {
            let item = displayItems[index]
            if (!item)
                continue

            let targetY = index * 46
            let sourceY = sourcePositions && sourcePositions[String(item.key || "")] !== undefined
                ? Number(sourcePositions[String(item.key || "")])
                : (targetY + root._filterSlideOffsetY)

            snapshots.push({
                key: String(item.key || ""),
                name: item.name || "",
                description: item.description || "",
                icon: item.icon || "",
                y: targetY,
                delay: root._compressedDelay(index, total),
                enterOffsetX: root._filterSlideOffsetX,
                enterOffsetY: sourceY - targetY
            })
        }

        if (snapshots.length === 0) {
            root._softReplaceActive = false
            root._activeSoftReplaceDuration = 0
            return
        }

        root._pendingIncomingItems = snapshots
        let overlayKeys = ({})
        for (let snapshotIndex = 0; snapshotIndex < snapshots.length; snapshotIndex++)
            overlayKeys[String((snapshots[snapshotIndex] && snapshots[snapshotIndex].key) || "")] = true
        root._softReplaceOverlayKeys = overlayKeys
        root._softReplaceActive = true
        root._activeSoftReplaceDuration = SettingsService.effectiveAnimation.staggerEnterDuration
            + root._windowForCount(snapshots.length)
        _incomingStartTimer.interval = Math.max(0, Number(delayMs) || 0)
        _incomingStartTimer.restart()
    }

    function completeSoftReplace(): void {
        let revision = root._filterTransitionRevision

        root._softReplaceActive = false

        if (resultList.count > 0)
            resultList.positionViewAtIndex(0, ListView.Beginning)

        root._awaitTopDelegates("completeSoftReplaceWait", revision, 8, function() {
            if (revision !== root._filterTransitionRevision)
                return

            if (resultList.forceLayout)
                resultList.forceLayout()

            root.syncInstantiatedDelegateState()
            let visibleCount = root._visibleDelegates().length
            let instantiatedCount = root.instantiatedDelegateKeys().length

            if (resultList.count > 0 && (visibleCount === 0 || instantiatedCount === 0)) {
                root._activeSoftReplaceDuration = 0
                return
            }

            root._softReplaceOverlayKeys = ({})
            root._incomingItems = []
            root._pendingIncomingItems = []
            root._activeSoftReplaceDuration = 0
        })
    }

    function _promoteInterruptedIncomingToOutgoing(): void {
        let snapshots = []
        let hadIncoming = root._incomingItems.length > 0 || root._pendingIncomingItems.length > 0

        for (let index = 0; index < root._incomingItems.length; index++) {
            let item = root._incomingItems[index]
            if (!item)
                continue

            snapshots.push({
                key: String(item.key || ""),
                name: item.name || "",
                description: item.description || "",
                icon: item.icon || "",
                selected: false,
                y: Number(item.y || 0),
                exitDelay: root._compressedDelay(index, root._incomingItems.length),
                exitKind: "interruptedIncoming",
                startOpacity: 0.42,
                startOffsetX: Math.round(root._filterSlideOffsetX * 0.45),
                startOffsetY: Math.round(root._filterSlideOffsetY * 0.45),
                exitOffsetX: Math.round(root._filterSlideOffsetX * 0.7),
                exitOffsetY: Math.round(root._filterSlideOffsetY * 0.7),
                exitDuration: Math.max(80, Math.round(SettingsService.effectiveAnimation.staggerExitDuration * 0.55))
            })
        }

        _outgoingClearTimer.stop()
        _incomingStartTimer.stop()
        _incomingClearTimer.stop()
        root._incomingItems = []
        root._pendingIncomingItems = []
        root._softReplaceActive = false
        root._activeSoftReplaceDuration = 0
        root._softReplaceOverlayKeys = ({})

        if (!hadIncoming)
            return

        if (snapshots.length > 0 && root._outgoingItems.length > 0) {
            let merged = []
            let seen = ({})

            function pushSnapshot(snapshot) {
                let snapshotId = String(snapshot.key || "") + "@" + Math.round(Number(snapshot.y || 0))
                if (seen[snapshotId])
                    return

                seen[snapshotId] = true
                merged.push(snapshot)
            }

            for (let existingIndex = 0; existingIndex < root._outgoingItems.length; existingIndex++)
                pushSnapshot(root._outgoingItems[existingIndex])

            for (let snapshotIndex = 0; snapshotIndex < snapshots.length; snapshotIndex++)
                pushSnapshot(snapshots[snapshotIndex])

            snapshots = merged
        }

        root._outgoingItems = snapshots
        root._activeSwapExitDuration = snapshots.length > 0
            ? SettingsService.effectiveAnimation.staggerExitDuration + root._windowForCount(snapshots.length)
            : 0

        if (snapshots.length > 0) {
            _outgoingClearTimer.interval = root._activeSwapExitDuration + 20
            _outgoingClearTimer.restart()
        }
    }

    function _windowForCount(total): int {
        let capped = Math.max(0, Math.min(total, root._maxViewportSlots))
        return Math.max(0, capped - 1) * SettingsService.effectiveAnimation.staggerExitStep
    }

    function _compressedDelay(rank, total): int {
        if (total <= 1)
            return 0

        let window = root._windowForCount(total)
        return Math.round(window * (rank / Math.max(1, total - 1)))
    }

    function _strictVisibleDelegates(): var {
        let delegates = []
        let topBoundary = Number(resultList.contentY || 0)
        let bottomBoundary = topBoundary + Number(resultList.height || 0)

        for (let index = 0; index < resultList.count; index++) {
            let delegate = resultList.itemAtIndex(index)
            if (!delegate)
                continue

            let itemTop = Number(delegate.y || 0)
            let itemBottom = itemTop + Number(delegate.height || 0)
            if (itemBottom <= topBoundary || itemTop >= bottomBoundary)
                continue

            delegates.push(delegate)
        }

        return delegates
    }

    function _visibleDelegates(): var {
        return root._strictVisibleDelegates()
    }

    function _estimatedVisibleSlotCount(): int {
        let sampleDelegate = resultList.itemAtIndex(0)
        let delegateHeight = sampleDelegate && Number(sampleDelegate.height || 0) > 0
            ? Number(sampleDelegate.height || 0)
            : 46
        let estimated = Math.max(
            1,
            Math.min(
                root._maxViewportSlots,
                Math.ceil(Number(resultList.height || 0) / Math.max(1, delegateHeight))
            )
        )

        return estimated
    }

    function _instantiatedTopDelegateCount(limit): int {
        let readyCount = 0
        let total = Math.min(Math.max(0, Number(limit) || 0), resultList.count)

        for (let index = 0; index < total; index++) {
            if (resultList.itemAtIndex(index))
                readyCount += 1
        }

        return readyCount
    }

    function _awaitTopDelegates(label, revision, attemptsRemaining, callback): void {
        Qt.callLater(function() {
            if (revision >= 0 && revision !== root._filterTransitionRevision)
                return

            if (resultList.forceLayout)
                resultList.forceLayout()

            let candidateVisibleSlots = root._estimatedVisibleSlotCount()
            let readyCount = root._instantiatedTopDelegateCount(candidateVisibleSlots)
            let targetReadyCount = Math.min(candidateVisibleSlots, resultList.count)

            if (targetReadyCount > 0 && readyCount < targetReadyCount && attemptsRemaining > 0) {
                root._awaitTopDelegates(label, revision, attemptsRemaining - 1, callback)
                return
            }

            callback(candidateVisibleSlots)
        })
    }

    function visibleDelegateKeys(): var {
        let delegates = root._visibleDelegates()
        let keys = []

        for (let index = 0; index < delegates.length; index++)
            keys.push(String(delegates[index].key || ""))

        return keys
    }

    function strictVisibleDelegateKeys(): var {
        let delegates = root._strictVisibleDelegates()
        let keys = []

        for (let index = 0; index < delegates.length; index++)
            keys.push(String(delegates[index].key || ""))

        return keys
    }

    function instantiatedDelegateKeys(): var {
        let keys = []

        if (resultList.forceLayout)
            resultList.forceLayout()

        for (let index = 0; index < resultList.count; index++) {
            let delegate = resultList.itemAtIndex(index)
            if (!delegate)
                continue

            keys.push(String(delegate.key || ""))
        }

        return keys
    }

    function prepareManagedEntry(mode): void {
        root.scrollAnimationsEnabled = root.itemAnimationsEnabled

        if (!root.itemAnimationsEnabled) {
            root._softManagedEntryActive = false
            root._managedEntryPending = false
            return
        }

        root._softManagedEntryActive = String(mode || "") === "soft"
        root._managedEntryPending = true
    }

    function scheduleManagedEntryRelease(delayMs): void {
        if (!root.itemAnimationsEnabled) {
            root.releaseManagedEntry()
            return
        }

        _managedEntryReleaseTimer.interval = Math.max(0, Number(delayMs) || 0)
        _managedEntryReleaseTimer.restart()
    }

    function _queueManagedVisibleDelegates(): void {
        let delegates = root._visibleDelegates()

        for (let index = 0; index < delegates.length; index++) {
            if (delegates[index].queueManagedEnter)
                delegates[index].queueManagedEnter(index, delegates.length)
        }
    }

    function syncVisibleDelegateState(): void {
        if (resultList.forceLayout)
            resultList.forceLayout()

        let delegates = root._visibleDelegates()
        for (let index = 0; index < delegates.length; index++) {
            if (delegates[index].syncViewportState)
                delegates[index].syncViewportState()
        }
    }

    function syncInstantiatedDelegateState(): void {
        root._awaitTopDelegates("syncInstantiatedDelegateStateWait", -1, 4, function() {
            let syncedCount = 0

            for (let index = 0; index < resultList.count; index++) {
                let delegate = resultList.itemAtIndex(index)
                if (!delegate)
                    continue

                if (delegate.syncViewportState) {
                    delegate.syncViewportState()
                    syncedCount += 1
                }
            }

        })
    }

    function queueRetainedVisibleEntries(retainedKeys): void {
        if (!root.itemAnimationsEnabled)
            return

        let revision = root._filterTransitionRevision

        root._awaitTopDelegates("retainedEnterWait", revision, 4, function(candidateVisibleSlots) {
            if (!root._filterTransitionActive || revision !== root._filterTransitionRevision)
                return

            let previousVisibleSet = ({})
            let enteringDelegates = []

            for (let index = 0; index < root._preTransitionVisibleKeys.length; index++)
                previousVisibleSet[String(root._preTransitionVisibleKeys[index] || "")] = true

            for (let delegateIndex = 0; delegateIndex < resultList.count; delegateIndex++) {
                let delegate = resultList.itemAtIndex(delegateIndex)
                if (!delegate)
                    continue

                let delegateKey = String(delegate.key || "")
                if (delegate.index >= candidateVisibleSlots)
                    continue

                if (!retainedKeys || !retainedKeys[delegateKey])
                    continue

                if (previousVisibleSet[delegateKey])
                    continue

                enteringDelegates.push(delegate)
            }

            for (let enteringIndex = 0; enteringIndex < enteringDelegates.length; enteringIndex++) {
                let enteringDelegate = enteringDelegates[enteringIndex]
                if (!enteringDelegate)
                    continue

                enteringDelegate.enterStartOpacity = 0.0
                enteringDelegate.enterStartOffsetX = 0
                enteringDelegate.enterStartOffsetY = 0

                if (enteringDelegate.queueManagedEnter)
                    enteringDelegate.queueManagedEnter(enteringIndex, enteringDelegates.length)
            }

        })
    }

    function releaseManagedEntry(): void {
        if (!root.itemAnimationsEnabled) {
            root._filterTransitionActive = false
            root._softManagedEntryActive = false
            root._managedEntryPending = false
            root.syncInstantiatedDelegateState()
            return
        }

        let revision = root._filterTransitionRevision

        if (resultList.count > 0)
            resultList.positionViewAtIndex(0, ListView.Beginning)
        else
            resultList.contentY = 0

        if (resultList.forceLayout)
            resultList.forceLayout()

        root._awaitTopDelegates("releaseManagedEntryWait", revision, 8, function() {
            if (revision !== root._filterTransitionRevision)
                return

            if (!root._managedEntryPending)
                return

            if (resultList.count > 0)
                resultList.positionViewAtIndex(0, ListView.Beginning)

            if (resultList.forceLayout)
                resultList.forceLayout()

            root._queueManagedVisibleDelegates()
            root._filterTransitionActive = false
            root._softManagedEntryActive = false
            root._managedEntryPending = false

            if (root._visibleDelegates().length === 0)
                root.syncInstantiatedDelegateState()
        })
    }

    ListView {
        id: resultList
        anchors.fill: parent
        z: 1
        clip: true
        opacity: 1
        cacheBuffer: 0
        reuseItems: false
        displayMarginBeginning: 92
        displayMarginEnd: 92

        move: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: root.itemAnimationsEnabled ? Theme.anim.moveDuration : 0
                easing.type: Theme.anim.moveType
            }
        }

        add: Transition {
                id: _addTransition
                enabled: root.itemAnimationsEnabled
                    && root._filterTransitionActive
                    && !root._managedEntryPending

                SequentialAnimation {
                    PropertyAction { property: "_filterAddOpacity"; value: root._expandFadeEnabled ? 0 : 1 }
                    PauseAnimation {
                        duration: root._compressedDelay(
                        _addTransition.ViewTransition.index,
                        Math.max(root._expandDelaySlots, 1)
                    )
                }
                ParallelAnimation {
                    NumberAnimation {
                        property: "_filterAddOpacity"
                        to: 1
                        duration: root._expandFadeEnabled ? Theme.anim.highlightDuration : 0
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        addDisplaced: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: root.itemAnimationsEnabled ? Theme.anim.moveDuration : 0
                easing.type: Theme.anim.moveType
            }
        }

        removeDisplaced: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: root.itemAnimationsEnabled ? Theme.anim.moveDuration : 0
                easing.type: Theme.anim.moveType
            }
        }

        moveDisplaced: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: root.itemAnimationsEnabled ? Theme.anim.moveDuration : 0
                easing.type: Theme.anim.moveType
            }
        }

        remove: Transition {
            id: _removeTransition
            enabled: root.itemAnimationsEnabled
                && !root._managedEntryPending
                && !root._filterTransitionActive

            SequentialAnimation {
                PauseAnimation {
                    duration: root._compressedDelay(
                        _removeTransition.ViewTransition.index,
                        Math.max(_removeTransition.ViewTransition.index + 1, 1)
                    )
                }
                ParallelAnimation {
                    NumberAnimation {
                        property: "opacity"
                        to: 0
                        duration: Theme.anim.highlightDuration
                        easing.type: Easing.InCubic
                    }
                }
            }
        }

        delegate: BarComponents.ViewportStaggerItem {
            id: _item

            required property int index
            required property string key
            required property string name
            required property string description
            required property string icon

            listView: resultList
            trackViewport: false
            ownerManagedEntry: root.itemAnimationsEnabled && root._managedEntryPending
            scrollAnimationsEnabled: root.itemAnimationsEnabled && root.scrollAnimationsEnabled
            suppressViewportTransitions: root.itemAnimationsEnabled && (ownerManagedEntry || root._filterTransitionActive)
            syncViewportStateWhenSuppressed: root.itemAnimationsEnabled && root._filterTransitionActive && !root._managedEntryPending && root._syncVisibleStateDuringFilter
            managedEnterKey: _item.key
            managedEnterJitterEnabled: false
            viewportPadding: 28
            scrollStep: SettingsService.effectiveAnimation.staggerExitStep
            viewportEnterBaseDelay: SettingsService.effectiveAnimation.staggerLevel2BaseDelay
            managedEnterStep: root._softManagedEntryActive
                ? Math.max(10, Math.round(root._managedEnterStep * 0.7))
                : root._managedEnterStep
            managedEnterFadeEnabled: root.itemAnimationsEnabled
            managedEnterStartOpacity: root._softManagedEntryActive ? 0.18 : 0.0
            enterOffsetX: root._softManagedEntryActive ? root._filterSlideOffsetX : 0
            managedEnterStartOffsetY: root._softManagedEntryActive
                ? root._filterSlideOffsetY
                : enterOffsetY
            enterOffsetY: SettingsService.effectiveAnimation.staggerEnterOffsetY
            exitOffsetY: SettingsService.effectiveAnimation.staggerExitOffsetY
            property real _filterAddOpacity: 1
            readonly property bool _coveredBySoftReplace: root._softReplaceActive
                && !!root._softReplaceOverlayKeys[String(_item.key || "")]

            width: resultList.width
            height: ThemeLauncher.resultRowHeight

            Rectangle {
                anchors.fill: parent
                opacity: _item._coveredBySoftReplace
                    ? 0
                    : (root.itemAnimationsEnabled && root._expandTransitionActive ? _item._filterAddOpacity : 1)
                color: root.selectedIndex === _item.index
                    ? Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.12)
                    : ((root.itemAnimationsEnabled && root._expandTransitionActive && !root._expandFadeEnabled)
                        ? Colors.background
                        : "transparent")

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: ThemeLauncher.resultInset
                    spacing: ThemeLauncher.resultGap

                    Image {
                        source: "image://icon/" + (_item.icon || "application-x-executable")
                        width: ThemeLauncher.resultIconSize
                        height: ThemeLauncher.resultIconSize
                        sourceSize: Qt.size(ThemeLauncher.resultIconSize, ThemeLauncher.resultIconSize)
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: ThemeLauncher.resultTextGap

                        Text {
                            text: _item.name
                            color: Colors.text
                            font.family: Theme.fontFamily
                            font.pixelSize: ThemeLauncher.resultTitleSize
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: _item.description
                            color: Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.55)
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall - 1
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            visible: _item.description !== ""
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !_item._coveredBySoftReplace
                    onEntered: root.selectRequested(_item.index)
                    onClicked: root.activateRequested(_item.index)
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        clip: true
        visible: root.itemAnimationsEnabled && root._outgoingItems.length > 0
        z: 0

        Repeater {
            model: root._outgoingItems

            delegate: BarComponents.StaggerItem {
                id: _outgoingItem

                required property var modelData

                x: 0
                y: modelData.y
                width: resultList.width
                height: ThemeLauncher.resultRowHeight
                exitDelay: modelData.exitDelay
                exitDuration: modelData.exitDuration !== undefined
                    ? Number(modelData.exitDuration)
                    : SettingsService.effectiveAnimation.staggerExitDuration
                exitOffsetX: modelData.exitOffsetX !== undefined
                    ? Number(modelData.exitOffsetX)
                    : root._filterSlideOffsetX
                exitOffsetY: modelData.exitOffsetY !== undefined
                    ? Number(modelData.exitOffsetY)
                    : root._filterSlideOffsetY
                enterStartOpacity: modelData.startOpacity !== undefined
                    ? Number(modelData.startOpacity)
                    : 1.0
                enterStartOffsetX: modelData.startOffsetX !== undefined
                    ? Number(modelData.startOffsetX)
                    : 0
                enterStartOffsetY: modelData.startOffsetY !== undefined
                    ? Number(modelData.startOffsetY)
                    : 0

                Component.onCompleted: {
                    _outgoingItem.opacity = _outgoingItem.enterStartOpacity
                    _outgoingItem._tx = _outgoingItem.enterStartOffsetX
                    _outgoingItem._ty = _outgoingItem.enterStartOffsetY
                    _outgoingItem.runExit()
                }

                Rectangle {
                    anchors.fill: parent
                    color: modelData.selected
                        ? Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.12)
                        : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: ThemeLauncher.resultInset
                        spacing: ThemeLauncher.resultGap

                        Image {
                            source: "image://icon/" + (modelData.icon || "application-x-executable")
                            width: ThemeLauncher.resultIconSize
                            height: ThemeLauncher.resultIconSize
                            sourceSize: Qt.size(ThemeLauncher.resultIconSize, ThemeLauncher.resultIconSize)
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: ThemeLauncher.resultTextGap

                            Text {
                                text: modelData.name
                                color: Colors.text
                                font.family: Theme.fontFamily
                                font.pixelSize: ThemeLauncher.resultTitleSize
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: modelData.description
                                color: Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.55)
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall - 1
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                visible: modelData.description !== ""
                            }
                        }
                    }
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        clip: true
        visible: root.itemAnimationsEnabled && root._incomingItems.length > 0
        z: 2

        Repeater {
            model: root._incomingItems

            delegate: BarComponents.StaggerItem {
                id: _incomingItem

                required property var modelData

                x: 0
                y: modelData.y
                width: resultList.width
                height: ThemeLauncher.resultRowHeight
                delay: modelData.delay
                enterStartOpacity: 0.0
                enterStartOffsetX: modelData.enterOffsetX !== undefined
                    ? modelData.enterOffsetX
                    : root._filterSlideOffsetX
                enterStartOffsetY: modelData.enterOffsetY !== undefined
                    ? modelData.enterOffsetY
                    : root._filterSlideOffsetY

                Component.onCompleted: runEnter()

                Rectangle {
                    anchors.fill: parent
                    color: "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: ThemeLauncher.resultInset
                        spacing: ThemeLauncher.resultGap

                        Image {
                            source: "image://icon/" + (modelData.icon || "application-x-executable")
                            width: ThemeLauncher.resultIconSize
                            height: ThemeLauncher.resultIconSize
                            sourceSize: Qt.size(ThemeLauncher.resultIconSize, ThemeLauncher.resultIconSize)
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: ThemeLauncher.resultTextGap

                            Text {
                                text: modelData.name
                                color: Colors.text
                                font.family: Theme.fontFamily
                                font.pixelSize: ThemeLauncher.resultTitleSize
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: modelData.description
                                color: Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.55)
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall - 1
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                visible: modelData.description !== ""
                            }
                        }
                    }
                }
            }
        }
    }

    function positionSelection(index): void {
        if (index < 0 || index >= resultList.count) return;
        resultList.positionViewAtIndex(index, ListView.Contain);
    }

    function delegateAtIndex(index): var {
        return resultList.itemAtIndex(index);
    }
}
