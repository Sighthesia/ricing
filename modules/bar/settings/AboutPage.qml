import Quickshell
import QtQuick
import QtQuick.Dialogs
import qs.config
import qs.services
import ".."

// About page: version info and settings reset button.
Item {
    id: root

    StaggerOrchestrator {
        id: _stagger
    }

    function runEnterAnimation(): void {
        _stagger.clear()
        _stagger.registerItem(s_header, 0, 1)
        _stagger.registerItem(s_divider1, 1, 1)
        _stagger.registerItem(s_resetButton, 2, 1)
        _stagger.registerItem(s_resetHint, 3, 1)
        _stagger.registerItem(s_divider2, 4, 1)
        _stagger.registerItem(s_ioRow, 5, 1)
        _stagger.registerItem(s_ioHint, 6, 1)
        _stagger.runEnter()
    }

    function runExitAnimation(): void {
        _stagger.clear()
        _stagger.registerItem(s_header, 0, 1)
        _stagger.registerItem(s_divider1, 1, 1)
        _stagger.registerItem(s_resetButton, 2, 1)
        _stagger.registerItem(s_resetHint, 3, 1)
        _stagger.registerItem(s_divider2, 4, 1)
        _stagger.registerItem(s_ioRow, 5, 1)
        _stagger.registerItem(s_ioHint, 6, 1)
        _stagger.runExit()
    }

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
        StaggerItem {
            id: s_header
            width: parent.width
            height: _headerCol.implicitHeight

            Column {
                id: _headerCol
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
        }

        // Divider
        StaggerItem {
            id: s_divider1
            width: parent.width
            height: 1

            Rectangle {
                anchors.fill: parent
                color: Colors.border
            }
        }

        // Reset to defaults button
        StaggerItem {
            id: s_resetButton
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
        StaggerItem {
            id: s_resetHint
            width: parent.width
            height: _resetHintText.implicitHeight

            Text {
                id: _resetHintText
                text: "重置后设置将在下一帧立即生效（热重载）"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall - 1
                color: Colors.textMuted
                wrapMode: Text.WordWrap
                width: parent.width
            }
        }

        // Divider
        StaggerItem {
            id: s_divider2
            width: parent.width
            height: 1

            Rectangle {
                anchors.fill: parent
                color: Colors.border
            }
        }

        // Export / Import row
        StaggerItem {
            id: s_ioRow
            width: parent.width
            height: _ioRow.height

            Row {
                id: _ioRow
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
        }

        StaggerItem {
            id: s_ioHint
            width: parent.width
            height: _ioHintText.implicitHeight

            Text {
                id: _ioHintText
                text: "导出：将当前设置复制到剪贴板  导入：选择一个 JSON 文件覆盖当前配置"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall - 1
                color: Colors.textMuted
                wrapMode: Text.WordWrap
                width: parent.width
            }
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

    // When switching to About while panel is already open, loader creates this
    // page without a new panelOpening signal. Trigger one enter cycle so items
    // do not remain at StaggerItem's default invisible state.
    Component.onCompleted: Qt.callLater(runEnterAnimation)
}
