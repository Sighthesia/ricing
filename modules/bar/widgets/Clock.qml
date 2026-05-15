import QtQuick
import Quickshell
import "../../../services" as Services

// Compact bar clock showing date and time.
Item {
    id: root

    implicitWidth: clockRow.implicitWidth + 16
    implicitHeight: 26

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
            font.pixelSize: 11
        }

        // Separator
        Rectangle {
            width: 1
            height: 12
            anchors.verticalCenter: parent.verticalCenter
            color: Services.Color.mOutline
        }

        // Time: HH:mm
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(systemClock.date, "hh:mm")
            color: Services.Color.mOnSurface
            font.pixelSize: 12
            font.bold: true
        }
    }
}
