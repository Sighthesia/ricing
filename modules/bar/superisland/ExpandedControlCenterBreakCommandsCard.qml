import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// Break-reminder command surface for the SuperIsland control center page.
Rectangle {
    id: root

    readonly property bool _reminderEnabled: SettingsService.data.superIsland.breakReminderEnabled
    readonly property bool _breakLive: BreakReminderService.breakActive || BreakReminderService.outroActive
    readonly property string _statusTitle:
        !root._reminderEnabled ? "提醒已关闭"
        : (BreakReminderService.breakActive
            ? "正在休息"
            : (BreakReminderService.preAlertActive ? "即将休息" : "定时运行中"))
    readonly property string _statusSubtitle:
        !root._reminderEnabled
            ? "你仍然可以手动开始一次休息。"
            : (BreakReminderService.breakActive
                ? ("剩余 " + BreakReminderService.countdownText + "，保持视线离开屏幕。")
                : (BreakReminderService.preAlertActive
                    ? (BreakReminderService.leadSeconds + " 秒后自动开始休息。")
                    : ("每 " + BreakReminderService.workMinutes + " 分钟提醒一次，休息 "
                        + BreakReminderService.breakDurationSeconds + " 秒。")))

    function _toggleReminderEnabled() {
        SettingsService.data.superIsland.breakReminderEnabled = !root._reminderEnabled
        SettingsService.save()
    }

    radius: Theme.cornerRadius
    color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.68)
    border.color: Qt.rgba(Colors.border.r, Colors.border.g, Colors.border.b, 0.72)
    border.width: 1
    implicitWidth: Math.round(280 * Theme.uiScale)
    implicitHeight: _contentColumn.implicitHeight + Theme.settingsPanelPadding * 2

    ColumnLayout {
        id: _contentColumn
        anchors.fill: parent
        anchors.margins: Theme.settingsPanelPadding
        spacing: 10

        ColumnLayout {
            spacing: 2

            Text {
                text: "休息提醒"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeBody
                font.weight: Font.Medium
                color: Colors.text
            }

            Text {
                text: root._statusTitle
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: root._breakLive ? Colors.highlight : Colors.textMuted
            }
        }

        Rectangle {
            Layout.fillWidth: true
            radius: 12
            color: Qt.rgba(
                Colors.highlight.r,
                Colors.highlight.g,
                Colors.highlight.b,
                root._breakLive ? 0.16 : 0.09
            )
            border.color: Qt.rgba(Colors.border.r, Colors.border.g, Colors.border.b, 0.28)
            border.width: 1
            implicitHeight: _summaryColumn.implicitHeight + Theme.barWidget.contentPaddingV * 4

            ColumnLayout {
                id: _summaryColumn
                anchors.fill: parent
                anchors.margins: Theme.barWidget.contentPaddingH
                spacing: 4

                Text {
                    text: root._breakLive ? BreakReminderService.phaseTitle : "20-20-20 护眼节律"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Colors.text
                }

                Text {
                    Layout.fillWidth: true
                    text: root._statusSubtitle
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Colors.textMuted
                    wrapMode: Text.WordWrap
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 8
            rowSpacing: 8

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 42
                radius: 12
                color: Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.9)
                border.color: "transparent"

                Text {
                    anchors.centerIn: parent
                    text: root._breakLive ? "打开休息" : "立即休息"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Colors.background
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: BreakReminderService.startBreakNow()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 42
                radius: 12
                color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.18)
                border.color: Qt.rgba(Colors.border.r, Colors.border.g, Colors.border.b, 0.42)
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "延后提醒"
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
                Layout.fillWidth: true
                implicitHeight: 42
                radius: 12
                color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.18)
                border.color: Qt.rgba(Colors.border.r, Colors.border.g, Colors.border.b, 0.42)
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "重置周期"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Colors.text
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: BreakReminderService.restartCycle()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 42
                radius: 12
                color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.18)
                border.color: root._reminderEnabled
                    ? Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.56)
                    : Qt.rgba(Colors.border.r, Colors.border.g, Colors.border.b, 0.42)
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: root._reminderEnabled ? "关闭提醒" : "开启提醒"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Colors.text
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root._toggleReminderEnabled()
                }
            }
        }
    }
}
