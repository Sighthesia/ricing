import Quickshell
import QtQuick
import qs.config
import qs.services
import "./settings"

// Floating settings panel that appears below the Bar at the right side of the screen.
// Opens when BarLayoutService.activePanel === "config".
PanelWindow {
    id: panelWindow

    // Sit at top-right; top margin pushes the panel below the bar
    anchors { top: true; right: true }
    margins { top: Theme.barHeight }

    implicitWidth: 480
    implicitHeight: content.implicitHeight + 20
    color: "transparent"

    // Keyboard input for hex color editing
    focusable: true

    // Show only when config tab is active; PanelWindow visibility handles show/hide
    visible: BarLayoutService.activePanel === "config"

    // Panel background card
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 4
        anchors.rightMargin: 4
        anchors.bottomMargin: 4
        radius: Theme.cornerRadius
        color: Colors.background
        border.color: Colors.border
        border.width: 1

        // Subtle inner shadow effect: second border inset
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Theme.cornerRadius - 1
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.04)
            border.width: 1
        }

        // Clicking blank space inside the panel clears any jump-to highlights
        // and dismisses the search dropdown (unfocuses search field).
        MouseArea {
            anchors.fill: parent
            onClicked: {
                content.clearAllHighlights()
                content.dismissSearch()
            }
        }
    }

    SettingsPanelContent {
        id: content
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            topMargin: 10
            leftMargin: 4
            rightMargin: 8
            bottomMargin: 10
        }
    }
}
