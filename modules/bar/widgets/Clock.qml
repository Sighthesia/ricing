import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.config

// Compact bar clock widget that shows the current date and time in two groups.
Rectangle {
    id: clock

    color: Colors.background
    radius: Theme.cornerRadius
    implicitHeight: Theme.barHeight
    implicitWidth: content.width + Theme.widgetPadding * 2

    // Time source
    SystemClock {
        id: systemClock
        precision: SystemClock.Minutes
    }

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: Theme.widgetPadding

        // Date section: MMM d
        RowLayout {
            spacing: 4
            Layout.alignment: Qt.AlignVCenter

            Text {
                Layout.alignment: Qt.AlignBaseline
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
                text: Qt.formatDateTime(systemClock.date, "MMM")
                color: Colors.textMuted
            }

            Text {
                Layout.alignment: Qt.AlignBaseline
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
                text: Qt.formatDateTime(systemClock.date, "d")
                color: Colors.text
            }
        }

        // Vertical separator
        Rectangle {
            implicitWidth: 1
            implicitHeight: Theme.fontSizeIcon
            color: Colors.text
            opacity: 0.3
            Layout.alignment: Qt.AlignVCenter
        }

        // Time section: HH:mm
        RowLayout {
            spacing: 0
            Layout.alignment: Qt.AlignVCenter

            Text {
                Layout.alignment: Qt.AlignBaseline
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeBody
                font.bold: true
                text: Qt.formatDateTime(systemClock.date, "hh")
                color: Colors.textMuted
            }

            Text {
                Layout.alignment: Qt.AlignBaseline
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeBody
                font.bold: true
                text: ":"
                color: Colors.text
            }

            Text {
                Layout.alignment: Qt.AlignBaseline
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeBody
                font.bold: true
                text: Qt.formatDateTime(systemClock.date, "mm")
                color: Colors.text
            }
        }
    }
}
