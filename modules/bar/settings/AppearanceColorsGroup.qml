import QtQuick
import qs.config
import qs.services
import ".."

// Manual color overrides used when dynamic theming is disabled.
StaggerItem {
    id: root

    property string searchQuery: ""
    property alias expanded: group.expanded
    property alias highlighted: group.highlighted

    width: parent ? parent.width : 0
    height: group.height
    delay: 120
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
        title: "颜色"
        expanded: true
        forceExpand: root.groupMatches(["强调色", "背景色", "表面色", "文字色", "次要文字", "边框色"])
        opacity: SettingsService.data.appearance.matugenEnabled ? 0.4 : 1.0
        Behavior on opacity { NumberAnimation { duration: Theme.anim.highlightDuration } }
        visible: root.searchQuery === "" || root.groupMatches(["强调色", "背景色", "表面色", "文字色", "次要文字", "边框色"])
        height: visible ? implicitHeight : 0

        ColorSection {
            label: "强调色"
            filterQuery: root.searchQuery
            value: SettingsService.data.appearance.accentColor
            onValueCommitted: (v) => {
                SettingsService.data.appearance.accentColor = v
                SettingsService.save()
            }
        }
        ColorSection {
            label: "背景色"
            filterQuery: root.searchQuery
            value: SettingsService.data.appearance.backgroundColor
            onValueCommitted: (v) => {
                SettingsService.data.appearance.backgroundColor = v
                SettingsService.save()
            }
        }
        ColorSection {
            label: "表面色"
            filterQuery: root.searchQuery
            value: SettingsService.data.appearance.surfaceColor
            onValueCommitted: (v) => {
                SettingsService.data.appearance.surfaceColor = v
                SettingsService.save()
            }
        }
        ColorSection {
            label: "文字色"
            filterQuery: root.searchQuery
            value: SettingsService.data.appearance.textColor
            onValueCommitted: (v) => {
                SettingsService.data.appearance.textColor = v
                SettingsService.save()
            }
        }
        ColorSection {
            label: "次要文字"
            filterQuery: root.searchQuery
            value: SettingsService.data.appearance.textMutedColor
            onValueCommitted: (v) => {
                SettingsService.data.appearance.textMutedColor = v
                SettingsService.save()
            }
        }
        ColorSection {
            label: "边框色"
            filterQuery: root.searchQuery
            value: SettingsService.data.appearance.borderColor
            onValueCommitted: (v) => {
                SettingsService.data.appearance.borderColor = v
                SettingsService.save()
            }
        }
    }
}
