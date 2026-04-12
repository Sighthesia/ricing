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
        forceExpand: root.groupMatches(["壁纸路径", "动态主题色", "切换模式", "位置来源", "城市", "纬度", "经度", "深色开始", "浅色开始", "配色算法", "日出日落", "自定义", "深色模式"])
        filterVisible: root.searchQuery === "" || root.groupMatches(["壁纸路径", "动态主题色", "切换模式", "位置来源", "城市", "纬度", "经度", "深色开始", "浅色开始", "配色算法", "日出日落", "自定义", "深色模式"])

        Item {
            id: wallpaperPathRow
            width: parent ? parent.width : ThemeSettings.rowWidth
            implicitHeight: ThemeSettings.rowHeight
            readonly property bool filterVisible: root.searchQuery === "" || root.matches("壁纸路径")
            readonly property int filterOrder: {
                if (!parent || !parent.children)
                    return 0

                for (let index = 0; index < parent.children.length; index++) {
                    if (parent.children[index] === wallpaperPathRow)
                        return index
                }

                return 0
            }

            visible: height > 0.5 || opacity > 0.01
            opacity: filterVisible ? 1 : 0
            height: filterVisible ? implicitHeight : 0
            clip: true

            Behavior on height {
                SequentialAnimation {
                    PauseAnimation { duration: wallpaperPathRow.filterOrder * SettingsService.effectiveAnimation.staggerExitStep }
                    NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
                }
            }

            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: wallpaperPathRow.filterOrder * SettingsService.effectiveAnimation.staggerExitStep }
                    NumberAnimation { duration: Theme.anim.highlightDuration }
                }
            }

            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: ThemeSettings.highlightInset
                anchors.rightMargin: ThemeSettings.highlightInset
                radius: ThemeSettings.highlightRadius
                color: Colors.highlight
                opacity: root.matches("壁纸路径") && root.searchQuery !== "" ? 0.1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.anim.highlightDuration } }
            }

            Rectangle {
                anchors {
                    left: parent.left
                    top: parent.top
                    bottom: parent.bottom
                    leftMargin: ThemeSettings.highlightInset
                }
                width: ThemeSettings.accentStripWidth
                radius: ThemeSettings.accentStripRadius
                color: Colors.highlight
                opacity: root.matches("壁纸路径") && root.searchQuery !== "" ? 0.9 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.anim.highlightDuration } }
            }

            Row {
                anchors.fill: parent
                anchors.leftMargin: ThemeSettings.panelPadding
                anchors.rightMargin: ThemeSettings.panelPadding
                spacing: ThemeSettings.rowGap

                Text {
                    width: ThemeSettings.labelWidth
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
                    width: parent.width - ThemeSettings.labelWidth - browseBtn.width - parent.spacing * 2
                    height: parent.height - ThemeSettings.fieldVerticalInset
                    radius: ThemeSettings.fieldRadius
                    color: Colors.surface
                    border.color: wallpaperInput.activeFocus ? Colors.highlight : Colors.border
                    border.width: 1
                    Behavior on border.color { ColorAnimation { duration: Theme.anim.highlightDuration } }

                    TextInput {
                        id: wallpaperInput
                        anchors.fill: parent
                        anchors.leftMargin: ThemeSettings.fieldPaddingH
                        anchors.rightMargin: ThemeSettings.fieldPaddingH
                        anchors.topMargin: ThemeSettings.fieldPaddingV
                        anchors.bottomMargin: ThemeSettings.fieldPaddingV
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
                    width: browseBtnText.implicitWidth + ThemeSettings.panelPadding + ThemeSettings.highlightInset
                    height: parent.height - ThemeSettings.fieldVerticalInset
                    radius: ThemeSettings.fieldRadius
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
            enabled: SettingsService.data.appearance.darkModeScheduleMode === "manual"
            onToggled: function(v) {
                SettingsService.data.appearance.darkMode = v
                SettingsService.save()
                if (SettingsService.data.appearance.matugenEnabled)
                    WallpaperService.triggerMatugen()
                else
                    WallpaperService.syncAppearanceMode()
            }
        }

        SegmentedSection {
            label: "切换模式"
            filterQuery: root.searchQuery
            currentValue: SettingsService.data.appearance.darkModeScheduleMode
            options: [
                { label: "手动", value: "manual" },
                { label: "日出日落", value: "sunrise-sunset" },
                { label: "自定义", value: "custom-time" }
            ]
            onOptionSelected: function(value) {
                SettingsService.data.appearance.darkModeScheduleMode = value
                SettingsService.save()
                WallpaperService.refreshDarkModeSchedule()
            }
        }

        Item {
            id: scheduleStatusRow
            width: parent ? parent.width : ThemeSettings.rowWidth
            readonly property bool filterVisible: SettingsService.data.appearance.darkModeScheduleMode === "custom-time"
            readonly property int filterOrder: {
                if (!parent || !parent.children)
                    return 0
                for (let index = 0; index < parent.children.length; index++) {
                    if (parent.children[index] === scheduleStatusRow)
                        return index
                }
                return 0
            }

            visible: height > 0.5 || opacity > 0.01
            opacity: filterVisible ? 1 : 0
            height: filterVisible ? ThemeSettings.rowHeight : 0
            clip: true

            Behavior on height {
                SequentialAnimation {
                    PauseAnimation { duration: scheduleStatusRow.filterOrder * SettingsService.effectiveAnimation.staggerExitStep }
                    NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
                }
            }

            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: scheduleStatusRow.filterOrder * SettingsService.effectiveAnimation.staggerExitStep }
                    NumberAnimation { duration: Theme.anim.highlightDuration }
                }
            }

            Row {
                anchors.fill: parent
                anchors.leftMargin: ThemeSettings.panelPadding
                anchors.rightMargin: ThemeSettings.panelPadding
                spacing: ThemeSettings.rowGap

                Text {
                    width: ThemeSettings.labelWidth
                    anchors.verticalCenter: parent.verticalCenter
                    text: "当前状态"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Colors.textMuted
                    elide: Text.ElideRight
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - ThemeSettings.labelWidth - parent.spacing
                    text: WallpaperService.darkModeScheduleStatus
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall
                    color: Colors.text
                    elide: Text.ElideRight
                }
            }
        }

        SegmentedSection {
            label: "位置来源"
            filterQuery: root.searchQuery
            shown: SettingsService.data.appearance.darkModeScheduleMode === "sunrise-sunset"
            currentValue: SettingsService.data.appearance.darkModeScheduleLocationMode
            options: [
                { label: "经纬度", value: "coordinates" },
                { label: "城市", value: "city" }
            ]
            onOptionSelected: function(value) {
                SettingsService.data.appearance.darkModeScheduleLocationMode = value
                SettingsService.save()

                if (value === "city") {
                    if (SettingsService.data.appearance.darkModeScheduleCity !== "")
                        GeocodingService.lookupCity(SettingsService.data.appearance.darkModeScheduleCity)
                } else {
                    WallpaperService.refreshDarkModeSchedule()
                }
            }
        }

        TextFieldSection {
            label: "城市"
            filterQuery: root.searchQuery
            value: SettingsService.data.appearance.darkModeScheduleCity
            shown: SettingsService.data.appearance.darkModeScheduleMode === "sunrise-sunset"
                && SettingsService.data.appearance.darkModeScheduleLocationMode === "city"
            onTextEdited: function(newValue) {
                SettingsService.data.appearance.darkModeScheduleCity = newValue.trim()
                GeocodingService.requestCityLookup(newValue)
            }
            onValueCommitted: function(newValue) {
                SettingsService.data.appearance.darkModeScheduleCity = newValue
                SettingsService.save()
                GeocodingService.lookupCity(newValue)
            }
        }

        Item {
            id: geocodeStatusRow
            width: parent ? parent.width : ThemeSettings.rowWidth
            readonly property bool filterVisible:
                SettingsService.data.appearance.darkModeScheduleMode === "sunrise-sunset"
                && SettingsService.data.appearance.darkModeScheduleLocationMode === "city"
            readonly property int filterOrder: {
                if (!parent || !parent.children)
                    return 0

                for (let index = 0; index < parent.children.length; index++) {
                    if (parent.children[index] === geocodeStatusRow)
                        return index
                }

                return 0
            }

            visible: height > 0.5 || opacity > 0.01
            opacity: filterVisible ? 1 : 0
            height: filterVisible ? ThemeSettings.rowHeight : 0
            clip: true

            Behavior on height {
                SequentialAnimation {
                    PauseAnimation { duration: geocodeStatusRow.filterOrder * SettingsService.effectiveAnimation.staggerExitStep }
                    NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
                }
            }

            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: geocodeStatusRow.filterOrder * SettingsService.effectiveAnimation.staggerExitStep }
                    NumberAnimation { duration: Theme.anim.highlightDuration }
                }
            }

            Row {
                anchors.fill: parent
                anchors.leftMargin: ThemeSettings.panelPadding
                anchors.rightMargin: ThemeSettings.panelPadding
                spacing: ThemeSettings.rowGap

                Text {
                    width: ThemeSettings.labelWidth
                    anchors.verticalCenter: parent.verticalCenter
                    text: "城市解析"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Colors.textMuted
                    elide: Text.ElideRight
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - ThemeSettings.labelWidth - parent.spacing
                    text: GeocodingService.lookupStatusText
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall
                    color: GeocodingService.lookupState === "error" ? Colors.error : Colors.text
                    elide: Text.ElideRight
                }
            }
        }

        TextFieldSection {
            label: "纬度"
            filterQuery: root.searchQuery
            value: String(SettingsService.data.appearance.darkModeScheduleLatitude)
            shown: SettingsService.data.appearance.darkModeScheduleMode === "sunrise-sunset"
                && SettingsService.data.appearance.darkModeScheduleLocationMode === "coordinates"
            onValueCommitted: function(newValue) {
                SettingsService.data.appearance.darkModeScheduleLatitude = parseFloat(newValue)
                SettingsService.save()
                WallpaperService.refreshDarkModeSchedule()
            }
        }

        TextFieldSection {
            label: "经度"
            filterQuery: root.searchQuery
            value: String(SettingsService.data.appearance.darkModeScheduleLongitude)
            shown: SettingsService.data.appearance.darkModeScheduleMode === "sunrise-sunset"
                && SettingsService.data.appearance.darkModeScheduleLocationMode === "coordinates"
            onValueCommitted: function(newValue) {
                SettingsService.data.appearance.darkModeScheduleLongitude = parseFloat(newValue)
                SettingsService.save()
                WallpaperService.refreshDarkModeSchedule()
            }
        }

        TextFieldSection {
            label: "深色开始"
            filterQuery: root.searchQuery
            value: SettingsService.data.appearance.darkModeScheduleDarkStart
            enabled: SettingsService.data.appearance.darkModeScheduleMode === "custom-time"
            onValueCommitted: function(newValue) {
                SettingsService.data.appearance.darkModeScheduleDarkStart = newValue
                SettingsService.save()
                WallpaperService.refreshDarkModeSchedule()
            }
        }

        TextFieldSection {
            label: "浅色开始"
            filterQuery: root.searchQuery
            value: SettingsService.data.appearance.darkModeScheduleLightStart
            enabled: SettingsService.data.appearance.darkModeScheduleMode === "custom-time"
            onValueCommitted: function(newValue) {
                SettingsService.data.appearance.darkModeScheduleLightStart = newValue
                SettingsService.save()
                WallpaperService.refreshDarkModeSchedule()
            }
        }

        Item {
            id: schemeRowShell
            readonly property bool filterVisible: SettingsService.data.appearance.matugenEnabled
            readonly property int filterOrder: {
                if (!parent || !parent.children)
                    return 0

                for (let index = 0; index < parent.children.length; index++) {
                    if (parent.children[index] === schemeRowShell)
                        return index
                }

                return 0
            }

            visible: height > 0.5 || opacity > 0.01
            opacity: filterVisible ? 1 : 0
            height: filterVisible ? ThemeSettings.rowHeight : 0
            width: parent ? parent.width : ThemeSettings.rowWidth

            clip: true

            Behavior on height {
                SequentialAnimation {
                    PauseAnimation { duration: schemeRowShell.filterOrder * SettingsService.effectiveAnimation.staggerExitStep }
                    NumberAnimation { duration: Theme.anim.highlightDuration }
                }
            }

            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: schemeRowShell.filterOrder * SettingsService.effectiveAnimation.staggerExitStep }
                    NumberAnimation { duration: Theme.anim.highlightDuration }
                }
            }

            Row {
                anchors.fill: parent
                anchors.leftMargin: ThemeSettings.panelPadding
                anchors.rightMargin: ThemeSettings.panelPadding
                spacing: ThemeSettings.rowGap

                Text {
                    width: ThemeSettings.labelWidth
                    anchors.verticalCenter: parent.verticalCenter
                    text: "配色算法"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Colors.textMuted
                    elide: Text.ElideRight
                }

                Flickable {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - ThemeSettings.labelWidth - parent.spacing
                    height: ThemeSettings.rowHeight
                    contentWidth: schemeRow.implicitWidth
                    clip: true

                    Row {
                        id: schemeRow
                        spacing: ThemeSettings.behaviorOptionGap

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

                                width: schemeLabel.implicitWidth + ThemeSettings.panelPadding
                                height: Math.max(ThemeSettings.switchHeight - ThemeSettings.highlightInset * 2, Math.round(22 * Theme.uiScale))
                                radius: ThemeSettings.sidebarSurfaceRadius
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
