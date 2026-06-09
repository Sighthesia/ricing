import QtQuick
import Quickshell
import "../../../services" as Services
import "../../../services/WidgetSettingsRegistry.js" as WidgetSettingsRegistry

// Compact bar clock showing date and time. While a transient message is
// active the date collapses away so the clock simplifies to time-only,
// yielding attention to the interrupting message.
Item {
    id: root

    // Simplify to time-only during transient messages (hardcoded on for now).
    readonly property bool simplified: Services.TransientMessageService.active
    readonly property var clockSettings: WidgetSettingsRegistry.settingsObject(
        "clock",
        Services.SettingsService.widgetSettings
    )
    readonly property bool showDate: clockSettings ? clockSettings.showDate : true
    readonly property bool showDateWhenSimplified: clockSettings ? clockSettings.showDateWhenSimplified : false
    readonly property bool use24Hour: clockSettings ? clockSettings.timeFormat === "24h" : false
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

            Text {
                id: dateText

                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(systemClock.date, "MMM d")
                color: Services.Color.mOnSurfaceVariant
                font.pixelSize: Services.TextSize.barContent
                opacity: root.dateRevealProgress
                x: Math.round((1 - root.dateRevealProgress) * -6)
            }
        }

        // Separator yields with the date so the clock remains one object.
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: root.dateRevealProgress > 0.01 ? 1 : 0
            height: 14
            clip: true

            Rectangle {
                anchors.fill: parent
                color: Services.Color.mOutline
                opacity: root.dateRevealProgress
            }
        }

        // Time: HH:mm
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(systemClock.date, root.use24Hour ? "HH:mm" : "hh:mm")
            color: Services.Color.mOnSurface
            font.pixelSize: Services.TextSize.barContent
            font.bold: true
        }
    }
}
