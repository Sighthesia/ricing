import QtQuick
import qs.config

// Settings panel with a search bar, left sidebar, and right page content.
// Search bar is always visible at the top. When the user types a query the
// normal sidebar+page view is replaced with a flat SearchResultsView. Clicking
// a result clears the search and scrolls to the corresponding section.
Item {
    id: root

    property string currentPage: "appearance"
    property string pendingSection: ""

    implicitWidth: Math.max(searchBar.implicitWidth, mainRow.implicitWidth)
    implicitHeight: searchBar.height + 6 +
        (searchField.text !== "" ? searchResultsView.implicitHeight : mainRow.implicitHeight)

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

        // Search icon
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
            // Placeholder via a Text overlay
        }

        // Placeholder text
        Text {
            visible: searchField.text === "" && !searchField.activeFocus
            anchors { left: searchField.left; verticalCenter: parent.verticalCenter }
            text: "搜索设置..."
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Colors.textMuted
        }

        // Clear button
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

    // ── Main content (sidebar + page loader) ────────────────────────
    Item {
        id: mainRow
        anchors { top: searchBar.bottom; topMargin: 6; left: parent.left; right: parent.right; bottom: parent.bottom }
        visible: searchField.text === ""
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
                    if (root.pendingSection !== "")
                        scrollDelay.restart()
                }
            }
        }
    }

    // ── Search results overlay ──────────────────────────────────────
    // Covers the main content area while a query is active.
    SearchResultsView {
        id: searchResultsView
        anchors { top: searchBar.bottom; topMargin: 6; left: parent.left; right: parent.right }
        visible: searchField.text !== ""
        query: searchField.text
        onNavigateTo: (page, sectionId) => {
            searchField.clear()
            root.currentPage = page
            root.pendingSection = sectionId
            scrollDelay.restart()
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
}

