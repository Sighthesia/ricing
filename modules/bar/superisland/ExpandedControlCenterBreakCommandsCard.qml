import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import ".." as BarComponents

// Break-reminder command surface for the SuperIsland control center page.
BarComponents.FloatingShellSurface {
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

    component ActionButton: BarComponents.FloatingShellSurface {
        id: buttonRoot

        property alias label: buttonLabel.text
        property color labelColor: Colors.text
        property color actionFillColor: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.18)
        property color actionBorderColor: Qt.rgba(Colors.border.r, Colors.border.g, Colors.border.b, 0.42)
        property bool hovered: actionArea.containsMouse
        property point ripplePoint: Qt.point(width / 2, height / 2)

        signal clicked()

        Layout.fillWidth: true
        implicitHeight: ThemeCards.compactActionHeight
        shellRadius: ThemeCards.compactRadius
        fillColor: actionFillColor
        borderColor: actionBorderColor
        innerBorderColor: Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, ThemeCards.shellInnerBorderAlpha)

        Behavior on fillColor {
            ColorAnimation { duration: Theme.anim.highlightDuration }
        }

        Behavior on borderColor {
            ColorAnimation { duration: Theme.anim.highlightDuration }
        }

        BarComponents.HoverRevealHighlight {
            anchors.fill: parent
            radius: ThemeCards.compactRadius
            hovered: buttonRoot.hovered
            highlightColor: Colors.highlight
            highlightOpacity: ThemeCards.hoverHighlightAlpha
            adaptiveContrast: true
            surfaceColor: buttonRoot.color
        }

        BarComponents.ClickRipple {
            id: actionRipple
            anchors.fill: parent
            radius: ThemeCards.compactRadius
            rippleColor: Colors.highlight
        }

        Text {
            id: buttonLabel
            anchors.centerIn: parent
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: buttonRoot.labelColor
        }

        MouseArea {
            id: actionArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                buttonRoot.ripplePoint = Qt.point(mouse.x, mouse.y)
                actionRipple.triggerRipple(mouse.x, mouse.y)
                buttonRoot.clicked()
            }
        }
    }

    implicitWidth: ThemeCards.compactWidth
    implicitHeight: _contentColumn.implicitHeight + ThemeCards.panelPadding * 2
    contentMargin: ThemeCards.panelPadding

    ColumnLayout {
        id: _contentColumn
        anchors.fill: parent
        anchors.margins: 0
        spacing: ThemeCards.compactGap

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

        BarComponents.FloatingShellSurface {
            Layout.fillWidth: true
            shellRadius: ThemeCards.compactRadius
            contentMargin: Theme.barWidget.contentPaddingH
            fillColor: Qt.rgba(
                Colors.highlight.r,
                Colors.highlight.g,
                Colors.highlight.b,
                root._breakLive ? 0.16 : 0.09
            )
            borderColor: Qt.rgba(Colors.border.r, Colors.border.g, Colors.border.b, 0.28)
            implicitHeight: _summaryColumn.implicitHeight + Theme.barWidget.contentPaddingV * 4

            ColumnLayout {
                id: _summaryColumn
                anchors.fill: parent
                anchors.margins: 0
                spacing: ThemeCards.panelGap / 2

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
            columnSpacing: ThemeCards.panelGap
            rowSpacing: ThemeCards.panelGap

            ActionButton {
                label: root._breakLive ? "打开休息" : "立即休息"
                labelColor: Colors.background
                actionFillColor: Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.9)
                actionBorderColor: Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.9)
                onClicked: BreakReminderService.startBreakNow()
            }

            ActionButton {
                label: "延后提醒"
                onClicked: BreakReminderService.snoozeBreak()
            }

            ActionButton {
                label: "重置周期"
                onClicked: BreakReminderService.restartCycle()
            }

            ActionButton {
                label: root._reminderEnabled ? "关闭提醒" : "开启提醒"
                actionBorderColor: root._reminderEnabled
                    ? Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.56)
                    : Qt.rgba(Colors.border.r, Colors.border.g, Colors.border.b, 0.42)
                onClicked: root._toggleReminderEnabled()
            }
        }
    }
}
