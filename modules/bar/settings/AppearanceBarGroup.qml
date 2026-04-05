import QtQuick
import qs.config
import qs.services
import ".."

// Bar geometry and placement settings group.
StaggerItem {
    id: root

    property string searchQuery: ""
    property alias expanded: group.expanded
    property alias highlighted: group.highlighted

    width: parent ? parent.width : 0
    height: group.height
    delay: 240
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
        title: "Bar"
        expanded: true
        forceExpand: root.groupMatches(["全局缩放", "高度", "透明度", "内边距", "小部件间距", "圆角", "位置", "伪屏幕圆角"])
        visible: root.searchQuery === "" || root.groupMatches(["全局缩放", "高度", "透明度", "内边距", "小部件间距", "圆角", "位置", "伪屏幕圆角"])
        height: visible ? implicitHeight : 0

        SliderSection {
            label: "全局缩放"
            filterQuery: root.searchQuery
            value: SettingsService.data.appearance.uiScale
            from: 0.75
            to: 1.5
            stepSize: 0.05
            unit: "×"
            onValueCommitted: (v) => {
                SettingsService.data.appearance.uiScale = v
                SettingsService.save()
            }
        }

        SliderSection {
            label: "高度"
            filterQuery: root.searchQuery
            value: SettingsService.data.bar.height
            from: 24
            to: 60
            stepSize: 1
            unit: "px"
            onValueCommitted: (v) => {
                SettingsService.data.bar.height = v
                SettingsService.save()
            }
        }

        SliderSection {
            label: "透明度"
            filterQuery: root.searchQuery
            value: SettingsService.data.bar.backgroundOpacity
            from: 0.0
            to: 1.0
            stepSize: 0.05
            onValueCommitted: (v) => {
                SettingsService.data.bar.backgroundOpacity = v
                SettingsService.save()
            }
        }

        SliderSection {
            label: "内边距"
            filterQuery: root.searchQuery
            value: SettingsService.data.bar.padding
            from: 0
            to: 20
            stepSize: 1
            unit: "px"
            onValueCommitted: (v) => {
                SettingsService.data.bar.padding = v
                SettingsService.save()
            }
        }

        SliderSection {
            label: "小部件间距"
            filterQuery: root.searchQuery
            value: SettingsService.data.bar.widgetSpacing
            from: 0
            to: 20
            stepSize: 1
            unit: "px"
            onValueCommitted: (v) => {
                SettingsService.data.bar.widgetSpacing = v
                SettingsService.save()
            }
        }

        SliderSection {
            label: "圆角"
            filterQuery: root.searchQuery
            value: SettingsService.data.appearance.cornerRadius
            from: 0
            to: 24
            stepSize: 1
            unit: "px"
            onValueCommitted: (v) => {
                SettingsService.data.appearance.cornerRadius = v
                SettingsService.save()
            }
        }

        SliderSection {
            label: "伪屏幕圆角"
            filterQuery: root.searchQuery
            value: SettingsService.data.appearance.screenCornerRadius
            from: 0
            to: 24
            stepSize: 1
            unit: "px"
            onValueCommitted: (v) => {
                SettingsService.data.appearance.screenCornerRadius = v
                SettingsService.save()
            }
        }

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
                            { value: "top", label: "顶部" },
                            { value: "bottom", label: "底部" }
                        ]

                        delegate: Rectangle {
                            required property var modelData

                            readonly property bool selected:
                                SettingsService.data.bar.position === modelData.value

                            width: 52
                            height: 24
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
                                onClicked: {
                                    SettingsService.data.bar.position = parent.modelData.value
                                    SettingsService.save()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
