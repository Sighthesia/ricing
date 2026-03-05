import QtQuick
import qs.config
import qs.services
import ".."

// Appearance settings page with five collapsible groups:
// Colors, Font, Bar, Animation, Behavior.
Item {
    id: root

    // Propagated from SettingsPanelContent. When non-empty, highlight matching items
    // in place and force-expand groups that contain matches.
    property string searchQuery: ""

    // Public stagger API — called by SettingsPanelContent when the panel opens/closes.
    function runEnterAnimation() {
        _siWallpaper.runEnter()
        _siColors.runEnter()
        _siFont.runEnter()
        _siBar.runEnter()
        _siAnimation.runEnter()
        _siBehavior.runEnter()
    }
    function runExitAnimation() {
        _siWallpaper.runExit()
        _siColors.runExit()
        _siFont.runExit()
        _siBar.runExit()
        _siAnimation.runExit()
        _siBehavior.runExit()
    }

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
            "wallpaper": groupWallpaper,
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
        groupWallpaper.highlighted = false
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

            // ── 壁纸 & 动态主题色 ──────────────────────────────────
            StaggerItem {
                id: _siWallpaper
                width: parent.width
                height: groupWallpaper.height
                delay:        60
                enterOffsetY: 22
                exitOffsetY:  10
                exitDelay: 0
            ExpandableGroup {
                id: groupWallpaper
                width: parent.width
                title: "壁纸 & 动态主题色"
                expanded: false
                forceExpand: root.groupMatches(["壁纸路径","动态主题色","配色算法","深色模式"])
                visible: root.searchQuery === "" || root.groupMatches(["壁纸路径","动态主题色","配色算法","深色模式"])
                height: visible ? implicitHeight : 0

                // ── Wallpaper path with file browser ──
                Item {
                    id: wallpaperPathRow
                    width: parent ? parent.width : 296
                    implicitHeight: Theme.settingsRowHeight
                    visible: root.searchQuery === "" || root.matches("壁纸路径")
                    height: visible ? implicitHeight : 0

                    // Search match highlight
                    Rectangle {
                        anchors.fill: parent
                        anchors.leftMargin: 4; anchors.rightMargin: 4
                        radius: 4
                        color: Colors.highlight
                        opacity: root.matches("壁纸路径") && root.searchQuery !== "" ? 0.1 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.anim.highlightDuration } }
                    }
                    Rectangle {
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; leftMargin: 4 }
                        width: 3; radius: 1
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

                        // Input field (shrunk to leave room for the browse button)
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
                                anchors.leftMargin: 6; anchors.rightMargin: 6
                                anchors.topMargin: 2; anchors.bottomMargin: 2
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

                        // Browse button
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

                // ── Enable dynamic theming ──
                ToggleSection {
                    label: "动态主题色"
                    filterQuery: root.searchQuery
                    value: SettingsService.data.appearance.matugenEnabled
                    onToggled: function(v) {
                        SettingsService.data.appearance.matugenEnabled = v
                        if (v) WallpaperService.triggerMatugen()
                    }
                }

                // ── Dark mode ──
                ToggleSection {
                    label: "深色模式"
                    filterQuery: root.searchQuery
                    value: SettingsService.data.appearance.darkMode
                    onToggled: function(v) {
                        SettingsService.data.appearance.darkMode = v
                        if (SettingsService.data.appearance.matugenEnabled)
                            WallpaperService.triggerMatugen()
                    }
                }

                // ── Scheme type picker (visible only when matugen is on) ──
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
            } // StaggerItem _siWallpaper

            // ── 颜色 ───────────────────────────────────────────────
            StaggerItem {
                id: _siColors
                width: parent.width
                height: groupColors.height
                delay:        120
                enterOffsetY: 22
                exitOffsetY:  10
                exitDelay: 0
            ExpandableGroup {
                id: groupColors
                width: parent.width
                title: "颜色"
                expanded: true
                forceExpand: root.groupMatches(["强调色","背景色","表面色","文字色","次要文字","边框色"])
                opacity: SettingsService.data.appearance.matugenEnabled ? 0.4 : 1.0
                Behavior on opacity { NumberAnimation { duration: Theme.anim.highlightDuration } }
                visible: root.searchQuery === "" || root.groupMatches(["强调色","背景色","表面色","文字色","次要文字","边框色"])
                height: visible ? implicitHeight : 0

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
            } // StaggerItem _siColors

            // ── 字体 ──────────────────────────────────────
            StaggerItem {
                id: _siFont
                width: parent.width
                height: groupFont.height
                delay:        180
                enterOffsetY: 22
                exitOffsetY:  10
                exitDelay: 0
            ExpandableGroup {
                id: groupFont
                width: parent.width
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
            } // StaggerItem _siFont

            // ── Bar ────────────────────────────────────────────────
            StaggerItem {
                id: _siBar
                width: parent.width
                height: groupBar.height
                delay:        240
                enterOffsetY: 22
                exitOffsetY:  10
                exitDelay: 0
            ExpandableGroup {
                id: groupBar
                width: parent.width
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
            } // StaggerItem _siBar

            // ── 动画 ───────────────────────────────────────────────
            StaggerItem {
                id: _siAnimation
                width: parent.width
                height: groupAnimation.height
                delay:        300
                enterOffsetY: 22
                exitOffsetY:  10
                exitDelay: 0
            ExpandableGroup {
                id: groupAnimation
                width: parent.width
                title: "动画"
                expanded: false
                forceExpand: root.groupMatches(["速度系数","入场时长","出场时长"])
                visible: root.searchQuery === "" || root.groupMatches(["速度系数","入场时长","出场时长"])
                height: visible ? implicitHeight : 0

                SliderSection {
                    label: "速度系数"
                    filterQuery: root.searchQuery
                    value: SettingsService.data.animation.speedFactor
                    from: 0.2; to: 3.0; stepSize: 0.1; unit: "×"
                    onValueCommitted: (v) => SettingsService.data.animation.speedFactor = v
                }

                SliderSection {
                    label: "入场时长"
                    filterQuery: root.searchQuery
                    value: SettingsService.data.animation.staggerEnterDuration
                    from: 60; to: 600; stepSize: 10; unit: "ms"
                    onValueCommitted: (v) => SettingsService.data.animation.staggerEnterDuration = v
                }

                SliderSection {
                    label: "出场时长"
                    filterQuery: root.searchQuery
                    value: SettingsService.data.animation.staggerExitDuration
                    from: 40; to: 400; stepSize: 10; unit: "ms"
                    onValueCommitted: (v) => SettingsService.data.animation.staggerExitDuration = v
                }
            }
            } // StaggerItem _siAnimation

            // ── 行为 ───────────────────────────────────────────────
            StaggerItem {
                id: _siBehavior
                width: parent.width
                height: groupBehavior.height
                delay:        360
                enterOffsetY: 22
                exitOffsetY:  10
                exitDelay: 0
            ExpandableGroup {
                id: groupBehavior
                width: parent.width
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
            } // StaggerItem _siBehavior

            Item { width: 1; height: 8 }
        }
    }
}
