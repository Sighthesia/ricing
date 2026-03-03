import QtQuick
import qs.config
import qs.services

// Appearance settings page with four collapsible groups:
// Colors, Bar, Animation, Behavior.
Item {
    id: root

    implicitWidth: parent ? parent.width : 340
    implicitHeight: Math.min(pageFlickable.contentHeight + 8, 480)

    // Scroll to a named section and flash its header to draw attention.
    // Called by SettingsPanelContent after the sidebar sub-item is clicked.
    function scrollToSection(sectionId) {
        var map = {
            "colors":    groupColors,
            "bar":       groupBar,
            "animation": groupAnimation,
            "behavior":  groupBehavior
        }
        var group = map[sectionId]
        if (!group) return
        group.expanded = true
        pageFlickable.contentY = Math.max(0, group.y - 4)
        group.flash()
    }

    Flickable {
        id: pageFlickable
        anchors.fill: parent
        contentWidth: width
        contentHeight: pageCol.implicitHeight
        clip: true
        boundsMovement: Flickable.StopAtBounds

        Column {
            id: pageCol
            width: pageFlickable.width
            spacing: 4

            Item { width: 1; height: 4 }

            // ── 颜色 ───────────────────────────────────────────────
            ExpandableGroup {
                id: groupColors
                title: "颜色"
                expanded: true

                ColorSection {
                    label: "强调色"
                    value: SettingsService.data.appearance.accentColor
                    onValueCommitted: (v) => SettingsService.data.appearance.accentColor = v
                }
                ColorSection {
                    label: "背景色"
                    value: SettingsService.data.appearance.backgroundColor
                    onValueCommitted: (v) => SettingsService.data.appearance.backgroundColor = v
                }
                ColorSection {
                    label: "表面色"
                    value: SettingsService.data.appearance.surfaceColor
                    onValueCommitted: (v) => SettingsService.data.appearance.surfaceColor = v
                }
            }

            // ── Bar ────────────────────────────────────────────────
            ExpandableGroup {
                id: groupBar
                title: "Bar"
                expanded: true

                SliderSection {
                    label: "高度"
                    value: SettingsService.data.bar.height
                    from: 24; to: 60; stepSize: 1; unit: "px"
                    onValueCommitted: (v) => SettingsService.data.bar.height = v
                }

                SliderSection {
                    label: "透明度"
                    value: SettingsService.data.bar.backgroundOpacity
                    from: 0.0; to: 1.0; stepSize: 0.05
                    onValueCommitted: (v) => SettingsService.data.bar.backgroundOpacity = v
                }

                // Position selector (reuses BehaviorSection position row directly)
                Item {
                    width: parent ? parent.width : 296
                    height: 32

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        Text {
                            width: 60
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
            }

            // ── 动画 ───────────────────────────────────────────────
            ExpandableGroup {
                id: groupAnimation
                title: "动画"
                expanded: false

                SliderSection {
                    label: "速度系数"
                    value: SettingsService.data.animation.speedFactor
                    from: 0.2; to: 3.0; stepSize: 0.1; unit: "×"
                    onValueCommitted: (v) => SettingsService.data.animation.speedFactor = v
                }
            }

            // ── 行为 ───────────────────────────────────────────────
            ExpandableGroup {
                id: groupBehavior
                title: "行为"
                expanded: false

                // Auto-hide toggle
                Item {
                    width: parent ? parent.width : 296
                    height: 32

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        Text {
                            width: 60
                            anchors.verticalCenter: parent.verticalCenter
                            text: "自动隐藏"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: Colors.textMuted
                        }

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

            Item { width: 1; height: 8 }
        }
    }
}
