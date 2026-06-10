import QtQuick
import Quickshell
import "../../services" as Services

// Compact clock display for the collapsed island state.
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
        Services.FluidText {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(systemClock.date, "MMM d")
            color: Services.Color.mOnSurfaceVariant
            basePixelSize: 11
        }

        // Separator
        Rectangle {
            width: 1
            height: 12
            anchors.verticalCenter: parent.verticalCenter
            color: Services.Color.mOutline
        }

        // Time: HH:mm
        Services.FluidText {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(systemClock.date, "hh:mm")
            color: Services.Color.mOnSurface
            basePixelSize: 12
            font.bold: true
        }
    }
}
