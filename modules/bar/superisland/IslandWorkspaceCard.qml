import QtQuick
import QtQuick.Layouts
import qs.config

Item {
    id: root

    required property var event
    required property string iconSource

    implicitWidth: content.implicitWidth
    implicitHeight: root.event.type === "window"
        ? (Theme.fontSizeBody + Theme.barWidget.contentPaddingV * 2)
        : Theme.barWidget.pillHeight

    RowLayout {
        id: content
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.barWidget.iconLabelSpacing

        Item {
            implicitWidth: root.event.type === "window" ? Theme.fontSizeBody : Theme.barWidget.primaryIconSize
            implicitHeight: implicitWidth
            Layout.alignment: Qt.AlignVCenter

            Image {
                anchors.centerIn: parent
                source: root.iconSource
                sourceSize.width: root.event.type === "window" ? Theme.fontSizeBody : Theme.barWidget.primaryIconSize
                sourceSize.height: root.event.type === "window" ? Theme.fontSizeBody : Theme.barWidget.primaryIconSize
                width: root.event.type === "window" ? Theme.fontSizeBody : Theme.barWidget.primaryIconSize
                height: root.event.type === "window" ? Theme.fontSizeBody : Theme.barWidget.primaryIconSize
                fillMode: Image.PreserveAspectFit
                smooth: true
            }
        }

        Item {
            implicitWidth: titleColumn.implicitWidth
            implicitHeight: titleColumn.implicitHeight
            Layout.alignment: Qt.AlignVCenter

            ColumnLayout {
                id: titleColumn
                spacing: root.event.type === "window" ? 0 : 0

                Text {
                    text: root.event.title || "Workspace"
                    color: Colors.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBody
                    font.bold: root.event.type !== "window"
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    Layout.maximumWidth: Math.round((root.event.type === "window" ? 150 : 180) * Theme.uiScale)
                }

                Text {
                    visible: root.event.type !== "window" && text !== ""
                    text: root.event.subtitle || ""
                    color: Colors.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                    Layout.maximumWidth: Math.round(180 * Theme.uiScale)
                }
            }
        }

        Rectangle {
            radius: Theme.cornerRadius
            color: Qt.rgba(1, 1, 1, 0.06)
            implicitHeight: labelText.implicitHeight + Theme.barWidget.badgePaddingV * 2
            implicitWidth: labelText.implicitWidth + Theme.barWidget.badgePaddingH * 2
            Layout.alignment: Qt.AlignVCenter

            Text {
                id: labelText
                anchors.centerIn: parent
                text: root.event.workspaceLabel || (root.event.type === "window" ? "Win" : "Space")
                color: Colors.textMuted
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
            }
        }
    }
}