import QtQuick
import "../lazerbar"

// Titled popup adapter that places chrome and content in separate owner layers.
LazerSplitSurface {
    id: root

    property string title: ""
    property string iconSource: ""
    property string extraText: ""
    readonly property alias contentItem: contentSurfaceItem
    readonly property alias headerCard: headerSurfaceItem

    implicitWidth: Math.max(headerRow.implicitWidth + 32, contentSurfaceItem.implicitWidth + 24)
    implicitHeight: headerSurfaceItem.height + dividerItem.height + contentSurfaceItem.implicitHeight

    // Header title and icon belong to the rail surface and reveal together.
    Row {
        id: headerRow
        parent: root.headerSurfaceItem
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.right: extraLabel.visible ? extraLabel.left : parent.right
        anchors.rightMargin: extraLabel.visible ? 8 : 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Image {
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            source: root.iconSource
            sourceSize: Qt.size(16, 16)
            fillMode: Image.PreserveAspectFit
            smooth: true
            asynchronous: true
            visible: root.iconSource !== ""
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - (parent.children[0].visible ? 24 : 0)
            text: root.title
            color: LazerTheme.textPrimary
            font.pixelSize: 14
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }

    // Header metadata stays inside the same rail owner layer.
    Text {
        id: extraLabel
        parent: root.headerSurfaceItem
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        text: root.extraText
        color: LazerTheme.textMuted
        font.pixelSize: 13
        visible: root.extraText !== ""
    }
}
