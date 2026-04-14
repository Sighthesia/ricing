import QtQuick
import QtQuick.Layouts
import qs.config
import ".." as BarComponents
import "./ExpandedControlCenterCalendar.js" as CalendarLogic

// Calendar surface for the SuperIsland control center page.
BarComponents.FloatingShellSurface {
    id: root

    readonly property var _dayLabels: ["一", "二", "三", "四", "五", "六", "日"]
    readonly property var _now: new Date()
    readonly property var _monthAnchor: new Date(root._now.getFullYear(), root._now.getMonth(), 1)
    readonly property var _calendarCells: CalendarLogic.buildMonthCells(root._monthAnchor, root._now)

    contentMargin: ThemeCards.panelPadding
    implicitWidth: ThemeCards.largePanelWidth
    implicitHeight: ThemeCards.largePanelHeight

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 0
        spacing: ThemeCards.largePanelGap

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

            BarComponents.FloatingShellSurface {
                shellRadius: ThemeCards.compactRadius
                fillColor: Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.16)
                borderColor: Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.36)
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

        BarComponents.FloatingShellSurface {
            Layout.fillWidth: true
            Layout.fillHeight: true
            shellRadius: ThemeCards.compactRadius
            contentMargin: ThemeCards.largePanelInset
            fillColor: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.34)
            borderColor: Qt.rgba(Colors.border.r, Colors.border.g, Colors.border.b, 0.42)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 0
                spacing: ThemeCards.compactGap

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

                RowLayout {
                    Layout.fillWidth: true
                    spacing: ThemeCards.panelGap

                    Repeater {
                        model: root._dayLabels

                        delegate: Text {
                            required property string modelData
                            Layout.fillWidth: true
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
                    columnSpacing: ThemeCards.dayGridGap
                    rowSpacing: ThemeCards.dayGridGap

                    Repeater {
                        model: root._calendarCells

                        delegate: Rectangle {
                            required property var modelData
                            width: Math.max(0, (_calendarGrid.width - _calendarGrid.columnSpacing * 6) / 7)
                            height: ThemeCards.dayCellHeight
                            radius: ThemeCards.dayCellRadius
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
