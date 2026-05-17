import QtQuick
import Quickshell.Widgets
import "../../../services" as Services

// Display the focused window icon and title.
Item {
    id: root

    implicitWidth: Math.min(activeRow.implicitWidth + 16, 220)
    implicitHeight: 26

    Row {
        id: activeRow
        anchors.centerIn: parent
        spacing: 6

        // Show the focused app icon when available.
        IconImage {
            anchors.verticalCenter: parent.verticalCenter
            source: "image://icon/" + (Services.NiriService.activeAppId || "application-x-executable")
            implicitSize: 16
            visible: Services.NiriService.activeAppId !== ""
        }

        // Keep the active window title readable in the bar.
        Text {
            id: titleText
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, 184)
            text: Services.NiriService.activeTitle || "Desktop"
            color: Services.Color.mOnSurface
            font.pixelSize: 12
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }
}
