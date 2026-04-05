import QtQuick
import qs.config
import qs.services
import ".."

// Wallpaper and dynamic-theme settings group used by `AppearancePage`.
StaggerItem {
    id: root

    property string searchQuery: ""
    property alias expanded: group.expanded
    property alias highlighted: group.highlighted

    width: parent ? parent.width : 0
    height: group.height
    delay: 60
    enterOffsetY: 22
    exitOffsetY: 10
    exitDelay: 0

    function matches(label) {
        if (!searchQuery) return false
        return label.toLowerCase().indexOf(searchQuery.toLowerCase()) !== -1
    }

    function groupMatches(labels) {
        if (!searchQuery) return false
        const query = searchQuery.toLowerCase()
        return labels.some(function(label) { return label.toLowerCase().indexOf(query) !== -1 })
    }

    function flash() {
        group.flash()
    }

    ExpandableGroup {
        id: group
        width: parent.width
        title: "壁纸 & 动态主题色"
        expanded: false
        forceExpand: root.groupMatches(["壁纸路径", "动态主题色", "配色算法", "深色模式"])
        visible: root.searchQuery === "" || root.groupMatches(["壁纸路径", "动态主题色", "配色算法", "深色模式"])
        height: visible ? implicitHeight : 0

        Item {
            id: wallpaperPathRow
            width: parent ? parent.width : 296
            implicitHeight: Theme.settingsRowHeight
            visible: root.searchQuery === "" || root.matches("壁纸路径")
            height: visible ? implicitHeight : 0

            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: 4
                anchors.rightMargin: 4
                radius: 4
                color: Colors.highlight
                opacity: root.matches("壁纸路径") && root.searchQuery !== "" ? 0.1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.anim.highlightDuration } }
            }

            Rectangle {
                anchors {
                    left: parent.left
                    top: parent.top
                    bottom: parent.bottom
                    leftMargin: 4
                }
                width: 3
                radius: 1
                color: Colors.highlight
                opacity: root.matches("壁纸路径") && root.searchQuery !== "" ? 0.9 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.anim.highlightDuration } }
            }

            Row {
                anchors.fill: parent
                anchors.leftMargin: Theme.settingsPanelPadding
                anchors.rightMargin: Theme.settingsPanelPadding
                spacing: 8

                Text {
                    width: Theme.settingsLabelWidth
                    anchors.verticalCenter: parent.verticalCenter
                    text: "壁纸路径"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Colors.textMuted
                    elide: Text.ElideRight
                }

                Rectangle {
                    id: wallpaperFieldRect
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - Theme.settingsLabelWidth - browseBtn.width - parent.spacing * 2
                    height: parent.height - 8
                    radius: 4
                    color: Colors.surface
                    border.color: wallpaperInput.activeFocus ? Colors.highlight : Colors.border
                    border.width: 1
                    Behavior on border.color { ColorAnimation { duration: Theme.anim.highlightDuration } }

                    TextInput {
                        id: wallpaperInput
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 6
                        anchors.topMargin: 2
                        anchors.bottomMargin: 2
                        text: SettingsService.data.appearance.wallpaperPath
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeSmall
                        color: Colors.text
                        selectByMouse: true
                        clip: true

                        HoverHandler { cursorShape: Qt.IBeamCursor }

                        onEditingFinished: {
                            const trimmed = text.trim()
                            if (trimmed !== "") {
                                WallpaperService.setWallpaper(trimmed)
                            } else {
                                text = SettingsService.data.appearance.wallpaperPath
                            }
                        }

                        onActiveFocusChanged: {
                            if (!activeFocus) text = SettingsService.data.appearance.wallpaperPath
                        }
                    }
                }

                Rectangle {
                    id: browseBtn
                    anchors.verticalCenter: parent.verticalCenter
                    width: browseBtnText.implicitWidth + 16
                    height: parent.height - 8
                    radius: 4
                    color: browseBtnArea.containsMouse ? Colors.highlight : Colors.surface
                    border.color: Colors.border
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: Theme.anim.highlightDuration } }

                    Text {
                        id: browseBtnText
                        anchors.centerIn: parent
                        text: "浏览"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Colors.text
                    }

                    MouseArea {
                        id: browseBtnArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: BarLayoutService.wallpaperPickerOpen = true
                    }
                }
            }
        }

        ToggleSection {
            label: "动态主题色"
            filterQuery: root.searchQuery
            value: SettingsService.data.appearance.matugenEnabled
            onToggled: function(v) {
                SettingsService.data.appearance.matugenEnabled = v
                SettingsService.save()
                if (v) WallpaperService.triggerMatugen()
            }
        }

        ToggleSection {
            label: "深色模式"
            filterQuery: root.searchQuery
            value: SettingsService.data.appearance.darkMode
            onToggled: function(v) {
                SettingsService.data.appearance.darkMode = v
                SettingsService.save()
                if (SettingsService.data.appearance.matugenEnabled)
                    WallpaperService.triggerMatugen()
                else
                    WallpaperService.syncAppearanceMode()
            }
        }

        Item {
            visible: SettingsService.data.appearance.matugenEnabled
            height: visible ? Theme.settingsRowHeight : 0
            width: parent ? parent.width : 296

            Behavior on height { NumberAnimation { duration: Theme.anim.highlightDuration } }

            Row {
                anchors.fill: parent
                anchors.leftMargin: Theme.settingsPanelPadding
                anchors.rightMargin: Theme.settingsPanelPadding
                spacing: 8

                Text {
                    width: Theme.settingsLabelWidth
                    anchors.verticalCenter: parent.verticalCenter
                    text: "配色算法"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Colors.textMuted
                    elide: Text.ElideRight
                }

                Flickable {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - Theme.settingsLabelWidth - parent.spacing
                    height: Theme.settingsRowHeight
                    contentWidth: schemeRow.implicitWidth
                    clip: true

                    Row {
                        id: schemeRow
                        spacing: 4

                        Repeater {
                            model: [
                                "scheme-tonal-spot",
                                "scheme-vibrant",
                                "scheme-expressive",
                                "scheme-fidelity",
                                "scheme-neutral",
                                "scheme-monochrome"
                            ]

                            delegate: Rectangle {
                                required property string modelData
                                required property int index

                                readonly property bool selected:
                                    SettingsService.data.appearance.matugenScheme === modelData

                                readonly property string shortLabel:
                                    modelData.replace("scheme-", "")

                                width: schemeLabel.implicitWidth + 12
                                height: 22
                                radius: Theme.cornerRadius - 4
                                color: selected ? Colors.highlight : Colors.surface
                                opacity: selected ? 0.9 : 0.55
                                Behavior on color { ColorAnimation { duration: Theme.anim.highlightDuration } }
                                Behavior on opacity { NumberAnimation { duration: Theme.anim.highlightDuration } }

                                Text {
                                    id: schemeLabel
                                    anchors.centerIn: parent
                                    text: parent.shortLabel
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Colors.text
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        SettingsService.data.appearance.matugenScheme = parent.modelData
                                        SettingsService.save()
                                        WallpaperService.triggerMatugen()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
