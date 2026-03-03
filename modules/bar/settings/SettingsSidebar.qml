import QtQuick
import qs.config

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

    // Track expanded state for each top-level category by index.
    property var expandedStates: [true, false]

    implicitWidth: 108
    implicitHeight: navCol.implicitHeight + 16

    readonly property var navModel: [
        {
            page: "appearance", icon: "\uf53f", label: "外观",
            sections: [
                { id: "colors",    label: "颜色" },
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
            delegate: Column {
                required property var modelData
                required property int index

                width: parent.width
                spacing: 1

                readonly property bool isActive:   root.currentPage === modelData.page
                readonly property bool isExpanded: root.expandedStates[index]

                // ── Top-level category row ─────────────────────────────────────
                Item {
                    id: topItem
                    width: parent.width
                    height: 34

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.cornerRadius - 4
                        color: isActive ? Colors.highlight : (topArea.containsMouse ? Colors.surface : "transparent")
                        opacity: isActive ? 0.25 : 0.5
                        Behavior on color { ColorAnimation { duration: Theme.anim.highlightDuration } }
                    }

                    // Expand arrow shown only when sub-items exist
                    Text {
                        visible: modelData.sections.length > 0
                        anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                        text: "\uf105"
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                        color: Colors.textMuted
                        rotation: isExpanded ? 90 : 0
                        Behavior on rotation { NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Easing.InOutCubic } }
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

                    MouseArea {
                        id: topArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
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
                    // Capture the parent page for use inside the inner Repeater delegate
                    property string pageId: modelData.page
                    width: parent.width
                    spacing: 1
                    // Animate height to zero instead of toggling visibility for a smooth collapse.
                    clip: true
                    height: isExpanded && modelData.sections.length > 0 ? implicitHeight : 0
                    Behavior on height { NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Easing.InOutCubic } }

                    Repeater {
                        model: modelData.sections
                        delegate: Item {
                            required property var modelData
                            width: parent.width
                            height: 28

                            Rectangle {
                                anchors { fill: parent; leftMargin: 8 }
                                radius: Theme.cornerRadius - 4
                                color: subArea.containsMouse ? Colors.surface : "transparent"
                                opacity: 0.5
                                Behavior on color { ColorAnimation { duration: Theme.anim.highlightDuration } }
                            }

                            Text {
                                anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                                text: modelData.label
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall - 1
                                color: Colors.textMuted
                            }

                            MouseArea {
                                id: subArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                // subCol.pageId captures the outer category page string.
                                onClicked: root.sectionRequested(subCol.pageId, modelData.id)
                            }
                        }
                    }
                }
            }
        }
    }
}
