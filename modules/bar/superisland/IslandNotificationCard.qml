import QtQuick
import QtQuick.Layouts
import qs.config

Item {
    id: root

    required property var event
    required property string iconSource
    readonly property int _iconSize: Theme.barWidget.primaryIconSize

    implicitWidth: content.implicitWidth
    implicitHeight: Theme.barWidget.pillHeight

    RowLayout {
        id: content
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.barWidget.iconLabelSpacing

        Image {
            source: root.iconSource
            sourceSize.width: root._iconSize
            sourceSize.height: root._iconSize
            width: root._iconSize
            height: root._iconSize
            fillMode: Image.PreserveAspectFit
            Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
            spacing: 0
            Layout.alignment: Qt.AlignVCenter

            Text {
                text: root.event.title || "Notification"
                color: Colors.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeBody
                font.bold: true
                elide: Text.ElideRight
                Layout.maximumWidth: Math.round(220 * Theme.uiScale)
            }

            Text {
                visible: text !== ""
                text: root.event.subtitle || ""
                color: Colors.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
                Layout.maximumWidth: Math.round(240 * Theme.uiScale)
            }
        }

        Rectangle {
            radius: Theme.cornerRadius
            color: root.event.priority === "critical" ? Colors.highlight : Qt.rgba(1, 1, 1, 0.06)
            implicitHeight: badgeText.implicitHeight + Theme.barWidget.badgePaddingV * 2
            implicitWidth: badgeText.implicitWidth + Theme.barWidget.badgePaddingH * 2
            Layout.alignment: Qt.AlignVCenter

            Text {
                id: badgeText
                anchors.centerIn: parent
                text: root.event.priority === "critical" ? "Alert" : "Notify"
                color: root.event.priority === "critical" ? Colors.background : Colors.textMuted
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
            }
        }
    }
}