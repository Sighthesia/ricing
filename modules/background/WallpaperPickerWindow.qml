import Quickshell
import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import qs.config
import qs.services
import qs.modules.bar

// Wallpaper folder-browser panel.
// Opens anchored top-right, below the bar.
// Lets user navigate directories and pick an image to set as wallpaper.
AnimatedPanelBase {
    id: root

    anchors { top: true; right: true }
    margins { top: Theme.barHeight }

    implicitWidth:  460
    implicitHeight: 500

    focusable: true

    active: BarLayoutService.wallpaperPickerOpen
    onActiveChanged: if (!active) BarLayoutService.wallpaperPickerOpen = false

    // Current directory being browsed
    property string currentDirectory:
        SettingsService.data.appearance.wallpaperDirectory !== ""
        ? SettingsService.data.appearance.wallpaperDirectory
        : (Quickshell.env("HOME") + "/Pictures/Wallpapers")

    // Folder model — shows subdirectories AND image files
    FolderListModel {
        id: folderModel
        folder: Qt.resolvedUrl("file://" + root.currentDirectory)
        showDirs: true
        showFiles: true
        showDirsFirst: true
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.avif", "*.bmp"]
        // nameFilters only applies to files; dirs are always shown when showDirs: true
    }

    // Outer panel card (same style as WidgetPickerWindow / SettingsPanelWindow)
    Rectangle {
        anchors.fill: parent
        anchors.margins: 4
        radius: Theme.cornerRadius
        color: Colors.background
        border.color: Colors.border
        border.width: 1
        clip: true

        // Subtle inner highlight
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius - 1
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.04)
            border.width: 1
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // ── Header row ──────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // Back button — only shown when not at the root wallpaper directory
                Rectangle {
                    width: 28; height: 28
                    radius: Theme.cornerRadius * 0.6
                    color: backArea.containsMouse
                           ? Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.18)
                           : "transparent"
                    visible: root.currentDirectory !== (Quickshell.env("HOME") + "/Pictures/Wallpapers")
                             && root.currentDirectory !== SettingsService.data.appearance.wallpaperDirectory

                    Text {
                        anchors.centerIn: parent
                        text: "←"
                        font.pixelSize: Theme.fontSizeBody
                        color: Colors.text
                    }
                    MouseArea {
                        id: backArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            // Navigate to parent directory
                            let parts = root.currentDirectory.split("/")
                            parts.pop()
                            root.currentDirectory = parts.join("/")
                        }
                    }
                }

                // Current path label
                Text {
                    Layout.fillWidth: true
                    text: root.currentDirectory.split("/").pop() || root.currentDirectory
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBody
                    font.weight: Font.Medium
                    color: Colors.text
                    elide: Text.ElideLeft
                }

                // Close button
                Rectangle {
                    width: 28; height: 28
                    radius: Theme.cornerRadius * 0.6
                    color: closeArea.containsMouse
                           ? Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.18)
                           : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Colors.textMuted
                    }
                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: BarLayoutService.wallpaperPickerOpen = false
                    }
                }
            }

            // ── Grid ─────────────────────────────────────────────────
            GridView {
                id: grid
                Layout.fillWidth: true
                Layout.fillHeight: true
                cellWidth: 115
                cellHeight: 115
                clip: true

                model: folderModel

                delegate: WallpaperPickerItem {
                    isDir:    model.fileIsDir
                    filePath: model.filePath
                    fileName: model.fileName

                    onPicked: function(path, dir) {
                        if (dir) {
                            root.currentDirectory = path
                        } else {
                            WallpaperService.setWallpaper(path)
                            BarLayoutService.wallpaperPickerOpen = false
                        }
                    }
                }

                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            }

            // ── Empty state ──────────────────────────────────────────
            Text {
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: "此目录为空"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeBody
                color: Colors.textMuted
                visible: folderModel.count === 0
            }
        }
    }
}
