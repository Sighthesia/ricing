import QtQuick
import qs.config
import qs.services

// Bar behavior controls: top/bottom position selector and auto-hide toggle.
// Both controls write directly to SettingsService.
Item {
    id: root

    implicitWidth: 296
    implicitHeight: behaviorCol.implicitHeight

    Column {
        id: behaviorCol
        width: parent.width
        spacing: 0

        // Position selector row
        Item {
            width: parent.width
            height: Theme.settingsRowHeight

            Row {
                anchors.fill: parent
                anchors.leftMargin: Theme.settingsPanelPadding
                anchors.rightMargin: Theme.settingsPanelPadding
                spacing: 8

                Text {
                    width: Theme.settingsLabelWidth
                    anchors.verticalCenter: parent.verticalCenter
                    text: "位置"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Colors.textMuted
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Repeater {
                        model: [
                            { value: "top",    label: "顶部" },
                            { value: "bottom", label: "底部" }
                        ]

                        delegate: Rectangle {
                            required property var modelData

                            readonly property bool selected:
                                SettingsService.data.bar.position === modelData.value

                            width: 52; height: 24
                            radius: Theme.cornerRadius - 4
                            color: selected ? Colors.highlight : Colors.surface
                            opacity: selected ? 0.9 : 0.6

                            Behavior on color { ColorAnimation { duration: Theme.anim.highlightDuration } }

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
                                onClicked: SettingsService.data.bar.position = parent.modelData.value
                            }
                        }
                    }
                }
            }
        }

        // Auto-hide toggle row
        Item {
            width: parent.width
            height: Theme.settingsRowHeight

            Row {
                anchors.fill: parent
                anchors.leftMargin: Theme.settingsPanelPadding
                anchors.rightMargin: Theme.settingsPanelPadding
                spacing: 8

                Text {
                    width: Theme.settingsLabelWidth
                    anchors.verticalCenter: parent.verticalCenter
                    text: "自动隐藏"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Colors.textMuted
                }

                // Toggle switch
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 42; height: 24

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: SettingsService.data.barBehavior.autoHide
                            ? Colors.highlight : Colors.surface
                        opacity: 0.8

                        Behavior on color { ColorAnimation { duration: Theme.anim.highlightDuration } }
                    }

                    Rectangle {
                        id: knob
                        width: 18; height: 18
                        radius: 9
                        anchors.verticalCenter: parent.verticalCenter
                        color: Colors.text
                        x: SettingsService.data.barBehavior.autoHide ? 21 : 3

                        Behavior on x {
                            NumberAnimation {
                                duration: Theme.anim.moveDuration
                                easing.type: Easing.InOutCubic
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SettingsService.data.barBehavior.autoHide =
                            !SettingsService.data.barBehavior.autoHide
                    }
                }
            }
        }
    }
}
