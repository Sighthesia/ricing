import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "./ExpandedControlCenterCalendar.js" as CalendarLogic

// Calendar-focused card for the SuperIsland control center page.
Rectangle {
    id: root

    readonly property var _dayLabels: ["一", "二", "三", "四", "五", "六", "日"]
    property var _now: new Date()
    readonly property var _monthAnchor: new Date(root._now.getFullYear(), root._now.getMonth(), 1)
    readonly property var _calendarCells: CalendarLogic.buildMonthCells(root._monthAnchor, root._now)

    radius: Theme.cornerRadius
    color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.68)
    border.color: Qt.rgba(Colors.border.r, Colors.border.g, Colors.border.b, 0.72)
    border.width: 1
    implicitHeight: Math.round(392 * Theme.uiScale)

    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: root._now = new Date()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.settingsPanelPadding + 2
        spacing: 12

        RowLayout {
            Layout.fillWidth: true

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: "控制中心"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBody + 2
                    font.weight: Font.DemiBold
                    color: Colors.text
                }

                Text {
                    text: Qt.formatDate(root._now, "yyyy 年 M 月 d 日") + "  " + CalendarLogic.weekdayLabel(root._now)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Colors.textMuted
                }
            }

            Rectangle {
                radius: Theme.cornerRadius
                color: Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.16)
                border.color: Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.36)
                border.width: 1
                implicitWidth: _todayBadgeText.implicitWidth + Theme.barWidget.badgePaddingH * 2
                implicitHeight: _todayBadgeText.implicitHeight + Theme.barWidget.badgePaddingV * 2

                Text {
                    id: _todayBadgeText
                    anchors.centerIn: parent
                    text: "今天 " + root._now.getDate()
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall
                    color: Colors.highlight
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.cornerRadius
            color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.34)
            border.color: Qt.rgba(Colors.border.r, Colors.border.g, Colors.border.b, 0.42)
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.settingsPanelPadding
                spacing: 10

                ColumnLayout {
                    spacing: 2

                    Text {
                        text: Qt.formatDate(root._monthAnchor, "yyyy 年 M 月")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeBody
                        font.weight: Font.Medium
                        color: Colors.text
                    }

                    Text {
                        text: "月历视图"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Colors.textMuted
                    }
                }

                Row {
                    id: _weekdayRow
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: root._dayLabels

                        delegate: Text {
                            required property string modelData
                            width: Math.max(0, (_weekdayRow.width - _weekdayRow.spacing * 6) / 7)
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeSmall
                            color: Colors.textMuted
                        }
                    }
                }

                Grid {
                    id: _calendarGrid
                    Layout.fillWidth: true
                    columns: 7
                    columnSpacing: 8
                    rowSpacing: 8

                    Repeater {
                        model: root._calendarCells

                        delegate: Rectangle {
                            required property var modelData
                            width: Math.max(0, (_calendarGrid.width - _calendarGrid.columnSpacing * 6) / 7)
                            height: Math.round(44 * Theme.uiScale)
                            radius: 10
                            color: modelData.isToday
                                ? Colors.highlight
                                : (modelData.currentMonth
                                    ? Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.28)
                                    : Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.12))
                            border.color: modelData.isToday
                                ? Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.82)
                                : Qt.rgba(Colors.border.r, Colors.border.g, Colors.border.b, 0.28)
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: modelData.day
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeBody
                                font.weight: modelData.isToday ? Font.DemiBold : Font.Normal
                                color: modelData.isToday
                                    ? Colors.background
                                    : (modelData.currentMonth ? Colors.text : Colors.textMuted)
                                opacity: modelData.weekend && !modelData.isToday ? 0.86 : 1
                            }
                        }
                    }
                }
            }
        }
    }
}
