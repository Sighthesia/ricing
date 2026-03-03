import QtQuick
import qs.config

// Settings panel with a persistent search bar at the top, left sidebar, and
// right page content. Typing in the search bar:
//   1. Shows a floating dropdown below the bar listing all matches + breadcrumbs.
//   2. Highlights matching items in-place and auto-expands containing groups.
// The normal sidebar + section layout stays visible at all times.
Item {
    id: root

    property string currentPage: "appearance"
    property string pendingSection: ""

    // Public API consumed by SettingsPanelWindow's click-to-deselect backdrop.
    function clearAllHighlights() {
        if (loader.item && loader.item.clearAllHighlights)
            loader.item.clearAllHighlights()
    }
    function dismissSearch() {
        searchField.focus = false
    }

    implicitWidth: Math.max(searchBar.implicitWidth, mainRow.implicitWidth)
    implicitHeight: searchBar.height + 6 + mainRow.implicitHeight

    // ── Master registry of all searchable settings ──────────────────
    readonly property var allSettingsItems: [
        { label: "强调色",     group: "外观 › 颜色", page: "appearance", section: "colors"    },
        { label: "背景色",     group: "外观 › 颜色", page: "appearance", section: "colors"    },
        { label: "表面色",     group: "外观 › 颜色", page: "appearance", section: "colors"    },
        { label: "文字色",     group: "外观 › 颜色", page: "appearance", section: "colors"    },
        { label: "次要文字",   group: "外观 › 颜色", page: "appearance", section: "colors"    },
        { label: "边框色",     group: "外观 › 颜色", page: "appearance", section: "colors"    },
        { label: "高度",       group: "外观 › Bar",  page: "appearance", section: "bar"       },
        { label: "透明度",     group: "外观 › Bar",  page: "appearance", section: "bar"       },
        { label: "内边距",     group: "外观 › Bar",  page: "appearance", section: "bar"       },
        { label: "小部件间距", group: "外观 › Bar",  page: "appearance", section: "bar"       },
        { label: "圆角",       group: "外观 › Bar",  page: "appearance", section: "bar"       },
        { label: "位置",       group: "外观 › Bar",  page: "appearance", section: "bar"       },
        { label: "速度系数",   group: "外观 › 动画", page: "appearance", section: "animation" },
        { label: "自动隐藏",   group: "外观 › 行为", page: "appearance", section: "behavior"  },
    ]

    property var filteredItems: {
        var q = searchField.text
        if (!q) return []
        q = q.toLowerCase()
        return allSettingsItems.filter(function(it) {
            return it.label.toLowerCase().indexOf(q) !== -1
                || it.group.toLowerCase().indexOf(q) !== -1
        })
    }

    // ── Search bar ──────────────────────────────────────────────────
    Item {
        id: searchBar
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 36
        implicitWidth: 360

        Rectangle {
            anchors.fill: parent
            radius: Theme.cornerRadius - 2
            color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.5)
            border.color: searchField.activeFocus ? Colors.highlight : Colors.border
            border.width: 1
            Behavior on border.color { ColorAnimation { duration: Theme.anim.highlightDuration } }
        }

        Text {
            id: searchIcon
            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
            text: "\uf002"
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeSmall
            color: Colors.textMuted
        }

        TextInput {
            id: searchField
            anchors { left: searchIcon.right; leftMargin: 8; right: clearBtn.left; rightMargin: 4; verticalCenter: parent.verticalCenter }
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Colors.text
            selectionColor: Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.35)
        }

        Text {
            visible: searchField.text === "" && !searchField.activeFocus
            anchors { left: searchField.left; verticalCenter: parent.verticalCenter }
            text: "搜索设置..."
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Colors.textMuted
        }

        Text {
            id: clearBtn
            visible: searchField.text !== ""
            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
            text: "\uf00d"
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeSmall
            color: Colors.textMuted
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: searchField.clear() }
        }
    }

    // ── Search dropdown (floats above content, z=10) ─────────────────
    Item {
        id: searchDropdown
        z: 10
        anchors { top: searchBar.bottom; topMargin: 2; left: parent.left; right: parent.right }
        height: visible ? Math.min(dropList.contentHeight + 16, 180) : 0
        visible: searchField.activeFocus && searchField.text !== "" && root.filteredItems.length > 0

        Rectangle {
            anchors.fill: parent
            radius: Theme.cornerRadius - 2
            color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.97)
            border.color: Colors.border
            border.width: 1

            // Subtle top shadow line for depth
            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 1 }
                height: 1
                color: Qt.rgba(1, 1, 1, 0.06)
            }
        }

        ListView {
            id: dropList
            anchors { fill: parent; margins: 6 }
            model: root.filteredItems
            clip: true
            spacing: 1
            boundsMovement: Flickable.StopAtBounds

            delegate: Item {
                required property var modelData
                width: dropList.width
                height: 36

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.cornerRadius - 4
                    color: dropItemArea.containsMouse ? Colors.highlight : "transparent"
                    opacity: dropItemArea.containsMouse ? 0.12 : 1
                    Behavior on opacity { NumberAnimation { duration: Theme.anim.highlightDuration } }
                }

                // Left-edge accent strip
                Rectangle {
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    width: 3; radius: 1
                    color: Colors.highlight
                    opacity: 0.8
                }

                Column {
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    spacing: 2
                    Text {
                        text: modelData.label
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Colors.text
                    }
                    Text {
                        text: modelData.group
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall - 2
                        color: Colors.textMuted
                    }
                }

                Text {
                    anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    text: "\uf105"
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall
                    color: Colors.textMuted
                    opacity: dropItemArea.containsMouse ? 1 : 0.4
                    Behavior on opacity { NumberAnimation { duration: Theme.anim.highlightDuration } }
                }

                MouseArea {
                    id: dropItemArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    // Keep search field focused so the dropdown stays open after click-through.
                    onPressed: searchField.forceActiveFocus()
                    onClicked: {
                        var page = modelData.page
                        var sectionId = modelData.section
                        searchField.clear()
                        if (root.currentPage !== page) {
                            root.currentPage = page
                            root.pendingSection = sectionId
                            // scrollDelay fires after Loader re-loads the new page
                        } else if (loader.item && loader.item.scrollToSection) {
                            loader.item.scrollToSection(sectionId)
                        }
                    }
                }
            }
        }
    }

    // ── Main content (sidebar + page loader) ────────────────────────
    Item {
        id: mainRow
        anchors { top: searchBar.bottom; topMargin: 6; left: parent.left; right: parent.right; bottom: parent.bottom }
        implicitWidth: sidebar.implicitWidth + contentItem.implicitWidth + 8
        implicitHeight: Math.max(sidebar.implicitHeight, contentItem.implicitHeight)

        SettingsSidebar {
            id: sidebar
            anchors { top: parent.top; left: parent.left; bottom: parent.bottom }
            currentPage: root.currentPage
            onPageSelected: (page) => root.currentPage = page
            onSectionRequested: (page, sectionId) => {
                if (root.currentPage !== page) {
                    root.currentPage = page
                    root.pendingSection = sectionId
                } else if (loader.item && loader.item.scrollToSection) {
                    loader.item.scrollToSection(sectionId)
                }
            }
        }

        Item {
            id: contentItem
            anchors { top: parent.top; left: sidebar.right; right: parent.right; bottom: parent.bottom; leftMargin: 8 }
            implicitWidth: loader.implicitWidth
            implicitHeight: loader.implicitHeight

            Loader {
                id: loader
                anchors.fill: parent
                source: {
                    switch (root.currentPage) {
                        case "appearance": return "AppearancePage.qml"
                        case "about":      return "AboutPage.qml"
                        default:           return "AppearancePage.qml"
                    }
                }
                onLoaded: {
                    if (loader.item && loader.item.hasOwnProperty("searchQuery"))
                        loader.item.searchQuery = Qt.binding(function() { return searchField.text })
                    if (root.pendingSection !== "")
                        scrollDelay.restart()
                }
            }
        }
    }

    Timer {
        id: scrollDelay
        interval: 60
        onTriggered: {
            if (root.pendingSection !== "" && loader.item && loader.item.scrollToSection) {
                loader.item.scrollToSection(root.pendingSection)
                root.pendingSection = ""
            }
        }
    }

    // Full-panel transparent click layer at the top of the z-stack.
    // Any click anywhere in the panel clears persistent jump highlights.
    // propagateComposedEvents ensures all underlying interactive elements
    // (sliders, toggles, buttons) still receive their click events normally.
    MouseArea {
        z: 200
        anchors.fill: parent
        propagateComposedEvents: true
        onClicked: (mouse) => {
            clearAllHighlights()
            mouse.accepted = false
        }
    }
}



