import QtQuick
import Quickshell
import "../../services" as Services
import "../bar/widgets" as ClockParts

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

        // Time uses the shared rolling-digit display.
        ClockParts.RollingClockTime {
            currentTime: systemClock.date
            digitPixelSize: 12
            hourMutedColor: Services.Color.mOnSurfaceVariant
            hourColor: Services.Color.mOnSurface
            minuteMutedColor: Services.Color.mOnSurfaceVariant
            minuteColor: Services.Color.mOnSurface
        }
    }
}
