import QtQuick
import Quickshell
import Quickshell.Widgets
import "../../services" as Services

// Expanded island content: search input + app grid or clipboard list.
Item {
    id: root

    Keys.onEscapePressed: Services.IslandService.close()

    Column {
        anchors.fill: parent
        spacing: 8

        // Search input bar.
        Rectangle {
            id: searchBar
            anchors.left: parent.left
            anchors.right: parent.right
            height: 40
            radius: 12
            color: Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, 0.08)

            TextInput {
                id: searchInput
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                verticalAlignment: TextInput.AlignVCenter
                color: Services.Color.mOnSurface
                font.pixelSize: 14
                text: Services.IslandService.query
                onTextChanged: Services.IslandService.query = text

                // Placeholder text.
                Text {
                    text: "Search apps or >clip for clipboard..."
                    color: Services.Color.mOnSurfaceVariant
                    opacity: 0.6
                    font.pixelSize: parent.font.pixelSize
                    anchors.verticalCenter: parent.verticalCenter
                    visible: parent.text.length === 0
                }
            }
        }

        // Results area.
        Item {
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.height - searchBar.height - 8

            // App grid mode.
            Loader {
                anchors.fill: parent
                active: Services.IslandService.mode === "apps"
                sourceComponent: islandAppGrid
            }

            // Clipboard mode.
            Loader {
                anchors.fill: parent
                active: Services.IslandService.mode === "clipboard"
                sourceComponent: islandClipboard
            }
        }
    }

    // Focus the search input when island expands.
    Connections {
        target: Services.IslandService
        function onExpandedChanged() {
            if (Services.IslandService.expanded) {
                searchInput.forceActiveFocus()
            }
        }
    }

    Component.onCompleted: {
        if (Services.IslandService.expanded)
            searchInput.forceActiveFocus()
    }

    // --- App grid component ---
    Component {
        id: islandAppGrid

        Item {
            property string query: {
                var q = Services.IslandService.query.toLowerCase()
                // Strip mode prefix if any
                if (q.startsWith(">")) return ""
                return q
            }

            property var filteredApps: {
                const q = query
                const all = DesktopEntries.applications.values
                if (!all || all.length === 0) return []
                return all.filter(a => {
                    if (!q) return true
                    const name = (a.name || "").toLowerCase()
                    const comment = (a.comment || "").toLowerCase()
                    return name.includes(q) || comment.includes(q)
                })
            }

            GridView {
                anchors.fill: parent
                anchors.margins: 4
                cellWidth: 100
                cellHeight: 100
                clip: true
                model: parent.filteredApps

                delegate: Item {
                    required property var modelData
                    width: GridView.view ? GridView.view.cellWidth : 100
                    height: GridView.view ? GridView.view.cellHeight : 100

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 4
                        radius: 8
                        color: delegateMouse.containsMouse
                            ? Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, 0.08)
                            : "transparent"
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 6

                        IconImage {
                            anchors.horizontalCenter: parent.horizontalCenter
                            source: "image://icon/" + (modelData.icon || "application-x-executable")
                            implicitSize: 40
                        }

                        Text {
                            text: modelData.name || ""
                            color: Services.Color.mOnSurface
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            width: 88
                        }
                    }

                    MouseArea {
                        id: delegateMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            modelData.execute()
                            Services.IslandService.close()
                        }
                    }
                }
            }
        }
    }

    // --- Clipboard list component ---
    Component {
        id: islandClipboard

        Item {
            Component.onCompleted: Services.ClipboardService.list()

            ListView {
                anchors.fill: parent
                anchors.margins: 4
                clip: true
                spacing: 4
                model: Services.ClipboardService.items

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: ListView.view ? ListView.view.width : 200
                    height: 36
                    radius: 8
                    color: clipMouse.containsMouse
                        ? Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, 0.08)
                        : "transparent"

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        verticalAlignment: Text.AlignVCenter
                        text: modelData.isImage ? "[Image]" : (modelData.preview || "")
                        color: Services.Color.mOnSurface
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: clipMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Services.ClipboardService.copyItem(modelData.id)
                            Services.IslandService.close()
                        }
                    }
                }
            }
        }
    }
}
