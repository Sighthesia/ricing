import QtQuick
import qs.services
import ".."

// Motion timing settings group for staggered panels and transitions.
StaggerItem {
    id: root

    property string searchQuery: ""
    property alias expanded: group.expanded
    property alias highlighted: group.highlighted

    width: parent ? parent.width : 0
    height: group.height
    delay: 300
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
        title: "动画"
        expanded: false
        forceExpand: root.groupMatches(["速度系数", "入场时长", "出场时长"])
        filterVisible: root.searchQuery === "" || root.groupMatches(["速度系数", "入场时长", "出场时长"])

        SliderSection {
            label: "速度系数"
            filterQuery: root.searchQuery
            value: SettingsService.data.animation.speedFactor
            from: 0.2
            to: 3.0
            stepSize: 0.1
            unit: "×"
            onValueCommitted: (v) => {
                SettingsService.data.animation.speedFactor = v
                SettingsService.save()
            }
        }

        SliderSection {
            label: "入场时长"
            filterQuery: root.searchQuery
            value: SettingsService.data.animation.staggerEnterDuration
            from: 60
            to: 600
            stepSize: 10
            unit: "ms"
            onValueCommitted: (v) => {
                SettingsService.data.animation.staggerEnterDuration = v
                SettingsService.save()
            }
        }

        SliderSection {
            label: "出场时长"
            filterQuery: root.searchQuery
            value: SettingsService.data.animation.staggerExitDuration
            from: 40
            to: 400
            stepSize: 10
            unit: "ms"
            onValueCommitted: (v) => {
                SettingsService.data.animation.staggerExitDuration = v
                SettingsService.save()
            }
        }
    }
}
