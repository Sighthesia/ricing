import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../settings" as SettingsModule

// Expanded settings page that keeps the full settings content inside SuperIsland.
Item {
    id: root

    readonly property var _defaultPages: [
        { value: "launcher", label: "启动器" },
        { value: "settings", label: "设置" },
        { value: "notifications", label: "通知" }
    ]

    function pageActivated() {
        _enterDelay.restart()
    }

    function pageDeactivated() {
        _enterDelay.stop()
        if (_settingsContent && _settingsContent.runExitAnimation)
            _settingsContent.runExitAnimation()
    }

    function _setDefaultPage(pageName) {
        SettingsService.data.superIsland.expandedDefaultPage = pageName
        SettingsService.save()
    }

    Timer {
        id: _enterDelay
        interval: 180
        repeat: false
        onTriggered: {
            if (_settingsContent && _settingsContent.runEnterAnimation)
                _settingsContent.runEnterAnimation()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 14

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 126
            radius: Theme.cornerRadius
            color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.8)
            border.color: Colors.border
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                Text {
                    text: "SuperIsland 扩展入口"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBody
                    font.weight: Font.Medium
                    color: Colors.text
                }

                Text {
                    Layout.fillWidth: true
                    text: "点击 SuperIsland 时，默认先打开哪个分页。你要的“可供设置”入口放在这里。"
                    wrapMode: Text.WordWrap
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Colors.textMuted
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: root._defaultPages

                        delegate: Rectangle {
                            required property var modelData

                            readonly property bool _selected:
                                SettingsService.data.superIsland.expandedDefaultPage === modelData.value

                            Layout.fillWidth: true
                            implicitHeight: 32
                            radius: Theme.cornerRadius - 2
                            color: _selected ? Colors.highlight : Colors.surface
                            opacity: _selected ? 0.92 : 0.64
                            border.color: _selected ? Colors.highlight : Colors.border
                            border.width: 1

                            Behavior on color {
                                ColorAnimation { duration: Theme.anim.highlightDuration }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                color: Colors.text
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root._setDefaultPage(parent.modelData.value)
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.cornerRadius
            color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.86)
            border.color: Colors.border
            border.width: 1

            SettingsModule.SettingsPanelContent {
                id: _settingsContent
                anchors.fill: parent
                anchors.margins: 10
            }
        }
    }
}
