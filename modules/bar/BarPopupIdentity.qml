import QtQuick
import "../lazerbar"

// Straight header identity layer with settings rail, optional icon, title and summary.
Rectangle {
    id: root

    property string title
    property string iconSource
    property string summary
    property real hostWidth: 260

    implicitWidth: hostWidth
    implicitHeight: 48
    width: hostWidth
    height: 48
    color: LazerTheme.settingsRail
    clip: true
    radius: 0

    // Left-aligned row: optional 16px icon plus title/summary column.
    Row {
        id: layoutRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 8

        // Optional 16px icon; hidden when iconSource is empty.
        Image {
            id: iconImage
            objectName: "identityIcon"
            width: 16
            height: 16
            anchors.verticalCenter: parent.verticalCenter
            source: root.iconSource
            visible: root.iconSource !== ""
            asynchronous: true
            fillMode: Image.PreserveAspectFit
            opacity: visible ? 1 : 0
        }

        Column {
            id: textColumn
            width: parent.width - (iconImage.visible ? iconImage.width + layoutRow.spacing : 0)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                id: titleText
                objectName: "identityTitle"
                width: parent.width
                text: root.title
                color: LazerTheme.textPrimary
                font.pixelSize: 13
                font.bold: true
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
                maximumLineCount: 1
            }

            Text {
                id: summaryText
                objectName: "identitySummary"
                width: parent.width
                text: root.summary
                color: LazerTheme.textMuted
                font.pixelSize: 10
                elide: Text.ElideRight
                visible: root.summary !== ""
                verticalAlignment: Text.AlignVCenter
                maximumLineCount: 1
                opacity: visible ? 0.92 : 0
            }
        }
    }
}
