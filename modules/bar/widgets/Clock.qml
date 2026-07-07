import QtQuick
import Quickshell
import "../../../services" as Services
import "../../../services/WidgetSettingsRegistry.js" as WidgetSettingsRegistry

// Compact bar clock showing a configurable date/time string. While a transient
// message is active the date collapses away unless compact mode is configured
// to keep it visible.
Item {
    id: root

    // Simplify to time-only during transient messages unless the user opts in.
    readonly property bool simplified: Services.TransientMessageService.active
    readonly property var clockSettings: WidgetSettingsRegistry.settingsObject(
        "clock",
        Services.SettingsService.widgetSettings
    )
    readonly property bool showDate: clockSettings ? clockSettings.showDate : true
    readonly property bool showDateWhenSimplified: clockSettings ? clockSettings.showDateWhenSimplified : false
    readonly property string clockFormat: clockSettings && typeof clockSettings.timeFormat === "string" && clockSettings.timeFormat.length > 0
        ? clockSettings.timeFormat
        : "yyyy.MM.dd|HH:mm"
    readonly property int separatorIndex: root.clockFormat.indexOf("|")
    readonly property string dateFormat: root.separatorIndex >= 0 ? root.clockFormat.slice(0, root.separatorIndex) : ""
    readonly property string timeFormat: root.separatorIndex >= 0 ? root.clockFormat.slice(root.separatorIndex + 1) : root.clockFormat
    readonly property real transientRevealProgress: Services.TransientMessageService.revealProgress
    readonly property real dateRevealProgress: root.showDate
        ? (root.showDateWhenSimplified ? 1 : 1 - root.transientRevealProgress)
        : 0

    implicitWidth: clockRow.implicitWidth + 20
    implicitHeight: 30

    SystemClock {
        id: systemClock
        precision: SystemClock.Minutes
    }

    Row {
        id: clockRow

        anchors.centerIn: parent
        spacing: 6

        // Date slot smoothly yields space to transient messages.
        Item {
            id: dateSlot

            anchors.verticalCenter: parent.verticalCenter
            width: dateText.implicitWidth * root.dateRevealProgress
            height: dateText.implicitHeight
            clip: true
            visible: width > 0.5

            Services.FluidText {
                id: dateText

                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(systemClock.date, root.dateFormat)
                color: Services.Color.mOnSurfaceVariant
                opacity: root.dateRevealProgress
                x: Math.round((1 - root.dateRevealProgress) * -6)
            }
        }

        // Separator yields with the date so compact mode keeps only the time.
        Item {
            id: separatorSlot

            anchors.verticalCenter: parent.verticalCenter
            width: root.dateRevealProgress > 0.01 ? 1 : 0
            height: 14
            clip: true
            visible: width > 0.5

            Rectangle {
                anchors.fill: parent
                color: Services.Color.mOutline
                opacity: root.dateRevealProgress
            }
        }

        // Time slot follows the configured clock format.
        Services.FluidText {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(systemClock.date, root.timeFormat)
            color: Services.Color.mOnSurface
            font.bold: true
        }
    }
}
