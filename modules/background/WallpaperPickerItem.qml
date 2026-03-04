import QtQuick
import qs.config

// Single grid card in WallpaperPickerWindow.
// Shows a thumbnail for image files, or a folder icon for directories.
// Parent GridView passes `isDir`, `filePath`, `fileName` via model roles.
Item {
    id: root

    // Required properties injected by GridView delegate
    required property bool   isDir
    required property string filePath   // absolute path
    required property string fileName   // base name

    // Emitted when user picks this card (parent handles routing)
    signal picked(string path, bool dir)

    implicitWidth:  110
    implicitHeight: 110

    Rectangle {
        id: card
        anchors.fill: parent
        anchors.margins: 4
        radius: Theme.cornerRadius
        color: cardArea.containsMouse
               ? Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.22)
               : Qt.rgba(Colors.surface.r,   Colors.surface.g,   Colors.surface.b,   0.80)
        clip: true

        // Image thumbnail — only visible for file entries
        Image {
            id: thumb
            anchors.fill: parent
            source: root.isDir ? "" : ("file://" + root.filePath)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: !root.isDir && status !== Image.Error
        }

        // Folder icon emoji — shown when entry is a directory
        Text {
            anchors.centerIn: parent
            text: "📁"
            font.pixelSize: 32
            visible: root.isDir
            color: Colors.textMuted
        }

        // File-name label at bottom
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: label.implicitHeight + 8
            color: Qt.rgba(0, 0, 0, 0.50)
            visible: !root.isDir || root.fileName !== ""

            Text {
                id: label
                anchors {
                    left: parent.left; right: parent.right
                    verticalCenter: parent.verticalCenter
                    margins: 6
                }
                text: root.fileName
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: "white"
                elide: Text.ElideRight
            }
        }

        // Hover/click area
        MouseArea {
            id: cardArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.picked(root.filePath, root.isDir)
        }

        // Selection press-scale animation
        scale: cardArea.pressed ? 0.93 : 1.0
        Behavior on scale {
            NumberAnimation { duration: 80; easing.type: Easing.OutQuad }
        }
    }
}
