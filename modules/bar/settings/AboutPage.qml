import QtQuick
import QtQuick.Dialogs
import Quickshell
import qs.config
import qs.services

// About page: version info and settings reset button.
Item {
    id: root

    implicitWidth: parent ? parent.width : 340
    implicitHeight: aboutCol.implicitHeight + 24

    Column {
        id: aboutCol
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: 16
            topMargin: 12
        }
        spacing: 12

        // Shell name + version
        Column {
            width: parent.width
            spacing: 4

            Text {
                text: "DymicShell"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeBody
                font.weight: Font.DemiBold
                color: Colors.text
            }

            Text {
                text: "Version 0.1.0"
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                color: Colors.textMuted
            }

            Text {
                text: "Config: " + SettingsService.settingsFile
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall - 1
                color: Colors.textMuted
                elide: Text.ElideMiddle
                width: parent.width
            }
        }

        // Divider
        Rectangle {
            width: parent.width
            height: 1
            color: Colors.border
        }

        // Reset to defaults button
        Item {
            width: parent.width
            height: 34

            Rectangle {
                id: resetBtn
                anchors.fill: parent
                anchors.rightMargin: parent.width - 160
                radius: Theme.cornerRadius - 2
                color: resetArea.containsMouse
                    ? Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.2)
                    : Colors.surface
                border.color: Colors.border
                border.width: 1

                Behavior on color { ColorAnimation { duration: Theme.anim.highlightDuration } }

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\uf0e2"  // Nerd Font undo/reset icon
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeSmall
                        color: Colors.textMuted
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "重置为默认值"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Colors.text
                    }
                }

                MouseArea {
                    id: resetArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        // Overwrite user settings with built-in defaults
                        let defaultFile = Quickshell.shellDir + "/config/settings-default.json"
                        Quickshell.execDetached(["cp", defaultFile, SettingsService.settingsFile])
                        // FileView.watchChanges will pick up the change automatically
                    }
                }
            }
        }

        // Reset confirmation hint
        Text {
            text: "重置后设置将在下一帧立即生效（热重载）"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall - 1
            color: Colors.textMuted
            wrapMode: Text.WordWrap
            width: parent.width
        }

        // Divider
        Rectangle { width: parent.width; height: 1; color: Colors.border }

        // Export / Import row
        Row {
            width: parent.width
            spacing: 8

            // ── 导出配置 ─────────────────────────
            Rectangle {
                width: (parent.width - 8) / 2
                height: 34
                radius: Theme.cornerRadius - 2
                color: exportArea.containsMouse
                    ? Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.2)
                    : Colors.surface
                border.color: Colors.border; border.width: 1
                Behavior on color { ColorAnimation { duration: Theme.anim.highlightDuration } }

                Row {
                    anchors.centerIn: parent; spacing: 6
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: ""  // upload icon
                        font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeSmall
                        color: Colors.textMuted
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "导出配置"
                        font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall
                        color: Colors.text
                    }
                }
                MouseArea {
                    id: exportArea; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    // Copy settings JSON to clipboard via wl-copy.
                    onClicked: Quickshell.execDetached(["sh", "-c",
                        "wl-copy < '" + SettingsService.settingsFile + "'"])
                }
            }

            // ── 导入配置 ─────────────────────────
            Rectangle {
                width: (parent.width - 8) / 2
                height: 34
                radius: Theme.cornerRadius - 2
                color: importArea.containsMouse
                    ? Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.2)
                    : Colors.surface
                border.color: Colors.border; border.width: 1
                Behavior on color { ColorAnimation { duration: Theme.anim.highlightDuration } }

                Row {
                    anchors.centerIn: parent; spacing: 6
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: ""  // download icon
                        font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeSmall
                        color: Colors.textMuted
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "导入配置"
                        font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSmall
                        color: Colors.text
                    }
                }
                MouseArea {
                    id: importArea; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: importDialog.open()
                }
            }
        }

        Text {
            text: "导出：将当前设置复制到剪贴板  导入：选择一个 JSON 文件覆盖当前配置"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall - 1
            color: Colors.textMuted
            wrapMode: Text.WordWrap
            width: parent.width
        }
    }

    // File picker for import — copies selected JSON over the current settings file.
    // FileView.watchChanges auto-reloads the settings without restart.
    FileDialog {
        id: importDialog
        title: "选择要导入的配置文件"
        nameFilters: ["JSON 文件 (*.json)", "所有文件 (*)"]
        onAccepted: {
            var src = importDialog.selectedFile.toString().replace(/^file:\/\//, "")
            Quickshell.execDetached(["cp", src, SettingsService.settingsFile])
        }
    }
}
