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
    property bool ownerManagedEntry: false
    readonly property int _maxViewportSlots: 6

    signal selectRequested(int index)
    signal activateRequested(int index)

    Layout.fillWidth: true
    Layout.fillHeight: true

    function runEnter(): void {
        root.scrollAnimationsEnabled = true

        let delegates = root._visibleDelegates()
        for (let index = 0; index < delegates.length; index++) {
            delegates[index].delay = root._compressedDelay(index, delegates.length)
            delegates[index].runEnter()
        }

        root.ownerManagedEntry = false
    }

    function runExit(): void {
        let delegates = root._visibleDelegates()
        for (let index = 0; index < delegates.length; index++) {
            delegates[index].exitDelay = root._compressedDelay(index, delegates.length)
            delegates[index].runExit()
        }
    }

    function visibleExitDuration(): int {
        return SettingsService.data.animation.staggerExitDuration
            + root._windowForCount(root._visibleDelegates().length)
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
        root.ownerManagedEntry = true
    }

    ListView {
        id: resultList
        anchors.fill: parent
        clip: true
        cacheBuffer: 0
        displayMarginBeginning: 92
        displayMarginEnd: 92

        delegate: BarComponents.ViewportStaggerItem {
            id: _item

            required property int index
            required property string name
            required property string description
            required property string icon

            listView: resultList
            scrollAnimationsEnabled: root.scrollAnimationsEnabled
            ownerManagedEntry: root.ownerManagedEntry
            viewportPadding: 28
            scrollStep: 24
            enterOffsetY: 42
            exitOffsetY: 18

            width: resultList.width
            height: 46

            Rectangle {
                anchors.fill: parent
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

    function positionSelection(index): void {
        if (index < 0 || index >= resultList.count) return;
        resultList.positionViewAtIndex(index, ListView.Contain);
    }

    function delegateAtIndex(index): var {
        return resultList.itemAtIndex(index);
    }
}
