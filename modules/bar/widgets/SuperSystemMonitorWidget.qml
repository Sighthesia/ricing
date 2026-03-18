import QtQuick
import QtQuick.Layouts
import qs.config

// Compact placeholder bar widget for future system monitoring metrics.
Rectangle {
    id: root

    color: Colors.background
    radius: Theme.cornerRadius
    implicitHeight: Theme.barHeight
    implicitWidth: content.implicitWidth + Theme.widgetPadding * 2

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: Theme.barWidget.pillSpacing

        Text {
            font.family: Theme.fontMono
            font.pixelSize: Theme.barWidget.compactIconSize
            font.bold: true
            text: "[]"
            color: Colors.textMuted
        }

        Text {
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            font.bold: true
            text: "SYS"
            color: Colors.text
        }

        Rectangle {
            implicitWidth: 1
            implicitHeight: Theme.barWidget.primaryIconSize
            color: Colors.border
            opacity: 0.5
            Layout.alignment: Qt.AlignVCenter
        }

        RowLayout {
            spacing: Theme.barWidget.iconSpacing

            Text {
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
                text: "CPU"
                color: Colors.textMuted
            }

            Text {
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
                text: "42%"
                color: Colors.text
            }
        }

        RowLayout {
            spacing: Theme.barWidget.iconSpacing

            Text {
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
                text: "MEM"
                color: Colors.textMuted
            }

            Text {
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
                text: "68%"
                color: Colors.text
            }
        }
    }
}
