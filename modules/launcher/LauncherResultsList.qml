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
    readonly property bool itemAnimationsEnabled: true
    property bool _filterTransitionActive: false
    property bool _syncVisibleStateDuringFilter: true
    property bool _managedEntryPending: false
    property bool _expandTransitionActive: false
    property bool _expandFadeEnabled: true
    property int _expandInsertCount: 0
    property int _expandDelaySlots: 0
    property int _filterTransitionRevision: 0
    property int _activeSwapExitDuration: 0
    property var _outgoingItems: []
    property var _preTransitionVisibleKeys: []
    readonly property int _maxViewportSlots: 6
    readonly property int _managedEnterStep: SettingsService.effectiveAnimation.staggerLevel2Step

    Timer {
        id: _outgoingClearTimer
        interval: root.visibleExitDuration() + 20
        repeat: false
        onTriggered: {
            console.log(
                "[LauncherSearchDebug]",
                "clearOutgoing",
                "revision=", root._filterTransitionRevision,
                "count=", root._outgoingItems.length
            )
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
        id: _filterTransitionReleaseTimer
        interval: Theme.anim.moveDuration + 20
        repeat: false
        onTriggered: root.endFilterTransition()
    }

    signal selectRequested(int index)
    signal activateRequested(int index)

    Layout.fillWidth: true
    Layout.fillHeight: true

    function _debugKeys(keys): string {
        let values = []

        for (let index = 0; index < (keys ? keys.length : 0); index++)
            values.push(String(keys[index] || ""))

        return "[" + values.join(", ") + "]"
    }

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

        root._outgoingItems = snapshots
        root._activeSwapExitDuration = snapshots.length > 0
            ? SettingsService.effectiveAnimation.staggerExitDuration + root._windowForCount(snapshots.length)
            : 0
        console.log(
            "[LauncherSearchDebug]",
            "swapExit",
            "revision=", root._filterTransitionRevision,
            "visibleKeys=", root._debugKeys(root.visibleDelegateKeys()),
            "snapshotKeys=", root._debugKeys(snapshots.map(function(snapshot) { return snapshot.key }))
        )
        if (snapshots.length > 0) {
            _outgoingClearTimer.interval = root._activeSwapExitDuration + 20
            _outgoingClearTimer.restart()
        } else {
            _outgoingClearTimer.stop()
        }
    }

    function resetFilterViewport(): void {
        resultList.contentY = 0
        if (resultList.forceLayout)
            resultList.forceLayout()
    }

    function beginFilterTransition(syncVisibleStateDuringFilter): void {
        if (!root.itemAnimationsEnabled) {
            root.resetTransientState()
            root.scrollAnimationsEnabled = false
            return
        }

        root._preTransitionVisibleKeys = root.strictVisibleDelegateKeys()
        root._filterTransitionRevision += 1
        console.log(
            "[LauncherSearchDebug]",
            "beginFilter",
            "revision=", root._filterTransitionRevision,
            "syncVisible=", syncVisibleStateDuringFilter !== false,
            "preVisible=", root._debugKeys(root._preTransitionVisibleKeys)
        )
        _outgoingClearTimer.stop()
        _managedEntryReleaseTimer.stop()
        _filterTransitionReleaseTimer.stop()
        root._outgoingItems = []
        root._activeSwapExitDuration = 0
        root._managedEntryPending = false
        root._expandTransitionActive = false
        root._expandInsertCount = 0
        root._filterTransitionActive = true
        root._syncVisibleStateDuringFilter = syncVisibleStateDuringFilter !== false
    }

    function beginExpandTransition(insertCount, delaySlots, syncVisibleStateDuringFilter, fadeEnabled): void {
        beginFilterTransition(syncVisibleStateDuringFilter)

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
        root._outgoingItems = []
        root._filterTransitionActive = false
        root._syncVisibleStateDuringFilter = true
        root._managedEntryPending = false
        root._expandTransitionActive = false
        root._expandFadeEnabled = true
        root._expandInsertCount = 0
        root._expandDelaySlots = 0
        root._activeSwapExitDuration = 0
        root._preTransitionVisibleKeys = []
    }

    function visibleExitDuration(): int {
        return SettingsService.effectiveAnimation.staggerExitDuration
            + root._windowForCount(root._visibleDelegates().length)
    }

    function activeSwapExitDuration(): int {
        return Math.max(0, root._activeSwapExitDuration)
    }

    function expandTransitionDuration(): int {
        return Theme.anim.moveDuration
            + root._windowForCount(root._expandDelaySlots)
            + Theme.anim.highlightDuration
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

    function prepareManagedEntry(): void {
        root.scrollAnimationsEnabled = root.itemAnimationsEnabled

        if (!root.itemAnimationsEnabled) {
            root._managedEntryPending = false
            return
        }

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
        if (resultList.forceLayout)
            resultList.forceLayout()

        for (let index = 0; index < resultList.count; index++) {
            let delegate = resultList.itemAtIndex(index)
            if (!delegate)
                continue

            if (delegate.syncViewportState)
                delegate.syncViewportState()
        }
    }

    function queueRetainedVisibleEntries(retainedKeys): void {
        if (!root.itemAnimationsEnabled)
            return

        let revision = root._filterTransitionRevision

        Qt.callLater(function() {
            if (!root._filterTransitionActive || revision !== root._filterTransitionRevision)
                return

            if (resultList.forceLayout)
                resultList.forceLayout()

            let previousVisibleSet = ({})
            let enteringDelegates = []
            let delegates = root._strictVisibleDelegates()

            for (let index = 0; index < root._preTransitionVisibleKeys.length; index++)
                previousVisibleSet[String(root._preTransitionVisibleKeys[index] || "")] = true

            for (let delegateIndex = 0; delegateIndex < delegates.length; delegateIndex++) {
                let delegate = delegates[delegateIndex]
                let delegateKey = String(delegate.key || "")

                if (!retainedKeys || !retainedKeys[delegateKey] || previousVisibleSet[delegateKey])
                    continue

                enteringDelegates.push(delegate)
            }

            for (let enteringIndex = 0; enteringIndex < enteringDelegates.length; enteringIndex++) {
                let enteringDelegate = enteringDelegates[enteringIndex]
                if (!enteringDelegate)
                    continue

                enteringDelegate.enterStartOpacity = 1.0
                enteringDelegate.enterStartOffsetY = Math.round(Number(enteringDelegate.enterOffsetY || 0) * 0.45)

                if (enteringDelegate.queueManagedEnter)
                    enteringDelegate.queueManagedEnter(enteringIndex, enteringDelegates.length)
            }

            console.log(
                "[LauncherSearchDebug]",
                "retainedEnter",
                "revision=", revision,
                "postVisible=", root._debugKeys(root.strictVisibleDelegateKeys()),
                "enteringKeys=", root._debugKeys(enteringDelegates.map(function(delegate) { return delegate.key }))
            )
        })
    }

    function releaseManagedEntry(): void {
        if (!root.itemAnimationsEnabled) {
            root._filterTransitionActive = false
            root._managedEntryPending = false
            root.syncInstantiatedDelegateState()
            return
        }

        resultList.contentY = 0
        if (resultList.forceLayout)
            resultList.forceLayout()

        Qt.callLater(function() {
            if (!root._managedEntryPending)
                return

            if (resultList.forceLayout)
                resultList.forceLayout()

            root._queueManagedVisibleDelegates()
            root._filterTransitionActive = false
            root._managedEntryPending = false
        })
    }

    ListView {
        id: resultList
        anchors.fill: parent
        z: 1
        clip: true
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
                enabled: root.itemAnimationsEnabled && root._expandTransitionActive

                SequentialAnimation {
                    PropertyAction { property: "_filterAddOpacity"; value: root._expandFadeEnabled ? 0 : 1 }
                    PropertyAction { property: "_filterAddOffsetX"; value: 30 }
                    PropertyAction { property: "_filterAddOffsetY"; value: 0 }
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
                    NumberAnimation {
                        property: "_filterAddOffsetX"
                        to: 0
                        duration: Theme.anim.moveDuration
                        easing.type: Theme.anim.moveType
                    }
                    NumberAnimation {
                        property: "_filterAddOffsetY"
                        to: 0
                        duration: Theme.anim.moveDuration
                        easing.type: Theme.anim.moveType
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
            enabled: root.itemAnimationsEnabled && !root._filterTransitionActive

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
                        duration: SettingsService.effectiveAnimation.staggerExitDuration
                        easing.type: Easing.InCubic
                    }
                    NumberAnimation {
                        property: "_ty"
                        to: 18
                        duration: SettingsService.effectiveAnimation.staggerExitDuration
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
            managedEnterStep: root._managedEnterStep
            managedEnterFadeEnabled: root.itemAnimationsEnabled
            managedEnterStartOpacity: 0.0
            managedEnterStartOffsetY: enterOffsetY
            enterOffsetY: SettingsService.effectiveAnimation.staggerEnterOffsetY
            exitOffsetY: SettingsService.effectiveAnimation.staggerExitOffsetY
            property real _filterAddOpacity: 1
            property real _filterAddOffsetX: 0
            property real _filterAddOffsetY: 0

            width: resultList.width
            height: 46

            Rectangle {
                anchors.fill: parent
                opacity: root.itemAnimationsEnabled && root._expandTransitionActive ? _item._filterAddOpacity : 1
                transform: Translate {
                    x: root.itemAnimationsEnabled && root._expandTransitionActive ? _item._filterAddOffsetX : 0
                    y: root.itemAnimationsEnabled && root._expandTransitionActive ? _item._filterAddOffsetY : 0
                }
                color: root.selectedIndex === _item.index
                    ? Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.12)
                    : ((root.itemAnimationsEnabled && root._expandTransitionActive && !root._expandFadeEnabled)
                        ? Colors.background
                        : "transparent")

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    Image {
                        source: "image://icon/" + (_item.icon || "application-x-executable")
                        width: 20
                        height: 20
                        sourceSize: Qt.size(20, 20)
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: _item.name
                            color: Colors.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall + 1
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
                height: 46
                exitDelay: modelData.exitDelay
                exitOffsetX: 30
                exitOffsetY: 0
                enterStartOpacity: 1.0
                enterStartOffsetX: 0
                enterStartOffsetY: 0

                Component.onCompleted: {
                    _outgoingItem.opacity = 1.0
                    _outgoingItem._ty = 0
                    _outgoingItem.runExit()
                }

                Rectangle {
                    anchors.fill: parent
                    color: modelData.selected
                        ? Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.12)
                        : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        Image {
                            source: "image://icon/" + (modelData.icon || "application-x-executable")
                            width: 20
                            height: 20
                            sourceSize: Qt.size(20, 20)
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: modelData.name
                                color: Colors.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall + 1
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
