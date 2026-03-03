import QtQuick
import qs.config

// Settings panel with left sidebar navigation and right page content.
// Sidebar selects between top-level categories; each page renders
// collapsible ExpandableGroup sections for its settings.
Item {
    id: root

    property string currentPage: "appearance"

    implicitWidth: sidebar.implicitWidth + contentItem.implicitWidth + 8
    implicitHeight: Math.max(sidebar.implicitHeight, contentItem.implicitHeight)

    SettingsSidebar {
        id: sidebar
        anchors { top: parent.top; left: parent.left; bottom: parent.bottom }
        currentPage: root.currentPage
        onPageSelected: (page) => root.currentPage = page
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
        }
    }
}
