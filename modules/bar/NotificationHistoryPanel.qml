import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.modules.bar

// Drop-down panel showing notification history, anchored below the bar at the right edge.
// Opened/closed by BarLayoutService.notificationHistoryOpen.
AnimatedPanelBase {
    id: root

    anchors { top: true; right: true }
    margins { top: Theme.barHeight }

    implicitWidth: ThemeCards.historyPanelWidth
    implicitHeight: ThemeCards.historyPanelHeight
    focusable: false

    // Component-local layout constants; promote to Theme tokens in a future notification token pass.
    readonly property int _appBadgeSize: ThemeCards.historyBadgeSize
    readonly property int _staggerBaseDelay: SettingsService.effectiveAnimation.staggerLevel1BaseDelay
    readonly property int _staggerStep: SettingsService.effectiveAnimation.staggerLevel1Step

    active: BarLayoutService.notificationHistoryOpen

    Timer {
        id: _enterDelayTimer
        interval: Theme.anim.highlightDuration
        repeat: false
        onTriggered: root._runHistoryEnter()
    }

    // Mark all notifications as seen when the panel slides open.
    onPanelOpening: {
        NotificationService.markAllSeen()
        _enterDelayTimer.restart()
    }

    onPanelClosing: {
        _enterDelayTimer.stop()
        root._runHistoryExit()
    }

    function _visibleHistoryDelegates() {
        let delegates = []

        for (let index = 0; index < _list.count; index++) {
            let delegate = _list.itemAtIndex(index)
            if (delegate)
                delegates.push(delegate)
        }

        return delegates
    }

    function _historyDelay(index) {
        return root._staggerBaseDelay + index * root._staggerStep
    }

    function _runHistoryEnter() {
        let delegates = root._visibleHistoryDelegates()

        for (let index = 0; index < delegates.length; index++) {
            let delegate = delegates[index]
            if (!delegate || typeof delegate.runEnter !== "function")
                continue

            delegate.delay = root._historyDelay(index)
            delegate.runEnter()
        }
    }

    function _runHistoryExit() {
        let delegates = root._visibleHistoryDelegates()

        for (let index = 0; index < delegates.length; index++) {
            let delegate = delegates[index]
            if (!delegate || typeof delegate.runExit !== "function")
                continue

            delegate.exitDelay = index * SettingsService.effectiveAnimation.staggerExitStep
            delegate.runExit()
        }
    }

    // Panel background
    FloatingShellSurface {
        anchors.fill: parent
        anchors.margins: ThemeCards.panelInset
        contentMargin: 0

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: ThemeCards.panelPadding
            spacing: ThemeCards.panelGap

            // Header: title + clear-all button
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "通知"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBody
                    font.bold: true
                    color: Colors.text
                    Layout.fillWidth: true
                }

                Rectangle {
                    implicitHeight: 24
                    implicitWidth: _clearLbl.implicitWidth + 16
                    radius: Theme.cornerRadius / 2
                    color: Qt.rgba(
                        Colors.highlight.r, Colors.highlight.g, Colors.highlight.b,
                        _clearTap.pressed ? 0.2 : 0.08
                    )
                    visible: NotificationService.historyList.count > 0

                    Text {
                        id: _clearLbl
                        anchors.centerIn: parent
                        text: "清空"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Colors.highlight
                    }

                    TapHandler {
                        id: _clearTap
                        onTapped: NotificationService.clearHistory()
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Colors.border
                opacity: 0.5
            }

            // History list
            ListView {
                id: _list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Math.max(4, Math.round(6 * Theme.uiScale))
                model: NotificationService.historyList

                delegate: StaggerItem {
                    id: _historyStagger

                    required property string appName
                    required property string summary
                    required property string body
                    required property string id
                    required property real timestamp

                    width: _list.width
                    height: _historyItem.implicitHeight
                    delay: root._historyDelay(index)
                    exitDelay: index * SettingsService.effectiveAnimation.staggerExitStep
                    enterOffsetY: SettingsService.effectiveAnimation.staggerEnterOffsetY
                    exitOffsetY: SettingsService.effectiveAnimation.staggerExitOffsetY

                    HistoryItem {
                        id: _historyItem
                        width: parent.width
                    }
                }

                // Empty state
                Text {
                    anchors.centerIn: parent
                    visible: NotificationService.historyList.count === 0
                    text: "暂无通知"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBody
                    color: Colors.textMuted
                }
            }
        }
    }

    // FIXME: swipe-to-delete not yet implemented (see design doc §Layer 3 HistoryItem)
    component HistoryItem: Item {
        // ListView delegate role properties (appName, summary, body, id, timestamp)
        required property string appName
        required property string summary
        required property string body
        required property string id
        required property real   timestamp

        implicitHeight: _row.implicitHeight + 16

        Rectangle {
            anchors.fill: parent
            radius: ThemeCards.compactRadius
            color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, ThemeCards.historyItemSurfaceAlpha)
            border.color: Colors.border
            border.width: 1

            RowLayout {
                id: _row
                anchors {
                    left: parent.left; right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                anchors.margins: ThemeCards.compactInset
                spacing: ThemeCards.panelGap

                // App initial-letter badge
                Rectangle {
                    width: root._appBadgeSize; height: root._appBadgeSize
                    radius: Math.max(4, Math.round(6 * Theme.uiScale))
                    color: Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.15)

                    Text {
                        anchors.centerIn: parent
                        text: appName.length > 0 ? appName[0].toUpperCase() : "?"
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: true
                        color: Colors.highlight
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: appName
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: Colors.textMuted
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        Text {
                            text: {
                                var diff = Date.now() - timestamp;
                                if (diff < 60000)     return "刚刚";
                                if (diff < 3600000)   return Math.floor(diff / 60000)   + " 分钟前";
                                if (diff < 86400000)  return Math.floor(diff / 3600000) + " 小时前";
                                return Math.floor(diff / 86400000) + " 天前";
                            }
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: Colors.textMuted
                        }
                    }

                    Text {
                        text: summary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: true
                        color: Colors.text
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Text {
                        text: body
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Colors.textMuted
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        visible: body !== ""
                    }
                }

                // Delete button — TapHandler inside Text so it shares the hit area
                Text {
                    text: "✕"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Colors.textMuted
                    padding: 4

                    TapHandler {
                        onTapped: NotificationService.removeFromHistory(id)
                    }
                }
            }
        }
    }
}
