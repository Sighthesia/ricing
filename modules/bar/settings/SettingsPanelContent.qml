import QtQuick
import qs.config

// Settings panel with left sidebar navigation and right page content.
// Sidebar selects between top-level categories; each page renders
// collapsible ExpandableGroup sections for its settings.
Item {
    id: root

    property string currentPage: "appearance"

    // Holds the section id to scroll to once the Loader finishes loading a new page.
    property string pendingSection: ""

    implicitWidth: sidebar.implicitWidth + contentItem.implicitWidth + 8
    implicitHeight: Math.max(sidebar.implicitHeight, contentItem.implicitHeight)

    SettingsSidebar {
        id: sidebar
        anchors { top: parent.top; left: parent.left; bottom: parent.bottom }
        currentPage: root.currentPage
        onPageSelected: (page) => root.currentPage = page
        onSectionRequested: (page, sectionId) => {
            if (root.currentPage !== page) {
                // Page change triggers Loader reload; defer scroll until onLoaded.
                root.currentPage = page
                root.pendingSection = sectionId
            } else if (loader.item && loader.item.scrollToSection) {
                loader.item.scrollToSection(sectionId)
            }
        }
    }

    Item {
        id: contentItem
        anchors {
            top: parent.top; left: sidebar.right; right: parent.right; bottom: parent.bottom
            leftMargin: 8
        }
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
            // After a page switch, execute any deferred scroll-to-section.
            onLoaded: {
                if (root.pendingSection !== "")
                    scrollDelay.restart()
            }
        }
    }

    // Small delay lets the newly loaded page finish its layout pass before scrolling.
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
