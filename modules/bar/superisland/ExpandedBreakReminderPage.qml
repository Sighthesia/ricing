import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// Full-screen 20-20-20 reminder page rendered inside the expanded SuperIsland shell.
Item {
    id: root

    function pageActivated() {
        _ringCanvas.requestPaint()
    }

    function pageDeactivated() {
    }

    function pageExitDuration() {
        return 0
    }

    readonly property real _ringSize: Math.max(220, Math.min(width, height) * 0.28)
    readonly property real _ringThickness: Math.max(14, Math.round(_ringSize * 0.055))
    readonly property real _contentPadding: Math.max(20, Math.round(28 * Theme.uiScale))

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.18)
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.14)
        border.color: Qt.rgba(Colors.border.r, Colors.border.g, Colors.border.b, 0.22)
        border.width: 1
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.06)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root._contentPadding
        spacing: Math.max(18, Math.round(22 * Theme.uiScale))

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                radius: 999
                color: Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.18)
                border.color: Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.46)
                border.width: 1
                implicitWidth: _badgeRow.implicitWidth + 24
                implicitHeight: 34

                RowLayout {
                    id: _badgeRow
                    anchors.centerIn: parent
                    spacing: 8

                    Rectangle {
                        width: 8
                        height: 8
                        radius: width / 2
                        color: Colors.highlight
                    }

                    Text {
                        text: BreakReminderService.phaseTitle
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeBody
                        font.weight: Font.DemiBold
                        color: Colors.text
                    }
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                id: _snoozeButton
                color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.34)
                border.color: Qt.rgba(Colors.border.r, Colors.border.g, Colors.border.b, 0.8)
                border.width: 1
                radius: 12
                implicitWidth: _snoozeLabel.implicitWidth + 28
                implicitHeight: 38

                Text {
                    id: _snoozeLabel
                    anchors.centerIn: parent
                    text: "延后 " + BreakReminderService.snoozeMinutes + " 分钟"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Colors.text
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: BreakReminderService.snoozeBreak()
                }
            }

            Rectangle {
                id: _finishButton
                color: Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.9)
                border.color: "transparent"
                radius: 12
                implicitWidth: _finishLabel.implicitWidth + 28
                implicitHeight: 38

                Text {
                    id: _finishLabel
                    anchors.centerIn: parent
                    text: "结束休息"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Colors.background
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: BreakReminderService.finishBreak()
                }
            }
        }

        Item { Layout.fillHeight: true }

        Item {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: root._ringSize
            implicitHeight: root._ringSize

            Canvas {
                id: _ringCanvas
                anchors.fill: parent

                onPaint: {
                    const context = getContext("2d")
                    const progress = Math.max(0, Math.min(1, BreakReminderService.breakProgress))
                    const size = Math.min(width, height)
                    const lineWidth = root._ringThickness
                    const center = size / 2
                    const radius = center - lineWidth / 2
                    const startAngle = -Math.PI / 2
                    const endAngle = startAngle + Math.PI * 2 * progress

                    context.clearRect(0, 0, width, height)

                    context.lineCap = "round"
                    context.lineWidth = lineWidth
                    context.strokeStyle = Qt.rgba(Colors.border.r, Colors.border.g, Colors.border.b, 0.3)
                    context.beginPath()
                    context.arc(center, center, radius, 0, Math.PI * 2, false)
                    context.stroke()

                    context.strokeStyle = Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.96)
                    context.beginPath()
                    context.arc(center, center, radius, startAngle, endAngle, false)
                    context.stroke()
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 8

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: BreakReminderService.countdownText
                    font.family: Theme.fontMono
                    font.pixelSize: Math.max(34, Math.round(42 * Theme.uiScale))
                    font.bold: true
                    color: Colors.text
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "保持视线离开屏幕"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Colors.textMuted
                }
            }
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 12

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: BreakReminderService.phaseSubtitle
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(16, Theme.fontSizeBody)
                font.weight: Font.Medium
                color: Colors.text
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "看看窗外、远处墙面或走廊尽头，让眼部肌肉从近距离聚焦里松开。"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeBody
                color: Colors.textMuted
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                Layout.maximumWidth: Math.min(parent.width, Math.round(720 * Theme.uiScale))
            }
        }

        Item { Layout.fillHeight: true }
    }

    Connections {
        target: BreakReminderService

        function onRemainingMsChanged() {
            _ringCanvas.requestPaint()
        }

        function onBreakProgressChanged() {
            _ringCanvas.requestPaint()
        }
    }
}
