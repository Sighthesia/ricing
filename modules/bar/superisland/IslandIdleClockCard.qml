import QtQuick
import QtQuick.Layouts
import qs.config

// Renders the steady idle clock pill content for SuperIsland.
Item {
    id: root

    required property date currentTime
    required property bool hasPendingEvents
    property int cardHeight: Theme.barWidget.pillHeight

    implicitWidth: idleRow.implicitWidth
    implicitHeight: root.cardHeight

    // Centered idle clock row.
    RowLayout {
        id: idleRow

        anchors.centerIn: parent
        spacing: Theme.barWidget.iconLabelSpacing

        // Month-day label.
        Text {
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeSmall
            text: Qt.formatDate(root.currentTime, "M月d日")
            color: Colors.textMuted
        }

        // Divider between date and time.
        Rectangle {
            implicitWidth: 1
            implicitHeight: Theme.fontSizeBody
            radius: width / 2
            color: Colors.border
            opacity: 0.65
            Layout.alignment: Qt.AlignVCenter
        }

        // Clock label.
        Text {
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeBody
            font.bold: true
            text: Qt.formatDateTime(root.currentTime, "hh:mm")
            color: Colors.text
        }

        // Pending-event indicator.
        Rectangle {
            visible: root.hasPendingEvents
            implicitWidth: Theme.barWidget.indicatorDotSize
            implicitHeight: Theme.barWidget.indicatorDotSize
            radius: width / 2
            color: Colors.highlight
            opacity: Colors.highlightAlpha + 0.2
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
