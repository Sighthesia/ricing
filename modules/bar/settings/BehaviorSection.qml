import QtQuick
import qs.config
import qs.services

// Bar behavior controls: top/bottom position selector and auto-hide toggle.
// Both controls write directly to SettingsService.
Item {
    id: root

    implicitWidth: ThemeSettings.rowWidth
    implicitHeight: behaviorCol.implicitHeight

    Column {
        id: behaviorCol
        width: parent.width
        spacing: 0

        // Position selector row
        Item {
            width: parent.width
            height: ThemeSettings.rowHeight

            Row {
                anchors.fill: parent
                anchors.leftMargin: ThemeSettings.panelPadding
                anchors.rightMargin: ThemeSettings.panelPadding
                spacing: ThemeSettings.rowGap

                Text {
                    width: ThemeSettings.labelWidth
                    anchors.verticalCenter: parent.verticalCenter
                    text: "位置"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Colors.textMuted
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: ThemeSettings.behaviorOptionGap

                    Repeater {
                        model: [
                            { value: "top",    label: "顶部" },
                            { value: "bottom", label: "底部" }
                        ]

                        delegate: Rectangle {
                            required property var modelData

                            readonly property bool selected:
                                SettingsService.data.bar.position === modelData.value

                            width: ThemeSettings.behaviorOptionWidth; height: ThemeSettings.switchHeight
                            radius: ThemeSettings.sidebarSurfaceRadius
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
            height: ThemeSettings.rowHeight

            Row {
                anchors.fill: parent
                anchors.leftMargin: ThemeSettings.panelPadding
                anchors.rightMargin: ThemeSettings.panelPadding
                spacing: ThemeSettings.rowGap

                Text {
                    width: ThemeSettings.labelWidth
                    anchors.verticalCenter: parent.verticalCenter
                    text: "自动隐藏"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Colors.textMuted
                }

                // Toggle switch
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: ThemeSettings.switchWidth; height: ThemeSettings.switchHeight

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: SettingsService.data.barBehavior.autoHide
                            ? Colors.highlight : Colors.surface
                        opacity: 0.8

                        Behavior on color { ColorAnimation { duration: Theme.anim.highlightDuration } }
                    }

                    Rectangle {
                        id: knob
                        width: ThemeSettings.switchKnobSize; height: ThemeSettings.switchKnobSize
                        radius: width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        color: Colors.text
                        x: SettingsService.data.barBehavior.autoHide
                            ? parent.width - width - ThemeSettings.switchInset
                            : ThemeSettings.switchInset

                        Behavior on x {
                            NumberAnimation {
                                duration: Theme.anim.moveDuration
                                easing.type: Theme.anim.moveType
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
