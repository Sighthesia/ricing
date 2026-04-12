import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import ".." as BarComponents
import "./ExpandedNotificationsPageLogic.js" as PageLogic

// Expanded notification center page for the SuperIsland overlay.
Item {
    id: root

    readonly property int _appBadgeSize: ThemeCards.historyBadgeSize
    readonly property int _maxExitSlots: 6
    property bool _pageActive: false
    property bool _historyRevealPending: false

    Timer {
        id: _cardEnterDelayTimer
        interval: Theme.anim.highlightDuration
        repeat: false
        onTriggered: {
            if (root._pageActive)
                root._runCardEnter()
            root._historyRevealPending = false
        }
    }

    function _visibleCardDelegates() {
        return PageLogic.visibleCardDelegates(_list, NotificationService.historyList.count)
    }

    function _syncStaggerItems(includeShell) {
        PageLogic.syncStaggerItems(_pageStagger, _listShell, includeShell)
    }

    function _runCardEnter() {
        let delegates = root._visibleCardDelegates()
        PageLogic.runCardEnter(delegates, _emptyState.visible, function() {
            _emptyState.delay = 0
            _emptyState.runEnter()
        })
    }

    function _runCardExit() {
        let delegates = root._visibleCardDelegates()
        PageLogic.runCardExit(
            delegates,
            _emptyState.visible,
            root._maxExitSlots,
            SettingsService.effectiveAnimation.staggerExitStep,
            function() {
                _emptyState.exitDelay = 0
                _emptyState.runExit()
            }
        )
    }

    function pageActivated() {
        if (root._historyRevealPending)
            return

        root._historyRevealPending = true
        root._pageActive = true
        NotificationService.markAllSeen()
        _syncStaggerItems(true)
        _pageStagger.runEnter()
        _cardEnterDelayTimer.restart()
    }

    function pageDeactivated() {
        root._pageActive = false
        root._historyRevealPending = false
        _cardEnterDelayTimer.stop()
        _listShell.exitDelay = 0
        _listShell.runExit()
        root._runCardExit()
    }

    function pageExitDuration() {
        let count = root._visibleCardDelegates().length

        if (count === 0 && _emptyState.visible)
            return SettingsService.effectiveAnimation.staggerExitDuration

        return SettingsService.effectiveAnimation.staggerExitDuration
            + PageLogic.exitWindow(count, root._maxExitSlots, SettingsService.effectiveAnimation.staggerExitStep)
    }

    function _relativeTime(timestamp) {
        return PageLogic.relativeTime(timestamp, Date.now())
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
                anchors.margins: ThemeCards.compactInset
                clip: true
                spacing: ThemeCards.panelGap
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
                    ownerManagedEntry: !root._pageActive || root._historyRevealPending
                    managedEnterKey: notificationId
                    managedEnterJitterEnabled: false
                    managedEnterFadeEnabled: true
                    managedEnterStartOpacity: 0.0
                    managedEnterStartOffsetY: enterOffsetY
                    viewportEnterBaseDelay: SettingsService.effectiveAnimation.staggerLevel2BaseDelay
                    managedEnterBaseDelay: SettingsService.effectiveAnimation.staggerLevel2BaseDelay
                    scrollStep: SettingsService.effectiveAnimation.staggerExitStep
                    managedEnterStep: SettingsService.effectiveAnimation.staggerLevel2Step
                    viewportPadding: 36
                    enterOffsetY: SettingsService.effectiveAnimation.staggerEnterOffsetY
                    exitOffsetY: SettingsService.effectiveAnimation.staggerExitOffsetY

                    width: _list.width
                    height: _cardBody.implicitHeight

                    Rectangle {
                        id: _cardBody
                        width: parent.width
                        implicitHeight: _row.implicitHeight + 18
                        radius: ThemeCards.compactRadius
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
                            anchors.margins: ThemeCards.panelPadding
                            spacing: ThemeCards.compactGap

                            Rectangle {
                                width: root._appBadgeSize
                                height: root._appBadgeSize
                                radius: Math.max(4, Math.round(6 * Theme.uiScale))
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
            if (!root.visible || root._historyRevealPending)
                return

            Qt.callLater(function() {
                root._syncStaggerItems(true)
                if (root._pageActive)
                    root._runCardEnter()
            })
        }
    }
}
