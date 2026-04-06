import QtQuick
import qs.services
import ".."

// Typography settings group for UI and monospace fonts.
StaggerItem {
    id: root

    property string searchQuery: ""
    property alias expanded: group.expanded
    property alias highlighted: group.highlighted

    width: parent ? parent.width : 0
    height: group.height
    delay: 180
    enterOffsetY: 22
    exitOffsetY: 10
    exitDelay: 0

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
        title: "字体"
        expanded: false
        forceExpand: root.groupMatches(["字体族", "等宽字体", "正文大小", "辅助大小", "图标大小"])
        filterVisible: root.searchQuery === "" || root.groupMatches(["字体族", "等宽字体", "正文大小", "辅助大小", "图标大小"])

        FontPickerSection {
            label: "字体族"
            filterQuery: root.searchQuery
            value: SettingsService.data.appearance.fontFamily
            onValueCommitted: (v) => {
                SettingsService.data.appearance.fontFamily = v
                SettingsService.save()
            }
        }
        FontPickerSection {
            label: "等宽字体"
            isMonospace: true
            filterQuery: root.searchQuery
            value: SettingsService.data.appearance.fontMono
            onValueCommitted: (v) => {
                SettingsService.data.appearance.fontMono = v
                SettingsService.save()
            }
        }
        SliderSection {
            label: "正文大小"
            filterQuery: root.searchQuery
            value: SettingsService.data.appearance.fontSizeBody
            from: 10
            to: 24
            stepSize: 1
            unit: "px"
            onValueCommitted: (v) => {
                SettingsService.data.appearance.fontSizeBody = v
                SettingsService.save()
            }
        }
        SliderSection {
            label: "辅助大小"
            filterQuery: root.searchQuery
            value: SettingsService.data.appearance.fontSizeSmall
            from: 8
            to: 18
            stepSize: 1
            unit: "px"
            onValueCommitted: (v) => {
                SettingsService.data.appearance.fontSizeSmall = v
                SettingsService.save()
            }
        }
        SliderSection {
            label: "图标大小"
            filterQuery: root.searchQuery
            value: SettingsService.data.appearance.fontSizeIcon
            from: 10
            to: 28
            stepSize: 1
            unit: "px"
            onValueCommitted: (v) => {
                SettingsService.data.appearance.fontSizeIcon = v
                SettingsService.save()
            }
        }
    }
}
