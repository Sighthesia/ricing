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
    property bool _filterTransitionActive: false
    property bool _managedEntryPending: false
    property bool _expandTransitionActive: false
    property int _expandInsertCount: 0
    property int _expandDelaySlots: 0
    property int _activeSwapExitDuration: 0
    property var _outgoingItems: []
    readonly property int _maxViewportSlots: 6
    readonly property int _managedEnterStep: 30

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
        root.scrollAnimationsEnabled = true

        if (root._managedEntryPending)
            return

        let delegates = root._visibleDelegates()
        for (let index = 0; index < delegates.length; index++) {
            if (delegates[index].runViewportEnter)
                delegates[index].runViewportEnter()
        }
    }

    function runExit(): void {
        let delegates = root._visibleDelegates()
        for (let index = 0; index < delegates.length; index++) {
            delegates[index].exitDelay = root._compressedDelay(index, delegates.length)
            delegates[index].runExit()
        }
    }

    function runSwapExit(nextKeys): void {
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
            ? SettingsService.data.animation.staggerExitDuration + root._windowForCount(snapshots.length)
            : 0
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

    function beginFilterTransition(): void {
        _outgoingClearTimer.stop()
        _managedEntryReleaseTimer.stop()
        _filterTransitionReleaseTimer.stop()
        root._outgoingItems = []
        root._activeSwapExitDuration = 0
        root._managedEntryPending = false
        root._expandTransitionActive = false
        root._expandInsertCount = 0
        root._filterTransitionActive = true
    }

    function beginExpandTransition(insertCount, delaySlots): void {
        beginFilterTransition()
        root._expandTransitionActive = true
        root._expandInsertCount = Math.max(0, Number(insertCount) || 0)
        root._expandDelaySlots = Math.max(root._expandInsertCount, Math.max(0, Number(delaySlots) || 0))
    }

    function endFilterTransition(): void {
        _filterTransitionReleaseTimer.stop()
        root._filterTransitionActive = false
        root._expandTransitionActive = false
        root._expandInsertCount = 0
        root._expandDelaySlots = 0
    }

    function scheduleFilterTransitionRelease(delayMs): void {
        _filterTransitionReleaseTimer.interval = Math.max(0, Number(delayMs) || 0)
        _filterTransitionReleaseTimer.restart()
    }

    function resetTransientState(): void {
        _outgoingClearTimer.stop()
        _managedEntryReleaseTimer.stop()
        _filterTransitionReleaseTimer.stop()
        root._outgoingItems = []
        root._filterTransitionActive = false
        root._managedEntryPending = false
        root._expandTransitionActive = false
        root._expandInsertCount = 0
        root._expandDelaySlots = 0
        root._activeSwapExitDuration = 0
    }

    function visibleExitDuration(): int {
        return SettingsService.data.animation.staggerExitDuration
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
        return Math.max(0, capped - 1) * SettingsService.data.animation.staggerExitStep
    }

    function _compressedDelay(rank, total): int {
        if (total <= 1)
            return 0

        let window = root._windowForCount(total)
        return Math.round(window * (rank / Math.max(1, total - 1)))
    }

    function _visibleDelegates(): var {
        let delegates = []

        for (let index = 0; index < resultList.count; index++) {
            let delegate = resultList.itemAtIndex(index)
            if (delegate && delegate.viewportVisible)
                delegates.push(delegate)
        }

        return delegates
    }

    function prepareManagedEntry(): void {
        root.scrollAnimationsEnabled = true
        root._managedEntryPending = true
    }

    function scheduleManagedEntryRelease(delayMs): void {
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

    function releaseManagedEntry(): void {
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
        clip: true
        cacheBuffer: 0
        displayMarginBeginning: 92
        displayMarginEnd: 92

        move: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: Theme.anim.moveDuration
                easing.type: Theme.anim.moveType
            }
        }

        add: Transition {
            id: _addTransition
            enabled: root._expandTransitionActive

            SequentialAnimation {
                PropertyAction { property: "_filterAddOpacity"; value: 0 }
                PropertyAction { property: "_filterAddOffsetY"; value: -18 }
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
                        duration: Theme.anim.highlightDuration
                        easing.type: Easing.OutCubic
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
                duration: Theme.anim.moveDuration
                easing.type: Theme.anim.moveType
            }
        }

        removeDisplaced: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: Theme.anim.moveDuration
                easing.type: Theme.anim.moveType
            }
        }

        moveDisplaced: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: Theme.anim.moveDuration
                easing.type: Theme.anim.moveType
            }
        }

        remove: Transition {
            id: _removeTransition
            enabled: !root._filterTransitionActive

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
                        duration: SettingsService.data.animation.staggerExitDuration
                        easing.type: Easing.InCubic
                    }
                    NumberAnimation {
                        property: "_ty"
                        to: 18
                        duration: SettingsService.data.animation.staggerExitDuration
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
            ownerManagedEntry: root._managedEntryPending
            scrollAnimationsEnabled: root.scrollAnimationsEnabled
            suppressViewportTransitions: ownerManagedEntry || root._filterTransitionActive
            syncViewportStateWhenSuppressed: root._filterTransitionActive && !root._managedEntryPending
            managedEnterKey: _item.key
            managedEnterJitterEnabled: false
            viewportPadding: 28
            scrollStep: 60
            viewportEnterBaseDelay: 80
            managedEnterStep: root._managedEnterStep
            managedEnterFadeEnabled: true
            managedEnterStartOpacity: 0.0
            managedEnterStartOffsetY: enterOffsetY
            enterOffsetY: 28
            exitOffsetY: 14
            property real _filterAddOpacity: 1
            property real _filterAddOffsetY: 0

            width: resultList.width
            height: 46

            Rectangle {
                anchors.fill: parent
                opacity: root._expandTransitionActive ? _item._filterAddOpacity : 1
                transform: Translate {
                    y: root._expandTransitionActive ? _item._filterAddOffsetY : 0
                }
                color: root.selectedIndex === _item.index
                    ? Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.12)
                    : "transparent"

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
        visible: root._outgoingItems.length > 0
        z: 1

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
                exitOffsetY: 18
                enterStartOpacity: 1.0
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
