import QtQuick
import Quickshell
import "../../../services" as Services

// Compact bar clock showing date and time.
Item {
    id: root

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

        // Date: MMM d
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(systemClock.date, "MMM d")
            color: Services.Color.mOnSurfaceVariant
            font.pixelSize: Services.TextSize.barContent
        }

        // Separator
        Rectangle {
            width: 1
            height: 14
            anchors.verticalCenter: parent.verticalCenter
            color: Services.Color.mOutline
        }

        // Time: HH:mm
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(systemClock.date, "hh:mm")
            color: Services.Color.mOnSurface
            font.pixelSize: Services.TextSize.barContent
            font.bold: true
        }
    }
}
