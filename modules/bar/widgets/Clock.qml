import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config

Rectangle {
    id: clock

    color: Palette.background
    radius: Theme.cornerRadius
    implicitHeight: Theme.barHeight
    implicitWidth: content.width + 24

    // Time source
    SystemClock {
        id: systemClock
        precision: SystemClock.Minutes
    }

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: 12

        // Date section: MMM d
        RowLayout {
            spacing: 4
            Layout.alignment: Qt.AlignVCenter

            Text {
                Layout.alignment: Qt.AlignBaseline
                font.family: Theme.fontFamily
                font.pointSize: 11
                font.bold: true
                text: Qt.formatDateTime(systemClock.date, "MMM")
                color: Palette.textMuted
            }

            Text {
                Layout.alignment: Qt.AlignBaseline
                font.family: Theme.fontFamily
                font.pointSize: 11
                font.bold: true
                text: Qt.formatDateTime(systemClock.date, "d")
                color: Palette.text
            }
        }

        // Vertical separator
        Rectangle {
            implicitWidth: 1
            implicitHeight: 16
            color: Palette.text
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
                font.pointSize: 13
                font.bold: true
                text: Qt.formatDateTime(systemClock.date, "hh")
                color: Palette.textMuted
            }

            Text {
                Layout.alignment: Qt.AlignBaseline
                font.family: Theme.fontMono
                font.pointSize: 13
                font.bold: true
                text: ":"
                color: Palette.text
            }

            Text {
                Layout.alignment: Qt.AlignBaseline
                font.family: Theme.fontMono
                font.pointSize: 13
                font.bold: true
                text: Qt.formatDateTime(systemClock.date, "mm")
                color: Palette.text
            }
        }
    }
}
