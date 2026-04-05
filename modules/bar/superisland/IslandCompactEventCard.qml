import QtQuick
import QtQuick.Layouts
import qs.config

// Renders compact icon plus text event content for SuperIsland lanes.
Item {
    id: root

    required property var event
    required property string iconSource
    property int cardHeight: Theme.barWidget.pillHeight
    property int titleMaxWidth: Math.round(220 * Theme.uiScale)
    property int subtitleMaxWidth: Math.round(180 * Theme.uiScale)

    implicitWidth: eventRow.implicitWidth
    implicitHeight: root.cardHeight

    RowLayout {
        id: eventRow

        anchors.centerIn: parent
        spacing: Theme.barWidget.iconLabelSpacing

        Image {
            source: root.iconSource
            sourceSize.width: Theme.barWidget.primaryIconSize
            sourceSize.height: Theme.barWidget.primaryIconSize
            width: Theme.barWidget.primaryIconSize
            height: Theme.barWidget.primaryIconSize
            fillMode: Image.PreserveAspectFit
            Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
            spacing: 0
            Layout.alignment: Qt.AlignVCenter

            Text {
                text: root.event.title || ""
                color: Colors.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeBody
                font.bold: true
                elide: Text.ElideRight
                maximumLineCount: 1
                wrapMode: Text.NoWrap
                Layout.maximumWidth: root.titleMaxWidth
            }

            Text {
                visible: text !== ""
                text: root.event.subtitle || ""
                color: Colors.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
                maximumLineCount: 1
                wrapMode: Text.NoWrap
                Layout.maximumWidth: root.subtitleMaxWidth
            }
        }
    }
}
