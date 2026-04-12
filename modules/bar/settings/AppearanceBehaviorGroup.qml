import QtQuick
import qs.config
import qs.services
import ".."

// Behavior toggles for bar interaction policy.
StaggerItem {
    id: root

    property string searchQuery: ""
    property alias expanded: group.expanded
    property alias highlighted: group.highlighted

    width: parent ? parent.width : 0
    height: group.height
    delay: 360
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
        title: "行为"
        expanded: false
        forceExpand: root.groupMatches(["自动隐藏"])
        filterVisible: root.searchQuery === "" || root.groupMatches(["自动隐藏"])

        Item {
            id: autoHideRow
            width: parent ? parent.width : ThemeSettings.rowWidth
            readonly property bool filterVisible: root.searchQuery === "" || root.groupMatches(["自动隐藏"])
            readonly property int filterOrder: {
                if (!parent || !parent.children)
                    return 0

                for (let index = 0; index < parent.children.length; index++) {
                    if (parent.children[index] === autoHideRow)
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
                    PauseAnimation { duration: autoHideRow.filterOrder * SettingsService.effectiveAnimation.staggerExitStep }
                    NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
                }
            }

            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: autoHideRow.filterOrder * SettingsService.effectiveAnimation.staggerExitStep }
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
                    text: "自动隐藏"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Colors.textMuted
                }

                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: ThemeSettings.switchWidth
                    height: ThemeSettings.switchHeight

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: SettingsService.data.barBehavior.autoHide
                            ? Colors.highlight : Colors.surface
                        opacity: 0.8

                        Behavior on color { ColorAnimation { duration: Theme.anim.highlightDuration } }
                    }

                    Rectangle {
                        width: ThemeSettings.switchKnobSize
                        height: ThemeSettings.switchKnobSize
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
                        onClicked: {
                            SettingsService.data.barBehavior.autoHide =
                                !SettingsService.data.barBehavior.autoHide
                            SettingsService.save()
                        }
                    }
                }
            }
        }
    }
}
