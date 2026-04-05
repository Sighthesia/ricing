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

    RowLayout {
        id: idleRow

        anchors.centerIn: parent
        spacing: Theme.barWidget.iconLabelSpacing

        Text {
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeBody
            font.bold: true
            text: Qt.formatDateTime(root.currentTime, "hh:mm")
            color: Colors.text
        }

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
