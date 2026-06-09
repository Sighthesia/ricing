import QtQuick
import Quickshell
import Quickshell.Widgets
import "../bar/MenuVisuals.js" as MenuVisuals
import "../../services" as Services

// Expanded island content: search input + app list or clipboard list.
Item {
    id: root

    function focusSearch() {
        searchInput.forceActiveFocus()
        searchInput.selectAll()
    }

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
            color: Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, MenuVisuals.hoverOpacity)

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
                focus: true
                Keys.onEscapePressed: Services.IslandService.close()

                // Navigate list with Up/Down keys.
                Keys.onUpPressed: {
                    var loader = Services.IslandService.mode === "clipboard" ? clipLoader : appLoader
                    if (loader.item && loader.item.count > 0) {
                        loader.item.currentIndex = Math.max(0, loader.item.currentIndex - 1)
                    }
                }
                Keys.onDownPressed: {
                    var loader = Services.IslandService.mode === "clipboard" ? clipLoader : appLoader
                    if (loader.item && loader.item.count > 0) {
                        loader.item.currentIndex = Math.min(loader.item.count - 1, loader.item.currentIndex + 1)
                    }
                }
                Keys.onReturnPressed: {
                    var loader = Services.IslandService.mode === "clipboard" ? clipLoader : appLoader
                    if (loader.item && loader.item.currentItem) {
                        if (Services.IslandService.mode === "clipboard") {
                            Services.ClipboardService.copyItem(loader.item.currentItem.modelData.id)
                        } else {
                            Services.LaunchCountService.recordLaunch(loader.item.currentItem.modelData.id || "")
                            loader.item.currentItem.modelData.execute()
                        }
                        Services.IslandService.close()
                    }
                }
                Keys.onEnterPressed: Keys.onReturnPressed(null)

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

            // App list mode.
            Loader {
                id: appLoader
                anchors.fill: parent
                active: Services.IslandService.mode === "apps"
                sourceComponent: islandAppList

                onLoaded: {
                    if (item) {
                        item.currentIndex = 0
                    }
                }
            }

            // Clipboard mode.
            Loader {
                id: clipLoader
                anchors.fill: parent
                active: Services.IslandService.mode === "clipboard"
                sourceComponent: islandClipboard

                onLoaded: {
                    if (item) {
                        item.currentIndex = 0
                    }
                }
            }
        }
    }

    // --- App list component ---
    Component {
        id: islandAppList

        ListView {
            id: appListView
            anchors.fill: parent
            anchors.margins: 4
            clip: true
            spacing: 4

            property string query: {
                var q = Services.IslandService.query.toLowerCase()
                if (q.startsWith(">")) return ""
                return q
            }

            property var filteredApps: {
                const q = query
                const all = DesktopEntries.applications.values
                if (!all || all.length === 0) return []
                const filtered = all.filter(a => {
                    if (!q) return true
                    const name = (a.name || "").toLowerCase()
                    const comment = (a.comment || "").toLowerCase()
                    const genericName = (a.genericName || "").toLowerCase()
                    const id = (a.id || "").toLowerCase()
                    const keywords = (a.keywords || []).join(" ").toLowerCase()
                    return name.includes(q) || comment.includes(q)
                        || genericName.includes(q) || id.includes(q)
                        || keywords.includes(q)
                })
                return filtered.sort((a, b) => {
                    const ca = Services.LaunchCountService.getLaunchCount(a.id || "")
                    const cb = Services.LaunchCountService.getLaunchCount(b.id || "")
                    return cb - ca
                })
            }

            model: filteredApps

            delegate: Rectangle {
                id: appDelegate
                required property var modelData
                required property int index
                width: ListView.view ? ListView.view.width : 200
                height: 48
                radius: 6
                color: delegateMouse.containsMouse || ListView.view.currentIndex === index
                    ? Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, MenuVisuals.hoverOpacity)
                    : "transparent"

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 12

                    IconImage {
                        anchors.verticalCenter: parent.verticalCenter
                        source: "image://icon/" + (modelData.icon || "application-x-executable")
                        implicitSize: 32
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 32
                        spacing: 2

                        Text {
                            text: modelData.name || ""
                            color: Services.Color.mOnSurface
                            font.pixelSize: 13
                            elide: Text.ElideRight
                            width: parent.width
                        }

                        Text {
                            text: modelData.comment || modelData.genericName || ""
                            color: Services.Color.mOnSurfaceVariant
                            font.pixelSize: 11
                            opacity: 0.7
                            elide: Text.ElideRight
                            width: parent.width
                            visible: text.length > 0
                        }
                    }
                }

                MouseArea {
                    id: delegateMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var app = appDelegate.modelData
                        var idx = appDelegate.index
                        if (ListView.view) ListView.view.currentIndex = idx
                        Services.LaunchCountService.recordLaunch(app.id || "")
                        app.execute()
                        Services.IslandService.close()
                    }
                }
            }
        }
    }

    // --- Clipboard list component ---
    Component {
        id: islandClipboard

        ListView {
            id: clipListView
            anchors.fill: parent
            anchors.margins: 4
            clip: true
            spacing: 4

            property string query: {
                var q = Services.IslandService.query.toLowerCase()
                if (q.startsWith(">clip")) return q.slice(5).trim()
                return q.startsWith(">") ? "" : q
            }

            property var filteredItems: {
                const q = query
                const all = Services.ClipboardService.items
                if (!all || all.length === 0) return []
                if (!q) return all
                return all.filter(item => {
                    const preview = (item.preview || "").toLowerCase()
                    return preview.includes(q)
                })
            }

            model: filteredItems

            Component.onCompleted: Services.ClipboardService.list()

            delegate: Rectangle {
                required property var modelData
                required property int index
                width: ListView.view ? ListView.view.width : 200
                height: 48
                radius: 6
                color: clipMouse.containsMouse || clipListView.currentIndex === index
                    ? Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, MenuVisuals.hoverOpacity)
                    : "transparent"

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: Text.AlignVCenter
                    text: modelData.isImage ? "[Image]" : (modelData.preview || "")
                    color: Services.Color.mOnSurface
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: clipMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        clipListView.currentIndex = index
                        Services.ClipboardService.copyItem(modelData.id)
                        Services.IslandService.close()
                    }
                }
            }
        }
    }
}
