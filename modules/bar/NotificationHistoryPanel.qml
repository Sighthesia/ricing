import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// Drop-down panel showing notification history, anchored below the bar at the right edge.
// Opened/closed by BarLayoutService.notificationHistoryOpen.
AnimatedPanelBase {
    id: root

    anchors { top: true; right: true }
    margins { top: Theme.barHeight }

    implicitWidth: 400
    implicitHeight: 480
    focusable: false

    active: BarLayoutService.notificationHistoryOpen

    // Mark all notifications as seen when the panel slides open
    onPanelOpening: NotificationService.markAllSeen()

    // Panel background
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 4
        anchors.rightMargin: 4
        anchors.bottomMargin: 4
        radius: Theme.cornerRadius
        color: Colors.background
        border.color: Colors.border
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

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
                spacing: 6
                model: NotificationService.historyList

                delegate: _HistoryItem { width: ListView.view.width }

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

    // Compact history item — swipe-to-delete not yet implemented
    component _HistoryItem: Item {
        // ListView delegate role properties (appName, summary, body, id, timestamp)
        required property string appName
        required property string summary
        required property string body
        required property string id
        required property real   timestamp

        implicitHeight: _row.implicitHeight + 16

        Rectangle {
            anchors.fill: parent
            radius: Theme.cornerRadius / 2
            color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.6)
            border.color: Colors.border
            border.width: 1

            RowLayout {
                id: _row
                anchors {
                    left: parent.left; right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                anchors.margins: 10
                spacing: 8

                // App initial-letter badge
                Rectangle {
                    width: 28; height: 28
                    radius: 6
                    color: Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.15)

                    Text {
                        anchors.centerIn: parent
                        text: appName.length > 0 ? appName[0].toUpperCase() : "?"
                        font.pixelSize: 12
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
