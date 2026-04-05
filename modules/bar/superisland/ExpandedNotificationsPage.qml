import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import ".." as BarComponents

// Expanded notification center page for the SuperIsland overlay.
Item {
    id: root

    readonly property int _appBadgeSize: 28
    readonly property int _maxExitSlots: 6
    property bool _pageActive: false

    function _visibleCardDelegates() {
        let delegates = []

        for (let index = 0; index < NotificationService.historyList.count; index++) {
            let delegate = _list.itemAtIndex(index)
            if (delegate)
                delegates.push(delegate)
        }

        return delegates
    }

    function _syncStaggerItems(includeShell) {
        _pageStagger.clear()
        if (includeShell !== false)
            _pageStagger.registerItem(_listShell, 0, 1)

        let delegates = root._visibleCardDelegates()
        for (let index = 0; index < delegates.length; index++) {
            _pageStagger.registerItem(delegates[index], index, 2)
        }

        if (_emptyState.visible)
            _pageStagger.registerItem(_emptyState, 0, 2)
    }

    function _exitWindow(total) {
        let cappedTotal = Math.max(0, Math.min(total, root._maxExitSlots))
        return Math.max(0, cappedTotal - 1) * SettingsService.data.animation.staggerExitStep
    }

    function _compressedExitDelay(rank, total) {
        if (total <= 1)
            return 0

        let window = root._exitWindow(total)
        return Math.round(window * (rank / Math.max(1, total - 1)))
    }

    function _runCardExit() {
        let delegates = root._visibleCardDelegates()

        for (let index = 0; index < delegates.length; index++) {
            let delegate = delegates[index]
            if (!delegate || typeof delegate.runExit !== "function")
                continue

            delegate.exitDelay = root._compressedExitDelay(index, delegates.length)
            delegate.runExit()
        }

        if (_emptyState.visible) {
            _emptyState.exitDelay = 0
            _emptyState.runExit()
        }
    }

    function pageActivated() {
        root._pageActive = true
        NotificationService.markAllSeen()
        _syncStaggerItems(true)
        _pageStagger.runEnter()
    }

    function pageDeactivated() {
        root._pageActive = false
        _listShell.exitDelay = 0
        _listShell.runExit()
        root._runCardExit()
    }

    function pageExitDuration() {
        let count = root._visibleCardDelegates().length

        if (count === 0 && _emptyState.visible)
            return SettingsService.data.animation.staggerExitDuration

        return SettingsService.data.animation.staggerExitDuration
            + root._exitWindow(count)
    }

    function _relativeTime(timestamp) {
        let diff = Date.now() - Number(timestamp || 0)
        if (diff < 60000)
            return "刚刚"
        if (diff < 3600000)
            return Math.floor(diff / 60000) + " 分钟前"
        if (diff < 86400000)
            return Math.floor(diff / 3600000) + " 小时前"
        return Math.floor(diff / 86400000) + " 天前"
    }

    function _tryOpenNotification(notificationId) {
        if (!notificationId)
            return

        NotificationService.invokeDefaultAction(notificationId)
    }

    BarComponents.StaggerOrchestrator {
        id: _pageStagger
    }

    BarComponents.StaggerItem {
        id: _listShell
        anchors.fill: parent
        Rectangle {
            anchors.fill: parent
            radius: Theme.cornerRadius
            color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.86)
            border.color: Colors.border
            border.width: 1

            ListView {
                id: _list
                anchors.fill: parent
                anchors.margins: 10
                clip: true
                spacing: 8
                model: NotificationService.historyList
                displayMarginBeginning: 120
                displayMarginEnd: 120

                delegate: BarComponents.ViewportStaggerItem {
                    id: _cardStagger

                    required property string appName
                    required property string summary
                    required property string body
                    required property string id
                    required property real timestamp
                    required property int index

                    readonly property string notificationId: id

                    listView: _list
                    scrollAnimationsEnabled: root._pageActive
                    scrollStep: 22
                    viewportPadding: 36
                    enterOffsetY: 34
                    exitOffsetY: 14

                    width: _list.width
                    height: _cardBody.implicitHeight

                    Rectangle {
                        id: _cardBody
                        width: parent.width
                        implicitHeight: _row.implicitHeight + 18
                        radius: Theme.cornerRadius - 2
                        color: _cardArea.containsMouse
                            ? Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.10)
                            : Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.62)
                        border.color: Colors.border
                        border.width: 1

                        Behavior on color {
                            ColorAnimation { duration: Theme.anim.highlightDuration }
                        }

                        RowLayout {
                            id: _row
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10

                            Rectangle {
                                width: root._appBadgeSize
                                height: root._appBadgeSize
                                radius: 6
                                color: Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.15)

                                Text {
                                    anchors.centerIn: parent
                                    text: appName.length > 0 ? appName[0].toUpperCase() : "?"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.DemiBold
                                    color: Colors.highlight
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3

                                RowLayout {
                                    Layout.fillWidth: true

                                    Text {
                                        Layout.fillWidth: true
                                        text: appName || "通知"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Colors.textMuted
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: root._relativeTime(timestamp)
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Colors.textMuted
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: summary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Medium
                                    color: Colors.text
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    visible: body !== ""
                                    text: body
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Colors.textMuted
                                }
                            }

                            Text {
                                text: "✕"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                color: Colors.textMuted
                                padding: 4

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: NotificationService.removeFromHistory(_cardStagger.notificationId)
                                }
                            }
                        }

                        MouseArea {
                            id: _cardArea
                            anchors.fill: _cardBody
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root._tryOpenNotification(_cardStagger.notificationId)
                        }
                    }
                }

                BarComponents.StaggerItem {
                    id: _emptyState
                    anchors.centerIn: parent
                    width: _emptyLabel.implicitWidth
                    height: _emptyLabel.implicitHeight
                    visible: NotificationService.historyList.count === 0

                    Text {
                        id: _emptyLabel
                        text: "暂无通知"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeBody
                        color: Colors.textMuted
                    }
                }
            }
        }
    }

    Connections {
        target: NotificationService.historyList

        function onCountChanged() {
            if (!root.visible)
                return

            Qt.callLater(function() {
                root._syncStaggerItems(true)
            })
        }
    }
}
