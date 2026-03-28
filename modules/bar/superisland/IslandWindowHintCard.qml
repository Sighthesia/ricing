import QtQuick
import QtQuick.Layouts
import qs.config

Item {
    id: root

    required property var event

    readonly property string _iconSource: root.event?.icon || ""

    implicitWidth: content.implicitWidth
    implicitHeight: Math.max(Theme.barWidget.pillHeight, content.implicitHeight)

    RowLayout {
        id: content

        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.barWidget.iconLabelSpacing

        Rectangle {
            radius: width / 2
            color: Qt.rgba(1, 1, 1, 0.06)
            border.color: Colors.border
            border.width: 1
            implicitWidth: Theme.barWidget.primaryIconSize + Theme.barWidget.contentPaddingV * 2
            implicitHeight: implicitWidth
            Layout.alignment: Qt.AlignVCenter
            visible: root._iconSource !== ""

            Image {
                anchors.centerIn: parent
                source: root._iconSource
                sourceSize.width: Theme.barWidget.primaryIconSize
                sourceSize.height: Theme.barWidget.primaryIconSize
                width: Theme.barWidget.primaryIconSize
                height: Theme.barWidget.primaryIconSize
                fillMode: Image.PreserveAspectFit
                smooth: true
            }
        }

        ColumnLayout {
            spacing: 0
            Layout.alignment: Qt.AlignVCenter

            Text {
                text: root.event?.title || "Window hint"
                color: Colors.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeBody
                font.bold: true
                elide: Text.ElideRight
                maximumLineCount: 1
                Layout.maximumWidth: Math.round(220 * Theme.uiScale)
            }

            Text {
                visible: text !== ""
                text: root.event?.subtitle || ""
                color: Colors.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
                maximumLineCount: 1
                Layout.maximumWidth: Math.round(220 * Theme.uiScale)
            }
        }

        Rectangle {
            radius: Theme.cornerRadius
            color: Colors.highlight
            opacity: Colors.highlightAlpha + 0.08
            implicitHeight: labelText.implicitHeight + Theme.barWidget.badgePaddingV * 2
            implicitWidth: labelText.implicitWidth + Theme.barWidget.badgePaddingH * 2
            Layout.alignment: Qt.AlignVCenter
            visible: labelText.text !== ""

            Text {
                id: labelText

                anchors.centerIn: parent
                text: root.event?.workspaceLabel || ""
                color: Colors.text
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
            }
        }
    }
}
