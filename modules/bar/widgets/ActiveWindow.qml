import QtQuick
import "../../../services" as Services

// Display focused window title from Niri IPC.
Item {
    id: root

    implicitWidth: Math.min(titleText.implicitWidth + 16, 200)
    implicitHeight: 26

    Text {
        id: titleText
        anchors.centerIn: parent
        width: Math.min(implicitWidth, 184)
        text: Services.NiriService.activeTitle || "Desktop"
        color: Services.Color.mOnSurface
        font.pixelSize: 12
        elide: Text.ElideRight
        maximumLineCount: 1
    }
}
