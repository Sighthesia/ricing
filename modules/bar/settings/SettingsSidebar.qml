import QtQuick
import qs.config
import qs.services
import ".."

// Left navigation sidebar with two-level hierarchy.
// Top-level categories can be expanded to reveal sub-section shortcuts.
// Signals:
//   pageSelected(page)          — switch active page
//   sectionRequested(page, id)  — scroll to named section within the page
Item {
    id: root

    property string currentPage: "appearance"
    signal pageSelected(string page)
    signal sectionRequested(string page, string sectionId)

    // Stagger animation signals: broadcast to all nav item delegates so they
    // can calculate their own delay from their index.
    signal enterAnimationTriggered
    signal exitAnimationTriggered

    function runEnterAnimation() { enterAnimationTriggered() }
    function runExitAnimation()  { exitAnimationTriggered() }

    // Track expanded state for each top-level category by index.
    property var expandedStates: [true, false]

    implicitWidth: 108
    implicitHeight: navCol.implicitHeight + 16

    readonly property var navModel: [
        {
            page: "appearance", icon: "\uf53f", label: "外观",
            sections: [
                { id: "colors",    label: "颜色" },
                { id: "font",      label: "字体" },
                { id: "bar",       label: "Bar"  },
                { id: "animation", label: "动画" },
                { id: "behavior",  label: "行为" }
            ]
        },
        {
            page: "about", icon: "\uf05a", label: "关于",
            sections: []
        }
    ]

    // Background fills the full allocated height (driven by parent anchors,
    // not by sidebar implicitHeight) so it never shrinks during item collapse.
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.5)
        radius: Theme.cornerRadius
    }

    Column {
        id: navCol
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 8; topMargin: 12 }
        spacing: 2

        Repeater {
            model: root.navModel
            delegate: StaggerItem {
                required property var modelData
                required property int index

                id: delegateCol
                delay:        80 + index * 60
                enterOffsetY: 28
                exitOffsetY:  14
                exitDelay:    index * 20
                width: parent.width
                height: topItem.height + subCol.height

                readonly property bool isActive:   root.currentPage === modelData.page
                readonly property bool isExpanded: root.expandedStates[index]

                // Broadcast to sub-item StaggerItems when sub-items should enter/exit.
                signal subEnterTriggered
                signal subExitTriggered

                onIsExpandedChanged: {
                    if (isExpanded)
                        subEnterTriggered()
                    else
                        subExitTriggered()
                }

                Connections {
                    target: root
                    function onEnterAnimationTriggered() {
                        delegateCol.runEnter()
                        // If sub-items are already visible when panel opens, stagger them in too.
                        if (delegateCol.isExpanded)
                            Qt.callLater(function() { delegateCol.subEnterTriggered() })
                    }
                    function onExitAnimationTriggered()  { delegateCol.runExit()  }
                }

                // ── Top-level category row ─────────────────────────────────────
                Item {
                    id: topItem
                    width: parent.width
                    height: Theme.settingsRowHeight

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.cornerRadius - 4
                        color: Colors.highlight
                        opacity: isActive ? 0.25 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.anim.highlightDuration } }
                    }

                    // Hover wipe — only active when the item is not the current page.
                    HoverRevealHighlight {
                        id: topHighlight
                        anchors.fill: parent
                        radius: Theme.cornerRadius - 4
                        hovered: topArea.containsMouse && !isActive
                        highlightColor: Colors.surface
                        highlightOpacity: 0.5
                    }

                    // Expand arrow shown only when sub-items exist
                    Text {
                        visible: modelData.sections.length > 0
                        anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                        text: "\uf105"
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeSmall
                        color: Colors.textMuted
                        rotation: isExpanded ? 90 : 0
                        Behavior on rotation { NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType } }
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.icon
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeSmall + 1
                            color: isActive ? Colors.highlight : Colors.textMuted
                            Behavior on color { ColorAnimation { duration: Theme.anim.highlightDuration } }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: isActive ? Colors.text : Colors.textMuted
                            font.weight: isActive ? Font.Medium : Font.Normal
                            Behavior on color { ColorAnimation { duration: Theme.anim.highlightDuration } }
                        }
                    }

                    ClickRipple {
                        id: topRipple
                        anchors.fill: parent
                        radius: Theme.cornerRadius - 4
                        rippleColor: Colors.highlight
                    }

                    MouseArea {
                        id: topArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: (mouse) => {
                            topRipple.triggerRipple(mouse.x, mouse.y)
                            root.pageSelected(modelData.page)
                            // Toggle sub-items for categories that have them
                            if (modelData.sections.length > 0) {
                                var newStates = root.expandedStates.slice()
                                newStates[index] = !newStates[index]
                                root.expandedStates = newStates
                            }
                        }
                    }
                }

                // ── Collapsible sub-items ──────────────────────────────────────
                Column {
                    id: subCol
                    anchors.top: topItem.bottom
                    anchors.topMargin: 1
                    // Capture the parent page for use inside the inner Repeater delegate
                    property string pageId: modelData.page
                    width: parent.width
                    spacing: 1
                    // Animate height to zero instead of toggling visibility for a smooth collapse.
                    clip: true
                    height: isExpanded && modelData.sections.length > 0 ? implicitHeight : 0
                    Behavior on height { NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType } }

                    Repeater {
                        model: modelData.sections
                        delegate: StaggerItem {
                            required property var modelData
                            required property int index

                            id: subDelegate
                            width: parent.width
                            height: Theme.settingsGroupHeaderHeight
                            delay:        40 + index * 40
                            // Sub-items are inside a clipped Column, so Y-offset would be
                            // visually cut off. Use opacity-only stagger (enterOffsetY: 0).
                            enterOffsetY: 0
                            exitOffsetY:  0
                            exitDelay:    index * 12

                            Connections {
                                target: delegateCol
                                function onSubEnterTriggered() { subDelegate.runEnter() }
                                function onSubExitTriggered()  { subDelegate.runExit()  }
                            }

                            HoverRevealHighlight {
                                id: subHighlight
                                anchors { fill: parent; leftMargin: 8 }
                                radius: Theme.cornerRadius - 4
                                hovered: subArea.containsMouse
                                highlightColor: Colors.surface
                                highlightOpacity: 0.5
                            }

                            Text {
                                anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                                text: modelData.label
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall - 1
                                color: Colors.textMuted
                            }

                            ClickRipple {
                                id: subRipple
                                anchors { fill: parent; leftMargin: 8 }
                                radius: Theme.cornerRadius - 4
                                rippleColor: Colors.highlight
                            }

                            MouseArea {
                                id: subArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                // subCol.pageId captures the outer category page string.
                                onClicked: (mouse) => {
                                    subRipple.triggerRipple(mouse.x, mouse.y)
                                    root.sectionRequested(subCol.pageId, modelData.id)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
