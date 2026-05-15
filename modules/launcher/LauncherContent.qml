import QtQuick
import "../../services" as Services

// Main content area: search input + dynamic results (apps or clipboard)
Item {
    id: root

    Keys.onEscapePressed: Services.LauncherService.close()

    Column {
        anchors.fill: parent
        spacing: 8

        // Search input bar
        Rectangle {
            radius: 8
            color: "#33ffffff"
            height: 44
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 12
            anchors.rightMargin: 12

            TextInput {
                id: searchInput
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                color: "white"
                font.pixelSize: 16
                text: Services.LauncherService.query
                onTextChanged: Services.LauncherService.query = text

                // Placeholder text
                Text {
                    text: "Search apps..."
                    color: "white"
                    opacity: 0.5
                    font.pixelSize: parent.font.pixelSize
                    anchors.verticalCenter: parent.verticalCenter
                    visible: parent.text.length === 0
                }

                Component.onCompleted: searchInput.forceActiveFocus()
            }

            // Re-focus when launcher becomes visible
            Connections {
                target: Services.LauncherService
                function onVisibleChanged() {
                    if (Services.LauncherService.visible)
                        searchInput.forceActiveFocus()
                }
            }
        }

        // Results area: apps grid, clipboard list, or shortcut list
        Loader {
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.height - 44 - 8 - 24
            source: {
                if (Services.LauncherService.mode === "clipboard" && Services.ClipboardService.available)
                    return "ClipboardList.qml"
                if (Services.LauncherService.mode === "shortcuts" && Services.NiriShortcutService.isLoaded)
                    return "ShortcutList.qml"
                return "AppGrid.qml"
            }
        }
    }
}
