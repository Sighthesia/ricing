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
        visible: root.searchQuery === "" || root.groupMatches(["自动隐藏"])
        height: visible ? implicitHeight : 0

        Item {
            width: parent ? parent.width : 296
            visible: root.searchQuery === "" || root.groupMatches(["自动隐藏"])
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
                    width: 42
                    height: 24

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: SettingsService.data.barBehavior.autoHide
                            ? Colors.highlight : Colors.surface
                        opacity: 0.8

                        Behavior on color { ColorAnimation { duration: Theme.anim.highlightDuration } }
                    }

                    Rectangle {
                        width: 18
                        height: 18
                        radius: 9
                        anchors.verticalCenter: parent.verticalCenter
                        color: Colors.text
                        x: SettingsService.data.barBehavior.autoHide ? 21 : 3

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
