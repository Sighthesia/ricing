import QtQuick
import qs.config
import qs.services

// Appearance settings page with five collapsible groups:
// Colors, Font, Bar, Animation, Behavior.
Item {
    id: root

    // Propagated from SettingsPanelContent. When non-empty, highlight matching items
    // in place and force-expand groups that contain matches.
    property string searchQuery: ""

    function matches(label) {
        if (!searchQuery) return false
        return label.toLowerCase().indexOf(searchQuery.toLowerCase()) !== -1
    }

    function groupMatches(labels) {
        if (!searchQuery) return false
        var q = searchQuery.toLowerCase()
        return labels.some(function(l) { return l.toLowerCase().indexOf(q) !== -1 })
    }

    implicitWidth: parent ? parent.width : 340
    implicitHeight: Math.min(pageFlickable.contentHeight + 8, 480)

    // Auto-clear highlights 3 seconds after a scroll-to-section jump.
    // Gives the user enough time to see which group was highlighted without
    // requiring an explicit click to dismiss.
    Timer {
        id: highlightClearTimer
        interval: 3000
        onTriggered: root.clearAllHighlights()
    }

    // Scroll to a named section, expand it if collapsed, and show a persistent
    // highlight on the group header. Cleared by clearAllHighlights().
    function scrollToSection(sectionId) {
        var map = {
            "colors":    groupColors,
            "font":      groupFont,
            "bar":       groupBar,
            "animation": groupAnimation,
            "behavior":  groupBehavior
        }
        var group = map[sectionId]
        if (!group) return
        group.expanded = true
        pageFlickable.contentY = Math.max(0, group.y - 4)
        // Clear any previously highlighted group first
        clearAllHighlights()
        group.highlighted = true
        group.flash()
        highlightClearTimer.restart()
    }

    // Remove persistent highlights from all groups.
    // Called when the user clicks on blank space in the panel.
    function clearAllHighlights() {
        groupColors.highlighted = false
        groupFont.highlighted = false
        groupBar.highlighted = false
        groupAnimation.highlighted = false
        groupBehavior.highlighted = false
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
                forceExpand: root.groupMatches(["主题预设","强调色","背景色","表面色","文字色","次要文字","边框色"])
                visible: root.searchQuery === "" || root.groupMatches(["主题预设","强调色","背景色","表面色","文字色","次要文字","边框色"])
                height: visible ? implicitHeight : 0

                ThemePresetPicker {
                    filterQuery: root.searchQuery
                }

                ColorSection {
                    label: "强调色"
                    filterQuery: root.searchQuery
                    value: SettingsService.data.appearance.accentColor
                    onValueCommitted: (v) => SettingsService.data.appearance.accentColor = v
                }
                ColorSection {
                    label: "背景色"
                    filterQuery: root.searchQuery
                    value: SettingsService.data.appearance.backgroundColor
                    onValueCommitted: (v) => SettingsService.data.appearance.backgroundColor = v
                }
                ColorSection {
                    label: "表面色"
                    filterQuery: root.searchQuery
                    value: SettingsService.data.appearance.surfaceColor
                    onValueCommitted: (v) => SettingsService.data.appearance.surfaceColor = v
                }
                ColorSection {
                    label: "文字色"
                    filterQuery: root.searchQuery
                    value: SettingsService.data.appearance.textColor
                    onValueCommitted: (v) => SettingsService.data.appearance.textColor = v
                }
                ColorSection {
                    label: "次要文字"
                    filterQuery: root.searchQuery
                    value: SettingsService.data.appearance.textMutedColor
                    onValueCommitted: (v) => SettingsService.data.appearance.textMutedColor = v
                }
                ColorSection {
                    label: "边框色"
                    filterQuery: root.searchQuery
                    value: SettingsService.data.appearance.borderColor
                    onValueCommitted: (v) => SettingsService.data.appearance.borderColor = v
                }
            }

            // ── 字体 ──────────────────────────────────────
            ExpandableGroup {
                id: groupFont
                title: "字体"
                expanded: false
                forceExpand: root.groupMatches(["字体族","等宽字体","正文大小","辅助大小","图标大小"])
                visible: root.searchQuery === "" || root.groupMatches(["字体族","等宽字体","正文大小","辅助大小","图标大小"])
                height: visible ? implicitHeight : 0

                FontPickerSection {
                    label: "字体族"
                    filterQuery: root.searchQuery
                    value: SettingsService.data.appearance.fontFamily
                    onValueCommitted: (v) => SettingsService.data.appearance.fontFamily = v
                }
                FontPickerSection {
                    label: "等宽字体"
                    isMonospace: true
                    filterQuery: root.searchQuery
                    value: SettingsService.data.appearance.fontMono
                    onValueCommitted: (v) => SettingsService.data.appearance.fontMono = v
                }
                SliderSection {
                    label: "正文大小"
                    filterQuery: root.searchQuery
                    value: SettingsService.data.appearance.fontSizeBody
                    from: 10; to: 24; stepSize: 1; unit: "px"
                    onValueCommitted: (v) => SettingsService.data.appearance.fontSizeBody = v
                }
                SliderSection {
                    label: "辅助大小"
                    filterQuery: root.searchQuery
                    value: SettingsService.data.appearance.fontSizeSmall
                    from: 8; to: 18; stepSize: 1; unit: "px"
                    onValueCommitted: (v) => SettingsService.data.appearance.fontSizeSmall = v
                }
                SliderSection {
                    label: "图标大小"
                    filterQuery: root.searchQuery
                    value: SettingsService.data.appearance.fontSizeIcon
                    from: 10; to: 28; stepSize: 1; unit: "px"
                    onValueCommitted: (v) => SettingsService.data.appearance.fontSizeIcon = v
                }
            }

            // ── Bar ────────────────────────────────────────────────
            ExpandableGroup {
                id: groupBar
                title: "Bar"
                expanded: true
                forceExpand: root.groupMatches(["全局缩放","高度","透明度","内边距","小部件间距","圆角","位置"])
                visible: root.searchQuery === "" || root.groupMatches(["全局缩放","高度","透明度","内边距","小部件间距","圆角","位置"])
                height: visible ? implicitHeight : 0

                SliderSection {
                    label: "全局缩放"
                    filterQuery: root.searchQuery
                    value: SettingsService.data.appearance.uiScale
                    from: 0.75; to: 1.5; stepSize: 0.05; unit: "×"
                    onValueCommitted: (v) => SettingsService.data.appearance.uiScale = v
                }

                SliderSection {
                    label: "高度"
                    filterQuery: root.searchQuery
                    value: SettingsService.data.bar.height
                    from: 24; to: 60; stepSize: 1; unit: "px"
                    onValueCommitted: (v) => SettingsService.data.bar.height = v
                }

                SliderSection {
                    label: "透明度"
                    filterQuery: root.searchQuery
                    value: SettingsService.data.bar.backgroundOpacity
                    from: 0.0; to: 1.0; stepSize: 0.05
                    onValueCommitted: (v) => SettingsService.data.bar.backgroundOpacity = v
                }

                SliderSection {
                    label: "内边距"
                    filterQuery: root.searchQuery
                    value: SettingsService.data.bar.padding
                    from: 0; to: 20; stepSize: 1; unit: "px"
                    onValueCommitted: (v) => SettingsService.data.bar.padding = v
                }

                SliderSection {
                    label: "小部件间距"
                    filterQuery: root.searchQuery
                    value: SettingsService.data.bar.widgetSpacing
                    from: 0; to: 20; stepSize: 1; unit: "px"
                    onValueCommitted: (v) => SettingsService.data.bar.widgetSpacing = v
                }

                SliderSection {
                    label: "圆角"
                    filterQuery: root.searchQuery
                    value: SettingsService.data.appearance.cornerRadius
                    from: 0; to: 24; stepSize: 1; unit: "px"
                    onValueCommitted: (v) => SettingsService.data.appearance.cornerRadius = v
                }

                // Position selector (reuses BehaviorSection position row directly)
                Item {
                    width: parent ? parent.width : 296
                    visible: root.searchQuery === "" || root.matches("位置")
                    height: visible ? Theme.settingsRowHeight : 0

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
            }

            // ── 动画 ───────────────────────────────────────────────
            ExpandableGroup {
                id: groupAnimation
                title: "动画"
                expanded: false
                forceExpand: root.groupMatches(["速度系数"])
                visible: root.searchQuery === "" || root.groupMatches(["速度系数"])
                height: visible ? implicitHeight : 0

                SliderSection {
                    label: "速度系数"
                    filterQuery: root.searchQuery
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
                forceExpand: root.groupMatches(["自动隐藏","位置"])
                visible: root.searchQuery === "" || root.groupMatches(["自动隐藏","位置"])
                height: visible ? implicitHeight : 0

                // Auto-hide toggle
                Item {
                    width: parent ? parent.width : 296
                    visible: root.searchQuery === "" || root.matches("自动隐藏")
                    height: visible ? Theme.settingsRowHeight : 0

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
