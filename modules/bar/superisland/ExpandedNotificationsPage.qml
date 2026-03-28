import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// Expanded notification center page for the SuperIsland overlay.
Item {
    id: root

    readonly property int _appBadgeSize: 28

    function pageActivated() {
        NotificationService.markAllSeen()
    }

    function pageDeactivated() {
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

            delegate: Rectangle {
                id: _cardRoot

                required property string appName
                required property string summary
                required property string body
                required property string id
                required property real timestamp

                readonly property string notificationId: id

                width: _list.width
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
                            onClicked: NotificationService.removeFromHistory(_cardRoot.notificationId)
                        }
                    }
                }

                MouseArea {
                    id: _cardArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root._tryOpenNotification(_cardRoot.notificationId)
                }
            }

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
